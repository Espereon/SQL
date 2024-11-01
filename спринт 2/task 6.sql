WITH dist AS (
    SELECT 
        r1.name AS rest1,
        r1.type AS type,
        r2.name AS rest2,
        ST_Distance(
            ST_SetSRID(ST_Point(r1.longitude, r1.latitude), 4326)::geography,
            ST_SetSRID(ST_Point(r2.longitude, r2.latitude), 4326)::geography
        ) AS distance
    FROM 
        cafe.restaurants r1
    JOIN 
        cafe.restaurants r2 ON r1.type = r2.type
    WHERE 
        r1.name <> r2.name
)
SELECT 
    rest1,
    type,
    rest2,
    MIN(distance) AS min_distance
FROM 
    dist
GROUP BY 
    rest1, type, rest2
ORDER BY 
    min_distance ASC
LIMIT 1;