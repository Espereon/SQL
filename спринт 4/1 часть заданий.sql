-- Задание № 1
INSERT INTO orders
    (order_id, order_dt, user_id, device_type, city_id, total_cost, discount, 
    final_cost)
SELECT MAX(order_id) + 1, current_timestamp, 
    '329551a1-215d-43e6-baee-322f2467272d', 
    'Mobile', 1, 1000.00, null, 1000.00
FROM orders;

/*Причина:
order_id - не имеет атвоинкремента, первичного ключа
Если заказ фиксируется с текущей датой (order_dt), то лишнее обращение к этой переменной, можно сделать иначе  
ещё там 10 индексов, возможно их можно почистить, но пока они не затронуты

План решения:
установить первичный ключ,  создать SEQUENCE для автоинкремента,установить дефолтным значение у order_dt текущего времени
*/

ALTER TABLE orders 
ADD PRIMARY KEY (order_id);

select MAX(order_id) from orders	
CREATE SEQUENCE serial START n; -- где n это максимальное значение
ALTER TABLE orders ALTER COLUMN order_id SET DEFAULT nextval('serial');

ALTER TABLE orders 
ALTER COLUMN order_dt 
SET DEFAULT CURRENT_TIMESTAMP;

-- Скрипт
explain
INSERT INTO orders (user_id, device_type, city_id, total_cost, discount, final_cost)
VALUES ('329551a1-215d-43e6-baee-322f2467272d', 'Mobile', 1, 1000.00, null, 1000.00);
DROP INDEX orders_total_final_cost_discount_idx;
DROP INDEX orders_total_cost_idx;
DROP INDEX orders_order_dt_idx;
DROP INDEX orders_final_cost_idx;
DROP INDEX orders_device_type_city_id_idx;
DROP INDEX orders_device_type_idx;
DROP INDEX orders_discount_idx;
-- не знаю, по идеи эти можно убрать, но на инсерты не особо повлияло 



-- Задание № 2
SELECT user_id::text::uuid, first_name::text, last_name::text, 
    city_id::bigint, gender::text
FROM users
WHERE city_id::integer = 4
    AND date_part('day', to_date(birth_date::text, 'yyyy-mm-dd')) 
        = date_part('day', to_date('31-12-2023', 'dd-mm-yyyy'))
    AND date_part('month', to_date(birth_date::text, 'yyyy-mm-dd')) 
        = date_part('month', to_date('31-12-2023', 'dd-mm-yyyy'))
/* Причины
к каждому столбцу идёт присвоение нового типа данных, где-то ещё и uuid, нет связи между таблицами cities и users, что упростит так же взаимодействие.

Решение: можно попопробовать привести всё сразу к определённому типу данных, выставить связи таблиц
*/
--Присвоение новых типов данных к user_id, first_name, last_name, gender, birth_date, registration_date, city_id (в тиблице cities)
ALTER TABLE users
ALTER COLUMN user_id
SET DATA TYPE VARCHAR(100);

ALTER TABLE users 
ALTER COLUMN user_id 
SET DATA TYPE uuid USING user_id::uuid;

ALTER TABLE users
ALTER COLUMN first_name
SET DATA TYPE VARCHAR(69);

ALTER TABLE users
ALTER COLUMN last_name
SET DATA TYPE VARCHAR(69);

ALTER TABLE users
ALTER COLUMN gender
SET DATA TYPE VARCHAR(24);

ALTER TABLE users
ALTER COLUMN birth_date
SET DATA TYPE DATE USING birth_date::date;

ALTER TABLE users
ALTER COLUMN registration_date
SET DATA TYPE DATE USING registration_date::date;

ALTER TABLE users
ALTER COLUMN city_id
SET DATA TYPE integer;

-- делаем первичный ключ в cities на колонку city_id и связываем внешним ключом с users 
ALTER TABLE cities
ADD PRIMARY KEY (city_id);

