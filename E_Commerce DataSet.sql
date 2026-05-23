CREATE TABLE ecommerce (
    invoice_no      VARCHAR(20),
    stock_code      VARCHAR(20),
    description     VARCHAR(200),
    quantity        INTEGER,
    invoice_date    TIMESTAMP,
    unit_price      DECIMAL(10,2),
    customer_id     VARCHAR(20),
    country         VARCHAR(100)
);

SELECT 'Table created successfully!' AS status;

SELECT * FROM ecommerce;

SET datestyle = 'ISO, MDY';

COPY ecommerce
FROM 'C:/temp/data.csv'
DELIMITER ','
CSV HEADER
ENCODING 'LATIN1';

SELECT COUNT(*) AS total_rows FROM ecommerce;


SELECT 
    COUNT(*) AS total_rows,
    COUNT(customer_id) AS rows_with_customer,
    COUNT(*) - COUNT(customer_id) AS missing_customer_id,
    SUM(CASE WHEN quantity < 0 THEN 1 ELSE 0 END) AS negative_qty,
    SUM(CASE WHEN unit_price <= 0 THEN 1 ELSE 0 END) AS zero_price
FROM ecommerce;

CREATE TABLE ecommerce_clean AS
SELECT 
    invoice_no,
    stock_code,
    TRIM(description) AS description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    quantity * unit_price AS revenue,
    DATE(invoice_date) AS invoice_date_only,
    DATE_TRUNC('month', invoice_date) AS invoice_month,
    DATE_PART('hour', invoice_date) AS purchase_hour,
    DATE_PART('dow', invoice_date) AS day_of_week,
    TO_CHAR(invoice_date, 'Day') AS day_name
FROM ecommerce
WHERE customer_id IS NOT NULL
AND quantity > 0
AND unit_price > 0
AND invoice_no NOT LIKE 'C%';

SELECT 
    COUNT(*) AS clean_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT invoice_no) AS unique_orders,
    COUNT(DISTINCT country) AS unique_countries,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
FROM ecommerce_clean;




-- Query 1: Business overview
SELECT
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT invoice_no) AS total_orders,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT stock_code) AS unique_products,
    COUNT(DISTINCT country) AS countries,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction_value
FROM ecommerce_clean;

-- Query 2: Revenue by country (Top 10)
SELECT 
    country,
    COUNT(DISTINCT customer_id) AS customers,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_order_value
FROM ecommerce_clean
GROUP BY country
ORDER BY total_revenue DESC
LIMIT 10;

-- Query 3: Monthly revenue trend
SELECT 
    invoice_month,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS active_customers,
    ROUND(SUM(revenue)::DECIMAL, 2) AS monthly_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_order_value
FROM ecommerce_clean
GROUP BY invoice_month
ORDER BY invoice_month;

-- Query 4: Top 10 best selling products
SELECT 
    stock_code,
    description,
    SUM(quantity) AS total_units_sold,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
FROM ecommerce_clean
GROUP BY stock_code, description
ORDER BY total_units_sold DESC
LIMIT 10;

-- Query 5: Revenue by day of week
SELECT 
    day_name,
    day_of_week,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_order_value
FROM ecommerce_clean
GROUP BY day_name, day_of_week
ORDER BY day_of_week;

-- Query 6: Hourly purchase pattern
SELECT 
    purchase_hour,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS revenue
FROM ecommerce_clean
GROUP BY purchase_hour
ORDER BY purchase_hour;

-- Query 7: Average order value by country
SELECT 
    country,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(AVG(order_total)::DECIMAL, 2) AS avg_order_value
FROM (
    SELECT 
        country,
        invoice_no,
        SUM(revenue) AS order_total
    FROM ecommerce_clean
    GROUP BY country, invoice_no
) order_totals
GROUP BY country
ORDER BY avg_order_value DESC
LIMIT 10;

