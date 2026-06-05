"""
01_profile_and_load.py
----------------------------------------------------------------------
The Bronze step of the medallion pipeline.

  CSV (Kaggle)  →  THIS SCRIPT  →  bronze.orders_raw  →  Silver → Gold → Power BI

What this script does, in order:

  1. Reads the DataCo CSV from disk (it's Latin-1 encoded, not UTF-8 —
     pandas will explode if you don't tell it).
  2. Prints a data-quality profile to the terminal: row count, dtypes,
     where the nulls are, whether there are duplicates, basic stats on
     the money columns. This is the EDA step — read the output before
     you trust the data.
  3. Cleans the column names into snake_case so Postgres will accept
     them (Postgres hates spaces and parentheses in identifiers).
  4. Loads the dataframe into Postgres at `bronze.orders_raw`, every
     column as TEXT. No type casting, no value cleaning, no business
     rules. That all happens later in SQL.

Why Bronze keeps everything as text: if the typing logic later turns
out to be wrong, the raw source is still here, untouched, and the
whole pipeline can be re-run from it. Auditable provenance.

Run it:
    source ~/sc-venv/bin/activate
    python python/01_profile_and_load.py

Then move on to:
    psql supplychain -f sql/02_silver_transform.sql
"""

import re
import sys
import pandas as pd
from sqlalchemy import create_engine, text

# ---------------------------------------------------------------------
# CONFIG — edit if your paths or Postgres user differ.
# ---------------------------------------------------------------------
CSV_PATH      = "data/DataCoSupplyChainDataset.csv"
DB_URL        = "postgresql+psycopg2://dineshmadhavan@localhost:5432/supplychain"
BRONZE_SCHEMA = "bronze"
BRONZE_TABLE  = "orders_raw"


def load_csv(path: str) -> pd.DataFrame:
    """Read the raw DataCo CSV. It's ISO-8859-1, not UTF-8."""
    print(f"Reading {path} ...")
    try:
        df = pd.read_csv(path, encoding="ISO-8859-1", low_memory=False)
    except FileNotFoundError:
        sys.exit(
            f"\nERROR: CSV not found at '{path}'.\n"
            f"Download it from Kaggle (see data/DOWNLOAD.md) "
            f"and drop it into the data/ folder."
        )
    return df


def profile(df: pd.DataFrame) -> None:
    """Print a data-quality profile of the raw dataframe.

    This is the part the portfolio screenshot captures. It shows:
      - how big the dataset is
      - which columns are useless (100% null)
      - whether there are duplicate orders hiding
      - whether the money columns contain anything suspicious
        (e.g. negative profit — yes, DataCo has those).
    """
    print("\n" + "=" * 60)
    print("DATA QUALITY PROFILE")
    print("=" * 60)
    print(f"Rows: {df.shape[0]:,}   Columns: {df.shape[1]}")

    print("\n--- Column dtypes ---")
    print(df.dtypes.to_string())

    # Show the worst null offenders first — these are the columns
    # that either need to be dropped or have a coalesce plan in Silver.
    print("\n--- Null counts (top 15) ---")
    nulls = df.isna().sum().sort_values(ascending=False)
    print(nulls[nulls > 0].head(15).to_string() or "  (no nulls)")

    # Full-row duplicates first (rare but possible after a bad export),
    # then key-level duplicates (which would break grain assumptions).
    print("\n--- Duplicate rows ---")
    print(f"  full-row duplicates: {df.duplicated().sum():,}")
    for key in ["Order Item Id", "Order Id"]:
        if key in df.columns:
            print(f"  duplicate '{key}': {df.duplicated(subset=[key]).sum():,}")

    # Describe only the columns that actually matter analytically.
    # `describe()` on all 53 columns is noise.
    print("\n--- Numeric summary (key measures) ---")
    measure_cols = [c for c in [
        "Sales", "Order Item Total", "Order Profit Per Order",
        "Order Item Quantity", "Days for shipping (real)",
    ] if c in df.columns]
    if measure_cols:
        print(df[measure_cols].describe().round(2).to_string())

    # Sanity-check sample so I can eyeball the actual content.
    print("\n--- Sample (first 3 rows, selected cols) ---")
    show = [c for c in [
        "Order Id", "order date (DateOrders)", "Category Name",
        "Customer Segment", "Order Region", "Sales", "Late_delivery_risk",
    ] if c in df.columns]
    print(df[show].head(3).to_string() if show else df.head(3).to_string())
    print("=" * 60 + "\n")


def clean_columns(df: pd.DataFrame) -> pd.DataFrame:
    """Convert column names to snake_case.

    Postgres allows quoted identifiers like "Order Id" but it makes
    every downstream query painful. Better to fix it once, here.
    Rule: anything that isn't a letter/digit becomes an underscore,
    leading/trailing underscores stripped, then lowercase.
    """
    df = df.copy()
    df.columns = [
        re.sub(r"[^0-9a-zA-Z]+", "_", c).strip("_").lower()
        for c in df.columns
    ]
    return df


def load_to_postgres(df: pd.DataFrame) -> None:
    """Write the dataframe into bronze.orders_raw, every column as TEXT.

    Why TEXT for everything: this is the immutable Bronze layer.
    Casting happens in SQL (Silver). If a cast fails later, I can
    still see the raw value here without losing it.

    `if_exists="replace"` so this script is idempotent — running it
    twice gives the same result.
    """
    print(f"Loading {len(df):,} rows -> {BRONZE_SCHEMA}.{BRONZE_TABLE} ...")
    engine = create_engine(DB_URL)

    # Create the schema if it doesn't exist yet (first-run safety).
    with engine.begin() as conn:
        conn.execute(text(f"CREATE SCHEMA IF NOT EXISTS {BRONZE_SCHEMA};"))

    # Bulk-load in chunks so the round-trip cost stays low.
    df.astype(str).to_sql(
        BRONZE_TABLE, engine, schema=BRONZE_SCHEMA,
        if_exists="replace", index=False,
        chunksize=10_000, method="multi",
    )

    # Verify by counting rows back out — proves the load actually landed.
    with engine.connect() as conn:
        n = conn.execute(
            text(f"SELECT COUNT(*) FROM {BRONZE_SCHEMA}.{BRONZE_TABLE}")
        ).scalar()
    print(f"Done. {BRONZE_SCHEMA}.{BRONZE_TABLE} now has {n:,} rows.")
    print("Next: psql supplychain -f sql/02_silver_transform.sql")


if __name__ == "__main__":
    df = load_csv(CSV_PATH)
    profile(df)
    df = clean_columns(df)
    load_to_postgres(df)
