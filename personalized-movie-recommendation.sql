### Verbessern der Kundenerfahrung durch Filmempfehlungen ###

• Szenario
	Als SQL-Experte bei einem Filmverleih, der die Sakila-Beispieldatenbank einsetzt, werden Sie vom Team für Kundenzufriedenheit kontaktiert. 
	Sie möchten die Kundenzufriedenheit durch personalisierte Filmempfehlungen verbessern. 
	Die Idee ist, die bisherige Verleihhistorie der Kunden zu analysieren und ihnen ähnliche Filme zu empfehlen, die ihnen zuvor gefallen haben.

• Zielsetzung
	Ihre Aufgabe ist es, mit Hilfe von SQL das Filmverleihverhalten der Kunden zu analysieren und eine Abfrage zu erstellen, 
	die für jeden Kunden auf der Grundlage seiner früheren Vorlieben Filme vorschlägt. 
	Das Empfehlungssystem sollte Faktoren wie Filmgenres, Schauspieler und Regisseure berücksichtigen, die mit der Verleihhistorie des Kunden übereinstimmen.
    
# Anforderungen #
1. Analysieren Sie die individuellen Kundenpräferenzen:
	• Untersuchen Sie die Genres und Schauspieler in den Filmen, die jeder Kunde ausgeliehen hat.
	• Ermitteln Sie die am häufigsten ausgeliehenen Genres und Schauspieler für jeden Kunden.

2. Identifizieren Sie potenzielle Filmempfehlungen:
	• Identifizieren Sie auf der Grundlage der bevorzugten Genres und Schauspieler jedes Kunden andere Filme in der Sakila-Datenbank, 
	  die diesen Vorlieben entsprechen, aber noch nicht von dem Kunden ausgeliehen wurden.

3. Ausgabeformat:
	• Die Ausgabe sollte jeden Kunden und seine empfohlenen Filme klar auflisten.
	• Dazu gehören auch relevante Filmdetails wie Titel und Kategorie.
    
4. Strategische Analyse zur Verbesserung des Kundenerlebnisses:
	• Denken Sie kreativ darüber nach, wie Sie die verfügbaren Daten nutzen können, um aussagekräftige Filmempfehlungen zu geben.
	• Dokumentieren Sie die Logik hinter der Abfrage und erläutern Sie, wie diese mit dem Ziel der Verbesserung des Kundenerlebnisses zusammenhängt.
    
# Vorgeschlagene Herangehensweise #
	• Verwenden Sie Tabellen wie customer, rental, film, film_actor, actor, film_category, category, und inventory.
	• Beginnen Sie damit, eine Abfrage oder eine Reihe von Abfragen zu erstellen, um die am häufigsten ausgeliehenen Genres und Schauspieler jedes Kunden zu ermitteln.
	• Entwickeln Sie eine Abfrage, um Filme zu finden, die diesen Vorlieben entsprechen, aber noch nicht vom Kunden ausgeliehen wurden.
	• Überlegen Sie sich, mehrere Tabellen zu verknüpfen, um einen umfassenden Überblick über Filme, Schauspieler, Genres und Verleihhistorie zu erhalten.
*/

DELIMITER $$
CREATE DEFINER=`root`@`localhost` FUNCTION `count_matching_words`(description TEXT, keywords TEXT) RETURNS int
    DETERMINISTIC
begin
	declare word_count int default 0 ;
    declare current_word varchar(255) ;
    declare delimiter char(1) default ' ' ;
    declare i int default 1 ;
    while i <= char_length(description) do
		set current_word = substring_index(substring_index(description, delimiter, i), delimiter, -1);
		if char_length(current_word) > 3 and find_in_set(current_word, keywords) then set word_count = word_count + 1;
        end if;
        set i = i + 1;
	end while;
    return word_count;
end$$
DELIMITER ;
  

set @Kunde = 325;