-- Query 8: Top 10 customers by revenue
SELECT 
    customer_id,
    COUNT(DISTINCT invoice_no) AS total_orders,
    SUM(quantity) AS total_units,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction
FROM ecommerce_clean
GROUP BY customer_id
ORDER BY total_revenue DESC
LIMIT 10;



-- Query 9: Customer purchase frequency
SELECT 
    order_count,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM (
    SELECT 
        customer_id,
        COUNT(DISTINCT invoice_no) AS order_count
    FROM ecommerce_clean
    GROUP BY customer_id
) customer_orders
GROUP BY order_count
ORDER BY order_count;

-- Query 10: One-time vs repeat customers
WITH customer_orders AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT invoice_no) AS order_count
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-Time'
        WHEN order_count BETWEEN 2 AND 5 THEN 'Occasional (2-5)'
        WHEN order_count BETWEEN 6 AND 10 THEN 'Regular (6-10)'
        ELSE 'Loyal (10+)'
    END AS customer_type,
    COUNT(*) AS customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM customer_orders
GROUP BY customer_type
ORDER BY customers DESC;

-- Query 11: Revenue funnel by customer type
WITH customer_orders AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT invoice_no) AS order_count,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-Time'
        WHEN order_count BETWEEN 2 AND 5 THEN 'Occasional (2-5)'
        WHEN order_count BETWEEN 6 AND 10 THEN 'Regular (6-10)'
        ELSE 'Loyal (10+)'
    END AS customer_type,
    COUNT(*) AS customers,
    ROUND(SUM(total_revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(total_revenue)::DECIMAL, 2) AS avg_revenue_per_customer
FROM customer_orders
GROUP BY customer_type
ORDER BY total_revenue DESC;

-- Query 12: Monthly new vs returning customers
WITH first_purchase AS (
    SELECT 
        customer_id,
        MIN(invoice_month) AS first_month
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    e.invoice_month,
    COUNT(DISTINCT CASE WHEN e.invoice_month = fp.first_month 
          THEN e.customer_id END) AS new_customers,
    COUNT(DISTINCT CASE WHEN e.invoice_month > fp.first_month 
          THEN e.customer_id END) AS returning_customers
FROM ecommerce_clean e
JOIN first_purchase fp ON e.customer_id = fp.customer_id
GROUP BY e.invoice_month
ORDER BY e.invoice_month;

-- Query 13: Average days between purchases
WITH customer_purchases AS (
    SELECT 
        customer_id,
        invoice_date_only,
        LAG(invoice_date_only) OVER (
            PARTITION BY customer_id ORDER BY invoice_date_only
        ) AS prev_purchase
    FROM (
        SELECT DISTINCT customer_id, invoice_date_only
        FROM ecommerce_clean
    ) distinct_purchases
)
SELECT 
    ROUND(AVG(invoice_date_only - prev_purchase), 1) AS avg_days_between_purchases,
    MIN(invoice_date_only - prev_purchase) AS min_days,
    MAX(invoice_date_only - prev_purchase) AS max_days
FROM customer_purchases
WHERE prev_purchase IS NOT NULL;

-- Query 14: Basket size analysis
WITH order_baskets AS (
    SELECT 
        invoice_no,
        COUNT(DISTINCT stock_code) AS items_in_basket,
        SUM(quantity) AS total_units,
        ROUND(SUM(revenue)::DECIMAL, 2) AS basket_value
    FROM ecommerce_clean
    GROUP BY invoice_no
)
SELECT 
    CASE 
        WHEN items_in_basket = 1 THEN '1 item'
        WHEN items_in_basket BETWEEN 2 AND 5 THEN '2-5 items'
        WHEN items_in_basket BETWEEN 6 AND 10 THEN '6-10 items'
        ELSE '10+ items'
    END AS basket_size,
    COUNT(*) AS orders,
    ROUND(AVG(basket_value)::DECIMAL, 2) AS avg_basket_value,
    ROUND(SUM(basket_value)::DECIMAL, 2) AS total_revenue
FROM order_baskets
GROUP BY basket_size
ORDER BY total_revenue DESC;

-- Query 15: Peak shopping months
SELECT 
    TO_CHAR(invoice_month, 'Month YYYY') AS month,
    COUNT(DISTINCT invoice_no) AS orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS revenue,
    ROUND(AVG(SUM(revenue)::DECIMAL) OVER (), 2) AS avg_monthly_revenue,
    CASE 
        WHEN SUM(revenue) > AVG(SUM(revenue)::DECIMAL) OVER () 
        THEN 'Above Average'
        ELSE 'Below Average'
    END AS performance
FROM ecommerce_clean
GROUP BY invoice_month
ORDER BY invoice_month;

-- Query 16: Country conversion funnel
SELECT 
    country,
    COUNT(DISTINCT customer_id) AS total_customers,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(COUNT(DISTINCT invoice_no)::DECIMAL / 
          COUNT(DISTINCT customer_id), 2) AS orders_per_customer,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(SUM(revenue)::DECIMAL / 
          COUNT(DISTINCT customer_id), 2) AS revenue_per_customer
FROM ecommerce_clean
GROUP BY country
HAVING COUNT(DISTINCT customer_id) > 10
ORDER BY revenue_per_customer DESC;



-- ============================================================
-- SECTION 3: RFM ANALYSIS (Most Important!)
-- ============================================================

-- Query 17: RFM Base calculation
WITH max_date AS (
    SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean
),
rfm_base AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
)
SELECT 
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    r_score + f_score + m_score AS rfm_total,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '🏆 Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN '💎 Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN '🆕 New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN '⚠️ At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN '💤 Lost Customers'
        ELSE '🌱 Potential Loyalists'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- Query 18: RFM Segment summary
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
),
rfm_scores AS (
    SELECT r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
),
rfm_segments AS (
    SELECT *,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS segment
    FROM rfm_scores
)
SELECT 
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary)::DECIMAL, 2) AS avg_monetary,
    ROUND(SUM(monetary)::DECIMAL, 2) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- Query 19: Top 10 champion customers
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
)
SELECT 
    customer_id,
    (SELECT last_date FROM max_date) - last_purchase AS recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY monetary DESC) AS value_tier
