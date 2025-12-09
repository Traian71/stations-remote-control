-- ============================================
-- SCHEMA BAZĂ DE DATE - Platformă SPC
-- Sistem Monitorizare Cabine Protecție Catodică
-- ============================================
-- Tabele Esențiale - Optimizat pentru Producție
-- Conform Standard SR 13392:2004
-- ============================================



USE db_cpms3;

-- Backend-ul folosește UTC, deci lăsăm timezone-ul implicit (UTC)

-- ============================================
-- 1. UTILIZATORI - Conturi Utilizatori
-- ============================================
CREATE TABLE utilizatori (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nume_utilizator VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    parola_hash VARCHAR(255) NOT NULL,
    nume_complet VARCHAR(255),
    activ BOOLEAN DEFAULT TRUE,
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ultima_autentificare TIMESTAMP NULL,
    INDEX idx_nume_utilizator (nume_utilizator),
    INDEX idx_email (email),
    INDEX idx_activ (activ)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Conturi utilizatori pentru acces platformă';

-- ============================================
-- 2. ROLURI - Roluri Utilizatori
-- ============================================
CREATE TABLE roluri (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nume VARCHAR(100) UNIQUE NOT NULL,
    descriere TEXT,
    rol_sistem BOOLEAN DEFAULT FALSE,
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Roluri utilizatori: Administrator, Operator, Vizualizator';

-- ============================================
-- 3. PERMISIUNI - Permisiuni Granulare
-- ============================================
CREATE TABLE permisiuni (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nume VARCHAR(100) UNIQUE NOT NULL,
    descriere TEXT,
    categorie VARCHAR(50),
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Permisiuni granulare pentru RBAC';

-- ============================================
-- 4. UTILIZATORI_ROLURI - Mapare Utilizatori-Roluri
-- ============================================
CREATE TABLE utilizatori_roluri (
    utilizator_id INT NOT NULL,
    rol_id INT NOT NULL,
    asignat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    asignat_de INT,
    PRIMARY KEY (utilizator_id, rol_id),
    FOREIGN KEY (utilizator_id) REFERENCES utilizatori(id) ON DELETE CASCADE,
    FOREIGN KEY (rol_id) REFERENCES roluri(id) ON DELETE CASCADE,
    FOREIGN KEY (asignat_de) REFERENCES utilizatori(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mapare utilizatori la rolurile lor';

-- ============================================
-- 5. ROLURI_PERMISIUNI - Mapare Roluri-Permisiuni
-- ============================================
CREATE TABLE roluri_permisiuni (
    rol_id INT NOT NULL,
    permisiune_id INT NOT NULL,
    PRIMARY KEY (rol_id, permisiune_id),
    FOREIGN KEY (rol_id) REFERENCES roluri(id) ON DELETE CASCADE,
    FOREIGN KEY (permisiune_id) REFERENCES permisiuni(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Mapare roluri la permisiunile lor';

-- ============================================
-- 6. CABINE - Dispozitive (Cabine + Module Măsură)
-- ============================================
-- Tabel unificat pentru ambele tipuri de dispozitive:
-- - CABINA (MC-CPCA3): ID 1001-4999 - Module control cu injecție
-- - MODUL_MASURA (Priza Potențial): ID 5001-8999 - Module măsură (24 măsurători/zi)
-- ============================================
CREATE TABLE cabine (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_cabina INT UNIQUE NOT NULL COMMENT 'ID dispozitiv: 1001-4999=Cabină, 5001-8999=Modul Măsură',
    
    -- Tip dispozitiv (auto-detectat din ID range)
    tip_dispozitiv VARCHAR(20) GENERATED ALWAYS AS (
        CASE 
            WHEN id_cabina BETWEEN 1001 AND 4999 THEN 'CABINA'
            WHEN id_cabina BETWEEN 5001 AND 8999 THEN 'MODUL_MASURA'
            ELSE 'UNKNOWN'
        END
    ) STORED COMMENT 'Tip: CABINA (1001-4999) sau MODUL_MASURA (5001-8999)',
    
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    
    -- Informații Hardware
    serie_fabricatie_cabina VARCHAR(100) COMMENT 'Serie fabricație (pentru cabine)',
    serie_fabricatie_modul VARCHAR(100) COMMENT 'Serie fabricație modul',
    lot VARCHAR(100),
    data_punere_functiune DATE,
    
    -- Status Dispozitiv
    ultima_comunicare TIMESTAMP NULL,
    activa BOOLEAN DEFAULT TRUE,
    status VARCHAR(50) DEFAULT 'ONLINE',
    
    -- Date GPS
    longitudine DECIMAL(11, 8),
    latitudine DECIMAL(10, 8),
    
    -- Socket tracking
    socket_id VARCHAR(255) NULL COMMENT 'Unique identifier for active socket connection',
    socket_connected_at DATETIME NULL COMMENT 'Timestamp when socket connection was established',
    socket_ip_address VARCHAR(45) NULL COMMENT 'IP address of connected device',
    
    -- Hardware Diagnostics (auto-sent by device)
    diagnostic_bits SMALLINT UNSIGNED DEFAULT 0 COMMENT '13-bit hardware diagnostic code (bits 0-12): 0=OK, 1=Problem',
    diagnostic_updated_at TIMESTAMP NULL COMMENT 'Timestamp when diagnostic_bits was last updated',

    -- Timestamps
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_id_cabina (id_cabina),
    INDEX idx_tip_dispozitiv (tip_dispozitiv),
    INDEX idx_status (status),
    INDEX idx_activa (activa),
    INDEX idx_ultima_comunicare (ultima_comunicare),
    INDEX idx_traseu (traseu),
    INDEX idx_locatie (locatie),
    INDEX idx_cabine_socket_id (socket_id),
    INDEX idx_diagnostic_bits (diagnostic_bits),
    INDEX idx_diagnostic_updated (diagnostic_updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Dispozitive: Cabine protecție catodică (1001-4999) și Module măsură (5001-8999)';

-- ============================================
-- 7. CABINA_MODULE_MASURA - Relație Părinte-Copil (Cabină → Module Măsură)
-- ============================================
-- O cabină (1001-4999) poate avea mai multe module măsură (5001-8999) asociate
-- Relația se setează doar din modulul măsură (copil) către cabina părinte
CREATE TABLE cabina_module_masura (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_cabina_parinte INT NOT NULL COMMENT 'ID cabină părinte (1001-4999)',
    id_modul_masura INT NOT NULL COMMENT 'ID modul măsură copil (5001-8999)',
    
    -- Metadata
    asignat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    asignat_de INT NULL COMMENT 'ID utilizator care a făcut asocierea',
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Constraints
    UNIQUE KEY unique_modul (id_modul_masura) COMMENT 'Un modul măsură poate avea doar o cabină părinte',
    FOREIGN KEY (id_cabina_parinte) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    FOREIGN KEY (id_modul_masura) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    FOREIGN KEY (asignat_de) REFERENCES utilizatori(id) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_cabina_parinte (id_cabina_parinte),
    INDEX idx_modul_masura (id_modul_masura),
    INDEX idx_asignat_la (asignat_la),
    
    -- Validation constraint: ensure parent is CABINA and child is MODUL_MASURA
    CONSTRAINT chk_parent_is_cabina CHECK (id_cabina_parinte BETWEEN 1001 AND 4999),
    CONSTRAINT chk_child_is_modul CHECK (id_modul_masura BETWEEN 5001 AND 8999)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Relație părinte-copil: Cabină (părinte) → Module Măsură (copii)';

-- ============================================
-- 8. PARAMETRI_MONITORIZATI - Date Telemetrie (Tabelul 1 - AMBELE TIPURI)
-- ============================================
-- Tip Date 21: Date stocate (transmisie automată în mod PROGRAMAT)
-- Tip Date 22: Date curente (transmisie continuă în mod CURENT)
-- Tip Date 30: Identificare tabel în baza de date (valoare implicită)
-- 
-- IMPORTANT: Tabel unificat pentru AMBELE tipuri de dispozitive:
-- - CABINA (1001-4999): 1 măsurătoare/zi (configurabil), are Uinj/Iinj
-- - MODUL_MASURA (5001-8999): 24 măsurători/zi (câte una pe oră), NU are Uinj/Iinj
-- ============================================
CREATE TABLE parametri_monitorizati (
    nr_crt BIGINT AUTO_INCREMENT PRIMARY KEY,
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    id_cabina INT NOT NULL COMMENT 'ID dispozitiv: 1001-4999=CABINA, 5001-8999=MODUL_MASURA',
    tip_date INT DEFAULT 30 COMMENT '21=Stocate(PROGRAMAT), 22=Curente(CURENT), 30=BD',
    data DATE NOT NULL,
    ora TIME NOT NULL,
    
    -- Parametri Măsurați (SR 13392:2004)
    uinj_v DECIMAL(10, 4) COMMENT 'Tensiunea de injecție [V] - doar CABINA',
    iinj_a DECIMAL(10, 4) COMMENT 'Curentul de injecție [A] - doar CABINA',
    pcon_dc_v DECIMAL(10, 4) COMMENT 'Potențial ON curent continuu [V]',
    pcon_ac_v DECIMAL(10, 4) COMMENT 'Potențial ON curent alternativ [V]',
    pcoff_v DECIMAL(10, 4) COMMENT 'Potențial OFF [V]',
    
    -- Status și Configurare (integers: device protocol format)
    injectie INT COMMENT '0=NONE, 1=NORMAL/ON, 2=OFF, 3=INTENSIVE',
    prescrisa_v DECIMAL(10, 4) COMMENT 'Prescrisa PC [V]',
    mod_transmisie INT COMMENT '0=PROGRAMAT, 1=CURENT',
    usa INT COMMENT '0=Închis, 1=Deschis',
    
    -- Sănătate Dispozitiv
    tensiune_baterie DECIMAL(5, 2) COMMENT 'Tensiune baterie [V]',
    temperatura DECIMAL(5, 2) COMMENT 'Temperatură [°C]',
    tensiune_retea INT COMMENT 'Tensiune rețea: 0=lipsa, 1=prezent',
    status_modul INT COMMENT 'Status modul: 0=OK, diferit de 0=eroare',
    putere_gsm_dbm DECIMAL(5, 2),
    putere_gps_dbm DECIMAL(5, 2),
    
    -- Calcule Server
    actualizare_min INT COMMENT 'Minute de la ultima recepție',
    status VARCHAR(20) DEFAULT 'OK' COMMENT 'OK/NOT OK',
    
    -- Metadata
    primit_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    INDEX idx_cabina_data (id_cabina, data, ora),
    INDEX idx_timestamp (data, ora),
    INDEX idx_primit (primit_la),
    INDEX idx_status (status),
    INDEX idx_tip_date (tip_date),
    INDEX idx_cabina_tip_date (id_cabina, tip_date, data)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabelul 1 - Parametri monitorizați (retenție 10 ani - SR 13392:2004)';

-- ============================================
-- 9. DATE_CONFIGURARE_CABINE - Configurație Cabine (Tabelul 2 - Tip Date 31)
-- ============================================
CREATE TABLE date_configurare_cabine (
    nr_crt INT AUTO_INCREMENT PRIMARY KEY,
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    id_cabina INT NOT NULL,
    tip_date INT DEFAULT 31,
    
    -- Configurare Injecție
    tip_injectie INT COMMENT '0=NONE, 1=NORMAL/ON, 2=OFF, 3=INTENSIVE',
    ora_start_masura_pcoff TIME,
    interval_masura_pcoff_h INT COMMENT 'Interval măsură PCoff [h]',
    durata_off_masura_pcoff_s INT COMMENT 'Durată OFF măsură PCoff [s]',
    
    -- Configurare Ciclu Intensiv
    ora_start_ciclu_intensiv TIME,
    durata_on_ciclu_intensiv_s INT COMMENT 'Durată ON CICLU INTENSIV [s]',
    durata_off_ciclu_intensiv_s INT COMMENT 'Durată OFF CICLU INTENSIV [s]',
    durata_ciclu_intensiv_min INT COMMENT 'Durată CICLU INTENSIV [min]',
    
    -- Reglare și Transmisie
    prescrisa_pc_v DECIMAL(10, 4) COMMENT 'Prescrisa PC [V]',
    mod_transmisie INT COMMENT '0=PROGRAMAT, 1=CURENT',
    tip_pc INT DEFAULT 0 COMMENT '0=PCoff (reglare automată activă), 1=PCon (fără reglare automată)',
    
    -- Date GPS
    longitudine DECIMAL(11, 8),
    latitudine DECIMAL(10, 8),
    
    -- Date Identificare (configurate prin HMI cu parolă)
    serie_fabricatie_cabina VARCHAR(100),
    serie_fabricatie_modul VARCHAR(100),
    lot VARCHAR(100),
    data_punere_functiune DATE,
    
    -- Timestamps
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_cabina (id_cabina),
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    INDEX idx_id_cabina (id_cabina),
    INDEX idx_mod_transmisie (mod_transmisie)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabelul 2 - Date configurare cabine';

-- ============================================
-- 10. LIMITE_SEMNALIZARI - Limite și Semnalizări (Tabelul 3 - Tip Date 32)
-- ============================================
CREATE TABLE limite_semnalizari (
    nr_crt INT AUTO_INCREMENT PRIMARY KEY,
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    id_cabina INT NOT NULL,
    tip_date INT DEFAULT 32,
    
    -- Limite Tensiune Injecție
    uinj_h_v DECIMAL(10, 4) COMMENT 'Limită superioară Uinj [V]',
    uinj_l_v DECIMAL(10, 4) COMMENT 'Limită inferioară Uinj [V]',
    
    -- Limite Curent Injecție
    iinj_h_a DECIMAL(10, 4) COMMENT 'Limită superioară Iinj [A]',
    iinj_l_a DECIMAL(10, 4) COMMENT 'Limită inferioară Iinj [A]',
    
    -- Limite Potențial ON DC
    pcon_dc_h_v DECIMAL(10, 4) COMMENT 'Limită superioară PconDC [V]',
    pcon_dc_l_v DECIMAL(10, 4) COMMENT 'Limită inferioară PconDC [V]',
    
    -- Limite Potențial ON AC
    pcon_ac_h_v DECIMAL(10, 4) COMMENT 'Limită superioară PconAC [V]',
    
    -- Limite Potențial OFF
    pcoff_h_v DECIMAL(10, 4) COMMENT 'Limită superioară Pcoff [V]',
    pcoff_l_v DECIMAL(10, 4) COMMENT 'Limită inferioară Pcoff [V]',
    
    -- Configurare
    mod_transmisie INT COMMENT '0=PROGRAMAT, 1=CURENT',
    acces INT DEFAULT 0 COMMENT '0=PERMIS, 1=INTERZIS',
    
    -- Limite Sănătate Dispozitiv
    baterie_l_v DECIMAL(5, 2) COMMENT 'Limită inferioară baterie [V]',
    temperatura_h_c DECIMAL(5, 2) COMMENT 'Limită superioară temperatură [°C]',
    temperatura_l_c DECIMAL(5, 2) COMMENT 'Limită inferioară temperatură [°C]',
    putere_gsm_l_dbm DECIMAL(5, 2) COMMENT 'Limită inferioară GSM [dBm]',
    putere_gps_l_dbm DECIMAL(5, 2) COMMENT 'Limită inferioară GPS [dBm]',
    
    -- Timestamps
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_cabina (id_cabina),
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    INDEX idx_id_cabina (id_cabina)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabelul 3 - Limite și semnalizări (doar pe server, nu se transmit către cabine)';

-- ============================================
-- 11. DATE_CONFIGURARE_MODULE_MASURA - Configurație Module Măsură (Tabelul 2 - Tip Date 31)
-- ============================================
-- Doar pentru module măsură (ID 5001-8999)
CREATE TABLE date_configurare_module_masura (
    nr_crt INT AUTO_INCREMENT PRIMARY KEY,
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    id_cabina INT NOT NULL COMMENT 'ID modul măsură: 5001-8999',
    tip_date INT DEFAULT 31,
    
    -- Configurare Măsurători
    ora_start_masura_pcoff TIME,
    interval_masura_pcoff_h INT COMMENT 'Interval măsură PCoff [h]',
    durata_off_masura_pcoff_s INT COMMENT 'Durată OFF măsură PCoff [s]',
    ora_transmisie_date TIME COMMENT 'Ora transmisie date zilnică',
    
    -- Date GPS
    longitudine DECIMAL(11, 8),
    latitudine DECIMAL(10, 8),
    
    -- Date Identificare (configurate prin HMI cu parolă)
    serie_fabricatie VARCHAR(100),
    lot VARCHAR(100),
    data_punere_functiune DATE,
    
    -- Timestamps
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_modul (id_cabina),
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    INDEX idx_id_cabina (id_cabina)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabelul 2 - Date configurare module măsură';

-- ============================================
-- 12. LIMITE_SEMNALIZARI_MASURA - Limite Module Măsură (Tabelul 3 - Tip Date 32)
-- ============================================
-- Doar pentru module măsură (ID 5001-8999)
CREATE TABLE limite_semnalizari_masura (
    nr_crt INT AUTO_INCREMENT PRIMARY KEY,
    traseu VARCHAR(255),
    locatie VARCHAR(255),
    id_cabina INT NOT NULL COMMENT 'ID modul măsură: 5001-8999',
    tip_date INT DEFAULT 32,
    
    -- Limite Potențial ON DC
    pcon_dc_h_v DECIMAL(10, 4) COMMENT 'Limită superioară PconDC [V]',
    pcon_dc_l_v DECIMAL(10, 4) COMMENT 'Limită inferioară PconDC [V]',
    
    -- Limite Potențial OFF
    pcoff_h_v DECIMAL(10, 4) COMMENT 'Limită superioară Pcoff [V]',
    pcoff_l_v DECIMAL(10, 4) COMMENT 'Limită inferioară Pcoff [V]',
    
    -- Configurare
    acces INT DEFAULT 0 COMMENT '0=PERMIS, 1=INTERZIS',
    
    -- Limite Sănătate Dispozitiv
    baterie_l_v DECIMAL(5, 2) COMMENT 'Limită inferioară baterie [V]',
    temperatura_h_c DECIMAL(5, 2) COMMENT 'Limită superioară temperatură [°C]',
    temperatura_l_c DECIMAL(5, 2) COMMENT 'Limită inferioară temperatură [°C]',
    putere_gsm_l_dbm DECIMAL(5, 2) COMMENT 'Limită inferioară GSM [dBm]',
    putere_gps_l_dbm DECIMAL(5, 2) COMMENT 'Limită inferioară GPS [dBm]',
    
    -- Timestamps
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    UNIQUE KEY unique_modul (id_cabina),
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    INDEX idx_id_cabina (id_cabina)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabelul 3 - Limite și semnalizări module măsură (doar pe server)';

-- ============================================
-- 13. COMENZI - Comenzi Telecontrol
-- ============================================
CREATE TABLE comenzi (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cabina INT NOT NULL,
    tip_comanda VARCHAR(50) NOT NULL COMMENT 'Tip Date: 10, 11, 12, 13, 14',
    date_comanda JSON,
    prioritate VARCHAR(20) DEFAULT 'NORMALA',
    status VARCHAR(50) DEFAULT 'IN_ASTEPTARE',
    
    -- Tracking
    creat_de INT NOT NULL,
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    trimis_la TIMESTAMP NULL,
    confirmat_la TIMESTAMP NULL,
    finalizat_la TIMESTAMP NULL,
    esuat_la TIMESTAMP NULL,
    
    -- Răspuns
    date_raspuns JSON,
    mesaj_eroare TEXT,
    numar_reincercari INT DEFAULT 0,
    max_reincercari INT DEFAULT 3,
    
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    FOREIGN KEY (creat_de) REFERENCES utilizatori(id) ON DELETE CASCADE,
    INDEX idx_cabina_status (id_cabina, status),
    INDEX idx_creat (creat_la),
    INDEX idx_status (status),
    INDEX idx_prioritate (prioritate)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Comenzi telecontrol trimise către cabine';

-- ============================================
-- 14. ISTORIC_COMENZI - Istoric Comenzi
-- ============================================
CREATE TABLE istoric_comenzi (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    comanda_id BIGINT NOT NULL,
    status VARCHAR(50) NOT NULL,
    mesaj_status TEXT,
    modificat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (comanda_id) REFERENCES comenzi(id) ON DELETE CASCADE,
    INDEX idx_comanda (comanda_id),
    INDEX idx_modificat (modificat_la)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Istoric modificări status comenzi';

-- ============================================
-- 15. JURNALE_AUDIT - Jurnale Audit Utilizatori
-- ============================================
CREATE TABLE jurnale_audit (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    utilizator_id INT,
    actiune VARCHAR(100) NOT NULL,
    tip_entitate VARCHAR(50),
    id_entitate VARCHAR(100),
    valori_vechi JSON,
    valori_noi JSON,
    adresa_ip VARCHAR(45),
    user_agent TEXT,
    status VARCHAR(20) DEFAULT 'SUCCES',
    mesaj_eroare TEXT,
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (utilizator_id) REFERENCES utilizatori(id) ON DELETE SET NULL,
    INDEX idx_utilizator (utilizator_id),
    INDEX idx_actiune (actiune),
    INDEX idx_entitate (tip_entitate, id_entitate),
    INDEX idx_creat (creat_la),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Jurnale audit pentru conformitate (cerință SR 13392:2004)';

-- ============================================
-- 16. NOTIFICARI_EMAIL - Notificări Email Anomalii
-- ============================================
CREATE TABLE notificari_email (
    id INT AUTO_INCREMENT PRIMARY KEY,
    utilizator_id INT NOT NULL,
    email VARCHAR(255) NOT NULL,
    activ BOOLEAN DEFAULT TRUE,
    creat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (utilizator_id) REFERENCES utilizatori(id) ON DELETE CASCADE,
    INDEX idx_utilizator (utilizator_id),
    INDEX idx_email (email),
    INDEX idx_activ (activ)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Utilizatori eligibili pentru notificări email privind erorile dispozitivelor';

-- ============================================
-- 17. ANOMALII_DETECTATE - Anomalii Detectate
-- ============================================
CREATE TABLE anomalii_detectate (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_cabina INT NOT NULL,
    id_masurare BIGINT NOT NULL COMMENT 'ID măsurătoare din parametri_monitorizati',
    
    -- Detalii Anomalie
    parametru_nume VARCHAR(100) NOT NULL COMMENT 'Nume parametru (ex: Tensiune Injecție)',
    parametru_cod VARCHAR(50) NOT NULL COMMENT 'Cod parametru (ex: uinj_v)',
    valoare_detectata DECIMAL(10, 4) COMMENT 'Valoarea măsurată',
    valoare_prag DECIMAL(10, 4) COMMENT 'Valoarea prag depășită',
    unitate VARCHAR(20) COMMENT 'Unitate măsură (V, A, °C, etc.)',
    
    -- Clasificare
    tip_anomalie VARCHAR(50) NOT NULL COMMENT 'Tip: DEPASIRE_LIMITA_SUPERIOARA, DEPASIRE_LIMITA_INFERIOARA, etc.',
    severitate VARCHAR(20) NOT NULL COMMENT 'MICA, MEDIE, MARE, CRITICA',
    descriere TEXT COMMENT 'Descriere detaliată anomalie',
    
    -- Status Gestionare
    status VARCHAR(20) DEFAULT 'ACTIVA' COMMENT 'ACTIVA, IN_REZOLVARE, REZOLVATA, IGNORATA',
    rezolvat_de INT NULL COMMENT 'ID utilizator care a rezolvat anomalia',
    rezolvat_la TIMESTAMP NULL COMMENT 'Data rezolvării',
    nota_rezolvare TEXT COMMENT 'Notă despre rezolvare',
    
    -- Notificări
    email_trimis BOOLEAN DEFAULT FALSE COMMENT 'Email de notificare trimis',
    email_trimis_la TIMESTAMP NULL COMMENT 'Data trimiterii email',
    
    -- Timestamps
    detectat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT 'Data detectării anomaliei',
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (id_cabina) REFERENCES cabine(id_cabina) ON DELETE CASCADE,
    FOREIGN KEY (id_masurare) REFERENCES parametri_monitorizati(nr_crt) ON DELETE CASCADE,
    FOREIGN KEY (rezolvat_de) REFERENCES utilizatori(id) ON DELETE SET NULL,
    INDEX idx_cabina (id_cabina),
    INDEX idx_masurare (id_masurare),
    INDEX idx_detectat (detectat_la),
    INDEX idx_status (status),
    INDEX idx_severitate (severitate),
    INDEX idx_tip_anomalie (tip_anomalie),
    INDEX idx_cabina_status (id_cabina, status),
    INDEX idx_cabina_detectat (id_cabina, detectat_la)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Anomalii detectate în măsurători - istoric complet pentru analiză';

-- ============================================
-- 18. CONFIGURARE_SISTEM - Configurare Platformă
-- ============================================
CREATE TABLE configurare_sistem (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cheie_config VARCHAR(100) UNIQUE NOT NULL,
    valoare_config TEXT,
    tip_date VARCHAR(20) DEFAULT 'STRING',
    descriere TEXT,
    criptat BOOLEAN DEFAULT FALSE,
    actualizat_de INT,
    actualizat_la TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (actualizat_de) REFERENCES utilizatori(id) ON DELETE SET NULL,
    INDEX idx_cheie (cheie_config)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Parametri configurare sistem';

-- ============================================
-- DATE INIȚIALE - Permisiuni
-- ============================================
INSERT INTO permisiuni (nume, descriere, categorie) VALUES
-- Gestionare Utilizatori
('CreareUtilizator', 'Creare conturi noi utilizatori', 'GESTIONARE_UTILIZATORI'),
('ActualizareUtilizator', 'Editare detalii utilizatori', 'GESTIONARE_UTILIZATORI'),
('DezactivareUtilizator', 'Dezactivare conturi utilizatori', 'GESTIONARE_UTILIZATORI'),
('ActivareUtilizator', 'Activare conturi utilizatori', 'GESTIONARE_UTILIZATORI'),
('VizualizareUtilizatori', 'Vizualizare listă și detalii utilizatori', 'GESTIONARE_UTILIZATORI'),

-- Gestionare Roluri
('CreareRol', 'Creare roluri noi', 'GESTIONARE_ROLURI'),
('ActualizareRol', 'Editare detalii roluri', 'GESTIONARE_ROLURI'),
('StergereRol', 'Ștergere roluri', 'GESTIONARE_ROLURI'),
('VizualizareRoluri', 'Vizualizare roluri', 'GESTIONARE_ROLURI'),

-- Configurare Sistem
('SetareParametriGlobali', 'Configurare parametri sistem globali', 'CONFIGURARE_SISTEM'),

-- Gestionare Cabine
('VizualizareDateCabine', 'Vizualizare măsurători cabine', 'GESTIONARE_CABINE'),
('ConfigurareCabina', 'Configurare parametri cabină', 'GESTIONARE_CABINE'),
('GestionareCabine', 'Gestionare cabine', 'GESTIONARE_CABINE'),

-- Telecontrol
('TrimitereComenzi', 'Trimitere comenzi către cabine', 'TELECONTROL'),

-- Audit & Raportare
('VizualizareJurnaleAudit', 'Vizualizare jurnale audit', 'AUDIT'),
('ExportDateAudit', 'Export jurnale audit', 'AUDIT'),
('VizualizareRapoarte', 'Vizualizare rapoarte predefinite', 'RAPORTARE'),
('CreareRapoartePersonalizate', 'Creare rapoarte personalizate', 'RAPORTARE'),
('ConfigurareDashboard', 'Configurare dashboard-uri', 'RAPORTARE'),

-- Notificări Email
('GestionareNotificariEmail', 'Gestionare utilizatori pentru notificări email privind erorile dispozitivelor', 'NOTIFICARI_EMAIL');

-- ============================================
-- DATE INIȚIALE - Roluri
-- ============================================
INSERT INTO roluri (nume, descriere, rol_sistem) VALUES
('Administrator', 'Acces complet sistem - toate permisiunile', TRUE),
('Operator', 'Acces operațional - monitorizare și control cabine', TRUE),
('Vizualizator', 'Acces doar citire - vizualizare date', TRUE);

-- ============================================
-- DATE INIȚIALE - Permisiuni Roluri
-- ============================================

-- Administrator: TOATE permisiunile
INSERT INTO roluri_permisiuni (rol_id, permisiune_id)
SELECT 1, id FROM permisiuni;

-- Operator: Permisiuni operaționale
INSERT INTO roluri_permisiuni (rol_id, permisiune_id)
SELECT 2, id FROM permisiuni 
WHERE nume IN (
    'VizualizareUtilizatori', 'VizualizareRoluri',
    'VizualizareDateCabine', 'ConfigurareCabina', 'TrimitereComenzi',
    'VizualizareRapoarte', 'CreareRapoartePersonalizate', 'ConfigurareDashboard'
);

-- Vizualizator: Permisiuni doar citire
INSERT INTO roluri_permisiuni (rol_id, permisiune_id)
SELECT 3, id FROM permisiuni 
WHERE nume IN ('VizualizareDateCabine', 'VizualizareRapoarte', 'VizualizareRoluri');

-- ============================================
-- DATE INIȚIALE - Configurare Sistem
-- ============================================
INSERT INTO configurare_sistem (cheie_config, valoare_config, tip_date, descriere) VALUES
('frecventa_colectare_date', '300', 'INTEGER', 'Frecvență implicită colectare date în secunde'),
('zile_retentie_date', '3650', 'INTEGER', 'Perioadă retenție date în zile (10 ani - SR 13392:2004)'),
('max_reincercari_comenzi', '3', 'INTEGER', 'Număr maxim reîncercări pentru comenzi eșuate'),
('timeout_sesiune_minute', '60', 'INTEGER', 'Timeout sesiune utilizator în minute'),
('versiune_platforma', '1.0.0', 'STRING', 'Versiune platformă'),
('mod_mentenanta', 'false', 'BOOLEAN', 'Activare mod mentenanță'),
('pcoff_min_threshold_v', '-0.85', 'DECIMAL', 'PCoff minimum threshold [V] - if all modules below this, increase prescrisa'),
('pcoff_max_threshold_v', '-0.75', 'DECIMAL', 'PCoff maximum threshold [V] - if all modules below this, increase prescrisa'),
('pcoff_correction_gradient_v', '0.05', 'DECIMAL', 'Gradient for prescrisa correction [V] - amount to increase prescrisa by');

-- ============================================
-- DATE INIȚIALE - Utilizator Admin Implicit
-- ============================================
-- Parolă: admin123 (bcrypt hash)
-- ⚠️ SCHIMBAȚI ACEASTĂ PAROLĂ DUPĂ PRIMA AUTENTIFICARE!
INSERT INTO utilizatori (nume_utilizator, email, parola_hash, nume_complet, activ) VALUES
('admin', 'admin@spc-platform.local', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5GyYqNxnT6jK6', 'Administrator Sistem', TRUE);

-- Asignare rol Administrator utilizatorului admin
INSERT INTO utilizatori_roluri (utilizator_id, rol_id) VALUES (1, 1);

-- ============================================
-- 19. SCADA_API_KEYS - API Keys pentru Integrare SCADA
-- ============================================
CREATE TABLE scada_api_keys (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    client_name VARCHAR(255) NOT NULL COMMENT 'SCADA platform name',
    description TEXT COMMENT 'Description of the integration',
    key_hash VARCHAR(64) UNIQUE NOT NULL COMMENT 'SHA-256 hash of API key for secure storage',
    key_prefix VARCHAR(8) COMMENT 'First 8 characters of key for identification',
    
    -- Permissions (JSON object)
    permissions JSON COMMENT 'Permissions: read_devices, read_measurements, read_alarms, send_commands, read_reports',
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE COMMENT 'Whether the API key is active',
    expires_at TIMESTAMP NULL COMMENT 'Expiration timestamp (NULL = never expires)',
    
    -- Usage tracking
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by INT COMMENT 'User ID who created this key',
    last_used_at TIMESTAMP NULL COMMENT 'Last time this key was used',
    request_count INT DEFAULT 0 COMMENT 'Total number of API requests made with this key',
    
    -- Rate limiting
    rate_limit_per_minute INT DEFAULT 60 COMMENT 'Maximum requests per minute allowed',
    
    -- IP whitelist (NULL = all IPs allowed)
    allowed_ips JSON COMMENT 'Array of allowed IP addresses (NULL = all IPs allowed)',
    
    -- Contact information
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    
    -- Foreign key
    FOREIGN KEY (created_by) REFERENCES utilizatori(id) ON DELETE SET NULL,
    
    -- Indexes
    INDEX idx_scada_api_keys_hash (key_hash),
    INDEX idx_scada_api_keys_active (is_active),
    INDEX idx_scada_api_keys_client (client_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='API keys for external SCADA platform integration';

-- ============================================
-- VERIFICARE
-- ============================================
SELECT 'Baza de date inițializată cu succes!' AS status;
SELECT COUNT(*) AS total_tabele FROM information_schema.tables WHERE table_schema = 'db_cpms3';
SELECT table_name AS nume_tabel FROM information_schema.tables WHERE table_schema = 'db_cpms3' ORDER BY table_name;
