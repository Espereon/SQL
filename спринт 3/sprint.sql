CREATE OR REPLACE PROCEDURE update_employees_rate(data json)
LANGUAGE plpgsql
AS $$
	DECLARE
    	employee_record json;
    	employee_id uuid;
    	rate_change integer;
		new_rate integer;
		min_rate integer := 500;
	BEGIN
    	FOR employee_record IN SELECT * FROM jsonb_array_elements(data::jsonb)
    		LOOP
        	employee_id := (employee_record->>'employee_id')::uuid;
        	rate_change := (employee_record->>'rate_change')::integer;
		SELECT rate + (rate * rate_change / 100) INTO new_rate
        FROM employees
        WHERE id = employee_id;
		IF new_rate < min_rate THEN
           	new_rate := min_rate;
        END IF;
        UPDATE employees
        SET rate = new_rate
        WHERE id = employee_id;
        RAISE NOTICE 'Ставка % обновлена на % процентов', employee_id, rate_change;
		    END LOOP;
	END;
$$;
-- тест
CALL update_employees_rate(
    '[
        {"employee_id": "80718590-e2bf-492b-8c83-6f8c11d007b1", "rate_change": 10}, 
        {"employee_id": "80718590-e2bf-492b-8c83-6f8c11d007b1", "rate_change": -5}
    ]'::json
);

CREATE OR REPLACE PROCEDURE indexing_salary(p integer)
LANGUAGE plpgsql
AS $$
DECLARE
    avg_rate numeric;
BEGIN
    SELECT AVG(rate) INTO avg_rate FROM employees;  
    UPDATE employees
    SET rate = ROUND(rate * CASE 
                                WHEN rate < avg_rate THEN (1 + (p + 2) / 100.0)
                                ELSE (1 + p / 100.0)
                            END);
    RAISE NOTICE 'процент индексации - % доп процент -  %', p, p + 2;
END;
$$;

--тест 
CALL indexing_salary(5);  -- для индексации зарплаты на 5%

--Задание 3
CREATE OR REPLACE PROCEDURE close_project(p_project_id uuid)
LANGUAGE plpgsql
AS $$
DECLARE
    project RECORD;
    total_worked_hours integer;
    saved_hours integer;
    bonus_hours_per_member integer;
    num_members integer;
BEGIN
    SELECT * INTO project
    FROM projects
    WHERE id = p_project_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'проект не найден или закрыт';
    END IF;
    RAISE NOTICE 'проект открыт';
    UPDATE projects
    SET is_active = false
    WHERE id = p_project_id;
    IF project.estimated_time IS NULL THEN
        RAISE NOTICE 'Estimated_time не задано, завершение процедуры';
        RETURN;
    END IF;
    SELECT COALESCE(SUM(work_hours), 0) INTO total_worked_hours,
		count(distinct(employee_id)) INTO num_members -- я не понимаю почемму он ругается на count, поэтому удалил строку, а нижнии правки забыл ввести
    FROM logs
    WHERE project_id = p_project_id;
    IF total_worked_hours = 0 THEN
        RAISE NOTICE 'Отработанных часов нет. Завершение процедуры.';
        RETURN;
    END IF;
    saved_hours := project.estimated_time - total_worked_hours;
    IF saved_hours <= 0 THEN
        RAISE NOTICE 'сэкономленных часов нет, завершение процедуры';
        RETURN;
    END IF;
    IF num_members = 0 THEN
        RAISE NOTICE 'yчастников нет, завершение процедуры';
        RETURN;
    END IF;
    bonus_hours_per_member := FLOOR((saved_hours * 0.75) / num_members);
        IF bonus_hours_per_member > 16 THEN
        bonus_hours_per_member := 16;
    END IF;
    INSERT INTO logs (employee_id,project_id,work_date,work_hours)
    SELECT DISTINCT(employee_id),project_id,CURRENT_DATE,bonus_hours_per_member
    FROM logs
    WHERE project_id = p_project_id;    
    RAISE NOTICE 'Проект % успешно закрыт, начислено бонусных часов % на каждого % участников', 
                 p_project_id, bonus_hours_per_member, num_members;
END;
$$;

-- тест
CALL close_project('5f14f454-afbf-4f05-8d48-19db9237c8ff');

-- задание 4