FROM rfm_base
ORDER BY monetary DESC
LIMIT 10;

-- Query 20: Lost customers analysis
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
customer_last AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_spent
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    customer_id,
    last_purchase,
    (SELECT last_date FROM max_date) - last_purchase AS days_inactive,
    total_orders,
    total_spent
FROM customer_last
WHERE (SELECT last_date FROM max_date) - last_purchase > 90
ORDER BY total_spent DESC
LIMIT 20;

-- Query 21: Customer lifetime value
SELECT 
    customer_id,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction,
    MIN(invoice_date_only) AS first_purchase,
    MAX(invoice_date_only) AS last_purchase,
    MAX(invoice_date_only) - MIN(invoice_date_only) AS customer_lifespan_days,
    ROUND((SUM(revenue) / NULLIF(MAX(invoice_date_only) - MIN(invoice_date_only), 0))::DECIMAL, 2) AS revenue_per_day
FROM ecommerce_clean
GROUP BY customer_id
HAVING MAX(invoice_date_only) - MIN(invoice_date_only) > 0
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 22: Cohort retention analysis
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM ecommerce_clean
    GROUP BY customer_id
),
cohort_data AS (
    SELECT 
        fp.cohort_month,
        DATE_TRUNC('month', e.invoice_date) AS purchase_month,
        COUNT(DISTINCT e.customer_id) AS customers
    FROM ecommerce_clean e
    JOIN first_purchase fp ON e.customer_id = fp.customer_id
    GROUP BY fp.cohort_month, purchase_month
)
SELECT 
    cohort_month,
    purchase_month,
    customers,
    EXTRACT(MONTH FROM AGE(purchase_month, cohort_month)) AS months_since_first
