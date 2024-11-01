CREATE OR REPLACE VIEW top_rest_avg_check AS
    WITH avg_checks AS (
        SELECT
            r.name AS restaurant_name,
            r.type AS restaurant_type,
            ROUND(AVG(s.avg_check), 2) AS avg_check
        FROM
            cafe.sales s
        JOIN
            cafe.restaurants r ON s.restaurant_uuid = r.restaurant_uuid
        GROUP BY
            r.name,
            r.type
    ),
    ranked_restaurants AS (
        SELECT
            restaurant_name,
            restaurant_type,
            avg_check,
            RANK() OVER (PARTITION BY restaurant_type ORDER BY avg_check DESC) AS rank
        FROM
            avg_checks
    )
    SELECT
        restaurant_name,
        restaurant_type,
        avg_check
    FROM
        ranked_restaurants
    WHERE
        rank <= 3;