create or replace view customers_revenue_pareto as
with
    total_revenue as (
        select sum(amount) as total_revenue
        from sakila.payment
    ),
    customer_revenue as (
        select
            c.customer_id,
            sum(p.amount) as total_spent
        from sakila.customer c
        join sakila.payment p on p.customer_id = c.customer_id
        group by c.customer_id
    ),
    ranked_customers as (
        select
            cr.customer_id,
            cr.total_spent,
            (cr.total_spent / tr.total_revenue) * 100 as revenue_stake,
            sum((cr.total_spent / tr.total_revenue) * 100) over (order by (cr.total_spent / tr.total_revenue) * 100 desc) as cumulated_stake
        from customer_revenue cr
        cross join total_revenue tr
    )
select
    rc.customer_id as kunden_id,
    concat(concat(upper(substring(c.first_name, 1, 1)), lower(substring(c.first_name, 2))), " ", concat(upper(substring(c.last_name, 1, 1)), lower(substring(c.last_name, 2)))) as kunde,
    rc.total_spent as kunden_umsatz,
    concat(((
		select max(customer_count) as max_customer_count
			from (
				select count(customer_id) as customer_count
					from ranked_customers
				where cumulated_stake <= 80
			) as t ) / (select count(customer_id) from sakila.customer)) * 100, "%" ) 
	as pareto_ratio
from sakila.customer c
join ranked_customers rc on rc.customer_id = c.customer_id
cross join total_revenue tr
where rc.cumulated_stake <= 80
group by 1, 2, 3
order by 3 desc;


select
	cy.name as Kategorie,
    count(r.rental_id) as "Anzahl Ausleihen",
    concat("$", sum(p.amount)) as Umsatz
		from customers_revenue_pareto crp
		join sakila.payment p on p.customer_id = crp.kunden_id
		join sakila.rental r on r.rental_id = p.rental_id
		join sakila.inventory inv on inv.inventory_id = r.inventory_id
		join sakila.film_category fc on fc.film_id = inv.film_id
		join sakila.category cy on cy.category_id = fc.category_id
group by cy.category_id
order by sum(p.amount) desc;
