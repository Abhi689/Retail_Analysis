CREATE DATABASE Retail_data
USE Retail_data;

SELECT
*
FROM "Transaction";
SELECT
*
FROM
Retail_Customer;
SELECT
*
FROM
prod_cat_info;
--1.COUNTING OF ROWS IN 3 TABLES
SELECT
COUNT(*)
FROM "Transaction";
SELECT
COUNT(*)
FROM Retail_Customer;
SELECT
COUNT(*)
FROM prod_cat_info;

--2.WHAT IS THE TOTAL NO. OF TRANSACTION THAT HAVE A RETURN
SELECT COUNT(*) AS total_returns
FROM "Transaction"
WHERE Qty < 0;
--converting date into its valid format
UPDATE "Transaction"
SET tran_date = CONVERT(DATE, tran_date, 105);
--105 corresponds to DD-MM-YYYY format.
--what is the time range pf the transaction data available for analysis ? Show the output in number of days, months and Years simultaneously in different colomns
SELECT 
    DATEDIFF(DAY, MIN(tran_date), MAX(tran_date)) AS num_days,
    DATEDIFF(MONTH, MIN(tran_date), MAX(tran_date)) AS num_months,
    DATEDIFF(YEAR, MIN(tran_date), MAX(tran_date)) AS num_years
FROM "Transaction"
;
--which product category does the sub-category "DIY" belong to?
SELECT prod_cat
FROM prod_cat_info
WHERE prod_subcat = 'DIY';
--which channel is most frequently used for transactions
SELECT Store_type, COUNT(*) AS transaction_count
FROM "Transaction"
GROUP BY Store_type
ORDER BY transaction_count DESC;

--what is the count of male and female cutomer in th database
SELECT 
    Gender,
    COUNT(*) AS gender_count
FROM Retail_Customer
GROUP BY Gender;
--from which city do we have maximum no. of customers  and how many
SELECT 
    city_code, 
    COUNT(*) AS customer_count
FROM Retail_Customer
GROUP BY city_code
ORDER BY customer_count DESC;
--how many subcategories are there under Books category
SELECT COUNT(DISTINCT prod_sub_cat_code) AS subcategory_count
FROM prod_cat_info
WHERE prod_cat = 'Books';

--what is the maximum quantity of product ever ordered
SELECT MAX(Qty) AS max_quantity
FROM "Transaction";
--what is the net total revenue generated in categories Electronics and Books
SELECT SUM(t.total_amt) AS net_total_revenue
FROM "Transaction" t
JOIN prod_cat_info pc
ON t.prod_cat_code = pc.prod_cat_code
WHERE pc.prod_cat IN ('Electronics', 'Books');
--how many customer have >10 transaction with us excluding return
SELECT COUNT(DISTINCT cust_id) AS customer_count
FROM (
    SELECT cust_id, COUNT(*) AS transaction_count
    FROM "Transaction"
    WHERE Qty > 0
    GROUP BY cust_id
    HAVING COUNT(*) > 10
) AS subquery;
--what is the combined revenue earned from Electronics and Clothing categories from Flagship stores
SELECT SUM(t.total_amt) AS combined_revenue
FROM "Transaction" t
JOIN prod_cat_info pc
ON t.prod_cat_code = pc.prod_cat_code
WHERE pc.prod_cat IN ('Electronics', 'Clothing')
AND t.Store_type = 'Flagship';
--what is total revenue generated from MALE customers in Electronics ? output should display total revenue by product sub cat
SELECT pc.prod_subcat, SUM(t.total_amt) AS total_revenue
FROM "Transaction" t
JOIN prod_cat_info pc ON t.prod_subcat_code = pc.prod_sub_cat_code
JOIN Retail_Customer c ON t.cust_id = c.customer_Id
WHERE c.Gender = 'M'
AND pc.prod_cat = 'Electronics'
GROUP BY pc.prod_subcat;

--what is percentage of sales and returns by product sub cat:display only top 5 categories in terms of sales
WITH subcat_sales AS (
    SELECT
        t.prod_subcat_code,
        SUM(CASE WHEN t.Qty > 0 THEN t.total_amt ELSE 0 END) AS total_sales,
        SUM(CASE WHEN t.Qty < 0 THEN t.total_amt ELSE 0 END) AS total_returns
    FROM "Transaction" t
    GROUP BY t.prod_subcat_code
),
subcat_percentages AS (
    SELECT
        sc.prod_subcat_code,
        sc.total_sales,
        sc.total_returns,
        (sc.total_sales * 100.0 / NULLIF(SUM(sc.total_sales) OVER (), 0)) AS sales_percentage,
        (sc.total_returns * 100.0 / NULLIF(SUM(sc.total_returns) OVER (), 0)) AS returns_percentage
    FROM subcat_sales sc
)
SELECT
    pc.prod_subcat,
    sp.total_sales,
    sp.total_returns,
    sp.sales_percentage,
    sp.returns_percentage
