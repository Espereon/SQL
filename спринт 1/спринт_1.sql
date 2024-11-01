/* про ссылку к файлу я несовсем понял, а как корректно загуглить в час ночи я не догоняю. 
Можете продемонстрировать, как ей пользоваться, чтобы код был переносимым. Спасибо.
А про группировку с gasoline_consumption были у меня проблемы, почему то в 1 СУБД было null, во второй 'null' - текстовоое,
поэтому на основе текущего я решил заменить пропуск на 0 и работать с таким вариантом*/



CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE TABLE IF NOT EXISTS raw_data.sales (
	id SERIAL PRIMARY KEY,	-- порядковый номер, автоинкремент
	auto VARCHAR (50), -- предоставленные данные текст с символами
	gasoline_consumption NUMERIC (9,2), -- предоставленные данные цифровые и null значения
	price NUMERIC (9,2), -- цифровые значения, сокращение цифр после запятой займусь позже
	date DATE, -- дата есть дата
	person_name TEXT, -- ФИ данные в 1 колонке, в 100 символов должно уместиться
	phone VARCHAR (30), -- заметил помимо цифр символ х
	discount SMALLINT, -- проценты могут быть и не целые 
	brand_origin TEXT -- название стран - текст
);

COPY raw_data.sales (id,auto,gasoline_consumption,price,date,person_name,phone,discount,brand_origin) 
FROM 'E:\learning\sql\cars.csv' DELIMITER ',' CSV HEADER NULL as 'null'; -- импортировал данные

SELECT * FROM raw_data.sales; -- посмотрел как выглядит

-- создание схемы и таблицы 
CREATE SCHEMA IF NOT EXISTS car_shop;
CREATE TABLE IF NOT EXISTS car_shop.sales (
	id SERIAL PRIMARY KEY,
	cars_id integer,
	price NUMERIC (9,2),
	discount SMALLINT CHECK (discount < 100),
	date DATE,
	client_id INTEGER
);

CREATE TABLE IF NOT EXISTS car_shop.clients (
	id SERIAL PRIMARY KEY,
	client_name TEXT,
	phone VARCHAR (30)
);

CREATE TABLE IF NOT EXISTS car_shop.cars (
	id SERIAL PRIMARY KEY,
	brand_id INTEGER,
	model_id INTEGER,
	color_id INTEGER,
	gasoline_consumption NUMERIC (9,2) CHECK (gasoline_consumption > -1)
);

CREATE TABLE IF NOT EXISTS car_shop.brand (
	id SERIAL PRIMARY KEY,
	brand_name TEXT,
	brand_origin_id INTEGER
);

CREATE TABLE IF NOT EXISTS car_shop.brand_origin(
	id SERIAL PRIMARY KEY,
	country VARCHAR (20)
);

CREATE TABLE IF NOT EXISTS car_shop.model (
	id SERIAL PRIMARY KEY,
	model_name VARCHAR (20)
);

CREATE TABLE IF NOT EXISTS car_shop.color (
	id SERIAL PRIMARY KEY,
	color_name VARCHAR (20)
); 

-- присвоение внешних ключей 
ALTER TABLE car_shop.sales ADD FOREIGN KEY (client_id) REFERENCES car_shop.clients (id);
ALTER TABLE car_shop.sales ADD FOREIGN KEY (cars_id) REFERENCES car_shop.cars (id);
ALTER TABLE car_shop.cars ADD FOREIGN KEY (brand_id) REFERENCES car_shop.brand (id);
ALTER TABLE car_shop.cars ADD FOREIGN KEY (model_id) REFERENCES car_shop.model (id);
ALTER TABLE car_shop.cars ADD FOREIGN KEY (color_id) REFERENCES car_shop.color (id);
ALTER TABLE car_shop.brand ADD FOREIGN KEY (brand_origin_id) REFERENCES car_shop.brand_origin (id);

-- перенос разновидностей цвета 
INSERT INTO car_shop.color (color_name)
SELECT DISTINCT SUBSTR(auto,(STRPOS(auto,', ')+2)) FROM raw_data.sales;

-- перенос стран производителей
INSERT INTO car_shop.brand_origin (country)
SELECT DISTINCT brand_origin FROM raw_data.sales

-- переносим имя клиента и телефон
INSERT INTO car_shop.clients (client_name, phone)
SELECT DISTINCT person_name, phone FROM raw_data.sales;

-- переносим данные по брендам
INSERT INTO car_shop.brand (brand_name, brand_origin_id)
SELECT DISTINCT SPLIT_PART(s.auto,' ',1), bo.id FROM raw_data.sales s
LEFT JOIN car_shop.brand_origin bo ON s.brand_origin = bo.country;