ALTER TABLE users
ALTER COLUMN city_id
SET DATA TYPE integer;

UPDATE users SET city_id = NULL where city_id = 0 --убираем значение 0, иначе не добавится внешний ключ
	
ALTER TABLE users
ADD CONSTRAINT fk_city
FOREIGN KEY (city_id) REFERENCES cities(city_id);

-- скрипт теперь выглядит так:
SELECT user_id, first_name, last_name, city_id, gender
FROM users
WHERE city_id = 4
    AND EXTRACT(day FROM birth_date) = 31
    AND EXTRACT(month FROM birth_date) = 12;

-- Задание № 3
-- сама процедура
BEGIN
    INSERT INTO order_statuses (order_id, status_id, status_dt)
    VALUES (p_order_id, 2, statement_timestamp());
    
    INSERT INTO payments (payment_id, order_id, payment_sum)
    VALUES (nextval('payments_payment_id_sq'), p_order_id, p_sum_payment);
    /*
    INSERT INTO sales(sale_id, sale_dt, user_id, sale_sum)
    SELECT NEXTVAL('sales_sale_id_sq'), statement_timestamp(), user_id, p_sum_payment
    FROM orders WHERE order_id = p_order_id; можно убрать эту таблицу, так как данные есть в первых двух*/  
END;
/* Причины:
между таблицами нет связей, плюс нет индексов, можно попробовать с ними.

Решение: */ 
-- добавляем ключи

ALTER TABLE payments
ADD PRIMARY KEY (payment_id);

ALTER TABLE payments
ADD CONSTRAINT fk_payment_id
FOREIGN KEY (payment_id) REFERENCES payments(payment_id);

ALTER TABLE statuses
ADD PRIMARY KEY (status_id);

ALTER TABLE statuses
ADD CONSTRAINT fk_status_id
FOREIGN KEY (status_id) REFERENCES statuses(status_id);

ALTER TABLE sales
ADD PRIMARY KEY (sale_id);

ALTER TABLE sales
ADD CONSTRAINT fk_sale_id
FOREIGN KEY (sale_id) REFERENCES sales(sale_id);

--создаём индексы
CREATE INDEX idx_payments_payment_id ON payments (payment_id);
CREATE INDEX idx_statuses_status_id ON statuses (status_id);
CREATE INDEX idx_sales_sale_id ON sales (sale_id);

-- Задание № 4
-- В пачке увидел подсказку, что можно воспользоваться партицированием. Можно попробовать сделать по годам
-- Решение: 
CREATE TABLE user_logs_2024 PARTITION OF user_logs
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01'); -- за 2024 год

CREATE TABLE user_logs_2024 PARTITION OF user_logs
FOR VALUES FROM ('2023-01-01') TO ('2024-01-01'); -- за 2023 год и так далее. 

-- Задание № 5
-- можно решить путём материализированного представления отчёта 
CREATE MATERIALIZED VIEW otchet AS
SELECT
    CASE
        WHEN DATE_PART('year', AGE(CURRENT_DATE, u.birth_date)) < 20 THEN '0–20'
        WHEN DATE_PART('year', AGE(CURRENT_DATE, u.birth_date)) < 30 THEN '20–30'
        WHEN DATE_PART('year', AGE(CURRENT_DATE, u.birth_date)) < 40 THEN '30–40'
        ELSE '40–100'
    END AS age_group,
    (SUM(d.spicy) * 100.0 / COUNT(*)) AS spicy_percentage,
    (SUM(d.fish) * 100.0 / COUNT(*)) AS fish_percentage,
    (SUM(d.meat) * 100.0 / COUNT(*)) AS meat_percentage
FROM
    orders o
JOIN
    users u ON o.user_id = u.user_id
JOIN
    order_items oi ON o.order_id = oi.order_id
JOIN
    dishes d ON oi.item = d.object_id
GROUP BY
    age_group
ORDER BY
    age_group;

SELECT * FROM otchet

