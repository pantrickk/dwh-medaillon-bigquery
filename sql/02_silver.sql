-- ====================================================================
-- SILVER VRSTVA – silver
-- Vyčištěná a typově sjednocená data ve sněhovém schématu.
-- Pořadí spouštění: číselníky a dimenze, potom faktové tabulky
-- (F_Kontrakty_a_Faktury čte z D_Zakaznik).
-- ====================================================================

-- ====================================================================
-- ČÍSELNÍKY A DIMENZE
-- ====================================================================

-- --------------------------------------------------------------------
-- D_Cas: kalendářní dimenze
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.D_Cas AS
WITH dny AS (
SELECT d AS datum
FROM UNNEST(GENERATE_DATE_ARRAY('2014-01-01', '2030-12-31', INTERVAL 1 DAY)) AS d
)
SELECT
CAST(FORMAT_DATE('%Y%m%d', datum) AS INT64) AS id_cas,
datum,
EXTRACT(YEAR FROM datum) AS rok,
EXTRACT(QUARTER FROM datum) AS kvartal,
EXTRACT(MONTH FROM datum) AS mesic,
-- České názvy měsíců
CASE EXTRACT(MONTH FROM datum)
WHEN 1 THEN 'Leden'
WHEN 2 THEN 'Únor'
WHEN 3 THEN 'Březen'
WHEN 4 THEN 'Duben'
WHEN 5 THEN 'Květen'
WHEN 6 THEN 'Červen'
WHEN 7 THEN 'Červenec'
WHEN 8 THEN 'Srpen'
WHEN 9 THEN 'Září'
WHEN 10 THEN 'Říjen'
WHEN 11 THEN 'Listopad'
WHEN 12 THEN 'Prosinec'
END AS nazev_mesice,
FORMAT_DATE('%Y-%m', datum) AS rok_mesic, -- např. '2024-05' pro snadné řazení v BI
EXTRACT(WEEK FROM datum) AS tyden_v_roku,
EXTRACT(DAY FROM datum) AS den_v_mesici,
EXTRACT(DAYOFWEEK FROM datum) AS den_v_tydnu_cislo, -- 1 = Neděle v BigQuery
-- České názvy dnů
CASE EXTRACT(DAYOFWEEK FROM datum)
WHEN 1 THEN 'Neděle'
WHEN 2 THEN 'Pondělí'
WHEN 3 THEN 'Úterý'
WHEN 4 THEN 'Středa'
WHEN 5 THEN 'Čtvrtek'
WHEN 6 THEN 'Pátek'
WHEN 7 THEN 'Sobota'
END AS nazev_dne,
-- Příznak pro víkend
CASE WHEN EXTRACT(DAYOFWEEK FROM datum) IN (1, 7) THEN TRUE ELSE FALSE END AS is_vikend
FROM dny;

ALTER TABLE silver.D_Cas
ADD PRIMARY KEY (id_cas) NOT ENFORCED;

ALTER TABLE silver.D_Cas
SET OPTIONS (description = 'Kalendářní časová dimenze pro časové řady a BI reporting (2014–2030, pokrývá všechna data ve faktech včetně budoucích splatností)');

ALTER TABLE silver.D_Cas
ALTER COLUMN id_cas SET OPTIONS (description = 'Surrogátní/přirozený časový klíč ve formátu YYYYMMDD (PK, např. 20240515)'),
ALTER COLUMN datum SET OPTIONS (description = 'Standardní kalendářní datum (DATE)'),
ALTER COLUMN rok SET OPTIONS (description = 'Kalendářní rok (např. 2024)'),
ALTER COLUMN kvartal SET OPTIONS (description = 'Kvartál/čtvrtletí roku (1-4)'),
ALTER COLUMN mesic SET OPTIONS (description = 'Číslo měsíce v roce (1-12)'),
ALTER COLUMN nazev_mesice SET OPTIONS (description = 'Český název měsíce (např. Leden, Květen)'),
ALTER COLUMN rok_mesic SET OPTIONS (description = 'Kombinace roku a měsíce ve formátu YYYY-MM pro řazení v BI'),
ALTER COLUMN tyden_v_roku SET OPTIONS (description = 'Číslo týdne v roce (1-53)'),
ALTER COLUMN den_v_mesici SET OPTIONS (description = 'Den v měsíci (1-31)'),
ALTER COLUMN den_v_tydnu_cislo SET OPTIONS (description = 'Číslo dne v týdnu podle BigQuery konvence (1 = Neděle, 2 = Pondělí, ..., 7 = Sobota)'),
ALTER COLUMN nazev_dne SET OPTIONS (description = 'Český název dne v týdnu (např. Pondělí, Neděle)'),
ALTER COLUMN is_vikend SET OPTIONS (description = 'Příznak, zda se jedná o víkendový den (TRUE = Sobota/Neděle, FALSE = Pracovní den)');

