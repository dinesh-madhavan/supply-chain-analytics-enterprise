# DAX Measures — Supply Chain Analytics semantic model

> Create a measures table (`_Measures`) in Power BI and add each of these.
> Mark `'gold dim_date'` as the date table (Model view → gold dim_date → Mark as date table → `full_date`).
> Relationships: each `'gold dim_*'[*_key]` → `'gold fact_sales'[*_key]`, single direction, 1-to-many.
> Note: tables imported from the `gold` schema land in Power BI as `gold <table_name>` (with a space), so they must be wrapped in single quotes in DAX.

## Core measures
```dax
Total Sales = SUM ( 'gold fact_sales'[sales] )

Total Profit = SUM ( 'gold fact_sales'[profit] )

Total Orders = DISTINCTCOUNT ( 'gold fact_sales'[order_id] )

Total Units = SUM ( 'gold fact_sales'[quantity] )

Profit Margin % =
DIVIDE ( [Total Profit], [Total Sales] )

Avg Order Value =
DIVIDE ( [Total Sales], [Total Orders] )
```

## Supply-chain / delivery KPIs
```dax
On-Time Orders =
CALCULATE ( COUNTROWS ( 'gold fact_sales' ), 'gold fact_sales'[is_late] = FALSE )

On-Time Delivery % =
DIVIDE ( [On-Time Orders], COUNTROWS ( 'gold fact_sales' ) )

Late Delivery Risk % =
AVERAGE ( 'gold fact_sales'[late_delivery_risk] )      -- column is 0/1

Avg Delivery Days =
AVERAGE ( 'gold fact_sales'[delivery_days] )

Late Orders =
CALCULATE ( COUNTROWS ( 'gold fact_sales' ), 'gold fact_sales'[is_late] = TRUE )
```

## Time intelligence (the "intermediate" signal — include these)
```dax
Sales YTD =
TOTALYTD ( [Total Sales], 'gold dim_date'[full_date] )

Sales Last Month =
CALCULATE ( [Total Sales], DATEADD ( 'gold dim_date'[full_date], -1, MONTH ) )

Sales MoM % =
VAR CurrVal = [Total Sales]
VAR Prev    = [Sales Last Month]
RETURN DIVIDE ( CurrVal - Prev, Prev )

Sales 3-Month Rolling Avg =
AVERAGEX (
    DATESINPERIOD ( 'gold dim_date'[full_date], MAX ( 'gold dim_date'[full_date] ), -3, MONTH ),
    [Total Sales]
)
```

## Conditional formatting helper (flag bad regions red)
```dax
On-Time Status Colour =
SWITCH (
    TRUE (),
    [On-Time Delivery %] < 0.90, "#D64550",   -- red
    [On-Time Delivery %] < 0.95, "#E9C46A",   -- amber
    "#2A9D8F"                                  -- green
)
```

## Validation
Each measure should match the SQL in `sql/04_analysis_queries.sql`.
E.g. `[On-Time Delivery %]` with a Region slicer = Q2's `on_time_pct / 100`.
If they differ, check relationship direction and the `is_late` logic.
