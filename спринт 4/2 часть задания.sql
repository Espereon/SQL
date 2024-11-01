-- находит топ пять долгих скриптов
SELECT queryid,
       calls,
       total_exec_time,
       rows,
       query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 5;

-- первый 
SELECT count(*)
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
WHERE (SELECT count(*)
	   FROM order_statuses os1
	   WHERE os1.order_id = o.order_id AND os1.status_id = $1) = $2
	AND o.city_id = $3
		-- total_exe_time = 48069.0276

-- второй
SELECT *
FROM user_logs
WHERE datetime::date > current_date
		-- total_exe_time = 775.4915
	

-- третий
SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = $1
ORDER BY 2
		-- total_exe_time = 725.6627
	
-- четвёртый 
SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM order_statuses os
    JOIN orders o ON o.order_id = os.order_id
    JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = $1::uuid
	AND os.status_dt IN (
	SELECT max(status_dt)
	FROM order_statuses
	WHERE order_id = o.order_id
    )
		-- total_exe_time = 80.3533 
	
-- пятый
SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
    JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (
	SELECT item
	FROM (SELECT item, SUM(count) AS total_sales
		  FROM order_items oi
		  GROUP BY 1) dishes_sales
	WHERE dishes_sales.total_sales > (
		SELECT SUM(t.total_sales)/ COUNT(*)
		FROM (SELECT item, SUM(count) AS total_sales
			FROM order_items oi
			GROUP BY
				1) t)
)
GROUP BY 1
ORDER BY orders_quantity DESC
		-- total_exe_time = 61.916
	

-- оптимизация:
-- первый запрос был "определяет количество неоплаченных заказов", можно добавить индексы и добавить на проверку not exists

CREATE INDEX cities_city_id__idx ON cities(city_id);
CREATE INDEX order_statuses_order_id__idx ON order_statuses(order_id);
CREATE INDEX order_statuses_status_id__idx ON order_statuses(status_id);
CREATE INDEX orders_order_id_city_id__idx ON orders(order_id, city_id);
CREATE INDEX order_statuses_order_id_status_id__idx ON order_statuses(order_id, status_id);

EXPLAIN ANALYZE SELECT count(*)
FROM order_statuses os
JOIN orders o ON o.order_id = os.order_id
WHERE NOT EXISTS (SELECT 1
	   FROM order_statuses os1
	   WHERE os1.order_id = o.order_id AND os1.status_id = 2)
	AND o.city_id = 1;
		-- "Execution Time: 7.837 ms"

-- второй скрипт был "ищет логи за текущий день"
-- убрать перевод в тип date

EXPLAIN ANALYZE SELECT *
FROM user_logs
WHERE datetime >= current_date AND datetime < current_date + interval '1 day';

		-- "Execution Time: 0.074 ms"

-- третий скрипт был "ищет действия и время действия определенного посетителя"
-- создадим индексы на visitor_uuid и datetime

CREATE INDEX user_logs_visitor_uuid_datetime_idx ON user_logs(visitor_uuid,datetime);

CREATE INDEX user_logs_y2021q2_visitor_uuid_datetime_idx
ON user_logs_y2021q2 (visitor_uuid, datetime);

CREATE INDEX user_logs_y2021q3_visitor_uuid_datetime_idx
ON user_logs_y2021q3 (visitor_uuid, datetime);

CREATE INDEX user_logs_y2021q4_visitor_uuid_datetime_idx
ON user_logs_y2021q4 (visitor_uuid, datetime);

EXPLAIN ANALYZE SELECT event, datetime
FROM user_logs
WHERE visitor_uuid = 'fd3a4daa-494a-423a-a9d1-03fd4a7f94e0'
ORDER BY 2;
		-- "Execution Time: 0.488 ms"

-- четвёртый был "выводит данные о конкретном заказе: id, дату, стоимость и текущий статус"
-- сделаем через оконную функцию в where 
EXPLAIN ANALYZE SELECT o.order_id, o.order_dt, o.final_cost, s.status_name
FROM (
    SELECT os.*,
           ROW_NUMBER() OVER (PARTITION BY os.order_id ORDER BY os.status_dt DESC) as rn
    FROM order_statuses os
) os
JOIN orders o ON o.order_id = os.order_id
JOIN statuses s ON s.status_id = os.status_id
WHERE o.user_id = 'c2885b45-dddd-4df3-b9b3-2cc012df727c'::uuid
AND os.rn = 1;
		-- "Execution Time: 60.148 ms"

-- пятый был "вычисляет количество заказов позиций, продажи которых выше среднего"
-- сделаем индексы на item и ещё один на item + count;
CREATE INDEX order_items_item_idx ON order_items(item);
CREATE INDEX idx_order_items_item_count ON order_items (item, count);

EXPLAIN ANALYZE WITH 
total_sales AS (
    SELECT item, SUM(count) AS total_sales
    FROM order_items
    GROUP BY item
),
average_sales AS (
    SELECT AVG(total_sales) AS avg_sales
    FROM total_sales
),
above_average_sales_items AS (
    SELECT item
    FROM total_sales
    WHERE total_sales > (SELECT avg_sales FROM average_sales)
)

SELECT d.name, SUM(count) AS orders_quantity
FROM order_items oi
JOIN dishes d ON d.object_id = oi.item
WHERE oi.item IN (SELECT item FROM above_average_sales_items)
GROUP BY 1
ORDER BY orders_quantity DESC
		-- "Execution Time: 27.206 ms"

