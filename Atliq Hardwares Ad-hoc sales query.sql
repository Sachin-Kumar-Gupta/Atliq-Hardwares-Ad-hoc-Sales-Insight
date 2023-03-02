select * from dim_customer;
select * from dim_product;
select * from fact_gross_price;
select * from fact_manufacturing_cost;
select * from fact_pre_invoice_deductions;
select * from fact_sales_monthly;

--1.Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select distinct(market) from dim_customer
where customer = 'Atliq Exclusive' and region = 'APAC';

--2.What is the percentage of unique product increase in 2021 vs. 2020?

with unique_prod as (
	select count(distinct case when cost_year = 2020 then product_code else 'Null' end) as unique_prod_2020,
	count(distinct case when cost_year = 2021 then product_code else 'Null' end) as unique_prod_2021
    from fact_manufacturing_cost)
	
select unique_prod_2020, unique_prod_2021,round(((unique_prod_2021 - unique_prod_2020):: numeric/unique_prod_2020)*100,2) as percentage_chg 
from unique_prod;

--3.Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.

select segment,count(distinct(product_code)) as prod_count from dim_product
group by segment
order by prod_count desc;

--4.Which segment had the most increase in unique products in 2021 vs 2020?

with prod as(
     select d.segment, count(distinct case when t.cost_year = 2020 then d.product_code else 'Null' end) as product_count_2020,
     count(distinct case when t.cost_year = 2021 then d.product_code else 'Null' end) as product_count_2021
	 from dim_product d
	 join fact_manufacturing_cost t on d.product_code = t.product_code
     group by d.segment)

select segment, product_count_2020, product_count_2021, (product_count_2021 - product_count_2020) as difference
from prod
order by difference desc;

--5.Get the products that have the highest and lowest manufacturing costs.

(select f.product_code, d.product, f.manufacturing_cost
from fact_manufacturing_cost f
join dim_product d on f.product_code = d.product_code
order by 3 desc
limit 1)
union all
(select f.product_code, d.product, f.manufacturing_cost
from fact_manufacturing_cost f
join dim_product d on f.product_code = d.product_code
order by 3 asc
limit 1);

--6.Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.

select f.customer_code,d.customer, round((avg(pre_invoice_discount_pct)*100.0),2) as avg
from fact_pre_invoice_deductions f
join dim_customer d on f.customer_code = d.customer_code
where f.fiscal_year = 2021 and d.market = 'India'
group by f.customer_code, d.customer
order by 3 desc
limit 5;

--7.Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month .

select extract('month' from f.date) as Month, extract('year' from f.date) as Year,
round(sum(f.sold_quantity*g.gross_price),2)
from fact_sales_monthly f
join fact_gross_price g 
on f.product_code = g.product_code and f.fiscal_year = g.fiscal_year
join dim_customer d on f.customer_code = d.customer_code
where d.customer = 'Atliq Exclusive'
group by Year, Month
order by Year , Month asc

--8.In which quarter of 2020, got the maximum total_sold_quantity?

select case 
when extract('month' from date) in (9,10,11) then 'Q1'
when extract('month' from date) in (12,1,2) then 'Q2'
when extract('month' from date) in (3,4,5) then 'Q3'
else 'Q4' end as Quarter, sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year = 2020
group by extract('month' from date),extract('year' from date)
order by total_sold_quantity desc

--9.Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?

with gross as(
	select d.channel, round(sum(f.sold_quantity*g.gross_price)/1000000,2) as gross_sales_mln
	from fact_sales_monthly f
	join fact_gross_price g 
	on f.product_code = g.product_code and f.fiscal_year = g.fiscal_year
	join dim_customer d on f.customer_code = d.customer_code
	where f.fiscal_year = 2021
	group by d.channel)

select *, ROUND(100.0 * (gross_sales_mln / sum(gross_sales_mln) over()), 2) as percentage
from gross
order by gross_sales_mln desc

--10.Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?

with sold as(
     select d.division,d.product, f.product_code, sum(f.sold_quantity) as total_sold_quantity,
	(dense_rank() over(partition by d.division order by sum(f.sold_quantity) desc))
	 from fact_sales_monthly f
	 join dim_product d on f.product_code = d.product_code
	 where f.fiscal_year = 2021
	 group by d.division,d.product, f.product_code)
	 
select division, product_code, product,total_sold_quantity, dense_rank as rank_order
from sold
where dense_rank <= 3
group by division, product_code, product,total_sold_quantity, dense_rank
order by division, rank_order asc

	 