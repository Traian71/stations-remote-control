-- ============================================
-- GENERATE MEASUREMENTS ONLY - V5 OPTIMIZED
-- Generează doar măsurători noi pentru dispozitivele existente
-- Simulează date trimise de dispozitive către cloud
-- ============================================
-- NOTĂ: Acest script folosește procedură pentru a genera date
-- pentru toate dispozitivele active din baza de date
-- 
-- CABINA (1001-4999): 1 măsurătoare/zi la ora 12:00
-- MODUL_MASURA (5001-8999): 24 măsurători/zi (câte una pe oră)
-- 
-- OPTIMIZĂRI V5:
-- - Perioadă istorică redusă la 30 zile (de la 3 ani)
-- - COMMIT periodic după fiecare 5 dispozitive
-- - Previne MySQL Error 2013 (Lost connection during query)
-- ============================================

USE db_cpms3;

DELIMITER //

CREATE PROCEDURE genereaza_masuratori_noi()
BEGIN
    DECLARE v_cabina INT;
    DECLARE v_zi INT;
    DECLARE v_ora INT;
    DECLARE v_data DATETIME;
    DECLARE v_traseu VARCHAR(255);
    DECLARE v_locatie VARCHAR(255);
    DECLARE v_tip_dispozitiv VARCHAR(20);
    DECLARE done INT DEFAULT FALSE;
    DECLARE v_total_zile INT DEFAULT 30; -- 30 zile (redus de la 3 ani pentru a preveni timeout)
    DECLARE v_commit_counter INT DEFAULT 0;
    
    DECLARE cabine_cursor CURSOR FOR 
        SELECT id_cabina, traseu, locatie FROM cabine WHERE activa = TRUE;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
    
    OPEN cabine_cursor;
    
    read_loop: LOOP
        FETCH cabine_cursor INTO v_cabina, v_traseu, v_locatie;
        IF done THEN
            LEAVE read_loop;
        END IF;
        
        -- Detectare tip dispozitiv
        IF v_cabina BETWEEN 1001 AND 4999 THEN
            SET v_tip_dispozitiv = 'CABINA';
        ELSEIF v_cabina BETWEEN 5001 AND 8999 THEN
            SET v_tip_dispozitiv = 'MODUL_MASURA';
        ELSE
            SET v_tip_dispozitiv = 'UNKNOWN';
        END IF;
        
        -- Generare date istorice
        SET v_zi = 0;
        WHILE v_zi < v_total_zile DO
            SET v_data = DATE_SUB(NOW(), INTERVAL (v_total_zile - v_zi) DAY);
            
            IF v_tip_dispozitiv = 'CABINA' THEN
                -- CABINA: 1 măsurătoare/zi la ora 12:00
                SET v_data = DATE_ADD(DATE(v_data), INTERVAL 12 HOUR);
                
                INSERT INTO parametri_monitorizati (
                    traseu, locatie, id_cabina, tip_date, data, ora,
                    uinj_v, iinj_a, pcon_dc_v, pcon_ac_v, pcoff_v,
                    injectie, prescrisa_v, mod_reglare, mod_transmisie, usa,
                    tensiune_baterie,
                    temperatura, tensiune_retea, status_modul,
                    putere_gsm_dbm, putere_gps_dbm,
                    actualizare_min, status
                ) VALUES (
                    v_traseu, v_locatie, v_cabina, 30, DATE(v_data), TIME(v_data),
                    12.0 + (RAND() * 2 - 1),
                    2.5 + (RAND() * 1 - 0.5),
                    -0.850 + (RAND() * 0.1 - 0.05),
                    0.150 + (RAND() * 0.1 - 0.05),
                    CASE WHEN v_zi % 7 = 0 THEN -0.920 + (RAND() * 0.05 - 0.025) ELSE NULL END,
                    1,
                    -0.850,
                    0,
                    0,
                    0,
                    12.6 + (RAND() * 0.4),
                    20.0 + (RAND() * 20 - 10),
                    1,
                    0,
                    -75.0 + (RAND() * 15 - 7.5),
                    -95.0 + (RAND() * 15 - 7.5),
                    TIMESTAMPDIFF(MINUTE, v_data, NOW()),
                    'OK'
                );
                
            ELSEIF v_tip_dispozitiv = 'MODUL_MASURA' THEN
                -- MODUL_MASURA: 24 măsurători/zi (câte una pe oră)
                -- Trimite același format Tip 21 ca CABINA, dar fără capacitate de injecție (uinj_v, iinj_a = NULL)
                SET v_ora = 0;
                WHILE v_ora < 24 DO
                    SET v_data = DATE_ADD(DATE(v_data), INTERVAL v_ora HOUR);
                    
                    INSERT INTO parametri_monitorizati (
                        traseu, locatie, id_cabina, tip_date, data, ora,
                        uinj_v, iinj_a, pcon_dc_v, pcon_ac_v, pcoff_v,
                        injectie, prescrisa_v, mod_reglare, mod_transmisie, usa,
                        tensiune_baterie,
                        temperatura, tensiune_retea, status_modul,
                        putere_gsm_dbm, putere_gps_dbm,
                        actualizare_min, status
                    ) VALUES (
                        v_traseu, v_locatie, v_cabina, 21, DATE(v_data), TIME(v_data),
                        NULL, NULL,  -- MODUL_MASURA nu are capacitate de injecție
                        -0.850 + (RAND() * 0.1 - 0.05),
                        0.150 + (RAND() * 0.1 - 0.05),
                        CASE WHEN v_ora % 6 = 0 THEN -0.920 + (RAND() * 0.05 - 0.025) ELSE NULL END,
                        0,  -- tip_injectie: 0=NONE (nu are injecție)
                        -0.850,
                        0,  -- mod_reglare: 0=PCoff
                        0,  -- mod_transmisie: 0=PROGRAMAT
                        0,
                        12.6 + (RAND() * 0.4),
                        20.0 + (RAND() * 20 - 10),
                        1,
                        0,
                        -75.0 + (RAND() * 15 - 7.5),
                        -95.0 + (RAND() * 15 - 7.5),
                        TIMESTAMPDIFF(MINUTE, v_data, NOW()),
                        'OK'
                    );
                    
                    SET v_ora = v_ora + 1;
                END WHILE;
            END IF;
                
            SET v_zi = v_zi + 1;
        END WHILE;
        
        -- Măsurătoare recentă (acum) pentru status ONLINE
        IF v_tip_dispozitiv = 'CABINA' THEN
            -- CABINA: 1 măsurătoare recentă
            INSERT INTO parametri_monitorizati (
                traseu, locatie, id_cabina, tip_date, data, ora,
                uinj_v, iinj_a, pcon_dc_v, pcon_ac_v, pcoff_v,
                injectie, prescrisa_v, mod_reglare, mod_transmisie, usa,
                tensiune_baterie,
                temperatura, tensiune_retea, status_modul,
                putere_gsm_dbm, putere_gps_dbm,
                actualizare_min, status
            ) VALUES (
                v_traseu, v_locatie, v_cabina, 30, 
                CURDATE(), 
                CURTIME(),
                12.0 + (RAND() * 2 - 1),
                2.5 + (RAND() * 1 - 0.5),
                -0.850 + (RAND() * 0.1 - 0.05),
                0.150 + (RAND() * 0.1 - 0.05),
                NULL,
                1,
                -0.850,
                0,
                0,
                0,
                12.6 + (RAND() * 0.4),
                20.0 + (RAND() * 20 - 10),
                1,
                0,
                -75.0 + (RAND() * 15 - 7.5),
                -95.0 + (RAND() * 15 - 7.5),
                0,
                'OK'
            );
        ELSEIF v_tip_dispozitiv = 'MODUL_MASURA' THEN
            -- MODUL_MASURA: 24 măsurători recente (ultima zi)
            -- Trimite același format Tip 21 ca CABINA, dar fără capacitate de injecție
            SET v_ora = 0;
            WHILE v_ora < 24 DO
                INSERT INTO parametri_monitorizati (
                    traseu, locatie, id_cabina, tip_date, data, ora,
                    uinj_v, iinj_a, pcon_dc_v, pcon_ac_v, pcoff_v,
                    injectie, prescrisa_v, mod_reglare, mod_transmisie, usa,
                    tensiune_baterie,
                    temperatura, tensiune_retea, status_modul,
                    putere_gsm_dbm, putere_gps_dbm,
                    actualizare_min, status
                ) VALUES (
                    v_traseu, v_locatie, v_cabina, 21, 
                    CURDATE(), 
                    MAKETIME(v_ora, 0, 0),
                    NULL, NULL,  -- MODUL_MASURA nu are capacitate de injecție
                    -0.850 + (RAND() * 0.1 - 0.05),
                    0.150 + (RAND() * 0.1 - 0.05),
                    CASE WHEN v_ora % 6 = 0 THEN -0.920 + (RAND() * 0.05 - 0.025) ELSE NULL END,
                    0,  -- tip_injectie: 0=NONE
                    -0.850,
                    0,  -- mod_reglare: 0=PCoff
                    0,  -- mod_transmisie: 0=PROGRAMAT
                    0,
                    12.6 + (RAND() * 0.4),
                    20.0 + (RAND() * 20 - 10),
                    1,
                    0,
                    -75.0 + (RAND() * 15 - 7.5),
                    -95.0 + (RAND() * 15 - 7.5),
                    0,
                    'OK'
                );
                SET v_ora = v_ora + 1;
            END WHILE;
        END IF;
        
        UPDATE cabine 
        SET ultima_comunicare = NOW(), status = 'ONLINE'
        WHERE id_cabina = v_cabina;
        
        -- COMMIT periodic pentru a preveni timeout (după fiecare dispozitiv)
        SET v_commit_counter = v_commit_counter + 1;
        IF v_commit_counter >= 5 THEN
            COMMIT;
            SET v_commit_counter = 0;
        END IF;
    END LOOP;
    
    CLOSE cabine_cursor;
    
    -- Final COMMIT pentru ultimele înregistrări
    COMMIT;
