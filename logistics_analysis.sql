USE logistics_project;

-- ============================================================
-- LOGISTICS SQL ANALYSIS
-- ============================================================
-- Purpose:
-- This script contains the analytical SQL queries for exploring
-- the logistics business after the CSV files have been loaded
-- into MySQL.
--
-- Analytical focus:
-- 1. Data relationship checks
-- 2. Business overview
-- 3. Yearly operating performance
-- 4. Customer revenue analysis
-- 5. Customer concentration analysis
--
-- Notes:
-- - Revenue is treated as gross revenue when it includes:
--   linehaul revenue + fuel surcharge + accessorial charges.
-- - Large money values are shown in millions for readability.
-- - This analysis uses known operating costs only. It is not a
--   complete profit and loss statement because the dataset does
--   not include all expenses such as wages, insurance, rent,
--   depreciation, taxes, and administrative overhead.


-- ============================================================
-- 1. DATA RELATIONSHIP CHECK
-- ============================================================
-- Question:
-- Does one load connect to more than one trip?
--
-- Why this matters:
-- Loads contain revenue, while trips contain operational movement.
-- If a load appears in multiple trips, joining loads to trips can
-- duplicate revenue unless we aggregate carefully.

SELECT
    load_id,
    COUNT(*) AS trip_count
FROM trips
GROUP BY load_id
HAVING COUNT(*) > 1;


/* ============================================================
   SECTION 1: BUSINESS OVERVIEW
   ============================================================

   Purpose:
   This section provides a broad understanding of the company's
   overall performance before moving into detailed analysis of
   customers, operations, drivers, fleet, and other business areas.

   It includes:
   1. All-time business performance
   2. Yearly business performance
   3. Top 10 customers overall
   4. Top 3 customers by year
   ============================================================ */
   
   
   -- ------------------------------------------------------------
-- 1.1 ALL-TIME BUSINESS PERFORMANCE
-- ------------------------------------------------------------
-- Purpose:
-- Summarize the company's overall activity and performance
-- across the entire period covered by the dataset.

WITH load_summary AS (
    SELECT
        COUNT(*) AS total_loads,
        SUM(revenue) AS linehaul_revenue,
        SUM(fuel_surcharge) AS fuel_surcharge,
        SUM(accessorial_charges) AS accessorial_charges,
        SUM(revenue + fuel_surcharge + accessorial_charges) AS gross_revenue
    FROM loads
),

trip_summary AS (
    SELECT
        COUNT(*) AS total_trips,
        SUM(actual_distance_miles) AS total_miles
    FROM trips
),

fuel_summary AS (
    SELECT
        SUM(total_cost) AS fuel_cost
    FROM fuel_purchases
),

maintenance_summary AS (
    SELECT
        SUM(total_cost) AS maintenance_cost
    FROM maintenance_records
),

claims_summary AS (
    SELECT
        SUM(claim_amount) AS claims_cost
    FROM safety_incidents
)

