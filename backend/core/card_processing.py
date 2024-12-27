import json
from pathlib import Path
import sqlite3
from typing import List, Dict, Any, Union


def load_cards() -> List[Dict[str, Any]]:
    """Load all flashcards from the SQLite database.

    Parameters
    ----------
    None

    Returns
    -------
    list of dict
        List of dictionaries containing card information with fields:

        - id : int
            Unique identifier for the card
        - front : str
            Front side text of the flashcard
        - back : str
            Back side text of the flashcard
        - last_asked : str
            Date when card was last reviewed (YYYY-MM-DD format)
        - next_review : str
            Date when card should be reviewed next (YYYY-MM-DD format)
        - retired : bool
            Whether the card has been retired from active review
        - tags : list of str
            List of strings containing card tags
        - images : list
            List of image references associated with the card
        - answers : dict
            Dictionary containing review statistics with fields:
            - correct : int
                Number of correct answers
            - partial : int
                Number of partial answers
            - incorrect : int
                Number of incorrect answers
        - streak : int
            Current streak of correct answers

    """
    db_path = Path(__file__).parent.parent / "data" / "cards.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute(
        """
    SELECT
        c.id,
        c.front,
        c.back,
        c.last_asked,
        c.next_review,
        c.retired,
        c.streak,
        c.images,
        a.correct,
        a.partial,
        a.incorrect,
        GROUP_CONCAT(t.name, ',') as tags
    FROM cards c
    JOIN answers a ON c.answers_id = a.id
    LEFT JOIN card_tags ct ON c.id = ct.card_id
    LEFT JOIN tags t ON ct.tag_id = t.id
    GROUP BY c.id
    """
    )

    cards = []
    for row in cursor.fetchall():
        (
            id_,
            front,
            back,
            last_asked,
            next_review,
            retired,
            streak,
            images_json,
            correct,
            partial,
            incorrect,
            tags,
        ) = row
        tags = tags.split(",") if tags else []
        images = json.loads(images_json) if images_json else []

        card = {
            "id": id_,
            "front": front,
            "back": back,
            "last_asked": last_asked,
            "next_review": next_review,
            "retired": bool(retired),
            "tags": tags,
            "images": images,
            "answers": {
                "correct": correct,
                "partial": partial,
                "incorrect": incorrect,
            },
            "streak": streak,
        }
        cards.append(card)

    conn.close()
    return cards


def update_cards(cards: List[Dict[str, Any]]) -> None:
    """Update multiple cards in bulk with transaction support.

    Parameters
    ----------
    cards : list of dict
        List of card dictionaries to update. Each dictionary must contain:

        - id : int
            Card identifier (must exist in database)
        - front : str
            Front side text
        - back : str
            Back side text
        - retired : bool
            Retirement status
        - streak : int
            Current streak
        - answers : dict
            Dictionary with keys 'correct', 'partial', 'incorrect'
        - tags : list of str
            List of tag strings

    Raises
    ------
    ValueError
        If a card with the specified ID is not found in the database
    Exception
        If any database operation fails, the entire transaction is rolled back

    Notes
    -----
    This function performs all updates within a single transaction,
    ensuring database consistency. If any operation fails, all changes
    are rolled back.
    """
    db_path = Path(__file__).parent.parent / "data" / "cards.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    try:
        cursor.execute("BEGIN TRANSACTION")

        for card in cards:
            cursor.execute("SELECT id FROM cards WHERE id = ?", (card["id"],))
            if not cursor.fetchone():
                raise ValueError(f"Card with ID {card['id']} not found")

            cursor.execute(
                """
                UPDATE cards
                SET front = ?, back = ?, retired = ?, streak = ?
                WHERE id = ?
                """,
                (
                    card["front"],
                    card["back"],
                    card["retired"],
                    card["streak"],
                    card["id"],
                ),
            )

            cursor.execute(
                """
                UPDATE answers
                SET correct = ?, partial = ?, incorrect = ?
                WHERE id = (SELECT answers_id FROM cards WHERE id = ?)
                """,
                (
                    card["answers"]["correct"],
                    card["answers"]["partial"],
                    card["answers"]["incorrect"],
                    card["id"],
                ),
            )

            cursor.execute(
                "DELETE FROM card_tags WHERE card_id = ?", (card["id"],)
            )
            for tag in card["tags"]:
                cursor.execute(
                    "INSERT OR IGNORE INTO tags (name) VALUES (?)",
                    (tag.lower(),),
                )
                cursor.execute(
                    "SELECT id FROM tags WHERE name = ?", (tag.lower(),)
                )
                tag_id = cursor.fetchone()[0]
                cursor.execute(
                    "INSERT INTO card_tags (card_id, tag_id) VALUES (?, ?)",
                    (card["id"], tag_id),
                )

        cursor.execute("COMMIT")
        print(f"Successfully updated {len(cards)} cards in bulk")

    except Exception as e:
        # Rollback on error
        cursor.execute("ROLLBACK")
        print(f"Error updating cards: {str(e)}")
        raise

    finally:
        conn.close()


def add_cards(new_cards: List[Dict[str, Union[str, List[str]]]]) -> None:
    """Add new flashcards to the SQLite database.

    Parameters
    ----------
    new_cards : list of dict
        List of new card dictionaries. Each dictionary must contain:

        - front : str
            Front side text
        - back : str
            Back side text
        - tags : list of str
            List of tag strings

    Notes
    -----
    The function automatically:

    - Creates new answer records with zero counts
    - Sets default values for last_asked and next_review to '2024-01-01'
    - Initializes retired status as False and streak as 0
    - Creates new tags if they don't exist in the database
    - Associates cards with their tags
    """
    db_path = Path(__file__).parent.parent / "data" / "cards.db"
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    for card in new_cards:
        cursor.execute(
            "INSERT INTO answers (correct, partial, incorrect) VALUES (?, ?, ?)",
            (0, 0, 0),
        )
        answers_id = cursor.lastrowid

        cursor.execute(
            """
            INSERT INTO cards (
                front, back, last_asked, next_review, retired, streak, answers_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                card["front"],
                card["back"],
                "2024-01-01",
                "2024-01-01",
                False,
                0,
                answers_id,
            ),
        )
        card_id = cursor.lastrowid

        for tag in card["tags"]:
            cursor.execute(
                "INSERT OR IGNORE INTO tags (name) VALUES (?)", (tag.lower(),)
            )

            cursor.execute(
                "SELECT id FROM tags WHERE name = ?", (tag.lower(),)
            )
            tag_id = cursor.fetchone()[0]

            cursor.execute(
                "INSERT INTO card_tags (card_id, tag_id) VALUES (?, ?)",
                (card_id, tag_id),
            )

    conn.commit()
    conn.close()
    print(f"Successfully added {len(new_cards)} cards")
