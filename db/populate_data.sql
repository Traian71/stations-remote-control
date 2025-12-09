-- ============================================
-- SCRIPT POPULARE DATE - Platformă SPC V4
-- Sistem Monitorizare Cabine Protecție Catodică
-- ============================================
-- Acest script populează toate tabelele cu date de exemplu
-- Suportă ambele tipuri de dispozitive:
-- - CABINA (ID 1001-4999): Module control cu injecție
-- - MODUL_MASURA (ID 5001-8999): Module măsură (24 măsurători/zi)
-- ============================================

USE db_cpms3;

-- Backend-ul folosește UTC, deci lăsăm timezone-ul implicit (UTC)

-- ============================================
-- 1. POPULARE CABINE (Dispozitive Unificate)
-- ============================================
-- Coordonate distribuite pe teritoriul României pentru vizibilitate mai bună pe hartă
-- tip_dispozitiv se auto-detectează din ID range

-- Module Control (CABINA) - ID 1001-4999
INSERT INTO cabine (id_cabina, traseu, locatie, serie_fabricatie_cabina, serie_fabricatie_modul, lot, data_punere_functiune, longitudine, latitudine, activa, status) VALUES
(1001, 'București-Ploiești', 'Buftea Conductă 1', 'C1001', 'M1001', 'L2023-01', '2023-01-15', 26.0823456, 44.4378901, TRUE, 'ONLINE'),
(1002, 'București-Ploiești', 'Otopeni Conductă 2', 'C1002', 'M1002', 'L2023-01', '2023-01-20', 26.1534567, 44.5489012, TRUE, 'ONLINE'),
(1003, 'Cluj-Napoca', 'Florești Conductă 1', 'C1003', 'M1003', 'L2023-02', '2023-02-10', 23.5845678, 46.7490123, TRUE, 'ONLINE'),
(1004, 'Ploiești-Brașov', 'Câmpina Conductă 1', 'C1004', 'M1004', 'L2023-02', '2023-02-15', 25.7323456, 45.1334567, TRUE, 'ONLINE'),
(1005, 'Timișoara-Arad', 'Arad Conductă 2', 'C1005', 'M1005', 'L2023-03', '2023-03-01', 21.3134567, 46.1845678, TRUE, 'ONLINE'),
(1006, 'Brașov-Sibiu', 'Făgăraș Conductă 1', 'C1006', 'M1006', 'L2023-03', '2023-03-15', 24.9736543, 45.8426789, TRUE, 'ONLINE'),
(1007, 'Craiova-Drobeta', 'Craiova Conductă 1', 'C1007', 'M1007', 'L2023-04', '2023-04-01', 23.8017654, 44.3193456, TRUE, 'ONLINE'),
(1008, 'București-Constanța', 'Fetești Conductă 1', 'C1008', 'M1008', 'L2023-04', '2023-04-10', 27.8334567, 44.3896543, TRUE, 'ONLINE'),
(1009, 'Iași-Bacău', 'Pașcani Conductă 2', 'C1009', 'M1009', 'L2023-05', '2023-05-01', 26.7145678, 47.2445678, TRUE, 'ONLINE'),
(1010, 'București-Constanța', 'Constanța Conductă 1', 'C1010', 'M1010', 'L2023-05', '2023-05-15', 28.6365432, 44.1756789, TRUE, 'ONLINE');

-- Module Măsură (MODUL_MASURA) - ID 5001-8999
INSERT INTO cabine (id_cabina, traseu, locatie, serie_fabricatie_modul, lot, data_punere_functiune, longitudine, latitudine, activa, status) VALUES
(5001, 'București-Ploiești', 'Buftea Priza 1', 'MM5001', 'L2023-06', '2023-06-01', 26.0923456, 44.4478901, TRUE, 'ONLINE'),
(5002, 'Cluj-Napoca', 'Florești Priza 1', 'MM5002', 'L2023-06', '2023-06-10', 23.5945678, 46.7590123, TRUE, 'ONLINE'),
(5003, 'Timișoara-Arad', 'Arad Priza 1', 'MM5003', 'L2023-07', '2023-07-01', 21.3234567, 46.1945678, TRUE, 'ONLINE'),
(5004, 'Craiova-Drobeta', 'Craiova Priza 1', 'MM5004', 'L2023-07', '2023-07-15', 23.8117654, 44.3293456, TRUE, 'ONLINE'),
(5005, 'Iași-Bacău', 'Pașcani Priza 1', 'MM5005', 'L2023-08', '2023-08-01', 26.7245678, 47.2545678, TRUE, 'ONLINE');