FROM cohort_data
ORDER BY cohort_month, purchase_month;



-- ============================================================
-- SECTION 3: RFM ANALYSIS (Most Important!)
-- ============================================================

-- Query 17: RFM Base calculation
WITH max_date AS (
    SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean
),
rfm_base AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
)
SELECT 
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    r_score + f_score + m_score AS rfm_total,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '🏆 Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN '💎 Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN '🆕 New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN '⚠️ At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN '💤 Lost Customers'
        ELSE '🌱 Potential Loyalists'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- Query 18: RFM Segment summary
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
),
rfm_scores AS (
    SELECT r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
),
rfm_segments AS (
    SELECT *,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS segment
    FROM rfm_scores
)
SELECT 
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary)::DECIMAL, 2) AS avg_monetary,
    ROUND(SUM(monetary)::DECIMAL, 2) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- Query 19: Top 10 champion customers
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
)
SELECT 
    customer_id,
    (SELECT last_date FROM max_date) - last_purchase AS recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY monetary DESC) AS value_tier
FROM rfm_base
ORDER BY monetary DESC
LIMIT 10;

-- Query 20: Lost customers analysis
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
customer_last AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_spent
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    customer_id,
    last_purchase,
    (SELECT last_date FROM max_date) - last_purchase AS days_inactive,
    total_orders,
    total_spent
FROM customer_last
WHERE (SELECT last_date FROM max_date) - last_purchase > 90
ORDER BY total_spent DESC
LIMIT 20;

-- Query 21: Customer lifetime value
SELECT 
    customer_id,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction,
    MIN(invoice_date_only) AS first_purchase,
    MAX(invoice_date_only) AS last_purchase,
    MAX(invoice_date_only) - MIN(invoice_date_only) AS customer_lifespan_days,
    ROUND((SUM(revenue) / NULLIF(MAX(invoice_date_only) - MIN(invoice_date_only), 0))::DECIMAL, 2) AS revenue_per_day
FROM ecommerce_clean
GROUP BY customer_id
HAVING MAX(invoice_date_only) - MIN(invoice_date_only) > 0
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 22: Cohort retention analysis
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM ecommerce_clean
    GROUP BY customer_id
),
cohort_data AS (
    SELECT 
        fp.cohort_month,
        DATE_TRUNC('month', e.invoice_date) AS purchase_month,
        COUNT(DISTINCT e.customer_id) AS customers
    FROM ecommerce_clean e
    JOIN first_purchase fp ON e.customer_id = fp.customer_id
    GROUP BY fp.cohort_month, purchase_month
)
SELECT 
    cohort_month,
    purchase_month,
    customers,
    EXTRACT(MONTH FROM AGE(purchase_month, cohort_month)) AS months_since_first
FROM cohort_data
ORDER BY cohort_month, purchase_month;

-- Query 17: RFM Base calculation
WITH max_date AS (
    SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean
),
rfm_base AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
)
SELECT 
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    r_score + f_score + m_score AS rfm_total,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
        ELSE 'Potential Loyalists'
    END AS customer_segment
FROM rfm_scores
ORDER BY rfm_total DESC;

-- Query 18: RFM Segment summary
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
),
rfm_scores AS (
    SELECT r.*,
        (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
        NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
        NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
    FROM rfm_base r
),
rfm_segments AS (
    SELECT *,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS segment
    FROM rfm_scores
)
SELECT 
    segment,
    COUNT(*) AS customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary)::DECIMAL, 2) AS avg_monetary,
    ROUND(SUM(monetary)::DECIMAL, 2) AS total_revenue
FROM rfm_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- Query 19: Top 10 champion customers
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
rfm_base AS (
    SELECT customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS frequency,
        ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
    FROM ecommerce_clean GROUP BY customer_id
)
SELECT 
    customer_id,
    (SELECT last_date FROM max_date) - last_purchase AS recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY monetary DESC) AS value_tier
