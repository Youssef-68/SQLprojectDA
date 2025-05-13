USE [SQLp]
GO

--Change Over Time (Trend of Sales)
SELECT year(order_date) as order_year,
       month(order_date) as order_month,
       count(distinct customer_key) as total_customer,
	     sum(quantity) as total_quantity,
	     sum(sales_amount) as total_sales 
FROM [dbo].[gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP BY year(order_date), month(order_date)
ORDER BY year(order_date), month(order_date);


--Aggregate the data progressively over time (Cumulative)
SELECT order_date,
       total_sales,
	     sum(total_sales) OVER (ORDER BY order_date) as running_total_sales
FROM (
SELECT DATETRUNC(month, order_date) as order_date, sum(sales_amount) as total_sales 
FROM [dbo].[gold.fact_sales]
WHERE order_date IS NOT NULL
GROUP By DATETRUNC(month, order_date)
) t;


--Analyze the yearly performance of product by comparing the average sales performance of the product
WITH yearly_sales AS (
SELECT year(s.order_date) as order_year, 
	     p.product_name, 
	     sum(s.sales_amount) as current_sales
FROM [dbo].[gold.fact_sales] s
LEFT JOIN [dbo].[gold.dim_products] p
ON s.product_key = p.product_key
WHERE s.order_date IS NOT NULL
GROUP BY year(s.order_date), p.product_name
)

SELECT product_name,
       order_year,
	     current_sales,
       avg(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
	   current_sales - avg(current_sales) OVER (PARTITION BY product_name) as diff_avg,
	-- YEAR over Year analysis
	   LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) py_sales,
	   current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) as diff_by,
	   CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	        WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
			    ELSE 'No change'
	   END py_change
FROM yearly_sales
ORDER BY product_name, order_year;


--Which categories contribute the most to overall sales
WITH category_sales as(
SELECT category, sum(sales_amount) as total_sales
FROM [dbo].[gold.fact_sales] s
LEFT JOIN [dbo].[gold.dim_products] p
ON s.product_key = p.product_key
GROUP BY category)

SELECT category, total_sales, CONCAT(ROUND((CAST (total_sales AS FLOAT) / sum(total_sales)  OVER())*100, 2), '%') as percentage_of_total_sales
FROM category_sales
ORDER BY total_sales;


--Segment products into cost ranges and count how many products fall into each segment
WITH product_segments AS (
SELECT product_key,
       product_name,
	   cost,
	   CASE WHEN cost < 100 THEN  'BELOW 100'
	        WHEN cost BETWEEN 100 AND 500 THEN  'BETWEEN 100 to 500'
			    WHEN cost BETWEEN 500 AND 1000 THEN  'BETWEEN 500 to 1000'
			    ELSE 'ABOVE 1000'
	   END cost_range    
FROM [dbo].[gold.dim_products])
SELECT cost_range, count(product_key) as total_products, sum(cost) as total_costs FROM product_segments
GROUP BY cost_range
ORDER BY total_products;
