import json
import os
from typing import Any, Dict
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from functools import lru_cache
from dotenv import load_dotenv
from llm import get_llm_response

load_dotenv()

app = FastAPI(
    title="IR AWS CMDB API",
    description="API for AWS Infrastructure Analysis",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_aws_infra_data() -> Dict[str, Any]:
    try:
        with open("file.json", "r") as file:
            return json.load(file)
    except FileNotFoundError:
        raise HTTPException(
            status_code=500,
            detail="AWS infrastructure data file not found"
        )
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=500,
            detail="Invalid AWS infrastructure data format"
        )

@app.get("/api/data", response_model=Dict[str, Any])
async def get_data():
    return get_aws_infra_data()

@app.get("/api/faq", response_model=Dict[str, Any])
async def get_faq():
    data = get_aws_infra_data()
    faq = generate_faq(data["account_id"])
    return {"faq": faq}

@lru_cache(maxsize=128)
def generate_faq(account_id: int) -> Dict[str, str]:
    data = get_aws_infra_data()
    questions = """
    Q: Are there potential security concerns with any of the security groups?
    Q: Are there any IAM users with potentially excessive permissions?
    Q: What security risks are present in any of the VPC configuration?
    Q: Are there any instances exposing sensitive services to the public?
    Q: Is there adequate network segmentation and isolation?
    """
    
    prompt = (
        f"Based on next AWS infrastructure, answer to the questions '{questions}'. "
        "Return a json list with format {'question': 'response'}. "
        f"AWS infrastructure: \n {json.dumps(data, indent=2)}"
    )
    
    try:
        response = get_llm_response(prompt)
        return json.loads(response)
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=500,
            detail="Error processing LLM response"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error generating FAQ: {str(e)}"
        )

@app.get("/api/question", response_model=Dict[str, str])
async def ask_question(message: str):
    if not message:
        raise HTTPException(
            status_code=400,
            detail="Question cannot be empty"
        )
        
    data = get_aws_infra_data()
    response = get_response(data["account_id"], message)
    return {"response": response}

@lru_cache(maxsize=128)
def get_response(account_id: int, question: str) -> str:
    data = get_aws_infra_data()
    prompt = (
        f"Based on next AWS infrastructure, answer me to the question '{question}'. "
        f"AWS infrastructure: {json.dumps(data, indent=2)}"
    )
    
    try:
        return get_llm_response(prompt)
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error getting response: {str(e)}"
        )

@app.get("/health")
async def health_check():
    return {"status": "healthy", "version": "1.0.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