-- ============================================
-- 2. POPULARE DATE_CONFIGURARE_CABINE (Tabelul 2 - doar pentru CABINA)
-- ============================================
-- Doar pentru module control (ID 1001-4999)
INSERT INTO date_configurare_cabine (
    traseu, locatie, id_cabina, tip_injectie, 
    ora_start_masura_pcoff, interval_masura_pcoff_h, durata_off_masura_pcoff_s,
    ora_start_ciclu_intensiv, durata_on_ciclu_intensiv_s, durata_off_ciclu_intensiv_s, durata_ciclu_intensiv_min,
    prescrisa_pc_v, mod_transmisie, tip_pc,
    longitudine, latitudine,
    serie_fabricatie_cabina, serie_fabricatie_modul, lot, data_punere_functiune
) VALUES
-- tip_injectie: 0=NONE, 1=NORMAL/ON, 2=OFF, 3=INTENSIVE | mod_transmisie: 0=PROGRAMAT, 1=CURENT
-- tip_pc: 0=PCoff (reglare automată activă), 1=PCon (fără reglare automată)
('București-Ploiești', 'Buftea Conductă 1', 1001, 1, '02:00:00', 24, 4, '14:00:00', 10, 4, 120, -0.850, 0, 0, 26.0823456, 44.4378901, 'C1001', 'M1001', 'L2023-01', '2023-01-15'),
('București-Ploiești', 'Otopeni Conductă 2', 1002, 3, '03:00:00', 24, 4, '15:00:00', 10, 4, 90, -0.900, 0, 1, 26.1534567, 44.5489012, 'C1002', 'M1002', 'L2023-01', '2023-01-20'),
('Cluj-Napoca', 'Florești Conductă 1', 1003, 1, '02:30:00', 24, 4, '14:30:00', 10, 4, 100, -0.875, 1, 0, 23.5845678, 46.7490123, 'C1003', 'M1003', 'L2023-02', '2023-02-10'),
('Ploiești-Brașov', 'Câmpina Conductă 1', 1004, 1, '02:00:00', 24, 4, '14:00:00', 10, 4, 110, -0.920, 0, 1, 25.7323456, 45.1334567, 'C1004', 'M1004', 'L2023-02', '2023-02-15'),
('Timișoara-Arad', 'Arad Conductă 2', 1005, 3, '03:00:00', 24, 4, '15:00:00', 10, 4, 95, -0.880, 0, 0, 21.3134567, 46.1845678, 'C1005', 'M1005', 'L2023-03', '2023-03-01'),
('Brașov-Sibiu', 'Făgăraș Conductă 1', 1006, 1, '02:00:00', 24, 4, '14:00:00', 10, 4, 105, -0.890, 0, 1, 24.9736543, 45.8426789, 'C1006', 'M1006', 'L2023-03', '2023-03-15'),
('Craiova-Drobeta', 'Craiova Conductă 1', 1007, 1, '02:30:00', 24, 4, '14:30:00', 10, 4, 115, -0.910, 1, 0, 23.8017654, 44.3193456, 'C1007', 'M1007', 'L2023-04', '2023-04-01'),
('București-Constanța', 'Fetești Conductă 1', 1008, 3, '03:00:00', 24, 4, '15:00:00', 10, 4, 100, -0.860, 0, 1, 27.8334567, 44.3896543, 'C1008', 'M1008', 'L2023-04', '2023-04-10'),
('Iași-Bacău', 'Pașcani Conductă 2', 1009, 1, '02:00:00', 24, 4, '14:00:00', 10, 4, 120, -0.895, 0, 0, 26.7145678, 47.2445678, 'C1009', 'M1009', 'L2023-05', '2023-05-01'),
('București-Constanța', 'Constanța Conductă 1', 1010, 1, '02:30:00', 24, 4, '14:30:00', 10, 4, 110, -0.870, 0, 1, 28.6365432, 44.1756789, 'C1010', 'M1010', 'L2023-05', '2023-05-15');

-- ============================================
-- 2b. POPULARE DATE_CONFIGURARE_MODULE_MASURA (Tabelul 2 - doar pentru MODUL_MASURA)
-- ============================================
-- Doar pentru module măsură (ID 5001-8999)
INSERT INTO date_configurare_module_masura (
    traseu, locatie, id_cabina,
    ora_start_masura_pcoff, interval_masura_pcoff_h, durata_off_masura_pcoff_s, ora_transmisie_date,
    longitudine, latitudine,
    serie_fabricatie, lot, data_punere_functiune
) VALUES
('București-Ploiești', 'Buftea Priza 1', 5001, '02:00:00', 1, 4, '08:00:00', 26.0923456, 44.4478901, 'MM5001', 'L2023-06', '2023-06-01'),
('Cluj-Napoca', 'Florești Priza 1', 5002, '02:00:00', 1, 4, '08:00:00', 23.5945678, 46.7590123, 'MM5002', 'L2023-06', '2023-06-10'),
('Timișoara-Arad', 'Arad Priza 1', 5003, '02:00:00', 1, 4, '08:00:00', 21.3234567, 46.1945678, 'MM5003', 'L2023-07', '2023-07-01'),
('Craiova-Drobeta', 'Craiova Priza 1', 5004, '02:00:00', 1, 4, '08:00:00', 23.8117654, 44.3293456, 'MM5004', 'L2023-07', '2023-07-15'),
('Iași-Bacău', 'Pașcani Priza 1', 5005, '02:00:00', 1, 4, '08:00:00', 26.7245678, 47.2545678, 'MM5005', 'L2023-08', '2023-08-01');

