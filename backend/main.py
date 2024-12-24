from fastapi import FastAPI, HTTPException, Request
import json
from backend.core import card_processing

app = FastAPI()


@app.get("/cards")
async def get_cards():
    try:
        cards = card_processing.load_cards()
        return cards
    except FileNotFoundError:
        return {"error": "Cards data file not found"}
    except json.JSONDecodeError:
        return {"error": "Invalid JSON format in cards data file"}


@app.post("/cards")
async def save_cards(request: Request):
    try:
        data = await request.json()
        card_processing.save_cards(data)
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
