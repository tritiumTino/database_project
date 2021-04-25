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