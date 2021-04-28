use waste_coor_system;

DELIMITER //

-- проверка поля hazard_class при вставке 
DROP TRIGGER IF EXISTS type_of_waste_insert//
CREATE TRIGGER type_of_waste_insert BEFORE INSERT ON type_of_waste
FOR EACH ROW
BEGIN
	SET NEW.hazard_class = COALESCE(NEW.hazard_class, 4);
END//

-- проверка поля hazard_class при обновлении
DROP TRIGGER IF EXISTS type_of_waste_update//
CREATE TRIGGER type_of_waste_update BEFORE UPDATE ON type_of_waste
FOR EACH ROW
BEGIN
	SET NEW.hazard_class = COALESCE(NEW.hazard_class, OLD.hazard_class, 4);
END//

-- автоматическое вычисление суммы вывоза бака
DROP TRIGGER IF EXISTS coming_out_insert//
CREATE TRIGGER coming_out_insert BEFORE INSERT ON coming_out
FOR EACH ROW
BEGIN
	SET NEW.total_amount = (SELECT ROUND((price * `value`),2) FROM trash_cans INNER JOIN price_list USING(category_id) WHERE trash_can_id = NEW.trash_can_id);
END//

-- автоматическое обновление суммы вывоза бака
DROP TRIGGER IF EXISTS coming_out_update//
CREATE TRIGGER coming_out_update BEFORE UPDATE ON coming_out
FOR EACH ROW
BEGIN
	SET NEW.total_amount = (SELECT ROUND((price * `value`),2) FROM trash_cans INNER JOIN price_list USING(category_id) WHERE trash_can_id = NEW.trash_can_id);
END//


-- добавление новой компании
DROP PROCEDURE IF EXISTS `sp_add_company`//
CREATE PROCEDURE `sp_add_company`(control_method VARCHAR(255), c_full_name VARCHAR(255), short_name VARCHAR(128), INN BIGINT, is_subsidiary BIT(1), job_title VARCHAR(128), l_full_name VARCHAR(255), num VARCHAR(255), start_date DATE, OUT tran_result VARCHAR(200))
BEGIN
    DECLARE `_rollback` BOOL DEFAULT 0;
   	DECLARE code varchar(100);
   	DECLARE error_string varchar(100);
    DECLARE last_user_id int;

   DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
   BEGIN
    	SET `_rollback` = 1;
	GET stacked DIAGNOSTICS CONDITION 1
          code = RETURNED_SQLSTATE, error_string = MESSAGE_TEXT;
    	SET tran_result := concat('Error occured. Code: ', code, '. Text: ', error_string);
    END;
		        
    START TRANSACTION;
		INSERT INTO companies (control_method, full_name, short_name, INN, is_subsidiary)
		  VALUES (control_method, c_full_name, short_name, INN, is_subsidiary);
		INSERT INTO leaders_of_companies (company_id, job_title, full_name)
		  VALUES (last_insert_id(), job_title, l_full_name); 
		INSERT INTO lease_contract (company_id, num, start_date)
		  VALUES (last_insert_id(), num, start_date);
	
	    IF `_rollback` THEN
	       ROLLBACK;
	    ELSE
		SET tran_result := 'ok';
	       COMMIT;
	    END IF;
END//

DELIMITER ;
