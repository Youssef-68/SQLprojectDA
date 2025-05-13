WITH base_query AS (
	-- 1)Retrieve core columns from tables
SELECT 
	s.order_number,
	s.product_key,
	s.order_date,
	s.sales_amount,
	s.quantity,
	c.customer_key,
	c.customer_number,
	c.birthdate,
	DATEDIFF(year, c.birthdate, GETDATE()) age,
	CONCAT(c.first_name, ' ', c.last_name) as customer_name
FROM [dbo].[gold.fact_sales] s
LEFT JOIN  [dbo].[gold.dim_customers] c
ON c.customer_key = s.customer_key
WHERE c.birthdate IS NOT NULL		),

customer_agg AS (

	-- 2)Customer Aggregation: Summarizes key matrics at the customer level
SELECT 
	customer_key,
	customer_number,
	age,
	customer_name,

	/*3.Aggregates customer-level metrics:
      - total orders
      - total sales
      - total quantity purchased
      - total products
      - lifespan (in months)	*/

	count(distinct order_number) as total_orders,
	sum(sales_amount) as total_sales,
	sum(quantity) as total_quantity,
	max(order_date) as last_order_date,
	DATEDIFF(month, min(order_date), max(order_date)) as lifespan
FROM base_query
GROUP BY customer_key,
	customer_number,
	customer_name,
	age			)

SELECT customer_key,
	customer_number,
	customer_name,
	age,
	CASE WHEN age < 20 THEN 'UNDER 20'
		 WHEN age BETWEEN 20 AND 29 THEN '20-29'
		 WHEN age BETWEEN 30 AND 39 THEN '30-39'
		 WHEN age BETWEEN 40 AND 49 THEN '40-49'
		 ELSE '50 and Above'
	END AS age_group,
	CASE WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
		 WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'REGULAR'
		 ELSE 'NEW'
	END AS customer_segment,
	last_order_date,



	-- 4)Calculates valuable KPIs:-
	DATEDIFF(month, last_order_date, GETDATE()) as recency,		--KPI_1: recency (months since last order)
	total_orders,
	total_sales,
	total_quantity,
	lifespan,
    CASE WHEN total_orders=0 THEN total_sales				--KPI2: average order value
		 ELSE (total_sales / total_orders) 
		 END AS avg_order_value,		
	CASE WHEN lifespan=0 THEN total_sales					--KPI3: average monthly spend
		 ELSE (total_sales / lifespan) 
		 END AS average_monthly_spend		
FROM customer_agg;



SELECT customer_segment,
	   count(distinct customer_number) as total_customers,
	   sum(total_sales) as total_sales
FROM [SQLp].[dbo].[gold.report_customers]
GROUP BY customer_segment
ORDER BY customer_segment;
