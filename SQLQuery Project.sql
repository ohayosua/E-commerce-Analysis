/* 
This is an E-commerce data analysis consists of multiple tables, constructed by Yosua Saputra.
Dataset was found on Kaggle: https://www.kaggle.com/olistbr/brazilian-ecommerce?select=olist_order_payments_dataset.csv 

Context:
This dataset was generously provided by Olist, the largest department store in Brazilian marketplaces. 
Olist connects small businesses from all over Brazil to channels without hassle and with a single contract.
Those merchants are able to sell their products through the Olist Store and ship them directly to the customers 
using Olist logistics partners. See more on our website: www.olist.com
After a customer purchases the product from Olist Store a seller gets notified to fulfill that order. Once the customer receives 
the product, or the estimated delivery date is due, the customer gets a satisfaction survey by email where he can give a note 
for the purchase experience and write down some comments.


Task:
My goal for this project is to provide insights about how the business is going and potentially provide new ideas to improve the 
market going forward.
*/

-- First, how do we measure the success of this e-commerce market. 
--I want to know based off each year which months has the highest revenue.
WITH cte AS (
	SELECT o.order_id, customer_id, order_status, order_approved_at, payment_value,
		FORMAT(order_approved_at, 'yyyy') AS 'year',
		FORMAT(order_approved_at, 'MM') AS 'month'
	FROM olist_orders_dataset o
	JOIN olist_order_payments_dataset p
	ON o.order_id = p.order_id
	WHERE order_status != 'canceled'
	AND order_approved_at IS NOT NULL) 
SELECT year, month , ROUND(SUM(payment_value),2) AS total_revenue
FROM cte
GROUP BY year, month
ORDER BY 3 DESC
-- As we can see the revenue has an upward trend as the year progresses since the data we have for 2016. 
-- This is an indicator of success over the period of time

--We take a deeper dive into month by month revenue percentage:
WITH cte1 AS (
	SELECT *, 
		LAG(total_revenue) OVER(ORDER BY year_month) AS previous_month
	FROM(
		SELECT year_month, ROUND(SUM(payment_value), 2) AS total_revenue
		FROM(
			SELECT payment_value,
				FORMAT(order_approved_at, 'yyyy-MM') AS 'year_month'
			FROM olist_orders_dataset o
			JOIN olist_order_payments_dataset p
			ON o.order_id = p.order_id
			WHERE order_status != 'canceled'
			AND order_approved_at IS NOT NULL) x
		GROUP BY year_month) y)
SELECT *,
	ROUND((total_revenue-previous_month)/previous_month * 100, 2) AS monthly_pct
FROM cte1
WHERE ROUND((total_revenue-previous_month)/previous_month * 100, 2) < 0
/*Interestingly enough after showing year_months that have slowed down from its previous months in terms of revenue,
we see that December of 2016 and September of 2018 sees a drop in total revenue by nearly 100%. Given that these are
the first and latest months recorded on our original data, we want to assume not every days of these months were tracked
which led to an inflated result of monthly loss.
*/
SELECT year_month, COUNT(payment_value) AS total_countof_payments
FROM(
	SELECT o.order_id, customer_id, order_approved_at, payment_value,
		FORMAT(order_approved_at, 'yyyy-MM') AS year_month
	FROM olist_orders_dataset o
	JOIN olist_order_payments_dataset p
	ON o.order_id = p.order_id
	WHERE order_status != 'canceled'
	AND order_approved_at IS NOT NULL) a
GROUP BY year_month
ORDER BY 2
/* Surely enough there were only 1 payment recorded on both those months. 

So far in our analysis we conclude that Olist, the largest department store in Brazilian marketplaces, is heading torwards the
right direction in terms of generating payment values especially in the year 2017. However, we also notice that the growth rate is 
slowly diminishing in 2018. Olist may need additional solutions to continue its market's success.

Metrics suggested to improve Olist's success:
How most e-commerce sites make money is through advertisement campaigns and commision from its sellers. Therefore, my proposal
would be to look at how engaged our sellers are in the market, improving sellers/buyer's experience, and improving ways in
implementing our advertisements.

1. User's experience
	- Buyers and Sellers pov:
		- How many of our sellers would be considered active sellers?
		- Are buyers satisfied with their experience through olist?
2. Marketing/advertisement campaigns:
	- Although we do not have data about this topic, we can think about when would be the right time to implement our 
	  marketing campaigns/ads. 
	- Suggested location for the campaign.
3. Additional features that could potentially help the experience/success of the business
*/ 



