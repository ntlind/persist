import pytest
from fastapi.testclient import TestClient
from main import create_app
import json
from unittest.mock import patch

app = create_app()
client = TestClient(app)

valid_card = {
    "front": "Hello",
    "back": "こんにちは",
    "tags": ["basic", "greetings"],
}

invalid_card = {
    "front": "Hello",
    "back": "こんにちは",
    # Missing tags field
}


@pytest.fixture
def mock_cards():
    return [
        {
            "front": "Hello",
            "back": "こんにちは",
            "tags": ["basic", "greetings"],
        },
        {
            "front": "Goodbye",
            "back": "さようなら",
            "tags": ["basic", "greetings"],
        },
    ]


def test_get_cards_success(mock_cards):
    with patch("core.card_processing.load_cards", return_value=mock_cards):
        response = client.get("/cards")
        assert response.status_code == 200
        assert response.json() == mock_cards


def test_get_cards_file_not_found():
    with patch(
        "core.card_processing.load_cards", side_effect=FileNotFoundError
    ):
        response = client.get("/cards")
        assert response.status_code == 404
        assert response.json() == {"detail": "Cards data file not found"}


def test_get_cards_invalid_json():
    with patch(
        "core.card_processing.load_cards",
        side_effect=json.JSONDecodeError("", "", 0),
    ):
        response = client.get("/cards")
        assert response.status_code == 400
        assert response.json() == {
            "detail": "Invalid JSON format in cards data file"
        }


def test_save_cards_success(mock_cards):
    with patch("core.card_processing.update_cards") as mock_update:
        response = client.post("/cards", json=mock_cards)
        assert response.status_code == 200
        mock_update.assert_called_once_with(mock_cards)


def test_save_cards_error():
    with patch(
        "core.card_processing.update_cards",
        side_effect=Exception("Test error"),
    ):
        response = client.post("/cards", json=[valid_card])
        assert response.status_code == 500
        assert response.json() == {"detail": "Test error"}


def test_add_cards_success():
    with patch("core.card_processing.add_cards") as mock_add:
        response = client.post("/add_cards", json=[valid_card])
        assert response.status_code == 200
        assert response.json() == {"message": "Successfully added 1 cards"}
        mock_add.assert_called_once_with([valid_card])


def test_add_cards_missing_fields():
    response = client.post("/add_cards", json=[invalid_card])
    assert response.status_code == 400
    assert response.json() == {"detail": "Missing required fields"}


def test_add_cards_error():
    with patch(
        "core.card_processing.add_cards", side_effect=Exception("Test error")
    ):
        response = client.post("/add_cards", json=[valid_card])
        assert response.status_code == 500
        assert response.json() == {"detail": "Test error"}