FROM rfm_base
ORDER BY monetary DESC
LIMIT 10;

-- Query 20: Lost customers analysis
WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
customer_last AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_spent
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    customer_id,
    last_purchase,
    (SELECT last_date FROM max_date) - last_purchase AS days_inactive,
    total_orders,
    total_spent
FROM customer_last
WHERE (SELECT last_date FROM max_date) - last_purchase > 90
ORDER BY total_spent DESC
LIMIT 20;

-- Query 21: Customer lifetime value
SELECT 
    customer_id,
    COUNT(DISTINCT invoice_no) AS total_orders,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction,
    MIN(invoice_date_only) AS first_purchase,
    MAX(invoice_date_only) AS last_purchase,
    MAX(invoice_date_only) - MIN(invoice_date_only) AS customer_lifespan_days,
    ROUND((SUM(revenue) / NULLIF(MAX(invoice_date_only) - MIN(invoice_date_only), 0))::DECIMAL, 2) AS revenue_per_day
FROM ecommerce_clean
GROUP BY customer_id
HAVING MAX(invoice_date_only) - MIN(invoice_date_only) > 0
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 22: Cohort retention analysis
WITH first_purchase AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date)) AS cohort_month
    FROM ecommerce_clean
    GROUP BY customer_id
),
cohort_data AS (
    SELECT 
        fp.cohort_month,
        DATE_TRUNC('month', e.invoice_date) AS purchase_month,
        COUNT(DISTINCT e.customer_id) AS customers
    FROM ecommerce_clean e
    JOIN first_purchase fp ON e.customer_id = fp.customer_id
    GROUP BY fp.cohort_month, purchase_month
)
SELECT 
    cohort_month,
    purchase_month,
    customers,
    EXTRACT(MONTH FROM AGE(purchase_month, cohort_month)) AS months_since_first
FROM cohort_data
ORDER BY cohort_month, purchase_month;

-- Query 23: Running revenue total
SELECT 
    invoice_month,
    ROUND(SUM(revenue)::DECIMAL, 2) AS monthly_revenue,
    ROUND(SUM(SUM(revenue)::DECIMAL) OVER (ORDER BY invoice_month), 2) AS cumulative_revenue
FROM ecommerce_clean
GROUP BY invoice_month
ORDER BY invoice_month;

-- Query 24: Month over month revenue growth
WITH monthly AS (
    SELECT 
        invoice_month,
        ROUND(SUM(revenue)::DECIMAL, 2) AS revenue
    FROM ecommerce_clean
    GROUP BY invoice_month
)
SELECT 
    invoice_month,
    revenue,
    LAG(revenue) OVER (ORDER BY invoice_month) AS prev_month,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY invoice_month), 2) AS change,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY invoice_month)) /
          NULLIF(LAG(revenue) OVER (ORDER BY invoice_month), 0) * 100, 2) AS growth_pct
FROM monthly
ORDER BY invoice_month;

-- Query 25: Rank customers by revenue per country
SELECT 
    country,
    customer_id,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    RANK() OVER (PARTITION BY country ORDER BY SUM(revenue) DESC) AS country_rank
FROM ecommerce_clean
GROUP BY country, customer_id
HAVING SUM(revenue) > 0
ORDER BY country, country_rank
LIMIT 30;

-- Query 26: Product revenue percentile
SELECT 
    description,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue,
    ROUND(PERCENT_RANK() OVER (ORDER BY SUM(revenue))::DECIMAL * 100, 2) AS revenue_percentile,
    NTILE(4) OVER (ORDER BY SUM(revenue)) AS quartile
