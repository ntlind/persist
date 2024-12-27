import pytest
import sqlite3
from pathlib import Path
from backend.core import card_processing
import json
import tempfile
import os


@pytest.fixture
def test_db(monkeypatch):
    """Create a temporary test database with sample data."""
    temp_dir = tempfile.mkdtemp()

    data_dir = Path(temp_dir) / "data"
    data_dir.mkdir(exist_ok=True)
    test_db_path = data_dir / "cards.db"

    conn = sqlite3.connect(test_db_path)
    cursor = conn.cursor()

    cursor.executescript(
        """
        CREATE TABLE IF NOT EXISTS answers (
            id INTEGER PRIMARY KEY,
            correct INTEGER DEFAULT 0,
            partial INTEGER DEFAULT 0,
            incorrect INTEGER DEFAULT 0
        );

        CREATE TABLE IF NOT EXISTS cards (
            id INTEGER PRIMARY KEY,
            front TEXT NOT NULL,
            back TEXT NOT NULL,
            last_asked TEXT NOT NULL DEFAULT '2024-01-01',
            next_review TEXT NOT NULL DEFAULT '2024-01-01',
            retired BOOLEAN DEFAULT FALSE,
            streak INTEGER DEFAULT 0,
            images TEXT DEFAULT '[]',
            answers_id INTEGER,
            FOREIGN KEY (answers_id) REFERENCES answers (id)
        );

        CREATE TABLE IF NOT EXISTS tags (
            id INTEGER PRIMARY KEY,
            name TEXT UNIQUE NOT NULL
        );

        CREATE TABLE IF NOT EXISTS card_tags (
            card_id INTEGER,
            tag_id INTEGER,
            PRIMARY KEY (card_id, tag_id),
            FOREIGN KEY (card_id) REFERENCES cards (id),
            FOREIGN KEY (tag_id) REFERENCES tags (id)
        );
    """
    )

    cursor.execute(
        "INSERT INTO answers (correct, partial, incorrect) VALUES (5, 2, 1)"
    )
    answers_id = cursor.lastrowid

    cursor.execute(
        """
        INSERT INTO cards (
            front, back, last_asked, next_review, retired, streak,
            answers_id, images
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """,
        (
            "Test Front",
            "Test Back",
            "2024-01-01",
            "2024-01-01",
            False,
            3,
            answers_id,
            json.dumps(["image1.jpg"]),
        ),
    )
    card_id = cursor.lastrowid

    cursor.execute("INSERT INTO tags (name) VALUES (?)", ("python",))
    tag_id = cursor.lastrowid

    cursor.execute(
        "INSERT INTO card_tags (card_id, tag_id) VALUES (?, ?)",
        (card_id, tag_id),
    )

    conn.commit()
    conn.close()

    def mock_path(*args, **kwargs):
        return Path(temp_dir)

    monkeypatch.setattr(Path, "parent", property(lambda self: mock_path()))

    yield test_db_path

    try:
        os.remove(test_db_path)
        os.rmdir(data_dir)
        os.rmdir(temp_dir)
    except Exception as e:
        print(f"Cleanup error: {e}")


def test_load_cards(test_db):
    """Test loading cards from database."""
    cards = card_processing.load_cards()
    assert len(cards) == 1

    card = cards[0]
    assert card["front"] == "Test Front"
    assert card["back"] == "Test Back"
    assert card["retired"] is False
    assert card["streak"] == 3
    assert card["tags"] == ["python"]
    assert card["images"] == ["image1.jpg"]
    assert card["answers"] == {"correct": 5, "partial": 2, "incorrect": 1}


def test_add_cards(test_db):
    """Test adding new cards to database."""
    new_cards = [
        {
            "front": "New Front",
            "back": "New Back",
            "tags": ["python", "testing"],
        }
    ]

    card_processing.add_cards(new_cards)

    cards = card_processing.load_cards()
    assert len(cards) == 2

    new_card = [c for c in cards if c["front"] == "New Front"][0]
    assert new_card["back"] == "New Back"
    assert set(new_card["tags"]) == {"python", "testing"}
    assert new_card["streak"] == 0
    assert new_card["answers"] == {"correct": 0, "partial": 0, "incorrect": 0}


def test_update_cards(test_db):
    """Test updating cards with transaction support."""
    cards = card_processing.load_cards()
    card = cards[0]

    card["front"] = "Transaction Test"
    card["tags"] = ["python", "transaction"]

    card_processing.update_cards([card])

    updated_cards = card_processing.load_cards()
    updated = updated_cards[0]
    assert updated["front"] == "Transaction Test"
    assert set(updated["tags"]) == {"python", "transaction"}


def test_update_cards_invalid_id(test_db):
    """Test updating non-existent card raises error."""
    invalid_card = {
        "id": 999,
        "front": "Invalid",
        "back": "Card",
        "retired": False,
        "streak": 0,
        "tags": ["test"],
        "answers": {"correct": 0, "partial": 0, "incorrect": 0},
    }

    with pytest.raises(ValueError):
        card_processing.update_cards([invalid_card])
