WITH max_district AS (
    SELECT district_name, count(restaurant_uuid) AS restaurant_count
    FROM cafe.restaurants r
    JOIN cafe.districts d ON r.location = d.id
    GROUP BY district_name
    ORDER BY restaurant_count DESC
    LIMIT 1
), 
min_district AS (
    SELECT district_name, count(restaurant_uuid) AS restaurant_count
    FROM cafe.restaurants r
    JOIN cafe.districts d ON r.location = d.id
    GROUP BY district_name
    ORDER BY restaurant_count ASC
    LIMIT 1
)
SELECT * FROM max_district
UNION ALL
SELECT * FROM min_district;