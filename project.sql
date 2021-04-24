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
    start_date DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (company_id) REFERENCES companies(company_id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX contract_num (num)
);

-- цеха
DROP TABLE IF EXISTS workshops;
CREATE TABLE workshops (
    workshop_id SERIAL,
	number INT,
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
    price DECIMAL(10,2)
);

-- мусорные баки
DROP TABLE IF EXISTS trash_cans;
CREATE TABLE trash_cans (
	trash_can_id SERIAL,
    category_id BIGINT UNSIGNED NOT NULL,
    value DECIMAL(5,2) DEFAULT 0.75,
    workshop_id BIGINT UNSIGNED NOT NULL COMMENT 'возле какого цеха располагается бак', 
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES price_list(category_id) ON UPDATE CASCADE,
    FOREIGN KEY (workshop_id) REFERENCES workshops(workshop_id) ON UPDATE CASCADE ON DELETE RESTRICT
);


-- мусорные баки, обсулживающие компании
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
    dump_time DATE,
    trash_can_id BIGINT UNSIGNED NOT NULL,
    total_amount INT UNSIGNED,
    FOREIGN KEY (trash_can_id) REFERENCES trash_cans(trash_can_id) ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX coming_out_time (dump_time)
);

-- представление 1. Полная информация о компаниях
CREATE OR REPLACE VIEW companies_info AS 
	SELECT c.company_id as id, short_name, INN, is_subsidiary, ldc.full_name as leader, job_title, lc.num as contract,
    cc.full_name as contact, cc.tel_num as contact_num
    FROM companies c INNER JOIN leaders_of_companies ldc USING(company_id)
    INNER JOIN lease_contract lc USING(company_id)
    INNER JOIN contacts_companies USING(company_id)
    INNER JOIN contacts cc USING(contact_id)
    ORDER BY id; 
