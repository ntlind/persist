import json
from pathlib import Path
import polars as pl


def build_index_from_cards():
    pass


def load_cards():
    cards_path = Path(__file__).parent.parent / "data" / "cards.json"
    with open(cards_path, "r") as f:
        return json.load(f)


def convert_file_to_cards(
    file_path, front_back_delimiter="=>", card_delimiter="--------------"
):
    with open(file_path, "r") as f:
        full_text = f.read()

    sections = full_text.split(card_delimiter)
    sections = [s.strip() for s in sections if s.strip()]

    all_cards = []

    for section in sections:
        if "=>" in section:
            front, back = section.split(front_back_delimiter, 1)
            card = {"front": front.strip(), "back": back.strip()}
            all_cards.append(card)

    output_path = Path(f"backend/data/{Path(file_path).stem}.json")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(all_cards, f, indent=2)

    print(f"Successfully processed {len(all_cards)} cards")
    return all_cards


def load_filtered_cards(
    parquet_path, tags=None, date_range=None, retired=None
):
    """
    Load cards from parquet file with filtering on tags, date ranges, and retired status

    Args:
        parquet_path (str): Path to parquet file
        tags (list): List of tags to filter on. If any tag matches, include the card
        date_range (dict): Dictionary with 'start' and 'end' dates in format 'YYYY-MM-DD'
        retired (bool): Filter for retired status (True/False), or None for all cards

    Example usage:
    load_filtered_cards(
        'backend/data/cards.parquet',
        tags=['computer_science', 'llms'],
        date_range={'start': '2024-03-01', 'end': '2024-03-31'},
        retired=False
    )
    """
    # Read parquet file
    df = pl.read_parquet(parquet_path)

    # Filter by tags if specified
    if tags:
        df = df.filter(pl.col("tags").list.contains(tags))

    # Filter by date range if specified
    if date_range:
        df = df.with_columns(
            pl.col("next_review").str.strptime(pl.Date, "%Y-%m-%d")
        )
        df = df.filter(
            (pl.col("next_review") >= date_range["start"])
            & (pl.col("next_review") <= date_range["end"])
        )
        # Convert back to string format
        df = df.with_columns(pl.col("next_review").dt.strftime("%Y-%m-%d"))

    # Filter by retired status if specified
    if retired is not None:
        df = df.filter(pl.col("retired") == retired)

    # Convert to Python dictionaries
    return df.to_dicts()
