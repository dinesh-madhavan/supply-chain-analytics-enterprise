# Dataset — DataCo Smart Supply Chain

## What to download
**DataCo Smart Supply Chain for Big Data Analysis** — the richest public supply-chain dataset (orders, shipping, delivery, late-delivery risk, profit, customer segments).

- **Kaggle:** https://www.kaggle.com/datasets/shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
- **File you need:** `DataCoSupplyChainDataset.csv` (~180,000 order rows, 53 columns)
- Also grab `DescriptionDataCoSupplyChain.csv` (the data dictionary).

## How to download (pick one)

### Option A — Browser (easiest)
1. Sign in to kaggle.com (free).
2. Open the dataset link above → **Download** button → unzip.
3. Move `DataCoSupplyChainDataset.csv` into this `/data` folder.

### Option B — Kaggle CLI (Mac)
```bash
pip install kaggle
# put your kaggle.com API token at ~/.kaggle/kaggle.json (Account → Create New Token)
cd ~/Documents/Nova/supply-chain-analytics-enterprise/data
kaggle datasets download -d shashwatwork/dataco-smart-supply-chain-for-big-data-analysis
unzip dataco-smart-supply-chain-for-big-data-analysis.zip
```

## Encoding note
The CSV is **Latin-1 (ISO-8859-1)**, not UTF-8. When importing:
- **DBeaver / Postgres:** set encoding to `LATIN1` on import.
- **Power BI:** Get Data → CSV → File Origin = `Western European (ISO)`.

## Key columns you'll use
| Column | Use |
|--------|-----|
| `Order Id`, `Order Item Id` | grain of fact table |
| `order date (DateOrders)`, `shipping date (DateOrders)` | delivery_days, lateness |
| `Days for shipping (real)`, `Days for shipment (scheduled)` | on-time vs late |
| `Late_delivery_risk` | binary risk flag (0/1) |
| `Sales`, `Order Item Total`, `Benefit per order` (profit) | revenue + margin |
| `Order Item Quantity` | volume |
| `Customer Id`, `Customer Segment` | dim_customers |
| `Product Card Id`, `Category Name`, `Product Name` | dim_products |
| `Order Region`, `Order Country`, `Market` | dim_geography |
| `Shipping Mode`, `Delivery Status` | delivery analysis |

> Once the CSV is in this folder, run `sql/01_bronze_load.sql`.