FROM ecommerce_clean
GROUP BY description
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 27: Moving average revenue
WITH daily_revenue AS (
    SELECT 
        invoice_date_only,
        ROUND(SUM(revenue)::DECIMAL, 2) AS daily_rev
    FROM ecommerce_clean
    GROUP BY invoice_date_only
)
SELECT 
    invoice_date_only,
    daily_rev,
    ROUND(AVG(daily_rev) OVER (
        ORDER BY invoice_date_only
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    )::DECIMAL, 2) AS seven_day_avg
FROM daily_revenue
ORDER BY invoice_date_only;

-- Query 28: LEAD — next purchase prediction
WITH customer_purchases AS (
    SELECT DISTINCT
        customer_id,
        invoice_date_only,
        LEAD(invoice_date_only) OVER (
            PARTITION BY customer_id 
            ORDER BY invoice_date_only
        ) AS next_purchase_date
    FROM ecommerce_clean
)
SELECT 
    customer_id,
    invoice_date_only AS purchase_date,
    next_purchase_date,
    next_purchase_date - invoice_date_only AS days_to_next_purchase
FROM customer_purchases
WHERE next_purchase_date IS NOT NULL
ORDER BY days_to_next_purchase ASC
LIMIT 20;

-- Query 29: ROW_NUMBER — first purchase per customer
WITH first_orders AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id 
            ORDER BY invoice_date
        ) AS rn
    FROM ecommerce_clean
)
SELECT 
    customer_id,
    invoice_no,
    invoice_date,
    country,
    ROUND(revenue::DECIMAL, 2) AS first_order_value
FROM first_orders
WHERE rn = 1
ORDER BY invoice_date
LIMIT 20;

-- Query 30: DENSE_RANK products by monthly sales
WITH monthly_product AS (
    SELECT 
        TO_CHAR(invoice_month, 'YYYY-MM') AS month,
        description,
        ROUND(SUM(revenue)::DECIMAL, 2) AS revenue
    FROM ecommerce_clean
    GROUP BY invoice_month, description
),
ranked AS (
    SELECT *,
        DENSE_RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS monthly_rank
    FROM monthly_product
)
SELECT 
    month,
    description,
    revenue,
    monthly_rank
FROM ranked
WHERE monthly_rank <= 5
ORDER BY month, monthly_rank;


-- Query 31: ABC product analysis
WITH product_revenue AS (
    SELECT 
        stock_code,
        description,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
    FROM ecommerce_clean
    GROUP BY stock_code, description
),
ranked AS (
    SELECT *,
        SUM(total_revenue) OVER () AS grand_total,
        ROUND((SUM(total_revenue) OVER (ORDER BY total_revenue DESC) / 
               SUM(total_revenue) OVER () * 100)::DECIMAL, 2) AS cumulative_pct
    FROM product_revenue
)
SELECT 
    stock_code,
    description,
    total_revenue,
    cumulative_pct,
    CASE 
        WHEN cumulative_pct <= 80 THEN 'A — Top Products'
        WHEN cumulative_pct <= 95 THEN 'B — Mid Products'
        ELSE 'C — Low Products'
    END AS abc_class
FROM ranked
ORDER BY total_revenue DESC
LIMIT 30;

-- Query 32: Customer segmentation by spend
WITH customer_spend AS (
    SELECT 
        customer_id,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_spend,
        COUNT(DISTINCT invoice_no) AS orders
    FROM ecommerce_clean
    GROUP BY customer_id
)
SELECT 
    CASE 
        WHEN total_spend >= 5000 THEN 'VIP (£5000+)'
        WHEN total_spend >= 1000 THEN 'Premium (£1000-5000)'
        WHEN total_spend >= 500 THEN 'Regular (£500-1000)'
        ELSE 'Entry (Under £500)'
    END AS segment,
    COUNT(*) AS customers,
    ROUND(AVG(total_spend)::DECIMAL, 2) AS avg_spend,
    ROUND(SUM(total_spend)::DECIMAL, 2) AS total_revenue,
    ROUND(AVG(orders), 1) AS avg_orders
FROM customer_spend
GROUP BY segment
ORDER BY total_revenue DESC;

