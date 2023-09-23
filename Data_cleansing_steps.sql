--1. Data Cleansing Steps

-- If the table exists, drop it first
IF OBJECT_ID('data_mart.clean_weekly_sales', 'U') IS NOT NULL
  DROP TABLE data_mart.clean_weekly_sales;
GO

-- Create the new cleaned table
SELECT 
    -- Convert week_date to DATE format
    CONVERT(DATE, week_date, 3) AS week_date, 
    
    -- Add week_number column
    DATEPART(WEEK, CONVERT(DATE, week_date, 3)) AS week_number,
    
    -- Add month_number column
    DATEPART(MONTH, CONVERT(DATE, week_date, 3)) AS month_number,
    
    -- Add calendar_year column
    DATEPART(YEAR, CONVERT(DATE, week_date, 3)) AS calendar_year,
    
    -- Existing columns
    region, platform, 
    
    -- Handle NULL values in segment
    CASE 
        WHEN segment='null' THEN 'unknown'
        ELSE segment
    END AS segment,
    
    -- Add age_band column
    CASE 
        WHEN segment LIKE '%1' THEN 'Young Adults'
        WHEN segment LIKE '%2' THEN 'Middle Aged'
        WHEN segment LIKE '%3' OR segment LIKE '%4' THEN 'Retirees'
        ELSE 'unknown'
    END AS age_band,
    
    -- Add demographic column
    CASE 
        WHEN segment LIKE 'C%' THEN 'Couples'
        WHEN segment LIKE 'F%' THEN 'Families'
        ELSE 'unknown'
    END AS demographic,
    
    -- Existing columns
    customer_type, transactions, sales,
    
    -- Generate avg_transaction column
    ROUND(CAST(sales AS FLOAT) / transactions, 2) AS avg_transaction

INTO data_mart.clean_weekly_sales

FROM data_mart.weekly_sales;
GO