-- ============================================
-- 3. POPULARE LIMITE_SEMNALIZARI (Tabelul 3 - doar pentru CABINA)
-- ============================================
-- Doar pentru module control (ID 1001-4999)
INSERT INTO limite_semnalizari (
    traseu, locatie, id_cabina,
    uinj_h_v, uinj_l_v, iinj_h_a, iinj_l_a,
    pcon_dc_h_v, pcon_dc_l_v, pcon_ac_h_v,
    pcoff_h_v, pcoff_l_v,
    mod_transmisie, acces,
    baterie_l_v,
    temperatura_h_c, temperatura_l_c,
    putere_gsm_l_dbm, putere_gps_l_dbm
) VALUES
-- mod_transmisie: 0=PROGRAMAT, 1=CURENT | acces: 0=PERMIS, 1=INTERZIS
('București-Ploiești', 'Buftea Conductă 1', 1001, 15.0, 10.0, 5.0, 1.0, -0.700, -1.000, 0.500, -0.750, -0.950, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('București-Ploiești', 'Otopeni Conductă 2', 1002, 15.0, 10.0, 5.0, 1.0, -0.750, -1.050, 0.500, -0.800, -1.000, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Cluj-Napoca', 'Florești Conductă 1', 1003, 15.0, 10.0, 5.0, 1.0, -0.725, -1.025, 0.500, -0.775, -0.975, 1, 1, 11.5, 60.0, -10.0, -90.0, -100.0),
('Ploiești-Brașov', 'Câmpina Conductă 1', 1004, 15.0, 10.0, 5.0, 1.0, -0.770, -1.070, 0.500, -0.820, -1.020, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Timișoara-Arad', 'Arad Conductă 2', 1005, 15.0, 10.0, 5.0, 1.0, -0.730, -1.030, 0.500, -0.780, -0.980, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Brașov-Sibiu', 'Făgăraș Conductă 1', 1006, 15.0, 10.0, 5.0, 1.0, -0.740, -1.040, 0.500, -0.790, -0.990, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Craiova-Drobeta', 'Craiova Conductă 1', 1007, 15.0, 10.0, 5.0, 1.0, -0.760, -1.060, 0.500, -0.810, -1.010, 1, 1, 11.5, 60.0, -10.0, -90.0, -100.0),
('București-Constanța', 'Fetești Conductă 1', 1008, 15.0, 10.0, 5.0, 1.0, -0.710, -1.010, 0.500, -0.760, -0.960, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Iași-Bacău', 'Pașcani Conductă 2', 1009, 15.0, 10.0, 5.0, 1.0, -0.745, -1.045, 0.500, -0.795, -0.995, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('București-Constanța', 'Constanța Conductă 1', 1010, 15.0, 10.0, 5.0, 1.0, -0.720, -1.020, 0.500, -0.770, -0.970, 0, 0, 11.5, 60.0, -10.0, -90.0, -100.0);

-- ============================================
-- 3b. POPULARE LIMITE_SEMNALIZARI_MASURA (Tabelul 3 - doar pentru MODUL_MASURA)
-- ============================================
-- Doar pentru module măsură (ID 5001-8999)
-- Nu au limite pentru Uinj/Iinj (nu au injecție)
INSERT INTO limite_semnalizari_masura (
    traseu, locatie, id_cabina,
    pcon_dc_h_v, pcon_dc_l_v,
    pcoff_h_v, pcoff_l_v,
    acces,
    baterie_l_v,
    temperatura_h_c, temperatura_l_c,
    putere_gsm_l_dbm, putere_gps_l_dbm
) VALUES
-- acces: 0=PERMIS, 1=INTERZIS
('București-Ploiești', 'Buftea Priza 1', 5001, -0.700, -1.000, -0.750, -0.950, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Cluj-Napoca', 'Florești Priza 1', 5002, -0.725, -1.025, -0.775, -0.975, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Timișoara-Arad', 'Arad Priza 1', 5003, -0.730, -1.030, -0.780, -0.980, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Craiova-Drobeta', 'Craiova Priza 1', 5004, -0.760, -1.060, -0.810, -1.010, 0, 11.5, 60.0, -10.0, -90.0, -100.0),
('Iași-Bacău', 'Pașcani Priza 1', 5005, -0.745, -1.045, -0.795, -0.995, 0, 11.5, 60.0, -10.0, -90.0, -100.0);
