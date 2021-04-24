USE waste_coor_system;

-- представление 1. Полная информация о компаниях
CREATE OR REPLACE VIEW companies_info AS 
	SELECT c.company_id as id, short_name, INN, is_subsidiary, ldc.full_name as leader, job_title, lc.num as contract,
    cc.full_name as contact, cc.tel_num as contact_num
    FROM companies c INNER JOIN leaders_of_companies ldc USING(company_id)
    INNER JOIN lease_contract lc USING(company_id)
    INNER JOIN contacts_companies USING(company_id)
    INNER JOIN contacts cc USING(contact_id)
    ORDER BY id; 
