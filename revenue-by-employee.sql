/*Szenario:
Die Zentrale möchte einen umfassenden Bericht über die Leistung der einzelnen Filialen. 
Der Bericht soll die Kennung der Filiale, den Gesamtumsatz, die durchschnittlichen Kundenausgaben, 
die Kategorie mit dem höchsten Umsatz und den Namen des Mitarbeiters mit der besten Leistung gemessen am Gesamtumsatz enthalten. 
Die Leistung des Personals wird innerhalb jeder Filiale eingestuft.
Gehe davon aus, dass genau eine Kategorie und genau ein Mitarbeiter den höchsten Wert hat.*/

select
	st.store_id as "Laden ID",
    city.city as Standort,
    concat("$", sum(p.amount)) as "Gesamtumsatz des Ladens",
    concat("$", round(avg(p.amount), 2)) as "⌀ Kundenausgaben",
    (select
		cy.name as Kategorie
			from sakila.category cy
            join sakila.film_category fc on fc.category_id = cy.category_id
            join sakila.inventory inv on inv.film_id = fc.film_id
            join sakila.rental r on r.inventory_id = inv.inventory_id
            join sakila.payment p on p.rental_id = r.rental_id
		where inv.store_id = st.store_id
		group by 1
        order by sum(p.amount) desc
        limit 1
	) as "Kategorie mit höchstem Umsatz",
	(select
		concat(s.first_name, " ", s.last_name) as Mitarbeiter
			from sakila.staff s
            join sakila.payment p on s.staff_id = p.staff_id
		where s.store_id = st.store_id
        group by 1
        order by sum(p.amount) desc
        limit 1
    ) as "Mitarbeiter mit höchstem Umsatz"
		from sakila.store st
        join sakila.address a on a.address_id = st.address_id
		join sakila.city on city.city_id = a.city_id
		join sakila.staff s on s.store_id = st.store_id
		join sakila.rental r on r.staff_id = s.staff_id
        join sakila.payment p on p.rental_id = r.rental_id
	group by 1;
 
 
 
with
	category_revenue as (
		select
			inv.store_id,
			cy.name as Kategorie,
			sum(p.amount) as category_revenue
				from sakila.category cy
				join sakila.film_category fc on fc.category_id = cy.category_id
				join sakila.inventory inv on inv.film_id = fc.film_id
				join sakila.rental r on r.inventory_id = inv.inventory_id
				join sakila.payment p on p.rental_id = r.rental_id
			group by 1, 2
		),
    staff_revenue as (
		select
			s.store_id,
            concat(s.first_name, " ", s.last_name) as Mitarbeiter,
            sum(p.amount) as staff_revenue
				from sakila.staff s
                join sakila.payment p on p.staff_id = s.staff_id
			group by 1, s.staff_id
    ),
	max_category_revenue as (
		select
			t.store_id,
            Kategorie
				from
					(select
						*,
                        rank() over (partition by store_id order by category_revenue desc) as cr_rank
							from category_revenue
					) t
				where cr_rank = 1
    ),
    max_staff_revenue as (
		select
			t.store_id,
            Mitarbeiter
				from
					(select
						*,
                        rank() over (partition by store_id order by staff_revenue desc) as sr_rank
							from staff_revenue
					) t
				where sr_rank = 1
    )
select
	st.store_id as "Laden ID",
    city.city as Standort,
    concat("$", sum(p.amount)) as "Gesamtumsatz des Ladens",
    concat("$", round(avg(p.amount), 2)) as "⌀ Kundenausgaben",
	mcr.Kategorie as "Kategorie mit dem höchstem Umsatz",
    msr.Mitarbeiter as "Mitarbeiter mit dem höchstem Umsatz"
		from sakila.store st
        join sakila.address a on a.address_id = st.address_id
		join sakila.city on city.city_id = a.city_id
		join sakila.staff s on s.store_id = st.store_id
		join sakila.rental r on r.staff_id = s.staff_id
        join sakila.payment p on p.rental_id = r.rental_id
        join max_category_revenue mcr on mcr.store_id = st.store_id
        join max_staff_revenue msr on msr.store_id = st.store_id
	group by 1, 5, 6
    order by 1;
