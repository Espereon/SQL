-- Создаём тип данных
CREATE TYPE cafe.restaurant_type AS ENUM 
    ('coffee_shop', 'restaurant', 'bar', 'pizzeria'); 

-- Создаём таблицу cafe.restaurants
CREATE TABLE cafe.restaurants (
    restaurant_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
    name text,
    location INTEGER,
    latitude double precision,
    longitude double precision,
    type cafe.restaurant_type,
    menu jsonb,
    FOREIGN KEY (location) REFERENCES cafe.districts(id)
);

-- Создаём таблицу cafe.managers
CREATE TABLE cafe.managers (
    manager_uuid UUID PRIMARY KEY DEFAULT GEN_RANDOM_UUID(),
    manager_name text,
    phone text
);

-- Создаём таблицу cafe.restaurant_manager_work_dates
CREATE TABLE cafe.restaurant_manager_work_dates (
    restaurant_uuid UUID NOT NULL,
    manager_uuid UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    FOREIGN KEY (restaurant_uuid) REFERENCES cafe.restaurants(restaurant_uuid),
    FOREIGN KEY (manager_uuid) REFERENCES cafe.managers(manager_uuid)
);

-- Создаём таблицу cafe.sales 
CREATE TABLE cafe.sales (
    date DATE NOT NULL,
    restaurant_uuid UUID NOT NULL,
    avg_check NUMERIC(6,2),
    PRIMARY KEY (date,restaurant_uuid),
    FOREIGN KEY (restaurant_uuid) REFERENCES cafe.restaurants(restaurant_uuid)
);