with
	kunde as (
		select
			c.customer_id as kunden_id,
            c.store_id as laden_id
				from sakila.customer c
		where c.customer_id = @Kunde
), 	-- wählt den Kunden aus der Datenbank, dem eine Empfehlung erstellt wird.
	-- In den weiteren Schritten werden dann nur Informationen zu diesem Kunden abgerufen, um die Abfrage effizient zu gestalten.
	kunde_verlauf_film as (
		select
			f.film_id,
            f.description as beschreibung
				from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
		group by 1
),	-- Gibt die bisherigen Ausleihen des Kunden aus. 
	kunde_vorlieben_kategorie as (
		select
			cy.category_id
				from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
                join sakila.film_category fc on fc.film_id = f.film_id
                join sakila.category cy on cy.category_id = fc.category_id
                join kunde k on k.kunden_id = r.customer_id
		group by 1
), 	-- Fragt die Filmkategorien ab, die der Kunde bisher ausgeliehen hat.
	kunde_vorlieben_schauspieler as (
		select
			a.actor_id
				from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
                join sakila.film_actor fa on fa.film_id = f.film_id
                join sakila.actor a on a.actor_id = fa.actor_id
                join kunde k on k.kunden_id = r.customer_id
		group by 1
),	-- Fragt die Schauspieler ab, die der Kunde bisher ausgeliehen hat.
	kunde_vorlieben_rating as (
		select
			f.rating
				from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
                join kunde k on k.kunden_id = r.customer_id
		group by 1
),	-- Fragt die Film-Ratings ab, die der Kunde bisher ausgeliehen hat.
	bestand as (
		select
			inv.inventory_id,
            count(inv.inventory_id) as bestand
			from sakila.inventory inv
		group by 1
		order by 1
),	-- Überpruft den Bestand an Filmen im Bestand.
	PG as (
		select 
			case
				when count(*) = count(case when f.rating like "PG%" then 1 end) then true
                else false
            end as pg
				from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
                join kunde k on k.kunden_id = r.customer_id          
),	-- Sicherheitscheck bzgl. PG Filmen, true wenn der Kunde bisher ausschließlich PG-rated Filme ausgeliehen hat.
	dauer as (
		select
			avg(f.length) as avg_dauer
			from sakila.rental r
                join sakila.inventory inv on inv.inventory_id = r.inventory_id
                join sakila.film f on f.film_id = inv.film_id
                join kunde k on k.kunden_id = r.customer_id
),	-- Fragt die durschnittliche Länge der Filme ab, die der Kunde bisher ausgeliehen hat.
	kunden_film_counter as (
		select
			count(*) as film_counter
				from sakila.rental r
                join kunde k on k.kunden_id = r.customer_id
),	-- Gibt an, wieviele Filme der Kunde bisher ausgeliehen hat.
	auslagerung_schauspieler as (
		select
			f.film_id,
             group_concat(
				distinct concat(concat(upper(substring(a.first_name, 1, 1)), lower(substring(a.first_name, 2))),
				" ",
				concat(upper(substring(a.last_name, 1, 1)), lower(substring(a.last_name, 2)))
				) order by a.actor_id
			separator ", ") as Schauspieler
				from sakila.film f
                left join sakila.film_actor fa on fa.film_id = f.film_id
                left join sakila.actor a on a.actor_id = fa.actor_id
		group by 1
)
select distinct
	t.Film,
    t.Kategorie,
    t.Rating,
    t.Länge,
    t.Schauspieler,
    t.Beschreibung
		from (
select
    f.title as Film,
    cy.name as Kategorie,
    f.rating as Rating,
    f.length as Länge,
    sa.Schauspieler as Schauspieler,
    f.description as Beschreibung
		from sakila.film f
        left join sakila.film_category fc on fc.film_id = f.film_id
        left join sakila.category cy on cy.category_id = fc.category_id
        left join sakila.inventory inv on inv.film_id = f.film_id
        left join sakila.film_actor fa on fa.film_id = f.film_id
        left join sakila.actor a on a.actor_id = fa.actor_id
        left join pg on true
        left join auslagerung_schauspieler sa on sa.film_id = f.film_id
        cross join dauer d
        cross join kunden_film_counter kfc
where f.film_id not in (select film_id from kunde_verlauf_film)
and (pg.pg is false or f.rating like "PG%")
and (cy.category_id in (select category_id from kunde_vorlieben_kategorie) or fa.actor_id in (select actor_id from kunde_vorlieben_schauspieler))
and (kfc.film_counter > 2 or rand() > 0.5)
group by f.film_id, cy.category_id, d.avg_dauer, a.actor_id
order by (
	(case
		when cy.category_id in (select category_id from kunde_vorlieben_kategorie) then 0.5
        else 0
    end) 
    +
    (case
		when a.actor_id in (select actor_id from kunde_vorlieben_schauspieler) then 0.5
        else 0
    end)
	+
    (case
		when count_matching_words(f.description, (select beschreibung from kunde_verlauf_film where f.film_id = film_id)) >= 4 then 0.8
		else 0
    end)
    +
    (select bestand from bestand where f.film_id = inventory_id) * 0.2
    +
    (case
		when abs(f.length - d.avg_dauer) <= 10 then 0.4
        else 0
	end)
    ) *
    rand() desc) as t
    limit 5;
