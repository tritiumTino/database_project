use waste_coor_system;

-- количество компаний на то или иное количество вывозов за последний месяц
SELECT count_of_dumps, count(short_name) as count_of_companies FROM (
	SELECT short_name, count(*) AS count_of_dumps FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		INNER JOIN trash_cans_companies USING(trash_can_id)
		INNER JOIN companies USING(company_id)
			WHERE month(dump_date) = month(NOW())
				GROUP BY short_name
		) tab
		GROUP BY count_of_dumps
		ORDER BY count_of_dumps DESC;


-- доля компании в вывозе за последний месяц
SET @sum_total_amount := (SELECT SUM(total_amount) FROM coming_out WHERE month(dump_date) = month(NOW()));
WITH tab (name, total) AS (SELECT short_name, SUM(total_amount) FROM coming_out 
	INNER JOIN trash_cans USING(trash_can_id) 
	INNER JOIN trash_cans_companies USING(trash_can_id)
	INNER JOIN companies USING(company_id)
		WHERE month(dump_date) = month(NOW())
			GROUP BY short_name) 
SELECT name, round(total/@sum_total_amount, 2) as part, 
	CASE WHEN round(total/@sum_total_amount, 2) >= 0.1 THEN 'main waste generator' WHEN round(total/@sum_total_amount, 2) >= 0.05 THEN 'important waste generator' ELSE 'side waste generator' END as status
	FROM tab 
		ORDER BY part DESC, name;


-- компании, находящиеся в цеху, производящем максимум мусора за последний месяц
WITH tab (id, val) as (SELECT workshop_id, SUM(`value`) as val FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		WHERE month(dump_date) = month(NOW()) 
			GROUP BY workshop_id 
			ORDER BY val desc limit 1)
SELECT short_name FROM companies 
	INNER JOIN workshops_companies USING(company_id) 
	WHERE workshop_id = (SELECT id FROM tab)
		ORDER BY short_name;


-- распределение компаний по цехам
SELECT `short_name`, `number`, `name` FROM workshops 
	INNER JOIN workshops_companies USING(workshop_id)
    INNER JOIN companies USING(company_id)
		ORDER BY short_name, `number`;
    