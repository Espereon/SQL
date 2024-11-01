-- Заполняем таблицу cafe.restaurants
INSERT INTO cafe.restaurants(name,location,type,menu,latitude,longitude)
SELECT DISTINCT(m.cafe_name),d.id,s.type::cafe.restaurant_type,m.menu,s.latitude,s.longitude
FROM raw_data.menu m
JOIN raw_data.sales s ON m.cafe_name = s.cafe_name
JOIN cafe.districts AS d ON ST_Within(
    ST_SetSRID(ST_MakePoint(s.longitude, s.latitude), 4326),
    d.district_geom
);

-- Заполняем тиблицу cafe.manager
INSERT INTO cafe.managers(manager_name,phone)
SELECT DISTINCT(manager),manager_phone FROM raw_data.sales;

-- Заполняем таблицу cafe.restaurant_manager_work_dates
INSERT INTO cafe.restaurant_manager_work_dates(restaurant_uuid,manager_uuid,start_date,end_date)
SELECT
    r.restaurant_uuid AS restaurant_uuid,
    m.manager_uuid AS manager_uuid,
    MIN(s.report_date) AS min_report_date,
    MAX(s.report_date) AS max_report_date
FROM
    raw_data.sales s
JOIN
    cafe.restaurants r ON s.cafe_name = r.name
JOIN
    cafe.managers m ON s.manager = m.manager_name
GROUP BY
    r.restaurant_uuid,
    m.manager_uuid
ORDER BY
    r.restaurant_uuid,
    m.manager_uuid;

-- Заполняем таблицу cafe.sales 
INSERT INTO cafe.sales(date,restaurant_uuid,avg_check)
SELECT s.report_date,r.restaurant_uuid,s.avg_check
FROM raw_data.sales s
JOIN cafe.restaurants r ON s.cafe_name = r.name;