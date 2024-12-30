from fastapi import FastAPI, HTTPException, Request
import json
from core import card_processing
import os


app = FastAPI()


@app.get("/cards")
async def get_cards():
    """Get all flashcards from the system.

    Returns
    -------
    list
        List of all cards in the system

    Raises
    ------
    HTTPException
        404 error if cards data file is not found
        400 error if cards data file contains invalid JSON
    """
    try:
        cards = card_processing.load_cards()
        return cards
    except FileNotFoundError:
        raise HTTPException(
            status_code=404, detail="Cards data file not found"
        )
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=400,
            detail="Invalid JSON format in cards data file",
        )


@app.post("/cards")
async def save_cards(request: Request):
    """Save a new set of cards, replacing all existing cards.

    Parameters
    ----------
    request : Request
        The request body should contain a JSON array of card objects.
        Each card should have 'front', 'back', and 'tags' fields.

    Returns
    -------
    None
        Returns nothing on success

    Raises
    ------
    HTTPException
        500 error if there's any error during processing
    """
    try:
        data = await request.json()
        card_processing.update_cards(data)
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/add_cards")
async def add_cards(request: Request):
    """Add new cards to the existing set of cards.

    Parameters
    ----------
    request : Request
        The request body should contain a JSON array of card objects.
        Each card must have 'front', 'back', and 'tags' fields.

    Returns
    -------
    dict
        A message indicating success and number of cards added

    Raises
    ------
    HTTPException
        400 error if required fields are missing
        500 error if there's any other error during processing

    Examples
    --------
    Request body:
    [
        {
            "front": "Hello",
            "back": "こんにちは",
            "tags": ["basic", "greetings"]
        }
    ]
    """
    try:
        data = await request.json()
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON format")

    # Each card should have front, back, and tags
    for card in data:
        if not all(k in card for k in ["front", "back", "tags"]):
            raise HTTPException(
                status_code=400, detail="Missing required fields"
            )

    try:
        card_processing.add_cards(data)
        return {"message": f"Successfully added {len(data)} cards"}
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.post("/shutdown")
async def shutdown():
    """Shutdown the backend server"""
    os._exit(0)  # Force immediate shutdown
