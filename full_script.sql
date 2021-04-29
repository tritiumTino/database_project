DROP DATABASE IF EXISTS waste_coor_system;
CREATE DATABASE waste_coor_system;

USE waste_coor_system;

DROP TABLE IF EXISTS companies;
CREATE TABLE companies (
	company_id SERIAL,
    control_method VARCHAR(255),
	full_name VARCHAR(255),
	short_name VARCHAR(128),
    INN BIGINT UNSIGNED UNIQUE,
    is_subsidiary BIT(1) COMMENT 'является ли дочерним обществом',
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	INDEX company_name (short_name),
    INDEX company_INN (INN)
);


-- руководители компаний
DROP TABLE IF EXISTS leaders_of_companies;
CREATE TABLE leaders_of_companies (
	company_id BIGINT UNSIGNED NOT NULL UNIQUE,
	job_title VARCHAR(128) COMMENT 'директор, генеральный директор',
	full_name VARCHAR(255),
	created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX leaders_of_companies_full_name (full_name)
);


-- договоры аренды
DROP TABLE IF EXISTS lease_contract;
CREATE TABLE lease_contract (
	company_id BIGINT UNSIGNED NOT NULL UNIQUE,
    num VARCHAR(255),
    start_date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX contract_num (num)
);

-- цеха
DROP TABLE IF EXISTS workshops;
CREATE TABLE workshops (
    workshop_id SERIAL,
	number INT UNIQUE,
    name VARCHAR(255),
    INDEX workshops_num (number)
);

