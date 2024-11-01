with top_pizza as (
	SELECT name,count(pizza) as pizza_count
		FROM (SELECT r.name,jsonb_object_keys(menu::jsonb ->'Пицца') AS pizza
				FROM cafe.restaurants r
				WHERE type = 'pizzeria'
		)
	GROUP BY name
	ORDER BY count(pizza) desc)

SELECT *
FROM top_pizza
WHERE pizza_count = (SELECT MAX(pizza_count) FROM top_pizza);