-- Query 33: Products frequently bought together
SELECT 
    a.description AS product_a,
    b.description AS product_b,
    COUNT(*) AS times_bought_together
FROM ecommerce_clean a
JOIN ecommerce_clean b ON a.invoice_no = b.invoice_no
    AND a.stock_code < b.stock_code
GROUP BY a.description, b.description
HAVING COUNT(*) > 50
ORDER BY times_bought_together DESC
LIMIT 15;

-- Query 34: Revenue concentration (Pareto)
WITH customer_revenue AS (
    SELECT 
        customer_id,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
    FROM ecommerce_clean
    GROUP BY customer_id
),
ranked AS (
    SELECT *,
        ROUND((SUM(total_revenue) OVER (ORDER BY total_revenue DESC) /
               SUM(total_revenue) OVER () * 100)::DECIMAL, 2) AS cumulative_pct,
        ROUND((ROW_NUMBER() OVER (ORDER BY total_revenue DESC) * 100.0 /
               COUNT(*) OVER ())::DECIMAL, 2) AS customer_pct
    FROM customer_revenue
)
SELECT 
    CASE 
        WHEN customer_pct <= 20 THEN 'Top 20% Customers'
        ELSE 'Bottom 80% Customers'
    END AS group_name,
    COUNT(*) AS customers,
    ROUND(SUM(total_revenue)::DECIMAL, 2) AS revenue,
    ROUND(SUM(total_revenue) * 100.0 / SUM(SUM(total_revenue)) OVER ()::DECIMAL, 2) AS revenue_pct
FROM ranked
GROUP BY group_name
ORDER BY revenue DESC;

-- Query 35: Seasonal analysis
SELECT 
    CASE 
        WHEN DATE_PART('month', invoice_date) IN (12, 1, 2) THEN 'Winter'
        WHEN DATE_PART('month', invoice_date) IN (3, 4, 5) THEN 'Spring'
        WHEN DATE_PART('month', invoice_date) IN (6, 7, 8) THEN 'Summer'
        ELSE 'Autumn'
    END AS season,
    COUNT(DISTINCT invoice_no) AS orders,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(SUM(revenue)::DECIMAL, 2) AS revenue,
    ROUND(AVG(revenue)::DECIMAL, 2) AS avg_transaction
FROM ecommerce_clean
GROUP BY season
ORDER BY revenue DESC;

-- Query 36: Churn prediction — inactive customers
WITH customer_activity AS (
    SELECT 
        customer_id,
        MAX(invoice_date_only) AS last_purchase,
        COUNT(DISTINCT invoice_no) AS total_orders,
        ROUND(SUM(revenue)::DECIMAL, 2) AS total_spent
    FROM ecommerce_clean
    GROUP BY customer_id
),
max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean)
SELECT 
    ca.customer_id,
    ca.last_purchase,
    md.last_date - ca.last_purchase AS days_inactive,
    ca.total_orders,
    ca.total_spent,
    CASE 
        WHEN md.last_date - ca.last_purchase > 180 THEN '🔴 Churned'
        WHEN md.last_date - ca.last_purchase > 90 THEN '🟡 At Risk'
        WHEN md.last_date - ca.last_purchase > 30 THEN '🟠 Slipping'
        ELSE 'Active'
    END AS churn_status
FROM customer_activity ca
CROSS JOIN max_date md
ORDER BY days_inactive DESC
LIMIT 20;

-- Query 37: EXISTS — customers who bought in multiple months
SELECT 
    customer_id,
    COUNT(DISTINCT invoice_month) AS active_months,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_revenue
FROM ecommerce_clean
WHERE EXISTS (
    SELECT 1 FROM ecommerce_clean e2
    WHERE e2.customer_id = ecommerce_clean.customer_id
    AND e2.invoice_month != ecommerce_clean.invoice_month
)
GROUP BY customer_id
HAVING COUNT(DISTINCT invoice_month) >= 3
ORDER BY active_months DESC
LIMIT 20;