-- --------------------------------------------------------------------
-- D_Kategorie_Zakazniku: číselník kategorií zákazníků
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.D_Kategorie_Zakazniku AS
SELECT
idkat AS id_kategorie,
Nazev AS nazev_kategorie,
ROUND(CAST(Sleva AS NUMERIC), 2) AS m_sleva
FROM bronze.t_kategorie_zakazniku;

ALTER TABLE silver.D_Kategorie_Zakazniku
ADD PRIMARY KEY (id_kategorie) NOT ENFORCED;

ALTER TABLE silver.D_Kategorie_Zakazniku
SET OPTIONS (description = 'Číselník kategorií zákazníků a příslušných slevových sazeb');

ALTER TABLE silver.D_Kategorie_Zakazniku
ALTER COLUMN id_kategorie SET OPTIONS (description = 'Unikátní identifikátor kategorie zákazníka (PK)'),
ALTER COLUMN nazev_kategorie SET OPTIONS (description = 'Název kategorie (např. Malozákazník, Velkozákazník, VIP)'),
ALTER COLUMN m_sleva SET OPTIONS (description = 'Procentuální výše slevy zaokrouhlená na 2 desetinná místa (např. 0.05 = 5 %)');

-- --------------------------------------------------------------------
-- D_Kategorie_Pohybu: číselník kategorií finančních pohybů
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.D_Kategorie_Pohybu (
  id_kategorie_pohybu INT64,
  nazev_kategorie STRING
);

INSERT INTO silver.D_Kategorie_Pohybu (id_kategorie_pohybu, nazev_kategorie)
VALUES
(1, 'Najem'),
(2, 'Zdroje'),
(3, 'Mzdy'),
(4, 'Osobni'),
(5, 'Rezie'),
(6, 'Trzby'),
(7, 'Ostatni');

ALTER TABLE silver.D_Kategorie_Pohybu
ADD PRIMARY KEY (id_kategorie_pohybu) NOT ENFORCED;

ALTER TABLE silver.D_Kategorie_Pohybu
SET OPTIONS (description = 'Číselník finančních kategorií příjmů a výdajů pro Cashflow');

ALTER TABLE silver.D_Kategorie_Pohybu
ALTER COLUMN id_kategorie_pohybu SET OPTIONS (description = 'Unikátní identifikátor kategorie finančního pohybu (PK)'),
ALTER COLUMN nazev_kategorie SET OPTIONS (description = 'Název finanční kategorie (např. Najem, Mzdy, Trzby)');

-- --------------------------------------------------------------------
-- D_Typ_Pohybu: číselník typů pohybu
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.D_Typ_Pohybu AS
SELECT 1 AS id_typ_pohybu, 'Výdaj' AS nazev_typu
UNION ALL
SELECT 2 AS id_typ_pohybu, 'Příjem' AS nazev_typu;

ALTER TABLE silver.D_Typ_Pohybu
ADD PRIMARY KEY (id_typ_pohybu) NOT ENFORCED;

ALTER TABLE silver.D_Typ_Pohybu
SET OPTIONS (description = 'Číselník typů finančních pohybů (Výdaj vs. Příjem)');

ALTER TABLE silver.D_Typ_Pohybu
ALTER COLUMN id_typ_pohybu SET OPTIONS (description = 'Unikátní identifikátor typu pohybu (PK, 1 = Výdaj, 2 = Příjem)'),
ALTER COLUMN nazev_typu SET OPTIONS (description = 'Název typu finančního pohybu (Výdaj / Příjem)');

-- --------------------------------------------------------------------
-- D_Kraje: číselník krajů
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Kraje
AS SELECT
    idkraj AS id_kraj,
    Kraj AS nazev_kraje
FROM bronze.t_Kraje;

ALTER TABLE silver.D_Kraje
ADD PRIMARY KEY (id_kraj) NOT ENFORCED;

ALTER TABLE silver.D_Kraje
SET OPTIONS (description = 'Geografický číselník krajů');