-- цеха-компании
DROP TABLE IF EXISTS workshops_companies;
CREATE TABLE workshops_companies (
    company_id BIGINT UNSIGNED NOT NULL,
	workshop_id BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (workshop_id, company_id),
	FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (workshop_id) REFERENCES workshops(workshop_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- отходы
DROP TABLE IF EXISTS type_of_waste;
CREATE TABLE type_of_waste (
	waste_id SERIAL,
	name VARCHAR(512),
	fkko_num VARCHAR(30) COMMENT '4 71 101 01 52 1',
	hazard_class INT,
	must_be_neutralized BIT(1) COMMENT 'должны ли отправляться на обезвреживание',
	can_be_recycled BIT(1),
	can_be_recycled_with_profit BIT(1) COMMENT 'могут ли быть отправлены на утилизацию с получением прибыли',
	can_be_buried BIT(1) COMMENT 'могут ли быть отправлены на захоронение',
	INDEX waste_num (fkko_num),
	INDEX waste_name (name)
);

-- отходы компаний
DROP TABLE IF EXISTS waste_companies;
CREATE TABLE waste_companies (
	company_id BIGINT UNSIGNED NOT NULL,
	waste_id BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (company_id, waste_id),
	FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (waste_id) REFERENCES type_of_waste(waste_id) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- смоимость вывоза за кубометр
DROP TABLE IF EXISTS price_list;
CREATE TABLE price_list (
	category_id SERIAL,
    category_name VARCHAR(128), 
    price DECIMAL(7,2)
);

-- мусорные баки
DROP TABLE IF EXISTS trash_cans;
CREATE TABLE trash_cans (
	trash_can_id SERIAL,
    category_id BIGINT UNSIGNED NOT NULL,
    `value` DECIMAL(5,2) DEFAULT 0.75,
    workshop_id BIGINT UNSIGNED NOT NULL COMMENT 'возле какого цеха располагается бак', 
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES price_list(category_id) ON UPDATE CASCADE,
    FOREIGN KEY (workshop_id) REFERENCES workshops(workshop_id) ON UPDATE CASCADE ON DELETE RESTRICT
);


-- мусорные баки, обслуживающие компании
DROP TABLE IF EXISTS trash_cans_companies;
CREATE TABLE trash_cans_companies (
	company_id BIGINT UNSIGNED NOT NULL,
	trash_can_id BIGINT UNSIGNED NOT NULL,
	PRIMARY KEY (company_id, trash_can_id),
	FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (trash_can_id) REFERENCES trash_cans(trash_can_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- контактные лица
DROP TABLE IF EXISTS contacts;
CREATE TABLE contacts (
	contact_id SERIAL,
    full_name VARCHAR(255),
    tel_num BIGINT UNSIGNED UNIQUE,
    email VARCHAR(128) UNIQUE,
    INDEX contacts_name (full_name)
);

-- контактные лица-предприятия (есть случаи, когда один человек обсуживает несколько компаний)
DROP TABLE IF EXISTS contacts_companies;
CREATE TABLE contacts_companies (
	company_id BIGINT UNSIGNED NOT NULL,
	contact_id BIGINT UNSIGNED NOT NULL,
    position VARCHAR(128),
	PRIMARY KEY (contact_id, company_id),
	FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE CASCADE ON DELETE CASCADE
);

-- поступление отходов на отвальное хозяйство
DROP TABLE IF EXISTS coming_out;
CREATE TABLE coming_out (
	coming_out_id SERIAL,
    dump_date DATE,
    trash_can_id BIGINT UNSIGNED NOT NULL,
    total_amount DECIMAL(10,2),
    is_paid BIT(1) DEFAULT 0,
    FOREIGN KEY (trash_can_id) REFERENCES trash_cans(trash_can_id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX coming_out_time (dump_date)
);


-- ПРЕДСТАВЛЕНИЯ

-- Полная информация о компаниях
CREATE OR REPLACE VIEW companies_info AS 
	SELECT c.company_id as id, short_name, INN, is_subsidiary, ldc.full_name as leader, job_title, lc.num as contract,
    cc.full_name as contact, cc.tel_num as contact_num
    FROM companies c INNER JOIN leaders_of_companies ldc USING(company_id)
    INNER JOIN lease_contract lc USING(company_id)
    INNER JOIN contacts_companies USING(company_id)
    INNER JOIN contacts cc USING(contact_id)
    ORDER BY id; 

-- Счета за вывоз отходов за последний месяц
CREATE OR REPLACE VIEW companies_bill AS 
	SELECT c.company_id as id, short_name, SUM(total_amount) as bill
    FROM companies c INNER JOIN trash_cans_companies USING(company_id)
    INNER JOIN trash_cans USING(trash_can_id)
    INNER JOIN coming_out USING(trash_can_id)
    WHERE MONTH(dump_date)=MONTH(NOW()) AND YEAR(dump_date)=YEAR(NOW())
    GROUP BY c.company_id, short_name
    ORDER BY id; 

-- ТРИГГЕРЫ И ХРАНИМЫЕ ПРОЦЕДУРЫ
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

-- НАПОЛНЕНИЕ ТАБЛИЦ ДАННЫМИ

USE waste_coor_system;

INSERT INTO type_of_waste 
	(`name`, `fkko_num`, `hazard_class`, `must_be_neutralized`, `can_be_recycled`, `can_be_recycled_with_profit`, `can_be_buried`)
	VALUES 
		('мусор от офисных и бытовых помещений организаций несортированный (исключая крупногабаритный)', '7 33 100 01 72 4', 4, 0, 0, 0, 1),
		('мусор и смет производственных помещений малоопасный', '7 33 210 01 72 4', 4, 0, 0, 0, 1),
		('мусор и смет производственных помещений практически неопасный', '7 33 210 02 72 5', 5, 0, 0, 0, 1),
		('мусор и смет от уборки складских помещений малоопасный', '7 33 220 01 72 4', 4, 0, 0, 0, 1),
		('мусор и смет от уборки складских помещений практически неопасный', '7 33 220 02 72 5', 5, 0, 0, 0, 1),
		('обтирочный материал, загрязненный лакокрасочными материалами в количестве менее 5%)', '8 92 110 02 60 4', 4, 0, 1, 0, 1),
		('обтирочный материал, загрязненный нефтью или нефтепродуктами (содержание нефти или нефтепродуктов менее 15%)', '9 19 204 02 60 4', 4, 0, 1, 0, 1),
		('опилки и стружка древесные, загрязненные нефтью или нефтепродуктами (содержание нефти или нефтепродуктов менее 15%)', '9 19 205 02 39 4', 4, 0, 1, 0, 1),
		('тара из черных металлов, загрязненная нефтепродуктами (содержание нефтепродуктов менее 15%)', '4 68 111 02 51 4', 4, 0, 1, 0, 1),
		('тара из черных металлов, загрязненная лакокрасочными материалами (содержание менее 5%)', '4 68 112 02 51 4', 4, 0, 1, 0, 1),
		('лом и отходы изделий из полиэтилена незагрязненные (кроме тары)', '4 34 110 03 51 5', 5, 0, 1, 1, 0),
		('лом и отходы, содержащие незагрязненные черные металлы в виде изделий, кусков, несортированные', '4 61 010 01 20 5', 5, 0, 1, 1, 0),
		('стружка черных металлов несортированная незагрязненная', '3 61 212 03 22 5', 5, 0, 1, 1, 0),
		('отходы минеральных масел моторных', '4 06 110 01 31 3', 3, 0, 1, 1, 0);


INSERT INTO companies (`control_method`, `full_name`, `short_name`, `INN`, `is_subsidiary`, `created_at`, `updated_at`) 
VALUES 
	('ООО','Ergonomic assymetric time-frame','Kuhlman-Leannon',532807010525,0,'2016-07-25 06:07:11','2020-10-31 00:19:20'),
	('АО','Down-sized incremental frame','Ratke-Morissette',942798620269,1,'2018-12-18 19:57:41','2021-03-22 22:54:43'),
	('АО','Ergonomic intermediate function','Yost-Gleichner',704817461747,1,'2015-12-01 14:13:34','2016-03-18 23:43:57'),
	('АО','Profound interactive frame','Swaniawski-Hartmann',578226823577,1,'2012-05-19 01:02:06','2017-07-05 17:38:25'),
	('ООО','Team-oriented client-driven GraphicInterface','Keebler-Moore',625518774646,0,'2014-07-13 03:10:04','2019-01-04 13:22:12'),
	('ЗАО','User-friendly fault-tolerant forecast','Lakin, Schimmel and Langworth',318102006793,0,'2017-01-31 20:16:35','2020-08-14 08:28:27'),
	('ООО','Extended web-enabled info-mediaries','Thompson PLC',920736098003,0,'2011-12-29 15:08:57','2017-06-12 17:45:43'),
	('ООО','Quality-focused even-keeled algorithm','Reichel PLC',281798301137,0,'2012-09-09 18:29:04','2013-01-21 23:20:40'),
	('ООО','Open-source encompassing instructionset','Wunsch, Corkery and Daniel',217874091168,0,'2018-03-07 13:33:55','2020-03-17 03:06:57'),
	('ЗАО','Public-key full-range functionalities','Funk PLC',426205939449,0,'2019-07-10 10:36:48','2020-07-03 07:45:22'),
	('АО','Mandatory bifurcated workforce','Boehm, Bruen and Koelpin',734175687738,1,'2015-10-30 09:10:38','2021-02-10 15:20:59'),
	('ЗАО','Devolved zerodefect structure','Sporer-Conroy',841887249226,0,'2014-05-19 00:32:02','2017-06-06 23:58:47'),
	('АО','Innovative optimizing emulation','Ondricka and Sons',764127051968,1,'2017-09-01 16:14:40','2019-10-19 08:04:29'),
	('ООО','Decentralized clear-thinking openarchitecture','Strosin-Zboncak',136073105463,0,'2016-08-08 19:11:39','2019-02-23 11:28:47'),
	('ООО','Re-engineered zerodefect database','Rowe, Braun and Jacobi',725954402110,0,'2016-06-23 05:23:24','2018-05-07 20:58:00'),
	('ООО','Up-sized 3rdgeneration ability','Grant, Witting and Hamill',453751965275,0,'2014-04-15 12:58:23','2015-01-01 12:24:20'),
	('ООО','Stand-alone client-driven matrices','Okuneva Ltd',241072388219,0,'2013-04-21 09:08:22','2018-10-28 21:00:28'),
	('ООО','De-engineered real-time monitoring','Ondricka-Raynor',784599242424,0,'2018-10-14 12:35:59','2018-12-10 15:26:56'),
	('ООО','Right-sized composite framework','Romaguera, Wiegand and Ortiz',207356413664,1,'2013-09-23 17:55:51','2016-09-03 01:16:41'),
	('АО','Persistent 5thgeneration flexibility','Turner LLC',736373046910,1,'2016-06-27 01:45:38','2020-08-07 10:21:49');


INSERT INTO price_list  (`category_name`, `price`) 
VALUES
	('пластик', 100.00),
	('стекло', 420.50),
	('макулатура', 80.50),
	('металл', 120.50),
	('прочее', 630.50);


INSERT INTO workshops (`number`, `name`) VALUES 
	(6,'Kunde-Ward'),(99,'LLC'), (28,'DuBuque'),(48,'Osinski'), (56,'Kuhic-McCullough'),(79,'Cassin-Berge'),
	(25,'Stracke-Boyle'),(11,'Beahan LLC'), (50,'Bogisich-Dach'),(7,'Boehm-Bergnaum');


INSERT INTO contacts (`full_name`, `tel_num`, `email`) VALUES 
	('Mrs. Sasha Gulgowski',89583012745,'maryam.carter@example.org'),
	('Jason Ruecker',89020477147,'okozey@example.com'),
	('Dr. Dasia Auer',89821302061,'barney02@example.com'),
	('Elvie Rohan',89780306561,'june67@example.net'),
	('Kaela Hegmann',89282256498,'arnaldo70@example.net'),
	('Mrs. Leila Lowe',89055909972,'jeremie08@example.org'),
	('Ardith Kub',89834492623,'devante.emmerich@example.org'),
	('Vince Dibbert',89494085642,'rudy50@example.org'),
	('Claudine Graham I',89010253736,'roderick99@example.net'),
	('Milan Prosacco',89749348086,'vandervort.reta@example.net'),
	('Avery Eichmann',89816960649,'kaitlyn.goodwin@example.org'),
	('Miss Allene Schinner II',89339077550,'samson11@example.org'),
	('Yvette Runolfsdottir I',89267308703,'bdonnelly@example.com'),
	('Edison Wolff',89896721774,'fstehr@example.org'),
	('Florida Pagac',89882954758,'luna17@example.net');


INSERT INTO leaders_of_companies VALUES 
	(1,'директор','Edison Bayer','2018-10-16 12:06:26','2020-10-29 02:50:27'),
	(2,'генеральный_директор','Alexis Breitenberg','2015-03-13 23:02:44','2021-04-02 16:50:51'),
	(3,'директор','Vernie Vandervort','2019-02-14 16:09:40','2020-09-07 18:27:45'),
	(4,'генеральный_директор','Dane Hahn IV','2014-01-28 02:35:55','2020-07-31 05:56:47'),
	(5,'директор','Ressie Braun','2015-12-02 12:25:19','2021-04-05 19:45:57'),
	(6,'директор','Dr. Cruz Mayert','2016-06-22 17:22:57','2020-10-11 14:19:58'),
	(7,'генеральный_директор','Aleen Upton','2018-08-03 02:10:37','2020-11-03 16:15:57'),
	(8,'генеральный_директор','Kenneth Pacocha','2011-11-06 14:18:44','2021-01-31 00:09:27'),
	(9,'директор','Nicholas Prohaska','2020-09-01 11:19:58','2021-02-23 05:55:49'),
	(10,'директор','Mrs. Tressa Reinger','2013-08-19 14:44:30','2020-10-09 18:15:47'),
	(11,'директор','Brando Sauer','2013-08-12 04:58:40','2020-10-12 12:23:52'),
	(12,'директор','Chadrick Steuber','2018-02-18 22:33:09','2020-06-26 20:02:28'),
	(13,'директор','Dr. Piper Von','2011-06-13 20:10:55','2020-07-23 09:06:37'),
	(14,'генеральный_директор','Ella Tillman','2017-07-09 09:32:57','2020-11-09 10:18:31'),
	(15,'генеральный_директор','Josh Rath','2015-02-27 08:32:00','2020-05-09 22:17:11'),
	(16,'директор','Elyse Kohler DVM','2011-12-24 01:17:57','2021-01-26 12:42:52'),
	(17,'генеральный_директор','Omer Boyer','2011-05-17 16:42:17','2020-10-30 04:10:26'),
	(18,'генеральный_директор','Herta Wintheiser','2021-03-24 21:30:21','2021-02-19 13:38:47'),
	(19,'генеральный_директор','Mrs. Lily Littel I','2014-09-20 20:04:09','2020-07-13 04:48:42'),
	(20,'генеральный_директор','Prof. Cullen Heller','2019-06-13 22:36:01','2021-02-27 20:09:26');

INSERT INTO lease_contract VALUES 
	(1,'УМ-8863875367591','2017-03-28','2017-02-10 00:00:00','2020-07-15 00:00:00'),
	(2,'УМ-2659214388855','2017-06-24','2017-02-06 00:00:00','2020-08-01 00:00:00'),
	(3,'УМ-1184045194944','2017-05-24','2017-03-30 00:00:00','2020-12-26 00:00:00'),
	(4,'УМ-7514655533583','2017-08-14','2017-03-13 00:00:00','2020-11-29 00:00:00'),
	(5,'УМ-2857405163995','2017-10-29','2017-11-20 00:00:00','2020-01-10 00:00:00'),
	(6,'УМ-5650256956481','2017-09-17','2017-02-20 00:00:00','2020-08-26 00:00:00'),
	(7,'УМ-1700680757384','2017-10-14','2017-12-21 00:00:00','2020-05-22 00:00:00'),
	(8,'УМ-4781446486868','2017-04-22','2017-08-12 00:00:00','2020-10-15 00:00:00'),
	(9,'УМ-8439114224057','2017-06-20','2017-06-03 00:00:00','2020-09-10 00:00:00'),
	(10,'УМ-7683766856802','2017-02-20','2017-02-14 00:00:00','2020-01-18 00:00:00'),
	(11,'УМ-1944376891888','2017-09-25','2017-09-11 00:00:00','2020-01-04 00:00:00'),
	(12,'УМ-7831647799766','2017-09-22','2017-01-25 00:00:00','2020-04-30 00:00:00'),
	(13,'УМ-2675731718357','2016-06-01','2016-07-09 00:00:00','2020-03-15 00:00:00'),
	(14,'УМ-7154459729029','2015-10-19','2015-02-18 00:00:00','2020-03-04 00:00:00'),
	(15,'УМ-1764076282607','2018-12-29','2018-08-27 00:00:00','2020-10-24 00:00:00'),
	(16,'УМ-3945786919733','2013-11-06','2013-05-03 00:00:00','2020-04-10 00:00:00'),
	(17,'УМ-0643260139716','2011-07-17','2011-06-23 00:00:00','2020-06-27 00:00:00'),
	(18,'УМ-0996250401240','2006-06-10','2006-01-04 00:00:00','2020-12-26 00:00:00'),
	(19,'УМ-1651208503061','2013-01-13','2013-04-27 00:00:00','2020-10-11 00:00:00'),
	(20,'УМ-2361769161905','2011-08-29','2011-11-27 00:00:00','2020-04-09 00:00:00');
    

INSERT INTO trash_cans VALUES 
	(1,5,15.28,5,'2019-02-13 21:53:21','2020-07-26 06:24:19'),
    (2,4,5.06,2,'2017-02-08 16:13:32','2018-11-20 13:39:28'),
	(3,5,13.00,3,'2019-12-28 18:01:21','2021-01-11 15:52:04'),
    (4,1,3.16,4,'2016-02-19 02:05:23','2018-10-04 19:26:52'),
	(5,5,4.21,5,'2015-10-16 10:42:56','2020-04-07 04:54:53'),
    (6,5,17.96,6,'2018-03-13 08:06:51','2019-06-16 20:11:29'),
	(7,5,14.44,7,'2015-08-19 18:26:33','2017-02-17 13:00:16'),
    (8,4,12.17,8,'2013-06-02 18:28:04','2017-11-09 16:06:02'),
	(9,5,7.42,9,'2019-08-20 06:08:59','2020-04-29 06:39:33'),
    (10,5,2.10,10,'2012-06-08 12:40:28','2019-01-29 15:09:57'),
	(11,1,10.45,11,'2018-05-06 18:28:57','2020-04-01 02:21:12'),
    (12,4,4.20,12,'2015-09-28 09:09:46','2018-12-30 01:17:40'),
	(13,1,11.90,13,'2018-08-18 14:02:06','2019-10-26 08:12:45'),
    (14,1,18.89,14,'2017-08-02 10:05:21','2018-01-13 22:51:22'),
	(15,5,15.19,15,'2014-04-09 09:31:26','2018-10-25 03:09:23'),
    (16,5,15.73,16,'2016-02-26 22:15:08','2018-06-17 18:49:57'),
	(17,5,13.20,17,'2018-09-15 03:25:24','2019-01-30 01:33:24'),
    (18,5,17.01,18,'2015-09-18 21:25:00','2016-12-05 01:43:26'),
	(19,5,13.16,19,'2015-04-05 02:49:29','2020-04-02 21:41:22'),
    (20,5,15.41,20,'2011-10-26 11:13:50','2015-09-06 21:29:50');

INSERT INTO contacts_companies VALUES 
	(1,1,'эколог'),(16,1,'эколог'),(2,2,'эколог'),(17,2,'эколог'),
	(3,3,'эколог'),(18,3,'эколог'),(4,4,'эколог'),
	(19,4,'эколог'),(5,5,'эколог'),(20,5,'эколог'),
	(6,6,'главный энергетик'),(7,7,'эколог'),(8,8,'главный энергетик'),
	(9,9,'эколог'),(10,10,'главный энергетик'),(11,11,'главный инженер'),
	(12,12,'главный энергетик'),(13,13,'эколог'),(14,14,'главный энергетик'),
	(15,15,'главный инженер');

INSERT INTO waste_companies VALUES 
	(1,5),(2,2),(2,12),
	(3,9),(4,11),(5,4),
	(6,10),(7,7),(8,12),
    (9,5),(10,6),(11,11),
	(12,12),(13,12),(14,12),
	(15,7),(19,9),(20,10);

INSERT INTO trash_cans_companies VALUES 
	(1,1),(2,2),(2,20),(4,4),(5,5),(6,6),(7,7),
	(8,8),(9,9),(10,10),(11,11),(13,13),
	(14,14),(15,15),(19,19),(3,3);

INSERT INTO workshops_companies VALUES 
	(1,12),(2,2),(3,3),(4,8),(5,15),(6,20),(7,7),
	(8,8),(9,9),(10,20),(11,11),(12,12),(13,3),
    (14,14),(15,15),(16,6),(17,4),(18,18),(19,3),(20,10);

INSERT INTO coming_out (`dump_date`,`trash_can_id`, `is_paid`)
VALUES
	('2021-03-05', 1, 1), ('2021-03-05', 2, 1), ('2021-03-05', 3, 1),
    ('2021-03-05', 4, 1), ('2021-03-05', 5, 1), ('2021-03-05', 6, 1),
    ('2021-03-05', 7, 1), ('2021-03-05', 8, 1), ('2021-03-05', 9, 1),
    ('2021-03-05', 10, 1), ('2021-03-05', 11, 1);
    
 
INSERT INTO coming_out (`dump_date`,`trash_can_id`)
VALUES
    ('2021-04-21', 1), ('2021-04-21', 2), ('2021-04-21', 11), 
    ('2021-04-21', 12), ('2021-04-21', 13), ('2021-04-21', 19), 
    ('2021-04-21', 6), ('2021-04-21', 4);


-- ВЫБОРКИ
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