-- Query 38: NOT EXISTS — one time buyers
SELECT 
    customer_id,
    MIN(invoice_date_only) AS purchase_date,
    ROUND(SUM(revenue)::DECIMAL, 2) AS total_spent,
    country
FROM ecommerce_clean e1
WHERE NOT EXISTS (
    SELECT 1 FROM ecommerce_clean e2
    WHERE e2.customer_id = e1.customer_id
    AND e2.invoice_no != e1.invoice_no
)
GROUP BY customer_id, country
ORDER BY total_spent DESC
LIMIT 20;


-- Query 39: Complete business summary
SELECT 'E-COMMERCE FUNNEL ANALYSIS REPORT' AS metric, '' AS value
UNION ALL SELECT '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━', ''
UNION ALL SELECT 'Total Transactions', COUNT(*)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Total Orders', COUNT(DISTINCT invoice_no)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Total Customers', COUNT(DISTINCT customer_id)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Total Products', COUNT(DISTINCT stock_code)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Total Countries', COUNT(DISTINCT country)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Total Revenue', '£' || ROUND(SUM(revenue)::DECIMAL, 2)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Avg Order Value', '£' || ROUND(AVG(revenue)::DECIMAL, 2)::TEXT FROM ecommerce_clean
UNION ALL SELECT 'Avg Orders per Customer', ROUND(COUNT(DISTINCT invoice_no)::DECIMAL / COUNT(DISTINCT customer_id), 2)::TEXT FROM ecommerce_clean;

-- Query 40: Export RFM segments
COPY (
    WITH max_date AS (SELECT MAX(invoice_date_only) AS last_date FROM ecommerce_clean),
    rfm_base AS (
        SELECT customer_id,
            MAX(invoice_date_only) AS last_purchase,
            COUNT(DISTINCT invoice_no) AS frequency,
            ROUND(SUM(revenue)::DECIMAL, 2) AS monetary
        FROM ecommerce_clean GROUP BY customer_id
    ),
    rfm_scores AS (
        SELECT r.*,
            (SELECT last_date FROM max_date) - r.last_purchase AS recency_days,
            NTILE(5) OVER (ORDER BY (SELECT last_date FROM max_date) - r.last_purchase ASC) AS r_score,
            NTILE(5) OVER (ORDER BY r.frequency ASC) AS f_score,
            NTILE(5) OVER (ORDER BY r.monetary ASC) AS m_score
        FROM rfm_base r
    )
    SELECT customer_id, recency_days, frequency, monetary,
        r_score, f_score, m_score,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost Customers'
            ELSE 'Potential Loyalists'
        END AS segment
    FROM rfm_scores
    ORDER BY monetary DESC
)
TO 'C:/temp/rfm_segments.csv' DELIMITER ',' CSV HEADER;

-- Query 41: Export top products
COPY (
    SELECT stock_code, description,
        SUM(quantity) AS units_sold,
        ROUND(SUM(revenue)::DECIMAL, 2) AS revenue
    FROM ecommerce_clean
    GROUP BY stock_code, description
    ORDER BY revenue DESC
    LIMIT 100
)
TO 'C:/temp/top_products.csv' DELIMITER ',' CSV HEADER;

-- Query 42: Export monthly summary
COPY (
    SELECT 
        TO_CHAR(invoice_month, 'YYYY-MM') AS month,
        COUNT(DISTINCT invoice_no) AS orders,
        COUNT(DISTINCT customer_id) AS customers,
        ROUND(SUM(revenue)::DECIMAL, 2) AS revenue
    FROM ecommerce_clean
    GROUP BY invoice_month
    ORDER BY invoice_month
)
TO 'C:/temp/monthly_summary.csv' DELIMITER ',' CSV HEADER;

SELECT 'E-Commerce Analysis Complete!' AS status;