ALTER TABLE silver.D_Kraje
ALTER COLUMN id_kraj SET OPTIONS (description = 'Unikátní identifikátor kraje (PK)'),
ALTER COLUMN nazev_kraje SET OPTIONS (description = 'Název kraje');

-- --------------------------------------------------------------------
-- D_Okresy: číselník okresů
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Okresy
AS SELECT
    idokres AS id_okres,
    Okres AS nazev_okresu,
    idkraj AS id_kraj
FROM bronze.t_Okresy;

ALTER TABLE silver.D_Okresy
ADD PRIMARY KEY (id_okres) NOT ENFORCED;

ALTER TABLE silver.D_Okresy
SET OPTIONS (description = 'Geografický číselník okresů navázaný na kraje');

ALTER TABLE silver.D_Okresy
ALTER COLUMN id_okres SET OPTIONS (description = 'Unikátní identifikátor okresu (PK)'),
ALTER COLUMN nazev_okresu SET OPTIONS (description = 'Název okresu'),
ALTER COLUMN id_kraj SET OPTIONS (description = 'Odkaz na kraj (FK -> D_Kraje)');

-- --------------------------------------------------------------------
-- D_PSC: číselník PSČ
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_PSC
AS SELECT
    CAST(PSC AS STRING) AS psc,
    idokres AS id_okres
FROM bronze.t_PSC;

ALTER TABLE silver.D_PSC
ADD PRIMARY KEY (psc) NOT ENFORCED;

ALTER TABLE silver.D_PSC
SET OPTIONS (description = 'Geografický číselník PSČ navázaný na okresy');

ALTER TABLE silver.D_PSC
ALTER COLUMN psc SET OPTIONS (description = 'Poštovní směrovací číslo jako přirozený klíč (Natural PK)'),
ALTER COLUMN id_okres SET OPTIONS (description = 'Odkaz na okres (FK -> D_Okresy)');

-- --------------------------------------------------------------------
-- D_Pobocky: dimenze poboček
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Pobocky
AS SELECT
    idpob AS id_pobocka,
    Nazev AS nazev_pobocky,
    CAST(PSC AS STRING) AS psc
FROM bronze.t_pobocky;

ALTER TABLE silver.D_Pobocky
ADD PRIMARY KEY (id_pobocka) NOT ENFORCED;

ALTER TABLE silver.D_Pobocky
SET OPTIONS (description = 'Dimenze poboček');

ALTER TABLE silver.D_Pobocky
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Unikátní identifikátor pobočky (PK)'),
ALTER COLUMN nazev_pobocky SET OPTIONS (description = 'Název pobočky'),
ALTER COLUMN psc SET OPTIONS (description = 'Poštovní směrovací číslo pobočky (FK -> D_PSC)');

-- --------------------------------------------------------------------
-- D_Funkce: číselník pracovních funkcí
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Funkce
AS SELECT
    idfce AS id_funkce,
    Nazev AS nazev_funkce,
    Ohodnoceni AS ohodnoceni
FROM bronze.t_funkce;

ALTER TABLE silver.D_Funkce
ADD PRIMARY KEY (id_funkce) NOT ENFORCED;

ALTER TABLE silver.D_Funkce
SET OPTIONS (description = 'Číselník pracovních pozic a funkcí zaměstnanců');

ALTER TABLE silver.D_Funkce
ALTER COLUMN id_funkce SET OPTIONS (description = 'Unikátní identifikátor pracovní funkce (PK)'),
ALTER COLUMN nazev_funkce SET OPTIONS (description = 'Název pozice (např. Obchodník, Sekretářka)'),
ALTER COLUMN ohodnoceni SET OPTIONS (description = 'Ohodnocení funkce (doporučené bonusy) v CZK');

-- --------------------------------------------------------------------
-- D_Zamestnanci: dimenze zaměstnanců
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Zamestnanci
AS SELECT
    idzam AS id_zamestnanec,
    Jmeno AS jmeno,
    Prijmeni AS prijmeni,
    idfce AS id_funkce,
    idpob AS id_pobocka,
    CAST(Plat AS NUMERIC) AS m_plat
FROM bronze.t_zamestnanci;

ALTER TABLE silver.D_Zamestnanci
ADD PRIMARY KEY (id_zamestnanec) NOT ENFORCED;

ALTER TABLE silver.D_Zamestnanci
SET OPTIONS (description = 'Dimenze zaměstnanců');

