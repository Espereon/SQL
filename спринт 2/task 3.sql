SELECT r.name,
	COUNT(DISTINCT(manager_uuid)) AS manager_change_count
FROM cafe.restaurant_manager_work_dates work_dates
JOIN cafe.restaurants r ON work_dates.restaurant_uuid = r.restaurant_uuid
GROUP BY r.name
ORDER BY manager_change_count DESC
LIMIT 3;