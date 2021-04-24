DELIMITER //

CREATE TRIGGER type_of_waste_insert BEFORE INSERT ON type_of_waste
FOR EACH ROW
BEGIN
	DECLARE val INT;
	IF (NEW.hazard_class not BETWEEN 1 AND 5) THEN 
		SET val = NEW.hazard_class;
	ELSE 
		SET val = 4;
	END IF;
    INSERT INTO type_of_waste values();
END//