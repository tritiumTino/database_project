use waste_coor_system;

-- количество компаний на то или иное количество вывозов за последний месяц
SELECT count_of_dumps, count(short_name) as count_of_companies FROM (
	SELECT short_name, count(*) AS count_of_dumps FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		INNER JOIN trash_cans_companies USING(trash_can_id)
		INNER JOIN companies USING(company_id)
			WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
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
		WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
			GROUP BY short_name) 
SELECT name, round(total/@sum_total_amount, 2) as part, 
	CASE 
		WHEN round(total/@sum_total_amount, 2) >= 0.1 THEN 'main waste generator' 
        WHEN round(total/@sum_total_amount, 2) >= 0.05 THEN 'important waste generator' 
        ELSE 'side waste generator' 
	END as status
	FROM tab 
		ORDER BY part DESC, name;


-- компании, находящиеся в цеху, производящем максимум мусора за последний месяц
WITH tab (id, val) as (SELECT workshop_id, SUM(`value`) as val FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
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
  
  
-- насколько счет за этот месяц больше, чем за прошлый
WITH t_prev (sn, stam_prev) as (
	SELECT short_name, SUM(total_amount) FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		INNER JOIN trash_cans_companies USING(trash_can_id)
		INNER JOIN companies USING(company_id)
			WHERE month(dump_date) = month(date_sub(now(), INTERVAL 1 MONTH))
				GROUP BY short_name),
t_now (sn, stam) as (
	SELECT short_name, SUM(total_amount) FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id) 
		INNER JOIN trash_cans_companies USING(trash_can_id)
		INNER JOIN companies USING(company_id)
			WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
				GROUP BY short_name)
SELECT sn as `name`, (IF(stam, stam, 0) - IF(stam_prev, stam_prev, 0)) as difference FROM t_prev LEFT JOIN t_now USING(sn)
UNION
SELECT sn as `name`, (IF(stam, stam, 0) - IF(stam_prev, stam_prev, 0)) as difference FROM t_prev RIGHT JOIN t_now USING(sn)
	ORDER BY difference DESC;
            
            
-- сколько отправлено на утилизацию за последний месяц
SELECT ROW_NUMBER() OVER (ORDER BY SUM(`value`) DESC) AS num,
	category_name, SUM(`value`) as sum_value FROM coming_out 
	INNER JOIN trash_cans USING(trash_can_id)
    INNER JOIN price_list USING(category_id)
		WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW()) AND category_id BETWEEN 1 AND 4
			GROUP BY category_name;


-- объемы отходов за последний месяц по цехам
SELECT `number`, `name`, SUM(`value`) as total FROM coming_out 
		INNER JOIN trash_cans USING(trash_can_id)
        INNER JOIN workshops USING(workshop_id)
			WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
				GROUP BY `number`, `name`
                ORDER BY total DESC;


-- неоплаченные счета
SELECT c.company_id as id, short_name, dump_date as `date`, total_amount as bill, 'not paid' as `status`
    FROM companies c 
		INNER JOIN trash_cans_companies USING(company_id)
		INNER JOIN trash_cans USING(trash_can_id)
		INNER JOIN coming_out USING(trash_can_id)
			WHERE is_paid=0
				ORDER BY id, `date`;

                
-- общий долг по компаниям
SELECT c.company_id as id, short_name, SUM(total_amount) as debt
    FROM companies c 
		INNER JOIN trash_cans_companies USING(company_id)
		INNER JOIN trash_cans USING(trash_can_id)
		INNER JOIN coming_out USING(trash_can_id)
			WHERE is_paid=0
				GROUP BY id, short_name
					ORDER BY id;