-- переносим данные в модель автомобиля
INSERT INTO car_shop.model (model_name)
SELECT DISTINCT substr(split_part(r.auto, ', ', 1), length(split_part(auto, ' ', 1))+2) FROM raw_data.sales as r;

-- заполнение таблицы cars
INSERT INTO car_shop.cars (brand_id, model_id, color_id, gasoline_consumption)
SELECT d.brand_id, d.model_id, d.color_id, d.gasoline_consumption FROM
(SELECT b.id AS brand_id, m.id AS model_id, c.id AS color_id, (CASE WHEN (s.gasoline_consumption) IS NULL THEN '0' ELSE s.gasoline_consumption END)::numeric(9,2) FROM raw_data.sales s
JOIN car_shop.brand b ON SPLIT_PART(s.auto,' ',1) = b.brand_name
JOIN car_shop.model m ON substr(split_part(s.auto, ', ', 1), length(split_part(s.auto, ' ', 1))+2) = m.model_name
JOIN car_shop.color c ON SUBSTR(s.auto,(STRPOS(s.auto,', ')+2)) = c.color_name) d
GROUP BY d.brand_id, d.model_id, d.color_id, d.gasoline_consumption;

-- заполнение таблицы sales
INSERT INTO car_shop.sales (cars_id, price, discount, date, client_id)
SELECT c.id, s.price, s.discount, s.date, clt.id FROM raw_data.sales s
JOIN car_shop.brand b ON SPLIT_PART(s.auto,' ',1) = b.brand_name
JOIN car_shop.model m ON substr(split_part(s.auto, ', ', 1), length(split_part(s.auto, ' ', 1))+2) = m.model_name
JOIN car_shop.color cl ON SUBSTR(s.auto,(STRPOS(s.auto,', ')+2)) = cl.color_name
JOIN car_shop.cars c ON (CASE WHEN (s.gasoline_consumption) IS NULL THEN '0' ELSE s.gasoline_consumption END)::numeric(9,2) = c.gasoline_consumption
AND b.id = c.brand_id AND m.id = c.model_id AND cl.id = c.color_id
JOIN car_shop.clients clt ON s.person_name = clt.client_name AND s.phone = clt.phone;
	
-- Задание № 1
SELECT (COUNT(model_id)*100)/(SELECT COUNT(*) FROM car_shop.model) as nulls_percentage_gasoline_consumption FROM
(SELECT model_id FROM car_shop.cars 
  WHERE gasoline_consumption = 0
  group by model_id)

-- Задание № 2
SELECT b.brand_name as brand_name, EXTRACT(year FROM s.date) as year, ROUND(AVG(s.price),2) as price_avg FROM car_shop.sales s
JOIN car_shop.cars c ON s.cars_id = c.id
JOIN car_shop.brand b ON c.brand_id = b.id
GROUP BY b.brand_name, EXTRACT(year FROM s.date)
ORDER BY b.brand_name, EXTRACT(year FROM s.date);

-- Задание № 3
SELECT month, year, price_avg FROM
(SELECT EXTRACT (month FROM date) as month, EXTRACT (year FROM date) as year, ROUND(AVG(price), 2) as price_avg FROM car_shop.sales
GROUP BY EXTRACT (month FROM date), EXTRACT (year FROM date))
WHERE year = 2022
ORDER BY month;

-- Задание № 4
SELECT cl.client_name AS person, STRING_AGG(b.brand_name ||' '|| m.model_name, ', ') AS cars FROM car_shop.sales s
JOIN car_shop.cars c ON s.cars_id = c.id
JOIN car_shop.brand b ON c.brand_id = b.id
JOIN car_shop.model m ON c.model_id = m.id
JOIN car_shop.clients cl ON s.client_id = cl.id
GROUP BY cl.client_name
ORDER BY cl.cleint_name;

-- Задание № 5
SELECT country as brand_origin, MAX(price) as price_max, MIN(price) as price_min FROM
(SELECT bo.country, ROUND((CASE WHEN s.discount = 0 THEN s.price ELSE s.price + (s.price * s.discount / 100) END), 2) as price FROM car_shop.sales s
JOIN car_shop.cars c ON s.cars_id = c.id
JOIN car_shop.brand b ON c.brand_id = b.id
LEFT JOIN car_shop.brand_origin bo ON b.brand_origin_id = bo.id)
GROUP BY country

-- Задание № 
SELECT COUNT(name) as persons_from_usa_count FROM car_shop.clients
WHERE phone LIKE '+1%';

-- команды для удобства
-- select * from car_shop.model
-- TRUNCATE TABLE car_shop.cars RESTART IDENTITY CASCADE;

