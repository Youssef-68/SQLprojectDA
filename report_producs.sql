WITH base_query AS (
-- 1)Gathers essential fields such as product name, category, subcategory, and cost.
SELECT s.order_number,
	   s.order_date,
	   s.customer_key,
	   s.sales_amount,
	   s.quantity,
	   p.product_name,
	   p.product_key,
	   p.category,
	   p.subcategory,
	   p.cost
FROM [dbo].[gold.fact_sales] s
LEFT JOIN [dbo].[gold.dim_products] p
ON s.product_key = p.product_key
WHERE order_date IS NOT NULL),

-- 2)Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
product_agg AS (
SELECT product_key,
	   product_name,
	   category,
	   subcategory,
	   cost,
	   count(distinct order_number) as total_orders,
	   count(distinct customer_key) as total_customers,
	   sum(sales_amount) as total_sales,
	   sum(quantity) as total_quantity,
	   max(order_date) as last_order_date,
	   DATEDIFF(month, min(order_date), max(order_date)) as lifespan,
	   ROUND(AVG(CAST(sales_amount aS FLOAT)/NULLIF(quantity,0)),1) AS avg_salling_price
FROM base_query
GROUP BY product_key,
	   product_name,
	   category,
	   subcategory,
	   cost)

/* 3)Aggregates product-level metrics:
		total orders
		total sales
		total quantity sold
		total customers (unique)
		lifespan (in months)	*/
SELECT product_key,
	   product_name,
	   category,
	   subcategory,
	   cost,
	   last_order_date,
	   DATEDIFF(month, last_order_date, GETDATE()) as recency_in_months,
	   CASE WHEN total_sales > 50000 THEN 'High Performance'
			WHEN total_sales >= 10000 THEN 'Mid Range'
			ELSE 'Low performance'
	   END AS product_segment,
	   lifespan,
	   total_orders,
	   total_sales,
	   total_quantity,
	   total_customers,
	   avg_salling_price,
	   CASE WHEN total_orders=0 THEN total_sales	
		 ELSE (total_sales / total_orders) 
		 END AS avg_order_value,		
	CASE WHEN lifespan=0 THEN total_sales	
		 ELSE (total_sales / lifespan) 
		 END AS average_monthly_spend
FROM product_agg
