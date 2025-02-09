import os
from anthropic import Anthropic


def get_anthropic_client():
    return Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY"))


def get_llm_response(input: str):
    client = get_anthropic_client()
    message = client.messages.create(
        max_tokens=1024,
        system="You are a cybersecurity analyst expert",
        messages=[{"role": "user", "content": input}],
        model="claude-3-5-sonnet-latest",
    )
    return message.content[0].text
