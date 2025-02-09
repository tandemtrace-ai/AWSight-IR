import json
import os
from typing import Any, Dict
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from functools import lru_cache
from dotenv import load_dotenv
from llm import get_llm_response

# Load environment variables
load_dotenv()

# Initialize FastAPI app
app = FastAPI(
    title="IR AWS CMDB API",
    description="API for AWS Infrastructure Analysis",
    version="1.0.0"
)

# Configure CORS
origins = [
    "http://localhost:5173",
    "http://localhost:8000",
    "http://localhost:80",
    "http://0.0.0.0:80",
    "http://18.170.218.29:80",
    "http://172.31.31.254:80",
    "http://18.170.218.29",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_aws_infra_data() -> Dict[str, Any]:
    """
    Load AWS infrastructure data from JSON file.
    Raises HTTPException if file not found or invalid JSON.
    """
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
    """
    Endpoint to retrieve AWS infrastructure data
    """
    return get_aws_infra_data()

@app.get("/api/faq", response_model=Dict[str, Any])
async def get_faq():
    """
    Endpoint to get FAQ responses based on infrastructure analysis
    """
    data = get_aws_infra_data()
    faq = generate_faq(data["account_id"])
    return {"faq": faq}

@lru_cache(maxsize=128)
def generate_faq(account_id: int) -> Dict[str, str]:
    """
    Generate FAQ responses using LLM.
    Cached by account_id to improve performance.
    """
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
    """
    Endpoint to get response for a specific question about the infrastructure
    """
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
    """
    Get LLM response for a specific question.
    Cached by account_id and question to improve performance.
    """
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

# Health check endpoint
@app.get("/health")
async def health_check():
    """
    Health check endpoint to verify API is running
    """
    return {"status": "healthy", "version": "1.0.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)