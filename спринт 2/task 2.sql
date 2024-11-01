CREATE MATERIALIZED VIEW top_rest_by_avg_check_task2 AS
SELECT
	EXTRACT(YEAR FROM date) AS year,
	r.name AS restaurant_name,
	r.type AS restaurant_type,
	ROUND(AVG(s.avg_check), 2) AS avg_check,
	LAG(ROUND(AVG(s.avg_check), 2)) OVER (PARTITION BY r.name ORDER BY EXTRACT(YEAR FROM date)) AS previous_year_avg_check,
	ROUND((ROUND(AVG(s.avg_check), 2) - LAG(ROUND(AVG(s.avg_check), 2)) OVER (PARTITION BY r.name ORDER BY EXTRACT(YEAR FROM date))) / NULLIF(LAG(ROUND(AVG(s.avg_check), 2)) OVER (PARTITION BY r.name ORDER BY EXTRACT(YEAR FROM date)), 0) * 100, 2) AS change
FROM
	cafe.sales s
JOIN
	cafe.restaurants r ON s.restaurant_uuid = r.restaurant_uuid

	WHERE EXTRACT(YEAR FROM date) != 2023
GROUP BY
	EXTRACT(YEAR FROM date),
	r.name,
	r.type;