ALTER TABLE silver.D_Zamestnanci
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Unikátní identifikátor zaměstnance (PK)'),
ALTER COLUMN jmeno SET OPTIONS (description = 'Jméno zaměstnance'),
ALTER COLUMN prijmeni SET OPTIONS (description = 'Příjmení zaměstnance'),
ALTER COLUMN id_funkce SET OPTIONS (description = 'Odkaz na funkci/pozici zaměstnance (FK -> D_Funkce)'),
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Odkaz na domovskou pobočku zaměstnance (FK -> D_Pobocky)'),
ALTER COLUMN m_plat SET OPTIONS (description = 'Základní platový výměr zaměstnance v CZK');

-- --------------------------------------------------------------------
-- D_Typy_Zdroju: číselník typů zdrojů
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Typy_Zdroju
AS SELECT
    idtypzdroje AS id_typ_zdroje,
    Typ AS nazev_typu
FROM bronze.t_typy_zdroju;

ALTER TABLE silver.D_Typy_Zdroju
ADD PRIMARY KEY (id_typ_zdroje) NOT ENFORCED;

ALTER TABLE silver.D_Typy_Zdroju
SET OPTIONS (description = 'Číselník typů zdrojů (stroje a pracovní čety)');

ALTER TABLE silver.D_Typy_Zdroju
ALTER COLUMN id_typ_zdroje SET OPTIONS (description = 'Unikátní identifikátor typu zdroje (PK)'),
ALTER COLUMN nazev_typu SET OPTIONS (description = 'Název typu zdroje (např. Speciální stroj, Pracovní četa - malíři)');

-- --------------------------------------------------------------------
-- D_Zdroje: dimenze zdrojů (stroje a čety)
-- --------------------------------------------------------------------
CREATE OR REPLACE TABLE silver.D_Zdroje 
AS SELECT
    idzdroje AS id_zdroj,
    Nazev AS nazev_zdroje,
    idtypzdroje AS id_typ_zdroje
FROM bronze.t_zdroje;

ALTER TABLE silver.D_Zdroje
ADD PRIMARY KEY (id_zdroj) NOT ENFORCED;

ALTER TABLE silver.D_Zdroje
SET OPTIONS (description = 'Dimenze konkrétních zdrojů (strojů a čet)');

ALTER TABLE silver.D_Zdroje
ALTER COLUMN id_zdroj SET OPTIONS (description = 'Unikátní identifikátor zdroje (PK)'),
ALTER COLUMN nazev_zdroje SET OPTIONS (description = 'Název nebo označení zdroje/stroje'),
ALTER COLUMN id_typ_zdroje SET OPTIONS (description = 'Odkaz na typ zdroje (FK -> D_Typy_Zdroju)');

-- --------------------------------------------------------------------
-- D_Zakaznik: dimenze zákazníků (odvozená ze tří snímků)
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.D_Zakaznik AS
WITH stavy AS (
  -- Všechny tři stavy zákazníků pod sebou, každý s datem stavu
  SELECT idzak, idzam, idkat, ICO, Nazev, Ulice, Mesto, PSC, Kredit,
         DATE '1900-01-01' AS datum_stavu
  FROM bronze.t_zakaznici
  UNION ALL
  SELECT idzak, idzam, idkat, ICO, Nazev, Ulice, Mesto, PSC, Kredit,
         DATE '2025-12-31'
  FROM `bronze.t_zakaznici_2025-12-31`
  UNION ALL
  SELECT idzak, idzam, idkat, ICO, Nazev, Ulice, Mesto, PSC, Kredit,
         DATE '2026-08-31'
  FROM `bronze.t_zakaznici_2026-08-31`
),
platnost AS (
  -- První a poslední výskyt zákazníka
  SELECT idzak,
         MIN(datum_stavu) AS prvni_vyskyt,
         MAX(datum_stavu) AS posledni_vyskyt
  FROM stavy
  GROUP BY idzak
),
posledni_stav AS (
  -- Atributy z posledního stavu, kde zákazník byl
  SELECT *
  FROM stavy
  WHERE TRUE
  QUALIFY ROW_NUMBER() OVER (PARTITION BY idzak ORDER BY datum_stavu DESC) = 1
)
SELECT
  z.idzak  AS id_zakaznik,
  z.idzam  AS id_zamestnanec,
  z.idkat  AS id_kat,
  z.ICO    AS ico,
  z.Nazev  AS nazev,
  z.Ulice  AS ulice,
  z.Mesto  AS mesto,
  z.PSC    AS psc,
  z.Kredit AS kredit,
  p.prvni_vyskyt AS platny_od,
  CASE p.posledni_vyskyt
    WHEN DATE '2026-08-31' THEN DATE '9999-12-31'
    WHEN DATE '2025-12-31' THEN DATE '2026-08-30'
    ELSE DATE '2025-12-30'
  END AS platny_do,
  p.posledni_vyskyt = DATE '2026-08-31' AS is_aktivni
