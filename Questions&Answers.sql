--2. DATA EXPLORATION

--1.What day of the week is used for each week_date value?

SELECT week_date, 
       DATEPART(WEEKDAY, CONVERT(DATE, week_date, 3)) AS DayOfWeekNumber, 
       DATENAME(WEEKDAY, CONVERT(DATE, week_date, 3)) AS DayOfWeekName
FROM data_mart.clean_weekly_sales
GROUP BY week_date
ORDER BY week_date;

--2.What range of week numbers are missing from the dataset?

WITH Weeks AS (
    SELECT DISTINCT DATEPART(WEEK, CONVERT(DATE, week_date, 3)) AS week_num,
                    DATEPART(YEAR, CONVERT(DATE, week_date, 3)) AS year_num
    FROM data_mart.clean_weekly_sales
)

, AllWeeks AS (
    SELECT DISTINCT a.week_num, w.year_num
    FROM (VALUES (1), (2), (3), (4), (5), (6), (7), (8), (9), (10), (11), (12), 
                 (13), (14), (15), (16), (17), (18), (19), (20), (21), (22), (23), (24), 
                 (25), (26), (27), (28), (29), (30), (31), (32), (33), (34), (35), (36), 
                 (37), (38), (39), (40), (41), (42), (43), (44), (45), (46), (47), (48), 
                 (49), (50), (51), (52)) AS a(week_num),
                 Weeks w
)

SELECT a.week_num as missing_weeks, a.year_num
FROM AllWeeks a
LEFT JOIN Weeks w ON a.week_num = w.week_num AND a.year_num = w.year_num
WHERE w.week_num IS NULL
ORDER BY a.year_num, a.week_num;

--3.How many total transactions were there for each year in the dataset?

SELECT calendar_year,
       SUM(transactions) AS total_transactions
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year
ORDER BY calendar_year;

--4.What is the total sales for each region for each month?

SELECT
	calendar_year,
	month_number,
	region,
	SUM (CAST(sales as BIGINT)) as total_sales
FROM data_mart.clean_weekly_sales
GROUP BY month_number,region,calendar_year
ORDER BY calendar_year,month_number

--5.What is the total count of transactions for each platform?
SELECT
	platform,
	SUM(transactions) as total_count_transactions
FROM data_mart.clean_weekly_sales
GROUP BY platform

--6.What is the percentage of sales for Retail vs Shopify for each month?

WITH MonthlySales AS (
    -- Aggregating total sales by month, year, and platform
    SELECT
        calendar_year,
        month_number,
        platform,
        SUM(CAST(sales AS BIGINT)) AS platform_sales
    FROM data_mart.clean_weekly_sales
    GROUP BY calendar_year, month_number, platform
)

, TotalMonthlySales AS (
    -- Aggregating total sales by month and year (regardless of platform)
    SELECT
        calendar_year,
        month_number,
        SUM(platform_sales) AS total_month_sales
    FROM MonthlySales
    GROUP BY calendar_year, month_number
)

SELECT 
    ms.calendar_year,
    ms.month_number,
    ms.platform,
    ms.platform_sales,
    ROUND((CAST(ms.platform_sales AS FLOAT) / tms.total_month_sales) * 100,2) AS percentage_of_total
FROM MonthlySales ms
JOIN TotalMonthlySales tms ON ms.calendar_year = tms.calendar_year AND ms.month_number = tms.month_number
ORDER BY ms.calendar_year, ms.month_number, ms.platform;

--7.What is the percentage of sales by demographic for each year in the dataset?
WITH yearly_sales AS(
SELECT
	calendar_year,
	demographic,
	SUM(CAST(sales AS BIGINT)) AS demographic_sales
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year, demographic
)
,
total_yearly_sales AS (
	 SELECT
        calendar_year,
        SUM(demographic_sales) AS total_yearly_sales
    FROM yearly_sales
    GROUP BY calendar_year)
SELECT
	ys.calendar_year,
    ys.demographic,
    ys.demographic_sales,
    ROUND((CAST(ys.demographic_sales AS FLOAT) / tys.total_yearly_sales) * 100,2) AS percentage_of_total
FROM yearly_sales ys
JOIN total_yearly_sales tys ON ys.calendar_year = tys.calendar_year
ORDER BY ys.calendar_year, ys.demographic;

--8.Which age_band and demographic values contribute the most to Retail sales?
WITH all_sales AS (
SELECT
	age_band,
	demographic,
	SUM(CAST(sales AS BIGINT)) as total_sales,
	rank() OVER(ORDER BY SUM(CAST(sales AS BIGINT)) desc) AS rank
FROM data_mart.clean_weekly_sales
WHERE platform='Retail' AND age_band!='unknown' 
GROUP BY age_band,demographic
)

SELECT 
	age_band,
	demographic,
	total_sales
FROM all_sales
WHERE rank=1

--9.Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT 
    calendar_year,
    platform,
    SUM(CAST(sales AS BIGINT)) / SUM(transactions) AS avg_transaction_size
FROM data_mart.clean_weekly_sales
WHERE platform IN ('Retail', 'Shopify')
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform;


--3. BEFORE & AFTER ANALYSIS

--Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.

--1.What is the total sales for the 4 weeks before and after 2020-06-15? 

--2.What is the growth or reduction rate in actual values and percentage of sales?

-- Calculate the total sales for 4 weeks before and after 2020-06-15
WITH BeforeAfterSales AS (
    SELECT 
    CASE 
        WHEN week_date < '2020-06-15' THEN 'Before'
        ELSE 'After'
    END AS period,
    SUM(CAST(sales AS BIGINT)) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE 
    -- 4 weeks before 2020-06-15 up to the day before 2020-06-15
    (week_date BETWEEN DATEADD(WEEK, -4, '2020-06-15') AND DATEADD(DAY, -1, '2020-06-15'))
    -- Or, the week of 2020-06-15 and the 3 weeks after
    OR (week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 3, '2020-06-15'))
