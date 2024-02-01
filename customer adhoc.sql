 /*1Provide the list of markets in which customer "Atliq Exclusive" operates its
business in the APAC region.*/

SELECT Distinct market 
FROM gdb023.dim_customer 
where customer = "Atliq Exclusive" and region = "APAC" Group by market;

/*2 What is the percentage of unique product increase in 2021 vs. 2020? The
final output contains these fields,
unique_products_2020
unique_products_2021
percentage_chg*/

SELECT Product2020.A AS unique_product_2020, Product2021.B AS unique_products_2021, ROUND((B-A)*100/A, 2) AS percentage_chg
FROM
     (
      (SELECT COUNT(DISTINCT(product_code)) AS A FROM gdb023.fact_sales_monthly
      WHERE fiscal_year = 2020) Product2020,
      (SELECT COUNT(DISTINCT(product_code)) AS B FROM gdb023.fact_sales_monthly
      WHERE fiscal_year = 2021) Product2021 
	 )
     ;
     
     /*3. Provide a report with all the unique product counts for each segment and
sort them in descending order of product counts. The final output contains
2 fields,
segment
product_count*/

SELECT segment, COUNT(DISTINCT(product_code)) AS product_count FROM gdb023.dim_product
GROUP BY segment
ORDER BY product_count DESC ;

/*4. Follow-up: Which segment had the most increase in unique products in
2021 vs 2020? The final output contains these fields,
segment
product_count_2020
product_count_2021
difference*/

WITH CTE AS (
    SELECT
        P.segment,
        COUNT(DISTINCT FS.product_code) AS product_count,
        FS.fiscal_year,
        ROW_NUMBER() OVER (PARTITION BY FS.fiscal_year ORDER BY P.segment) AS row_num
    FROM
        gdb023.dim_product P
    JOIN
        gdb023.fact_sales_monthly FS ON P.product_code = FS.product_code
    WHERE
        FS.fiscal_year IN ('2020', '2021')
    GROUP BY
        FS.fiscal_year, P.segment
)

SELECT
    A.segment,
    MAX(CASE WHEN fiscal_year = '2020' THEN product_count END) AS product_count_2020,
    MAX(CASE WHEN fiscal_year = '2021' THEN product_count END) AS product_count_2021,
    MAX(CASE WHEN fiscal_year = '2021' THEN product_count END) - MAX(CASE WHEN fiscal_year = '2020' THEN product_count END) AS difference
FROM
    CTE A
GROUP BY
    A.row_num, A.segment;


   /*5. Get the products that have the highest and lowest manufacturing costs.
The final output should contain these fields,
product_code
product
manufacturing_cost*/
  
     WITH RankedProducts AS (
    SELECT product_code,product,manufacturing_cost,
        RANK() OVER (ORDER BY manufacturing_cost) AS cost_rank_asc,
        RANK() OVER (ORDER BY manufacturing_cost DESC) AS cost_rank_desc
    FROM gdb023.fact_manufacturing_cost F JOIN gdb023.dim_product P using(product_code)
)
SELECT product_code, product,manufacturing_cost
FROM RankedProducts
WHERE cost_rank_asc = 1 OR cost_rank_desc = 1;

/*6. Generate a report which contains the top 5 customers who received an
average high pre_invoice_discount_pct for the fiscal year 2021 and in the
Indian market. The final output contains these fields,
customer_code
customer
average_discount_percentage*/
SELECT
    C.customer_code,
    C.customer,
    Round(AVG(FP.pre_invoice_discount_pct),4) AS avg_discount_pct
   FROM gdb023.fact_pre_invoice_deductions FP
INNER JOIN
gdb023.dim_customer C ON FP.customer_code = C.customer_code
WHERE C.market = 'India' AND FP.fiscal_year = '2021'
GROUP BY C.customer_code, C.customer
Order by avg_discount_pct desc
limit 5 ;
/*7. Get the complete report of the Gross sales amount for the customer “Atliq
Exclusive” for each month. This analysis helps to get an idea of low and
high-performing months and take strategic decisions.
The final report contains these columns:
Month
Year
Gross sales Amount*/

WITH temp_table AS (
    SELECT customer,
    monthname(date) AS months ,
    year(date) AS year,
    (sold_quantity * gross_price)  AS gross_sales
 FROM gdb023.fact_sales_monthly s JOIN
 gdb023.fact_gross_price g ON s.product_code = g.product_code
 JOIN gdb023.dim_customer c ON s.customer_code=c.customer_code
 WHERE customer="Atliq exclusive"
)
SELECT months,year, concat(round(sum(gross_sales)/1000000,2),"M") AS gross_sales FROM temp_table
GROUP BY year,months
ORDER BY year,months;

/*8. In which quarter of 2020, got the maximum total_sold_quantity? The final
output contains these fields sorted by the total_sold_quantity,
Quarter
total_sold_quantity*/

SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then 'Q1' 
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then 'Q2'
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then 'Q3'
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then 'Q4'
    END AS Quarters,
    SUM(sold_quantity) AS total_sold_quantity
FROM gdb023.fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters
ORDER BY total_sold_quantity DESC;

#TASK 9
WITH cte AS (
      SELECT c.channel,sum(s.sold_quantity * g.gross_price) AS total_sales
  FROM gdb023.fact_sales_monthly s 
  JOIN gdb023.fact_gross_price g ON s.product_code = g.product_code
  JOIN gdb023.dim_customer c ON s.customer_code = c.customer_code
  WHERE s.fiscal_year= 2021
  GROUP BY c.channel
  ORDER BY total_sales DESC
)
SELECT channel,
  round(total_sales/1000000,2) AS gross_sales_in_millions,
  round(total_sales/(sum(total_sales) OVER())*100,2) AS percentage 
FROM cte ;


-- TASK 10
/*10. Get the Top 3 products in each division that have a high
total_sold_quantity in the fiscal_year 2021? The final output contains these
fields,
division
product_code
product
total_sold_quantity
rank_order*/

WITH temp_table AS (
    select division, s.product_code,sum(sold_quantity) AS total_sold_quantity,
    rank() OVER (partition by division order by sum(sold_quantity) desc) AS rank_order
 FROM
 gdb023.fact_sales_monthly s
 JOIN gdb023.dim_product p
 ON s.product_code = p.product_code
 WHERE fiscal_year = 2021
 GROUP BY product_code,division
)
SELECT * FROM temp_table
WHERE rank_order IN (1,2,3);

