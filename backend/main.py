from fastapi import FastAPI
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