END //

DELIMITER ;

CALL genereaza_masuratori_noi();
DROP PROCEDURE genereaza_masuratori_noi;

-- ============================================
-- VERIFICARE MĂSURĂTORI GENERATE
-- ============================================
SELECT '=== VERIFICARE MĂSURĂTORI GENERATE ===' AS '';
SELECT CONCAT('Total măsurători: ', COUNT(*)) AS rezultat FROM parametri_monitorizati;
SELECT CONCAT('Cabine ONLINE: ', COUNT(*)) AS rezultat FROM cabine WHERE status = 'ONLINE';
SELECT CONCAT('Cabine OFFLINE: ', COUNT(*)) AS rezultat FROM cabine WHERE status = 'OFFLINE';

-- Verificare distribuție măsurători pe tip dispozitiv
SELECT 
    CASE 
        WHEN id_cabina BETWEEN 1001 AND 4999 THEN 'CABINA (1/zi)'
        WHEN id_cabina BETWEEN 5001 AND 8999 THEN 'MODUL_MASURA (24/zi)'
        ELSE 'UNKNOWN'
    END AS tip_dispozitiv,
    COUNT(*) AS total_masuratori,
    COUNT(DISTINCT id_cabina) AS numar_dispozitive,
    ROUND(COUNT(*) / COUNT(DISTINCT id_cabina), 1) AS medie_masuratori_per_dispozitiv
FROM parametri_monitorizati
GROUP BY tip_dispozitiv;

-- Afișare ultimele măsurători pentru fiecare cabină
SELECT 
    pm.id_cabina,
    c.locatie,
    pm.data,
    pm.ora,
    pm.uinj_v,
    pm.iinj_a,
    pm.pcon_dc_v,
    pm.pcon_ac_v,
    pm.mod_reglare,
    pm.tensiune_baterie,
    pm.temperatura,
    pm.tensiune_retea,
    pm.status_modul,
    pm.primit_la,
    c.ultima_comunicare,
    c.status
FROM parametri_monitorizati pm
JOIN cabine c ON pm.id_cabina = c.id_cabina
WHERE pm.primit_la = (
    SELECT MAX(primit_la) 
    FROM parametri_monitorizati 
    WHERE id_cabina = pm.id_cabina
)
ORDER BY pm.id_cabina;

SELECT 'Măsurători generate cu succes!' AS status;