FROM posledni_stav z
JOIN platnost p ON z.idzak = p.idzak;

ALTER TABLE silver.D_Zakaznik
ADD PRIMARY KEY (id_zakaznik) NOT ENFORCED;

ALTER TABLE silver.D_Zakaznik
SET OPTIONS (description = 'Dimenze zákazníků. Jeden řádek na zákazníka s obdobím platnosti odvozeným ze snímků (t_zakaznici, 2025-12-31, 2026-08-31).');

ALTER TABLE silver.D_Zakaznik
ALTER COLUMN id_zakaznik SET OPTIONS (description = 'Unikátní identifikátor zákazníka ze zdrojového systému (PK)'),
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Odkaz na pečujícího obchodníka/zaměstnance (FK -> D_Zamestnanci)'),
ALTER COLUMN id_kat SET OPTIONS (description = 'Odkaz na kategorii zákazníka (FK -> D_Kategorie_Zakazniku)'),
ALTER COLUMN ico SET OPTIONS (description = 'Identifikační číslo osoby (IČO) zákazníka'),
ALTER COLUMN nazev SET OPTIONS (description = 'Název firmy nebo jméno zákazníka'),
ALTER COLUMN ulice SET OPTIONS (description = 'Ulice a číslo popisné sídla zákazníka'),
ALTER COLUMN mesto SET OPTIONS (description = 'Město/obec sídla zákazníka'),
ALTER COLUMN psc SET OPTIONS (description = 'Poštovní směrovací číslo (FK -> D_PSC)'),
ALTER COLUMN kredit SET OPTIONS (description = 'Schválený kreditní limit zákazníka pro odběr na fakturu'),
ALTER COLUMN platny_od SET OPTIONS (description = 'Datum prvního snímku, ve kterém se zákazník objevil. 1900-01-01 = zákazník z výchozí tabulky t_zakaznici (přesné datum vzniku není známo)'),
ALTER COLUMN platny_do SET OPTIONS (description = 'Den před prvním snímkem, ve kterém zákazník chybí (konec spolupráce). 9999-12-31 = aktivní zákazník'),
ALTER COLUMN is_aktivni SET OPTIONS (description = 'Odvozený příznak: TRUE, pokud je zákazník v posledním snímku 2026-08-31 (platny_do = 9999-12-31)');

-- ====================================================================
-- FAKTOVÉ TABULKY
-- ====================================================================

-- --------------------------------------------------------------------
-- F_Cashflow: všechny peněžní pohyby (12 zdrojových tabulek, plán i skutečnost)
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE silver.F_Cashflow AS

-- 1. NÁJEM PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,idpob AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,1 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_vydaje_najem_plan`

UNION ALL

-- 1. NÁJEM SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,idpob AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,1 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_vydaje_najem_skutecnost`

UNION ALL

-- 2. MZDY PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,idzam AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,3 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_vydaje_mzdy_plan`

UNION ALL

-- 2. MZDY SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,idzam AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,3 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_vydaje_mzdy_skutecnost`

UNION ALL

-- 3. OSOBNÍ PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,idzam AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,4 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_vydaje_osobni_plan`

UNION ALL

-- 3. OSOBNÍ SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,idzam AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,4 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_vydaje_osobni_skutecnost`

UNION ALL

-- 4. REŽIE PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,idpob AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,5 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_vydaje_rezie_plan`

UNION ALL

-- 4. REŽIE SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,idpob AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,5 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_vydaje_rezie_skutecnost`

UNION ALL

-- 5. ZDROJE PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,idzdroje AS id_zdroje
  ,2 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_vydaje_zdroje_plan`

UNION ALL

-- 5. ZDROJE SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,CAST(NULL AS INT64) AS id_kontraktu
  ,idzdroje AS id_zdroje
  ,2 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,1 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_vydaje_zdroje_skutecnost`

UNION ALL

