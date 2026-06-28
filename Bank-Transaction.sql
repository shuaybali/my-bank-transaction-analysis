-- ============================================================
-- PROJECT: My Bank Transaction Analysis (Lloyds Bank – UK)
-- AUTHOR: Ali Shuayb Ali
-- TOOLS: PostgreSQL, pgAdmin
-- PURPOSE: Analyse personal bank account transactions
--          Data cleaning, categorisation, spending trends,
--          growth/saving percentages, and rankings
-- ============================================================

-- ============================================================
-- 1. DATA CLEANING
-- ============================================================

-- Remove columns I don't need for analysis
ALTER TABLE account
DROP COLUMN IF EXISTS "Account Number",
DROP COLUMN IF EXISTS "Sort Code";

-- Check data types to make sure everything is correct
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'account';

-- ============================================================
-- 2. CLEANING TRANSACTION DESCRIPTIONS
-- ============================================================

-- Group all money transfer descriptions into one category
UPDATE account
SET "Transaction Description" = 'Money transfer'
WHERE "Transaction Description" ILIKE '%REAL REMIT LIMITED%'
   OR "Transaction Description" ILIKE '%WorldRemit%'
   OR "Transaction Description" ILIKE '%Dahabshiil%';

-- Small transfers are marked as family support
UPDATE account
SET "Transaction Description" = 'Family support'
WHERE "Transaction Description" = 'Money transfer'
  AND "Debit Amount" < 400;

-- ============================================================
-- 3. SPENDING CATEGORIES (UK Only)
-- ============================================================

WITH categorized AS (
    SELECT
        "Transaction Description",
        "Debit Amount",
        CASE
            WHEN "Transaction Description" ILIKE '%TESCO%' 
              OR "Transaction Description" ILIKE '%SAINSBURY%' 
              OR "Transaction Description" ILIKE '%ASDA%' 
              OR "Transaction Description" ILIKE '%MORRISON%' 
              OR "Transaction Description" ILIKE '%CO-OP%' 
              OR "Transaction Description" ILIKE '%WAITROSE%' 
              OR "Transaction Description" ILIKE '%ALDI%' 
              OR "Transaction Description" ILIKE '%LIDL%' THEN 'Supermarket'

            WHEN "Transaction Description" ILIKE '%AMAZON%' 
              OR "Transaction Description" ILIKE '%EBAY%' 
              OR "Transaction Description" ILIKE '%ASOS%' 
              OR "Transaction Description" ILIKE '%BOOHOO%' THEN 'Online Shopping'

            WHEN "Transaction Description" ILIKE '%UBER%' 
              OR "Transaction Description" ILIKE '%DELIVEROO%' 
              OR "Transaction Description" ILIKE '%JUST EAT%' THEN 'Takeaway'

            WHEN "Transaction Description" ILIKE '%PUB%' 
              OR "Transaction Description" ILIKE '%BAR%' 
              OR "Transaction Description" ILIKE '%RESTAURANT%' 
              OR "Transaction Description" ILIKE '%CAFE%' 
              OR "Transaction Description" ILIKE '%COFFEE%' THEN 'Food & Drink'

            WHEN "Transaction Description" ILIKE '%TRANSPORT%' 
              OR "Transaction Description" ILIKE '%TRAIN%' 
              OR "Transaction Description" ILIKE '%BUS%' 
              OR "Transaction Description" ILIKE '%TUBE%' 
              OR "Transaction Description" ILIKE '%TAXI%' THEN 'Transport'

            WHEN "Transaction Description" ILIKE '%SALARY%' 
              OR "Transaction Description" ILIKE '%WAGES%' 
              OR "Transaction Description" ILIKE '%PAYMENT%' 
              OR "Transaction Description" ILIKE '%INCOME%' THEN 'Income'

            WHEN "Transaction Description" ILIKE '%RENT%' 
              OR "Transaction Description" ILIKE '%MORTGAGE%' THEN 'Housing'

            ELSE 'Other'
        END AS category
    FROM account
    WHERE "Debit Amount" > 0
)
SELECT
    category,
    COUNT(*) AS transaction_count,
    ROUND(SUM("Debit Amount")::NUMERIC, 2) AS total_spent
FROM categorized
GROUP BY category
ORDER BY total_spent DESC
LIMIT 3;

-- ============================================================
-- 4. MONTHLY SPENDING TREND WITH GROWTH AND SAVING PERCENTAGES
-- ============================================================