GROUP BY 
    CASE 
        WHEN week_date < '2020-06-15' THEN 'Before'
        ELSE 'After'
    END
)

--Calculate the growth or reduction in actual values and percentage
SELECT 
    b.total_sales as BeforeSales,
    a.total_sales as AfterSales,
    (a.total_sales - b.total_sales) as Difference,
    ROUND(CAST((a.total_sales - b.total_sales) * 100.0 / b.total_sales AS DECIMAL(10,2)), 2) as GrowthReductionRate
FROM BeforeAfterSales a, BeforeAfterSales b
WHERE a.Period = 'After' AND b.Period = 'Before';

--3.What about the entire 12 weeks before and after?
WITH BeforeAfterSales AS (
    SELECT 
    CASE 
        WHEN week_date < '2020-06-15' THEN 'Before'
        ELSE 'After'
    END AS period,
    SUM(CAST(sales AS BIGINT)) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE 
    -- 12 weeks before 2020-06-15 up to the day before 2020-06-15
    (week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND DATEADD(DAY, -1, '2020-06-15'))
    -- Or, the week of 2020-06-15 and the 11 weeks after
    OR (week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 11, '2020-06-15'))
GROUP BY 
    CASE 
        WHEN week_date < '2020-06-15' THEN 'Before'
        ELSE 'After'
    END
)

-- Calculate the growth or reduction in actual values and percentage
SELECT 
    b.total_sales as BeforeSales,
    a.total_sales as AfterSales,
    (a.total_sales - b.total_sales) as Difference,
    ROUND(CAST((a.total_sales - b.total_sales) * 100.0 / b.total_sales AS DECIMAL(10,2)), 2) as GrowthReductionRate
FROM BeforeAfterSales a, BeforeAfterSales b
WHERE a.Period = 'After' AND b.Period = 'Before';

--4.How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

SELECT
	calendar_year,
	SUM(CAST(sales AS BIGINT)) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE calendar_year in ('2018','2019')
GROUP BY calendar_year
ORDER BY calendar_year

--4. BONUS QUESTION
/*Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

-region
-platform
-age_band
-demographic
-customer_type

*/
-- For Region
WITH BeforeSales AS (
    SELECT
        region,
        SUM(CAST(sales AS BIGINT)) as total_sales_before
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-14'
    GROUP BY region
),
AfterSales AS (
    SELECT
        region,
        SUM(CAST(sales AS BIGINT)) as total_sales_after
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY region
)
SELECT 
    b.region,
    b.total_sales_before,
    a.total_sales_after,
    (a.total_sales_after - b.total_sales_before) as Difference
FROM AfterSales a
JOIN BeforeSales b ON a.region = b.region
ORDER BY Difference;

-- You can repeat the above steps for platform, age_band, demographic, and customer_type.
-- For Platform
WITH BeforeSales AS (
    SELECT
        platform,
        SUM(CAST(sales AS BIGINT)) as total_sales_before
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-14'
    GROUP BY platform
),
AfterSales AS (
    SELECT
        platform,
        SUM(CAST(sales AS BIGINT)) as total_sales_after
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY platform
)
SELECT 
    b.platform,
    b.total_sales_before,
    a.total_sales_after,
    (a.total_sales_after - b.total_sales_before) as Difference
FROM AfterSales a
JOIN BeforeSales b ON a.platform = b.platform
ORDER BY Difference;

-- For Age_band
WITH BeforeSales AS (
    SELECT
        age_band,
        SUM(CAST(sales AS BIGINT)) as total_sales_before
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-14'
    GROUP BY age_band
),
AfterSales AS (
    SELECT
        age_band,
        SUM(CAST(sales AS BIGINT)) as total_sales_after
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY age_band
)
SELECT 
    b.age_band,
    b.total_sales_before,
    a.total_sales_after,
    (a.total_sales_after - b.total_sales_before) as Difference
FROM AfterSales a
JOIN BeforeSales b ON a.age_band = b.age_band
ORDER BY Difference;

-- For demographic
WITH BeforeSales AS (
    SELECT
        demographic,
        SUM(CAST(sales AS BIGINT)) as total_sales_before
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-14'
    GROUP BY demographic
),
AfterSales AS (
    SELECT
        demographic,
        SUM(CAST(sales AS BIGINT)) as total_sales_after
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY demographic
)
SELECT 
    b.demographic,
    b.total_sales_before,
    a.total_sales_after,
    (a.total_sales_after - b.total_sales_before) as Difference
FROM AfterSales a
JOIN BeforeSales b ON a.demographic = b.demographic
ORDER BY Difference;

-- For customer_type
WITH BeforeSales AS (
    SELECT
        customer_type,
        SUM(CAST(sales AS BIGINT)) as total_sales_before
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN DATEADD(WEEK, -12, '2020-06-15') AND '2020-06-14'
    GROUP BY customer_type
),
AfterSales AS (
    SELECT
        customer_type,
        SUM(CAST(sales AS BIGINT)) as total_sales_after
    FROM data_mart.clean_weekly_sales
    WHERE week_date BETWEEN '2020-06-15' AND DATEADD(WEEK, 12, '2020-06-15')
    GROUP BY customer_type
)
SELECT 
    b.customer_type,
    b.total_sales_before,
    a.total_sales_after,
    (a.total_sales_after - b.total_sales_before) as Difference
FROM AfterSales a
JOIN BeforeSales b ON a.customer_type = b.customer_type
ORDER BY Difference;