-- 6. PŘÍJMY PLAN
SELECT 
  idpol AS id_cashflow
  ,CAST(NULL AS INT64) AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,idkontr AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,6 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,2 AS id_typ_pohybu
  ,castka AS m_castka
  ,TRUE AS is_plan
FROM `bronze.t_prijmy_plan`

UNION ALL

-- 6. PŘÍJMY SKUTEČNOST
SELECT 
  idpol AS id_cashflow
  ,idrefpol AS id_ref_pol
  ,CAST(NULL AS INT64) AS id_pobocka
  ,CAST(NULL AS INT64) AS id_zamestnanec
  ,idkontr AS id_kontraktu
  ,CAST(NULL AS INT64) AS id_zdroje
  ,6 AS id_kategorie_pohybu
  ,CAST(FORMAT_TIMESTAMP('%Y%m%d', TIMESTAMP(datum)) AS INT64) AS id_cas  
  ,2 AS id_typ_pohybu
  ,castka AS m_castka
  ,FALSE AS is_plan
FROM `bronze.t_prijmy_skutecnost`;

ALTER TABLE silver.F_Cashflow
ADD PRIMARY KEY (id_cashflow) NOT ENFORCED;

ALTER TABLE silver.F_Cashflow
SET OPTIONS (description = 'Faktová tabulka finančních pohybů (příjmy i výdaje, plán vs. skutečnost)');