WITH monthly_spend AS (
    SELECT
        EXTRACT(YEAR FROM "Transaction Date") AS year,
        EXTRACT(MONTH FROM "Transaction Date") AS month_number,
        TO_CHAR("Transaction Date", 'Month') AS month_name,
        SUM("Debit Amount") AS total_spent,
        COUNT(*) AS total_transactions
    FROM account
    GROUP BY year, month_number, month_name
),
with_previous AS (
    SELECT
        year,
        month_name,
        month_number,
        total_spent,
        total_transactions,
        LAG(total_spent) OVER (ORDER BY year, month_number) AS previous_month_spent
    FROM monthly_spend
)
SELECT
    year,
    month_name,
    total_spent,
    total_transactions,
    previous_month_spent,
    ROUND(100.0 * (total_spent - previous_month_spent) / NULLIF(previous_month_spent, 0), 2) AS growth_percentage,
    ROUND(100.0 * (previous_month_spent - total_spent) / NULLIF(previous_month_spent, 0), 2) AS saving_percentage,
    RANK() OVER (PARTITION BY year ORDER BY total_spent DESC) AS rank_in_year
FROM with_previous
ORDER BY year, month_number;

-- ============================================================
-- 5. YEARLY INCOME ANALYSIS
-- ============================================================

WITH yearly_income AS (
    SELECT
        EXTRACT(YEAR FROM "Transaction Date") AS year,
        "Transaction Description",
        SUM("Credit Amount") AS total_income
    FROM account
    WHERE "Transaction Description" IN ('IAC GROUP LTD', 'ARTIFEX INTERIOR S', 'EXTRA PERSONNEL AU')
    GROUP BY year, "Transaction Description"
)
SELECT *
FROM yearly_income
ORDER BY year;

-- ============================================================
-- 6. WEEKLY SPENDING PATTERN
-- ============================================================

SELECT
    TO_CHAR("Transaction Date", 'Day') AS day_name,
    EXTRACT(ISODOW FROM "Transaction Date") AS day_number,
    ROUND(SUM("Debit Amount")::NUMERIC, 2) AS total_spent,
    COUNT(*) AS transaction_count
FROM account
WHERE "Debit Amount" > 0
GROUP BY day_name, day_number
ORDER BY day_number;

-- ============================================================
-- 7. TOP 3 SPENDING CATEGORIES (ENGLISH KEYWORDS)
-- ============================================================

WITH categorized_english AS (
    SELECT
        "Transaction Description",
        "Debit Amount",
        CASE
            WHEN "Transaction Description" ILIKE '%TESCO%' 
              OR "Transaction Description" ILIKE '%SAINSBURY%' 
              OR "Transaction Description" ILIKE '%ASDA%' 
              OR "Transaction Description" ILIKE '%MORRISON%' 
              OR "Transaction Description" ILIKE '%CO-OP%' 
              OR "Transaction Description" ILIKE '%WAITROSE%' 
              OR "Transaction Description" ILIKE '%ALDI%' 
              OR "Transaction Description" ILIKE '%LIDL%' THEN 'Supermarket'

            WHEN "Transaction Description" ILIKE '%AMAZON%' 
              OR "Transaction Description" ILIKE '%EBAY%' 
              OR "Transaction Description" ILIKE '%ASOS%' 
              OR "Transaction Description" ILIKE '%BOOHOO%' THEN 'Online Shopping'

            WHEN "Transaction Description" ILIKE '%UBER%' 
              OR "Transaction Description" ILIKE '%DELIVEROO%' 
              OR "Transaction Description" ILIKE '%JUST EAT%' THEN 'Takeaway'

            WHEN "Transaction Description" ILIKE '%PUB%' 
              OR "Transaction Description" ILIKE '%BAR%' 
              OR "Transaction Description" ILIKE '%RESTAURANT%' 
              OR "Transaction Description" ILIKE '%CAFE%' 
              OR "Transaction Description" ILIKE '%COFFEE%' THEN 'Food & Drink'

            WHEN "Transaction Description" ILIKE '%TRANSPORT%' 
              OR "Transaction Description" ILIKE '%TRAIN%' 
              OR "Transaction Description" ILIKE '%BUS%' 
              OR "Transaction Description" ILIKE '%TUBE%' 
              OR "Transaction Description" ILIKE '%TAXI%' THEN 'Transport'

            WHEN "Transaction Description" ILIKE '%SALARY%' 
              OR "Transaction Description" ILIKE '%WAGES%' 
              OR "Transaction Description" ILIKE '%PAYMENT%' 
              OR "Transaction Description" ILIKE '%INCOME%' THEN 'Income'

            WHEN "Transaction Description" ILIKE '%RENT%' 
              OR "Transaction Description" ILIKE '%MORTGAGE%' THEN 'Housing'

            ELSE 'Other'
        END AS category
    FROM account
    WHERE "Debit Amount" > 0
)
SELECT
    category,
    COUNT(*) AS transaction_count,
    ROUND(SUM("Debit Amount")::NUMERIC, 2) AS total_spent
FROM categorized_english
GROUP BY category
ORDER BY total_spent DESC
LIMIT 3;

-- ============================================================
-- END OF PROJECT
-- ============================================================
