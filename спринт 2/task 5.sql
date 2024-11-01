SELECT 
	   DISTINCT ON (r.name)
	   r.name,
	   'Пицца' as type,
	   pizza_details.key as pizza_name,
	   MAX(pizza_details.value) as max_price
		
FROM cafe.restaurants r,
	 jsonb_each_text(r.menu::jsonb -> 'Пицца') AS pizza_details
WHERE type = 'pizzeria'
GROUP BY r.name,pizza_name
ORDER BY r.name, max_price DESC;