SELECT
    ls.total_loads,
    ts.total_trips,
    ROUND(ts.total_miles, 2) AS total_miles,

    ROUND(ls.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(ls.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(ls.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(ls.gross_revenue / 1000000, 2) AS gross_revenue_millions,

    ROUND(fs.fuel_cost / 1000000, 2) AS fuel_cost_millions,
    ROUND(ms.maintenance_cost / 1000000, 2) AS maintenance_cost_millions,
    ROUND(cs.claims_cost / 1000000, 2) AS claims_cost_millions,

    ROUND(
        (fs.fuel_cost + ms.maintenance_cost + cs.claims_cost) / 1000000,
        2
    ) AS known_operating_cost_millions,

    ROUND(
        (ls.gross_revenue - (fs.fuel_cost + ms.maintenance_cost + cs.claims_cost)) / 1000000,
        2
    ) AS estimated_operating_margin_millions,

    ROUND(
        (ls.gross_revenue - (fs.fuel_cost + ms.maintenance_cost + cs.claims_cost))
        / ls.gross_revenue * 100,
        2
    ) AS estimated_margin_pct
FROM load_summary ls
CROSS JOIN trip_summary ts
CROSS JOIN fuel_summary fs
CROSS JOIN maintenance_summary ms
CROSS JOIN claims_summary cs;


-- ============================================================
-- 1.2. YEARLY OPERATING PERFORMANCE
-- ============================================================
-- Question:
-- How has operating performance changed by year?
--
-- Why this matters:
-- The all-time overview gives the big picture, but yearly analysis
-- shows whether revenue, cost, and margins are improving or
-- weakening over time.
--
-- Unlike the all-time overview, each CTE returns multiple rows,
-- one row per year. Therefore, we join by business_year instead
-- of using CROSS JOIN.

WITH load_summary AS (
    SELECT
        YEAR(load_date) AS business_year,
        COUNT(*) AS total_loads,
        SUM(revenue) AS linehaul_revenue,
        SUM(fuel_surcharge) AS fuel_surcharge,
        SUM(accessorial_charges) AS accessorial_charges,
        SUM(revenue + fuel_surcharge + accessorial_charges) AS gross_revenue
    FROM loads
    GROUP BY YEAR(load_date)
),

trip_summary AS (
    SELECT
        YEAR(dispatch_date) AS business_year,
        COUNT(*) AS total_trips,
        SUM(actual_distance_miles) AS total_miles
    FROM trips
    GROUP BY YEAR(dispatch_date)
),

fuel_summary AS (
    SELECT
        YEAR(purchase_date) AS business_year,
        SUM(total_cost) AS fuel_cost
    FROM fuel_purchases
    GROUP BY YEAR(purchase_date)
),

maintenance_summary AS (
    SELECT
        YEAR(maintenance_date) AS business_year,
        SUM(total_cost) AS maintenance_cost
    FROM maintenance_records
    GROUP BY YEAR(maintenance_date)
),

claims_summary AS (
    SELECT
        YEAR(incident_date) AS business_year,
        SUM(claim_amount) AS claims_cost
    FROM safety_incidents
    GROUP BY YEAR(incident_date)
)

SELECT
    ls.business_year,
    ls.total_loads,
    ts.total_trips,
    ROUND(ts.total_miles, 2) AS total_miles,

    ROUND(ls.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(ls.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(ls.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(ls.gross_revenue / 1000000, 2) AS gross_revenue_millions,

    ROUND(COALESCE(fs.fuel_cost, 0) / 1000000, 2) AS fuel_cost_millions,
    ROUND(COALESCE(ms.maintenance_cost, 0) / 1000000, 2) AS maintenance_cost_millions,
    ROUND(COALESCE(cs.claims_cost, 0) / 1000000, 2) AS claims_cost_millions,

    ROUND(
        (
            COALESCE(fs.fuel_cost, 0)
            + COALESCE(ms.maintenance_cost, 0)
            + COALESCE(cs.claims_cost, 0)
        ) / 1000000,
        2
    ) AS known_operating_cost_millions,

    ROUND(
        (
            ls.gross_revenue
            - (
                COALESCE(fs.fuel_cost, 0)
                + COALESCE(ms.maintenance_cost, 0)
                + COALESCE(cs.claims_cost, 0)
            )
        ) / 1000000,
        2
    ) AS estimated_operating_margin_millions,

    ROUND(
        (
            ls.gross_revenue
            - (
                COALESCE(fs.fuel_cost, 0)
                + COALESCE(ms.maintenance_cost, 0)
                + COALESCE(cs.claims_cost, 0)
            )
        ) / ls.gross_revenue * 100,
        2
    ) AS estimated_margin_pct
FROM load_summary ls
LEFT JOIN trip_summary ts
    ON ls.business_year = ts.business_year
LEFT JOIN fuel_summary fs
    ON ls.business_year = fs.business_year
LEFT JOIN maintenance_summary ms
    ON ls.business_year = ms.business_year
LEFT JOIN claims_summary cs
    ON ls.business_year = cs.business_year
ORDER BY ls.business_year;

-- ============================================================
-- 1.3. TOP 10 CUSTOMERS BY ACTUAL GROSS REVENUE
-- ============================================================
-- Question:
-- Which customers generated the most actual gross revenue?
--
-- Annual revenue potential is intentionally excluded here because
-- it is a static customer attribute and is not clearly tied to the
-- years covered by the load activity.
--
-- Gross revenue is calculated as:
-- linehaul revenue + fuel surcharge + accessorial charges.

WITH customer_actual_revenue AS (
    SELECT
        l.customer_id,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue) AS linehaul_revenue,
        SUM(l.fuel_surcharge) AS fuel_surcharge,
        SUM(l.accessorial_charges) AS accessorial_charges,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    GROUP BY l.customer_id
)

SELECT
    c.customer_id,
    c.customer_name,
    c.customer_type,
    car.total_loads,
    ROUND(car.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(car.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(car.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(car.gross_revenue / 1000000, 2) AS gross_revenue_millions
FROM customers c
JOIN customer_actual_revenue car
    ON c.customer_id = car.customer_id
ORDER BY car.gross_revenue DESC
LIMIT 10;


-- ------------------------------------------------------------
-- 1.4 TOP 3 CUSTOMERS BY YEAR
-- ------------------------------------------------------------
-- Purpose:
-- Identify the three highest-performing customers within each
-- year and examine whether customer rankings changed over time.

WITH customer_year_revenue AS (
    SELECT
        YEAR(l.load_date) AS business_year,
        l.customer_id,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue) AS linehaul_revenue,
        SUM(l.fuel_surcharge) AS fuel_surcharge,
        SUM(l.accessorial_charges) AS accessorial_charges,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    GROUP BY
        YEAR(l.load_date),
        l.customer_id
),

ranked_customers AS (
    SELECT
        cyr.business_year,
        cyr.customer_id,
        cyr.total_loads,
        cyr.linehaul_revenue,
        cyr.fuel_surcharge,
        cyr.accessorial_charges,
        cyr.gross_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY cyr.business_year
            ORDER BY cyr.gross_revenue DESC
        ) AS customer_rank
    FROM customer_year_revenue cyr
)

SELECT
    rc.business_year,
    rc.customer_rank,
    c.customer_id,
    c.customer_name,
    c.customer_type,
    rc.total_loads,
    ROUND(rc.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(rc.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(rc.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(rc.gross_revenue / 1000000, 2) AS gross_revenue_millions
FROM ranked_customers rc
JOIN customers c
    ON rc.customer_id = c.customer_id
WHERE rc.customer_rank <= 3
ORDER BY
    rc.business_year,
    rc.customer_rank;
    
-- ============================================================
-- 2. TIME TREND ANALYSIS
-- ============================================================
-- This section explores how business activity and financial performance
-- change over time. The goal is to understand whether the company is
-- growing, whether revenue patterns are stable or uneven, and whether
-- performance changes across years or months.
--
-- The analysis begins with yearly revenue movement, then can expand into
-- load volume, seasonality, cost trends, and margin trends.
-- ============================================================


-- ------------------------------------------------------------
-- 2.1 Year-over-Year Gross Revenue Growth
-- ------------------------------------------------------------
-- Business question:
-- How has gross revenue changed from one year to the next?
--
-- Purpose:
-- This query calculates yearly gross revenue and compares each year
-- against the previous year to measure revenue growth or decline.
--
-- Gross revenue includes:
-- - linehaul revenue
-- - fuel surcharge
-- - accessorial charges

-- Year-over-year gross revenue growth
-- Purpose:
-- This query shows how total gross revenue changed from one year to the next.
-- Gross revenue includes linehaul revenue, fuel surcharge, and accessorial charges.

WITH annual_revenue AS (
    SELECT
        YEAR(load_date) AS business_year,
        SUM(revenue + fuel_surcharge + accessorial_charges) AS gross_revenue
    FROM loads
    GROUP BY YEAR(load_date)
),

revenue_with_previous_year AS (
    SELECT
        business_year,
        gross_revenue,
        LAG(gross_revenue) OVER (
            ORDER BY business_year
        ) AS previous_year_revenue
    FROM annual_revenue
)

SELECT
    business_year,
    ROUND(gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(previous_year_revenue / 1000000, 2) AS previous_year_revenue_millions,
    ROUND((gross_revenue - previous_year_revenue) / 1000000, 2) AS revenue_change_millions,
    ROUND(
        (gross_revenue - previous_year_revenue)
        / previous_year_revenue * 100,
        2
    ) AS revenue_growth_pct
FROM revenue_with_previous_year
ORDER BY business_year;

-- ------------------------------------------------------------
-- 2.2 Explaining Flat Revenue: Load Volume and Load Value
-- ------------------------------------------------------------
-- Business question:
-- Why did gross revenue remain broadly flat across the period?
--
-- Purpose:
-- This section breaks the revenue trend into load volume and load value.
-- It first checks whether shipment volume changed, then examines whether
-- the average value and mix of loads changed over time.

-- We first check the total loads across the different years
SELECT
    YEAR(load_date) AS business_year,
    COUNT(*) AS total_loads
FROM loads
GROUP BY YEAR(load_date)
ORDER BY business_year;


WITH yearly_load_revenue AS (
    SELECT
        YEAR(load_date) AS business_year,
        COUNT(*) AS total_loads,
        SUM(revenue + fuel_surcharge + accessorial_charges) AS gross_revenue
    FROM loads
    GROUP BY YEAR(load_date)
)

SELECT
    business_year,
    total_loads,
    ROUND(gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(gross_revenue / total_loads, 2) AS avg_gross_revenue_per_load
FROM yearly_load_revenue
ORDER BY business_year;



-- ------------------------------------------------------------
-- 2.2.3 Load Value Mix by Year
-- ------------------------------------------------------------
-- Business question:
-- Did the mix of low-value, standard-value, and high-value loads change over time?
--
-- Purpose:
-- Gross revenue remained broadly flat across the period. This query checks
-- whether that stability hides a shift in the types of loads being moved.
-- It classifies each load into value tiers based on gross revenue per load,
-- then compares the yearly mix of those tiers.
--
-- Load value tiers:
-- - Low Value: bottom 25% of loads by gross revenue
-- - Standard Value: middle 50% of loads by gross revenue
-- - High Value: top 25% of loads by gross revenue

WITH load_revenue AS (
    SELECT
        load_id,
        YEAR(load_date) AS business_year,
        revenue + fuel_surcharge + accessorial_charges AS gross_revenue
    FROM loads
),

load_quartiles AS (
    SELECT
        load_id,
        business_year,
        gross_revenue,
        NTILE(4) OVER (
            ORDER BY gross_revenue
        ) AS revenue_quartile
    FROM load_revenue
),

load_value_tiers AS (
    SELECT
        load_id,
        business_year,
        gross_revenue,
        CASE
            WHEN revenue_quartile = 1 THEN 'Low Value'
            WHEN revenue_quartile IN (2, 3) THEN 'Standard Value'
            WHEN revenue_quartile = 4 THEN 'High Value'
        END AS load_value_tier
    FROM load_quartiles
),

yearly_tier_summary AS (
    SELECT
        business_year,
        load_value_tier,
        COUNT(*) AS total_loads,
        SUM(gross_revenue) AS gross_revenue
    FROM load_value_tiers
    GROUP BY
        business_year,
        load_value_tier
),

yearly_load_totals AS (
    SELECT
        business_year,
        COUNT(*) AS yearly_total_loads
    FROM load_value_tiers
    GROUP BY business_year
)

SELECT
    yts.business_year,
    yts.load_value_tier,
    yts.total_loads,
    ROUND(yts.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ylt.yearly_total_loads,
    ROUND(yts.total_loads / ylt.yearly_total_loads * 100, 2) AS share_of_yearly_loads
FROM yearly_tier_summary yts
JOIN yearly_load_totals ylt
    ON yts.business_year = ylt.business_year
ORDER BY
    yts.business_year,
    CASE
        WHEN yts.load_value_tier = 'Low Value' THEN 1
        WHEN yts.load_value_tier = 'Standard Value' THEN 2
        WHEN yts.load_value_tier = 'High Value' THEN 3
    END;
    
    
    -- ------------------------------------------------------------
-- 2.3 Revenue Composition Trend
-- ------------------------------------------------------------
-- Business question:
-- Did the makeup of gross revenue change over time?
--
-- Purpose:
-- This query breaks yearly gross revenue into linehaul revenue,
-- fuel surcharge, and accessorial charges. It helps determine whether
-- flat gross revenue reflects stable core freight revenue or whether
-- one revenue component offset changes in another component.
--
-- Gross revenue includes:
-- - linehaul revenue
-- - fuel surcharge
-- - accessorial charges

WITH yearly_revenue_components AS (
    SELECT
        YEAR(load_date) AS business_year,
        SUM(revenue) AS linehaul_revenue,
        SUM(fuel_surcharge) AS fuel_surcharge,
        SUM(accessorial_charges) AS accessorial_charges
    FROM loads
    GROUP BY YEAR(load_date)
),

yearly_gross_revenue AS (
    SELECT
        business_year,
        linehaul_revenue,
        fuel_surcharge,
        accessorial_charges,
        linehaul_revenue + fuel_surcharge + accessorial_charges AS gross_revenue
    FROM yearly_revenue_components
)

SELECT
    business_year,

    ROUND(linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(gross_revenue / 1000000, 2) AS gross_revenue_millions,

    ROUND(linehaul_revenue / gross_revenue * 100, 2) AS linehaul_share_pct,
    ROUND(fuel_surcharge / gross_revenue * 100, 2) AS fuel_surcharge_share_pct,
    ROUND(accessorial_charges / gross_revenue * 100, 2) AS accessorial_share_pct

FROM yearly_gross_revenue
ORDER BY business_year;


-- ------------------------------------------------------------
-- 2.4 Known Operating Cost Trend
-- ------------------------------------------------------------
-- Business question:
-- Did known operating costs rise, fall, or remain stable while revenue stayed flat?
--
-- Purpose:
-- This query summarizes yearly fuel, maintenance, and claims costs.
-- Since gross revenue remained broadly flat, changes in these costs help
-- show whether the business faced margin pressure over time.
--
-- Note:
-- This is not a complete operating cost view. It only includes cost
-- categories available in the dataset: fuel purchases, maintenance records,
-- and safety/claims costs.

WITH yearly_fuel_cost AS (
    SELECT
        YEAR(purchase_date) AS business_year,
        SUM(total_cost) AS fuel_cost
    FROM fuel_purchases
    WHERE YEAR(purchase_date) != 2025
    GROUP BY YEAR(purchase_date)
),

yearly_maintenance_cost AS (
    SELECT
        YEAR(maintenance_date) AS business_year,
        SUM(total_cost) AS maintenance_cost
    FROM maintenance_records
    WHERE YEAR(maintenance_date) != 2025
    GROUP BY YEAR(maintenance_date)
),

yearly_claims_cost AS (
    SELECT
        YEAR(incident_date) AS business_year,
        SUM(claim_amount) AS claims_cost
    FROM safety_incidents
    WHERE YEAR(incident_date) != 2025
    GROUP BY YEAR(incident_date)
)

SELECT
    f.business_year,

    ROUND(f.fuel_cost / 1000000, 2) AS fuel_cost_millions,
    ROUND(COALESCE(m.maintenance_cost, 0) / 1000000, 2) AS maintenance_cost_millions,
    ROUND(COALESCE(c.claims_cost, 0) / 1000000, 2) AS claims_cost_millions,

    ROUND(
        (
            f.fuel_cost
            + COALESCE(m.maintenance_cost, 0)
            + COALESCE(c.claims_cost, 0)
        ) / 1000000,
        2
    ) AS known_operating_cost_millions

FROM yearly_fuel_cost f
LEFT JOIN yearly_maintenance_cost m
    ON f.business_year = m.business_year
LEFT JOIN yearly_claims_cost c
    ON f.business_year = c.business_year
ORDER BY f.business_year;

-- ------------------------------------------------------------
-- 2.5 Estimated Operating Margin Trend
-- ------------------------------------------------------------
-- Business question:
-- Did declining known operating costs improve estimated operating margin
-- while gross revenue remained broadly flat?
--
-- Purpose:
-- This query combines yearly gross revenue with known operating costs
-- to estimate how margin changed over time. Since the dataset does not
-- include every business expense, this should be interpreted as an
-- estimated margin based only on available cost categories.

WITH yearly_gross_revenue AS (
    SELECT
        YEAR(load_date) AS business_year,
        SUM(revenue + fuel_surcharge + accessorial_charges) AS gross_revenue
    FROM loads
    WHERE YEAR(load_date) BETWEEN 2022 AND 2024
    GROUP BY YEAR(load_date)
),

yearly_fuel_cost AS (
    SELECT
        YEAR(purchase_date) AS business_year,
        SUM(total_cost) AS fuel_cost
    FROM fuel_purchases
    WHERE YEAR(purchase_date) BETWEEN 2022 AND 2024
    GROUP BY YEAR(purchase_date)
),

yearly_maintenance_cost AS (
    SELECT
        YEAR(maintenance_date) AS business_year,
        SUM(total_cost) AS maintenance_cost
    FROM maintenance_records
    WHERE YEAR(maintenance_date) BETWEEN 2022 AND 2024
    GROUP BY YEAR(maintenance_date)
),

yearly_claims_cost AS (
    SELECT
        YEAR(incident_date) AS business_year,
        SUM(claim_amount) AS claims_cost
    FROM safety_incidents
    WHERE YEAR(incident_date) BETWEEN 2022 AND 2024
    GROUP BY YEAR(incident_date)
),

yearly_known_operating_cost AS (
    SELECT
        f.business_year,
        f.fuel_cost,
        m.maintenance_cost,
        c.claims_cost,
        f.fuel_cost
            + COALESCE(m.maintenance_cost, 0)
            + COALESCE(c.claims_cost, 0) AS known_operating_cost
    FROM yearly_fuel_cost f
    LEFT JOIN yearly_maintenance_cost m
        ON f.business_year = m.business_year
    LEFT JOIN yearly_claims_cost c
        ON f.business_year = c.business_year
)

SELECT
    ygr.business_year,

    ROUND(ygr.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(ykoc.known_operating_cost / 1000000, 2) AS known_operating_cost_millions,

    ROUND(
        (ygr.gross_revenue - ykoc.known_operating_cost) / 1000000,
        2
    ) AS estimated_operating_margin_millions,

    ROUND(
        (ygr.gross_revenue - ykoc.known_operating_cost)
        / ygr.gross_revenue * 100,
        2
    ) AS estimated_margin_pct

FROM yearly_gross_revenue ygr
JOIN yearly_known_operating_cost ykoc
    ON ygr.business_year = ykoc.business_year
ORDER BY ygr.business_year;

-- ============================================================
-- 3. CUSTOMER ANALYSIS
-- ============================================================
-- This section examines the customer base to understand who generates
-- the company's transportation demand and revenue. After reviewing the
-- overall business trend, the analysis now shifts to the customers behind
-- that activity.
--
-- The goal is to identify the most valuable customers, assess customer
-- concentration, compare customer types, and understand how different
-- customer groups contribute to load volume and gross revenue.
-- ============================================================

-- 3.1 Top 10 Customers by Gross Revenue
-- This query identifies the customers generating the most actual revenue.
-- Gross revenue includes linehaul revenue, fuel surcharge, and accessorial charges.
-- The revenue share shows how much each customer contributes to total company revenue.

WITH customer_revenue AS (
    SELECT
        l.customer_id,
        c.customer_name,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue) AS linehaul_revenue,
        SUM(l.fuel_surcharge) AS fuel_surcharge,
        SUM(l.accessorial_charges) AS accessorial_charges,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    JOIN customers c
        ON l.customer_id = c.customer_id
    GROUP BY
        l.customer_id,
        c.customer_name
),

total_revenue AS (
    SELECT
        SUM(gross_revenue) AS total_gross_revenue
    FROM customer_revenue
)

SELECT
    cr.customer_id,
    cr.customer_name,
    cr.total_loads,
    ROUND(cr.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(cr.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(cr.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(cr.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(cr.gross_revenue / tr.total_gross_revenue * 100, 2) AS share_of_total_revenue_pct
FROM customer_revenue cr
CROSS JOIN total_revenue tr
ORDER BY cr.gross_revenue DESC
LIMIT 10;

-- 3.2 Customer Revenue Concentration
-- This query measures how much total company revenue is generated by the largest customers.
-- It helps assess whether the business depends heavily on a small number of customers.

WITH customer_revenue AS (
    SELECT
        l.customer_id,
        c.customer_name,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    JOIN customers c
        ON l.customer_id = c.customer_id
    GROUP BY
        l.customer_id,
        c.customer_name
),

ranked_customers AS (
    SELECT
        customer_id,
        customer_name,
        gross_revenue,
        ROW_NUMBER() OVER (
            ORDER BY gross_revenue DESC
        ) AS customer_rank
    FROM customer_revenue
),

total_revenue AS (
    SELECT
        SUM(gross_revenue) AS total_gross_revenue
    FROM customer_revenue
)

SELECT
    'Top 1 Customer' AS customer_group,
    ROUND(SUM(rc.gross_revenue) / 1000000, 2) AS gross_revenue_millions,
    ROUND(SUM(rc.gross_revenue) / MAX(tr.total_gross_revenue) * 100, 2) AS share_of_total_revenue_pct
FROM ranked_customers rc
CROSS JOIN total_revenue tr
WHERE rc.customer_rank <= 1

UNION ALL

SELECT
    'Top 5 Customers' AS customer_group,
    ROUND(SUM(rc.gross_revenue) / 1000000, 2) AS gross_revenue_millions,
    ROUND(SUM(rc.gross_revenue) / MAX(tr.total_gross_revenue) * 100, 2) AS share_of_total_revenue_pct
FROM ranked_customers rc
CROSS JOIN total_revenue tr
WHERE rc.customer_rank <= 5

UNION ALL

SELECT
    'Top 10 Customers' AS customer_group,
    ROUND(SUM(rc.gross_revenue) / 1000000, 2) AS gross_revenue_millions,
    ROUND(SUM(rc.gross_revenue) / MAX(tr.total_gross_revenue) * 100, 2) AS share_of_total_revenue_pct
FROM ranked_customers rc
CROSS JOIN total_revenue tr
WHERE rc.customer_rank <= 10

UNION ALL

SELECT
    'All Customers' AS customer_group,
    ROUND(MAX(tr.total_gross_revenue) / 1000000, 2) AS gross_revenue_millions,
    100.00 AS share_of_total_revenue_pct
FROM total_revenue tr;

-- 3.3 Revenue and Load Volume by Customer Type
-- This query compares customer types by load volume and gross revenue.
-- It helps show whether the business is driven more by Contract, Dedicated, or Spot customers.

WITH customer_type_revenue AS (
    SELECT
        c.customer_type,
        COUNT(DISTINCT c.customer_id) AS number_of_customers,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue) AS linehaul_revenue,
        SUM(l.fuel_surcharge) AS fuel_surcharge,
        SUM(l.accessorial_charges) AS accessorial_charges,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM customers c
    JOIN loads l
        ON c.customer_id = l.customer_id
    GROUP BY c.customer_type
),

total_revenue AS (
    SELECT
        SUM(gross_revenue) AS total_gross_revenue
    FROM customer_type_revenue
)

SELECT
    ctr.customer_type,
    ctr.number_of_customers,
    ctr.total_loads,
    ROUND(ctr.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(ctr.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(ctr.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(ctr.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(ctr.gross_revenue / tr.total_gross_revenue * 100, 2) AS share_of_total_revenue_pct,
    ROUND(ctr.gross_revenue / ctr.total_loads, 2) AS avg_gross_revenue_per_load
FROM customer_type_revenue ctr
CROSS JOIN total_revenue tr
ORDER BY ctr.gross_revenue DESC;

-- 3.4 Freight Type Mix by Customer Type
-- This query breaks each customer type into its primary freight types.
-- It helps show what kind of freight demand sits behind Contract, Spot, and Dedicated customers.

WITH customer_type_freight_revenue AS (
    SELECT
        c.customer_type,
        c.primary_freight_type,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue) AS linehaul_revenue,
        SUM(l.fuel_surcharge) AS fuel_surcharge,
        SUM(l.accessorial_charges) AS accessorial_charges,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    JOIN customers c
        ON l.customer_id = c.customer_id
    GROUP BY
        c.customer_type,
        c.primary_freight_type
),

customer_type_total_revenue AS (
    SELECT
        customer_type,
        SUM(gross_revenue) AS customer_type_total_revenue
    FROM customer_type_freight_revenue
    GROUP BY customer_type
)

SELECT
    ctfr.customer_type,
    ctfr.primary_freight_type,
    ctfr.total_loads,
    ROUND(ctfr.linehaul_revenue / 1000000, 2) AS linehaul_revenue_millions,
    ROUND(ctfr.fuel_surcharge / 1000000, 2) AS fuel_surcharge_millions,
    ROUND(ctfr.accessorial_charges / 1000000, 2) AS accessorial_charges_millions,
    ROUND(ctfr.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(cttr.customer_type_total_revenue / 1000000, 2) AS customer_type_total_revenue_millions,
    ROUND(ctfr.gross_revenue / cttr.customer_type_total_revenue * 100, 2) AS share_of_customer_type_revenue_pct
FROM customer_type_freight_revenue ctfr
JOIN customer_type_total_revenue cttr
    ON ctfr.customer_type = cttr.customer_type
ORDER BY
    ctfr.customer_type,
    ctfr.gross_revenue DESC;
    
-- ============================================================
-- 4. ROUTE AND GEOGRAPHIC DEMAND ANALYSIS
-- ============================================================
-- This section examines where freight demand is concentrated and how
-- that demand moves across the logistics network.
--
-- After identifying who creates demand in the Customer Analysis section,
-- the next step is to understand where loads are moving geographically.
-- Revenue is not treated as something generated by a route alone; instead,
-- routes and lanes are viewed as corridors through which customer demand
-- flows.
--
-- The analysis begins by identifying the destination markets with the
-- highest load volume and gross revenue, then moves into lane-level
-- performance to understand which origin-destination corridors carry the
-- most activity and how efficiently those lanes are priced and served.
--
-- This helps distinguish between geographic demand concentration and true
-- route performance.
-- ============================================================

-- 4.1 Freight Demand by Destination Market
-- This query identifies which destination states receive the most freight demand.
-- It measures demand using total loads, gross revenue, share of total loads,
-- share of total revenue, and average gross revenue per load.

WITH destination_market_summary AS (
    SELECT
        r.destination_state,
        COUNT(l.load_id) AS total_loads,
        SUM(l.revenue + l.fuel_surcharge + l.accessorial_charges) AS gross_revenue
    FROM loads l
    JOIN routes r
        ON l.route_id = r.route_id
    GROUP BY r.destination_state
),

company_totals AS (
    SELECT
        SUM(total_loads) AS company_total_loads,
        SUM(gross_revenue) AS company_total_gross_revenue
    FROM destination_market_summary
)

SELECT
    dms.destination_state,
    dms.total_loads,
    ROUND(dms.gross_revenue / 1000000, 2) AS gross_revenue_millions,
    ROUND(dms.total_loads / ct.company_total_loads * 100, 2) AS share_of_total_loads_pct,
    ROUND(dms.gross_revenue / ct.company_total_gross_revenue * 100, 2) AS share_of_total_revenue_pct,
    ROUND(dms.gross_revenue / dms.total_loads, 2) AS avg_gross_revenue_per_load
FROM destination_market_summary dms
CROSS JOIN company_totals ct
ORDER BY dms.gross_revenue DESC;
    