---------------------------------------------------------------------------------------------------------------------------------------
-- 1. USER'S EXPERIENCE
-- Customer Engagement(Active sellers, buyer's experience)
/*
To determine whether a seller is active or not we will assume:
	- Really Active: Seller sold an approved order from at least 500 different dates
	- Active: Seller sold an approved order from 250-499 different dates
	- Somewhat Active: Seller sold an approved order from 50-249 different dates
	- Somewhat Not Active: Seller sold an approved order from 10-49 different dates
	- Not Active: Seller sold an approved order less than 10 different dates
*/

WITH total_engaged_seller AS (
SELECT seller_id, 
	CASE WHEN distinct_order_dates >= 500 THEN 'Really_Active'
		WHEN distinct_order_dates BETWEEN 250 AND 499 THEN 'Active'
		WHEN distinct_order_dates BETWEEN 50 AND 249 THEN 'Somewhat_Active'
		WHEN distinct_order_dates BETWEEN 10 AND 49 THEN 'Somewhat_not_Active'
		WHEN distinct_order_dates < 10 THEN 'Not_Active'
		END AS engagement
FROM (
SELECT seller_id, COUNT(DISTINCT order_approved_at) AS distinct_order_dates
FROM olist_order_items_dataset oi
JOIN olist_orders_dataset o
ON oi.order_id = o.order_id
GROUP BY seller_id) seller_activity
)
SELECT engagement, COUNT(*) AS total_engaged_results
FROM total_engaged_seller
GROUP BY engagement
ORDER BY 2
/* This query shows us that most of the sellers are inactive. For one it could mean most sellers are individuals and not 
already a business selling partner with olist. 
*/

/* Next we will analyze the buyers and their experience. Given their review_score I will want to know the average based on 
the difference between their estimated shipping and how long it actually took, as well as the average rating in which 
products/product-category scored the highest average reviews. This will also give valuable insights to sellers as well.
*/
WITH shipping_difference AS (
	SELECT order_id, review_score, 
		DATEDIFF(day, order_approved_at, order_estimated_delivery_date) AS est_duration,
		DATEDIFF(day, order_approved_at, order_delivered_customer_date) AS actual_duration,
		DATEDIFF(day, order_approved_at, order_estimated_delivery_date) - DATEDIFF(day, order_approved_at, order_delivered_customer_date)
		AS diff
	FROM (
		SELECT review_id, r.order_id, review_score, order_approved_at, order_delivered_customer_date, order_estimated_delivery_date
		FROM olist_order_reviews_dataset r
		JOIN olist_orders_dataset o
		ON r.order_id = o.order_id
		WHERE order_status != 'canceled'
		AND order_approved_at IS NOT NULL) x)
SELECT diff, ROUND(AVG(review_score), 2) AS avg_review
FROM shipping_difference
GROUP BY diff
ORDER BY diff
/* A few reviews scored well even though the shipping process was delayed tremendously. However, we can safely conclude that
those who's orders were on time or even days or months ahead of its estimated schedule received the highest reviews.
*/
-- For the products:
SELECT COALESCE(product_category_name, 'Other') AS product_category_name, COUNT(product_category_name) AS amount,
	AVG(DATEDIFF(day, order_approved_at, order_estimated_delivery_date) - DATEDIFF(day, order_approved_at, order_delivered_customer_date))
	AS shipping_diff,
	ROUND(AVG(review_score), 2) AS avg_review
FROM(
	SELECT r.order_id, review_score, order_approved_at, order_delivered_customer_date, order_estimated_delivery_date,
		oi.product_id, product_category_name
	FROM olist_order_reviews_dataset r
	JOIN olist_orders_dataset o
	ON r.order_id = o.order_id
	JOIN olist_order_items_dataset oi
	ON o.order_id = oi.order_id
	JOIN olist_products_dataset p
	ON oi.product_id = p.product_id
	WHERE order_status != 'canceled'
	AND order_approved_at IS NOT NULL) category_reviews
GROUP BY product_category_name
ORDER BY 4 DESC
-- From our output we see that average reviews by category name does not correlate with how much the shipping date deviates from the
-- estimated shipping date. Also to take into consideration is the amount ordered per each product's category.



-- 2. MARKETING/ADVERTISEMENT CAMPAIGN:
/*
Our data does not give us values about revenue associating with ads or marketing campaigns. However, many of the largest-commerce sites 
make money through advertisement campaigns and in this section I will analyze the right place or time to implement these 
additional measures.
*/

-- First we want to look at what times during the given day orders are being placed.
SELECT hour_day, COUNT(*) AS total_purchases
FROM(
	SELECT order_purchase_timestamp, FORMAT(order_purchase_timestamp,'HH') AS hour_day
	FROM olist_orders_dataset) hours_purchased
GROUP BY hour_day
ORDER BY total_purchases DESC
/*
Most products are bought around 4:00 pm, 11:00 am, 2:00pm, 1:00pm, 3:00 pm, 9:00 pm, 8:00pm,  respectively.
Least active purchases around 5:00 am, 4:00 am, 3:00 am, 6:00 am , assuming when most people are usually not awake
This could possibly show the times during the days when online traffic spike as well. Why could this be helpful? 
Given this data, product specific ads can be implemented during the peak hours when most people are browsing the web. Keep in
mind the cost to produce the ongoing marketing campaign can affect the profit margins for the better or worse. 
*/

-- Now we will look at the location which would best be appropriate to implement potential ads to maximize profit.
-- For this example I will write a query for busiest hours during the day, of the top ten state-city and its total number purchases.

WITH top_10 AS (
	SELECT customer_state, customer_city
	FROM(
		SELECT *, RANK() OVER(ORDER BY total_purchases_count DESC) AS ranking
		FROM (
			SELECT customer_state, customer_city, COUNT(*) AS total_purchases_count
			FROM olist_customers_dataset c
			JOIN olist_orders_dataset o
			ON c.customer_id = o.customer_id
			WHERE order_status != 'canceled'
			AND order_approved_at IS NOT NULL
			GROUP BY customer_state, customer_city) ranks) rankss
			WHERE ranking BETWEEN 1 AND 10)

SELECT customer_state, customer_city, hour_day, COUNT(hour_day) AS total
FROM
	(SELECT customer_state, customer_city, order_purchase_timestamp, 
		FORMAT(order_purchase_timestamp,'HH') AS hour_day
	FROM olist_customers_dataset c
	JOIN olist_orders_dataset o
	ON c.customer_id = o.customer_id) location_time
	WHERE EXISTS (
		SELECT 1 
		FROM top_10 
		WHERE location_time.customer_state = top_10.customer_state
		AND location_time.customer_city = top_10.customer_city)
		GROUP BY customer_state, customer_city, hour_day
		ORDER BY total DESC

/* The query shows the top 10 most engaged location by state and city based off of total count of orders that have been purchased. 
Then outputs the most busiest hours during the 24 hour day. The results states city of Sao Paulo which is located in the state 'SP' 
is the busiest location and within this exact location at 4:00 pm is where online traffic is at its peak. This could give olist an
idea now of where or where not to implement its market strategies with an addition to its given time during the day.
*/



-- 3. ADDITIONAL FEATURES THAT COULD HELP INCREASE LEVEL OF EXPERIENCE/SUCCESS 
/*
This last section is to provide additional assumptions on improving olist moving forward. As we saw earlier in our analysis, the
customer's ratings have a correlation with how far off its order's shipping estimate is from the actual shipping date. Most being
days, weeks, or sometimes even months keeping the customers waiting. To improve the customer's experience even further, olist can look 
to consider e-commerce subscription plans. For example, the largest and most successful e-commerce company, Amazon, has its very own
subscription program where they charge its users a monthly or annaul fee. By subscribing and becoming a member they get access to 
faster shipping, exclusive deals, and many more perks. This could potentially enhance customers' experience and in addition to 
generating more profits for olist as a whole with a fair and strategized price.
*/