CREATE OR REPLACE PROCEDURE log_work(
                                        p_employee_id uuid,
                                        p_project_id uuid,
                                        p_work_date date,
                                        p_worked_hour integer)
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM 1 
    FROM projects
    WHERE id = p_project_id AND is_active = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Проект заркыт';
        RETURN;
    END IF;
    RAISE NOTICE 'Проект открыт';
    IF p_worked_hour < 1 OR p_worked_hour > 24 THEN
        RAISE EXCEPTION 'некорректное кол-во часов, процедура остановленна';
        RETURN;
    END IF;
    RAISE NOTICE 'часы работы получены';
    INSERT INTO logs (employee_id, project_id, work_date, work_hours,required_review)
    VALUES (p_employee_id, p_project_id, p_work_date, p_worked_hour,
            CASE
                WHEN p_worked_hour > 16 
		OR p_work_date > CURRENT_DATE 
		OR p_work_date < CURRENT_DATE - INTERVAL '7 days' THEN true 
                ELSE false
            END);
    RAISE NOTICE 'Запись в логи внесена';
END;
$$;

-- тест
CALL log_work(
    '6db4f4a3-239b-4085-a3f9-d1736040b38c', -- employee uuid
    '35647af3-2aac-45a0-8d76-94bc250598c2', -- project uuid
    '2023-10-22',                           -- work date
    4                                       -- worked hours
);

-- задание 5
CREATE TABLE employee_rate_history (
    id serial PRIMARY KEY,
    employee_id uuid NOT NULL,
    rate integer NOT NULL,
    from_date date NOT NULL,
    FOREIGN KEY (employee_id) REFERENCES public.employees(id)
);

INSERT INTO employee_rate_history (employee_id, rate, from_date)
SELECT id, rate, '2020-12-26'
FROM employees;

CREATE OR REPLACE FUNCTION save_employee_rate_history()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO employee_rate_history (employee_id, rate, from_date)
    VALUES (NEW.id, NEW.rate, CURRENT_DATE);
    RETURN NEW;
END;
$$ 
LANGUAGE plpgsql;

CREATE TRIGGER change_employee_rate
AFTER INSERT OR UPDATE OF rate ON employees
FOR EACH ROW
EXECUTE FUNCTION save_employee_rate_history();

-- задание 6 
CREATE OR REPLACE FUNCTION best_project_workers(p_project_id uuid)
RETURNS TABLE(employee text, work_hours INTEGER) AS $$
BEGIN
    RETURN QUERY
    SELECT sub.employee_name, sub.total_hours
    FROM (
        SELECT e.name AS employee_name, 
               SUM(l.work_hours)::INTEGER AS total_hours,
               COUNT(DISTINCT l.work_date) AS work_days
        FROM logs l
        JOIN employees e ON l.employee_id = e.id
        WHERE l.project_id = p_project_id
        GROUP BY e.name
        ORDER BY total_hours DESC, work_days DESC, RANDOM()
        LIMIT 3
    ) sub;
END;
$$ LANGUAGE plpgsql;

--тест
SELECT employee, work_hours FROM best_project_workers(
    '4abb5b99-3889-4c20-a575-e65886f266f9' -- Project UUID
);

-- задание 7 
CREATE OR REPLACE FUNCTION calculate_month_salary(p_begin_date date,p_end_date date)
RETURNS TABLE(employee_id uuid, employee_name text,worked_hours integer,salary numeric) AS $$
BEGIN
    RETURN QUERY
    WITH total_hours AS (
        SELECT 
            l.employee_id,
            e.name,
            e.rate,
            SUM(l.work_hours) AS total_work_hours
        FROM logs l
        JOIN employees e ON l.employee_id = e.id
        WHERE l.created_at BETWEEN p_begin_date AND p_end_date
        AND l.required_review IS false 
        AND l.is_paid IS false
        GROUP BY l.employee_id, e.name, e.rate
    )
    SELECT
        th.employee_id,
        th.name,
        th.total_work_hours::integer AS worked_hours,
        (LEAST(th.total_work_hours, 160) * th.rate + 
        GREATEST(th.total_work_hours - 160, 0) * th.rate * 1.25) AS salary
    FROM total_hours th;

END;
$$ LANGUAGE plpgsql;

-- тест
SELECT * FROM calculate_month_salary(
    '2023-10-01',  -- start of month
    '2023-10-31'   -- end of month
);