ALTER TABLE silver.F_Cashflow
ALTER COLUMN id_cashflow SET OPTIONS (description = 'Unikátní identifikátor řádku finančního pohybu (PK)'),
ALTER COLUMN id_ref_pol SET OPTIONS (description = 'Odkaz ze skutečné položky na odpovídající plánovanou položku (FK -> F_Cashflow.id_cashflow)'),
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Odkaz na pobočku, ke které se výdaj/příjem váže (FK -> D_Pobocky)'),
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Odkaz na zaměstnance u mzdových/osobních výdajů (FK -> D_Zamestnanci)'),
ALTER COLUMN id_kontraktu SET OPTIONS (description = 'Odkaz na zakázku/kontrakt u příjmů (FK -> F_Kontrakty_a_Faktury)'),
ALTER COLUMN id_zdroje SET OPTIONS (description = 'Odkaz na zdroj/stroj u nákladů na zdroje (FK -> D_Zdroje)'),
ALTER COLUMN id_kategorie_pohybu SET OPTIONS (description = 'Odkaz na kategorii finančního pohybu (FK -> D_Kategorie_Pohybu)'),
ALTER COLUMN id_cas SET OPTIONS (description = 'Odkaz na datum realizace/plánu ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_typ_pohybu SET OPTIONS (description = 'Odkaz na typ pohybu (FK -> D_Typ_Pohybu, 1 = Výdaj, 2 = Příjem)'),
ALTER COLUMN m_castka SET OPTIONS (description = 'Finanční částka položky v CZK'),
ALTER COLUMN is_plan SET OPTIONS (description = 'Příznak, zda se jedná o plánovaný pohyb (TRUE = Plán, FALSE = Skutečnost)');

-- --------------------------------------------------------------------
-- F_Kontrakty_a_Faktury: kontrakty s fakturou a hodnocením (1 řádek = 1 kontrakt)
-- --------------------------------------------------------------------

CREATE OR REPLACE TABLE `silver.F_Kontrakty_a_Faktury`
AS
SELECT
  k.idkontr AS id_kontrakt,
  f.idfaktury AS cislo_faktury,
  k.idzak AS id_zakaznik,
  z.id_zamestnanec AS id_zamestnanec,
  k.idzdroje AS id_zdroj,
  -- Časové atributy kontraktu
  CAST(FORMAT_TIMESTAMP('%Y%m%d', k.datumod) AS INT64) AS id_cas_kontrakt_od,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', k.datumdo) AS INT64) AS id_cas_kontrakt_do,
  -- Datumové atributy faktury
  -- Pozor: ve zdroji jsou sloupce dat_vystaveni a dat_splatnosti prohozené,
  -- proto je zde vědomě mapujeme obráceně (oprava chyby zdroje)
  CAST(FORMAT_TIMESTAMP('%Y%m%d', f.dat_vystaveni) AS INT64) AS id_faktura_splatnost,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', f.dat_splatnosti) AS INT64) AS id_faktura_vystaveni,
  CAST(FORMAT_TIMESTAMP('%Y%m%d', f.dat_zaplaceno) AS INT64) AS id_faktura_zaplaceno,
  CAST(k.cena_celkem AS NUMERIC) AS m_cena_kontraktu,
  CAST(k.naklady_celkem AS NUMERIC) AS m_naklady_kontraktu,
  CAST(f.cena_celkem AS NUMERIC) AS m_cena_faktury,
  -- Logické příznaky
  CASE WHEN f.idfaktury IS NOT NULL THEN TRUE ELSE FALSE END AS is_fakturovane,
  CASE WHEN f.dat_zaplaceno IS NOT NULL THEN TRUE ELSE FALSE END AS is_zaplaceno,
  f.idzaplaceno AS id_stav_uhrady,
  CAST(s.NPS AS INT64) AS nps
FROM `bronze.t_kontrakty` AS k
LEFT JOIN `silver.D_Zakaznik` AS z
  ON k.idzak = z.id_zakaznik
LEFT JOIN `bronze.t_faktury_vydane` AS f
  ON k.idkontr = f.idkontr
LEFT JOIN `bronze.t_spokojenost` AS s
  ON k.idkontr = s.idkontr
WHERE k.idkontr IS NOT NULL;

ALTER TABLE silver.F_Kontrakty_a_Faktury
ADD PRIMARY KEY (id_kontrakt) NOT ENFORCED;

ALTER TABLE silver.F_Kontrakty_a_Faktury
SET OPTIONS (description = 'Faktová tabulka zakázek (kontraktů), vystavených faktur a spokojenosti zákazníků');

ALTER TABLE silver.F_Kontrakty_a_Faktury
ALTER COLUMN id_kontrakt SET OPTIONS (description = 'Unikátní identifikátor kontraktu/zakázky (PK)'),
ALTER COLUMN cislo_faktury SET OPTIONS (description = 'Číslo vystavené faktury navázané na kontrakt'),
ALTER COLUMN id_zakaznik SET OPTIONS (description = 'Odkaz na zákazníka (FK -> D_Zakaznik)'),
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Odkaz na pečujícího obchodníka (FK -> D_Zamestnanci)'),
ALTER COLUMN id_zdroj SET OPTIONS (description = 'Odkaz na alokovaný zdroj/stroj (FK -> D_Zdroje)'),
ALTER COLUMN id_cas_kontrakt_od SET OPTIONS (description = 'Datum zahájení kontraktu ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_cas_kontrakt_do SET OPTIONS (description = 'Datum ukončení kontraktu ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_faktura_splatnost SET OPTIONS (description = 'Datum splatnosti faktury YYYYMMDD (FK -> D_Cas); ve zdroji uloženo ve sloupci dat_vystaveni (názvy sloupců ve zdroji jsou prohozené)'),
ALTER COLUMN id_faktura_vystaveni SET OPTIONS (description = 'Datum vystavení faktury YYYYMMDD (FK -> D_Cas); ve zdroji uloženo ve sloupci dat_splatnosti (názvy sloupců ve zdroji jsou prohozené)'),
ALTER COLUMN id_faktura_zaplaceno SET OPTIONS (description = 'Datum skutečné úhrady faktury YYYYMMDD (FK -> D_Cas); NULL = neuhrazeno'),
ALTER COLUMN m_cena_kontraktu SET OPTIONS (description = 'Smluvní celková cena kontraktu bez DPH v CZK'),
ALTER COLUMN m_naklady_kontraktu SET OPTIONS (description = 'Plánované celkové náklady na realizaci kontraktu v CZK'),
ALTER COLUMN m_cena_faktury SET OPTIONS (description = 'Fakturovaná částka na dané faktuře v CZK'),
ALTER COLUMN is_fakturovane SET OPTIONS (description = 'Příznak, zda k zakázce existuje záznam faktury (TRUE / FALSE)'),
ALTER COLUMN is_zaplaceno SET OPTIONS (description = 'Příznak, zda má faktura datum úhrady (TRUE / FALSE)'),
ALTER COLUMN id_stav_uhrady SET OPTIONS (description = 'Stav úhrady faktury dle zdroje (pomZaplaceno): 1 = Ano, 2 = Ne, 0 = Není relevantní (zrušený kontrakt bez skutečné faktury)'),
ALTER COLUMN nps SET OPTIONS (description = 'Hodnocení spokojenosti zákazníka s kontraktem na škále 0-10 (ve zdroji označeno NPS, nejde o index NPS)');