FROM subcat_percentages sp
JOIN prod_cat_info pc ON sp.prod_subcat_code = pc.prod_sub_cat_code
ORDER BY sp.total_sales DESC
OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY;

--from all customers aged between 25 to 35 years find what is the net total revenue generated by these customers in last 30 days of transaction from max transaction date available in the data
--  Calculate customer ages and filter those aged between 25 to 35 years
WITH customer_age AS (
    SELECT
        customer_Id,
        DATEDIFF(YEAR, DOB, GETDATE()) AS age
    FROM Retail_Customer
),
filtered_customers AS (
    SELECT customer_Id
    FROM customer_age
    WHERE age BETWEEN 25 AND 35
),

--Determine the maximum transaction date
max_transaction_date AS (
    SELECT MAX(tran_date) AS max_date
    FROM "Transaction"
),

--Filter transactions from the last 30 days
recent_transactions AS (
    SELECT t.*
    FROM "Transaction" t
    CROSS JOIN max_transaction_date mtd
    WHERE t.tran_date BETWEEN DATEADD(DAY, -30, mtd.max_date) AND mtd.max_date
)

-- Join filtered customers with recent transactions and calculate net total revenue
SELECT 
    SUM(rt.total_amt) AS net_total_revenue
FROM recent_transactions rt
JOIN filtered_customers fc ON rt.cust_id = fc.customer_Id
WHERE rt.Qty > 0;  -- Ensuring that returns are excluded (assuming Qty > 0 means a valid sale)

--which product category has seen the max value of returns in the last 3 months of trnsaction 
-- Filter transactions for the last three months and identify return transactions
WITH recent_returns AS (
    SELECT
        t.prod_cat_code,
        t.total_amt
    FROM "Transaction" t
    WHERE t.tran_date >= DATEADD(MONTH, -3, GETDATE())
      AND t.Qty < 0  -- Identify return transactions
),

--Sum the return values by product category
returns_by_category AS (
    SELECT
        t.prod_cat_code,
        SUM(t.total_amt) AS total_return_value
    FROM recent_returns t
    GROUP BY t.prod_cat_code
)

-- Join with product_categories to get category names and find the category with the max return value
SELECT
    pc.prod_cat,
    rbc.total_return_value
FROM returns_by_category rbc
JOIN prod_cat_info pc ON rbc.prod_cat_code = pc.prod_cat_code
ORDER BY rbc.total_return_value DESC
OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

--which store type sells the maximum  products; by value of sales amount and by quantity sold
--by value of sales amount
SELECT Store_type, SUM(total_amt) AS total_sales_amount
FROM "Transaction"
GROUP BY Store_type
ORDER BY total_sales_amount DESC
OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

--by quantity sold
SELECT Store_type, SUM(Qty) AS total_quantity_sold
FROM "Transaction"
GROUP BY Store_type
ORDER BY total_quantity_sold DESC
OFFSET 0 ROWS FETCH NEXT 1 ROWS ONLY;

--what are the categories for which average revenue is above the overall average
WITH category_avg_revenue AS (
    SELECT
        pc.prod_cat,
        AVG(t.total_amt) AS avg_category_revenue,
        (SELECT AVG(total_amt) FROM "Transaction") AS overall_avg_revenue
    FROM "Transaction" t
    JOIN prod_cat_info pc ON t.prod_cat_code = pc.prod_cat_code
    GROUP BY pc.prod_cat
)
SELECT
    prod_cat
FROM category_avg_revenue
WHERE avg_category_revenue > overall_avg_revenue;

--find the average and total revenue by each subcategory for the categories which are among top 5 categories in terms of quantity sold
WITH top_categories AS (
    SELECT
        pc.prod_cat_code,
        SUM(t.Qty) AS total_quantity_sold
    FROM "Transaction" t
    JOIN prod_cat_info pc ON t.prod_cat_code = pc.prod_cat_code
    GROUP BY pc.prod_cat_code
    ORDER BY total_quantity_sold DESC
    OFFSET 0 ROWS FETCH NEXT 5 ROWS ONLY
),
subcategory_revenue AS (
    SELECT
        pc.prod_cat_code,
        pc.prod_subcat,
        SUM(t.total_amt) AS total_revenue,
        AVG(t.total_amt) AS avg_revenue
    FROM "Transaction" t
    JOIN prod_cat_info pc ON t.prod_cat_code = pc.prod_cat_code
    JOIN top_categories tc ON pc.prod_cat_code = tc.prod_cat_code
    GROUP BY pc.prod_cat_code, pc.prod_subcat
)
SELECT
    pc.prod_cat_code,
    pc.prod_subcat,
    sr.total_revenue,
    sr.avg_revenue
FROM subcategory_revenue sr
JOIN prod_cat_info pc ON sr.prod_cat_code = pc.prod_cat_code
ORDER BY pc.prod_cat_code, pc.prod_subcat;
