-- ====================================================================
-- GOLD VRSTVA – gold
-- Denormalizované dimenze a datové marty (hvězdicové schéma) pro reporting.
-- Pořadí spouštění: dimenze, F_Cashflow_Mart, F_Kontrakty_Mart,
-- F_Cashflow_Odhad (čte z F_Cashflow_Mart).
-- ====================================================================

-- ====================================================================
-- DENORMALIZOVANÉ DIMENZE
-- ====================================================================

-- A. ZÁKAZNÍCI (Zákazník + Kategorie + Geografie)
CREATE OR REPLACE TABLE gold.D_Zakaznici AS
SELECT
  z.id_zakaznik,
  z.nazev AS nazev_zakaznika,
  z.ico,
  z.kredit,
  z.is_aktivni AS je_aktivny_zakaznik,
  kz.nazev_kategorie AS kategoria_zakaznika,
  kz.m_sleva AS sleva_pct,
  z.psc,
  COALESCE(o.nazev_okresu, 'Zahraničí / neuvedeno') AS nazev_okresu,
  COALESCE(k.nazev_kraje,  'Zahraničí / neuvedeno') AS nazev_kraje,
  z.platny_od,
  z.platny_do
FROM silver.D_Zakaznik z
LEFT JOIN silver.D_Kategorie_Zakazniku kz
  ON CAST(z.id_kat AS INT64) = CAST(kz.id_kategorie AS INT64)
LEFT JOIN silver.D_PSC p
  ON CAST(z.psc AS STRING) = CAST(p.psc AS STRING)
LEFT JOIN silver.D_Okresy o
  ON CAST(p.id_okres AS INT64) = CAST(o.id_okres AS INT64)
LEFT JOIN silver.D_Kraje k
  ON CAST(o.id_kraj AS INT64) = CAST(k.id_kraj AS INT64);

ALTER TABLE gold.D_Zakaznici ADD PRIMARY KEY (id_zakaznik) NOT ENFORCED;

ALTER TABLE gold.D_Zakaznici
SET OPTIONS (description = 'Denormalizovaná dimenze zákazníků spojující základní údaje, kategorii slevy a kompletní geografii');

ALTER TABLE gold.D_Zakaznici
ALTER COLUMN id_zakaznik SET OPTIONS (description = 'Unikátní identifikátor zákazníka (PK)'),
ALTER COLUMN nazev_zakaznika SET OPTIONS (description = 'Název firmy nebo jméno zákazníka'),
ALTER COLUMN ico SET OPTIONS (description = 'Identifikační číslo osoby (IČO)'),
ALTER COLUMN kredit SET OPTIONS (description = 'Schválený kreditní limit pro odběr na fakturu v CZK/EUR'),
ALTER COLUMN je_aktivny_zakaznik SET OPTIONS (description = 'Příznak aktivity zákazníka (TRUE = aktivní, FALSE = neaktivní)'),
ALTER COLUMN kategoria_zakaznika SET OPTIONS (description = 'Název kategorie zákazníka (např. VIP, Velkozákazník)'),
ALTER COLUMN sleva_pct SET OPTIONS (description = 'Slevová sazba v procentech přiznaná dané kategorii'),
ALTER COLUMN psc SET OPTIONS (description = 'Poštovní směrovací číslo sídla zákazníka'),
ALTER COLUMN nazev_okresu SET OPTIONS (description = 'Název okresu sídla zákazníka'),
ALTER COLUMN nazev_kraje SET OPTIONS (description = 'Název kraje sídla zákazníka'),
ALTER COLUMN platny_od SET OPTIONS (description = 'Datum prvního snímku, ve kterém se zákazník objevil (1900-01-01 = výchozí stav t_zakaznici)'),
ALTER COLUMN platny_do SET OPTIONS (description = 'Konec spolupráce (den před snímkem, kde zákazník chybí); 9999-12-31 = aktivní');


-- B. POBOČKY (Pobočka + Geografie)
CREATE OR REPLACE TABLE gold.D_Pobocky AS
SELECT 
  p.id_pobocka,
  p.nazev_pobocky,
  p.psc,
  o.nazev_okresu,
  k.nazev_kraje
FROM silver.D_Pobocky p
LEFT JOIN silver.D_PSC psc 
  ON CAST(p.psc AS STRING) = CAST(psc.psc AS STRING)
LEFT JOIN silver.D_Okresy o 
  ON CAST(psc.id_okres AS INT64) = CAST(o.id_okres AS INT64)
LEFT JOIN silver.D_Kraje k 
  ON CAST(o.id_kraj AS INT64) = CAST(k.id_kraj AS INT64);

ALTER TABLE gold.D_Pobocky ADD PRIMARY KEY (id_pobocka) NOT ENFORCED;

ALTER TABLE gold.D_Pobocky
SET OPTIONS (description = 'Denormalizovaná dimenze poboček společnosti spojující pobočku s kompletní geografickou strukturou');

ALTER TABLE gold.D_Pobocky
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Unikátní identifikátor pobočky (PK)'),
ALTER COLUMN nazev_pobocky SET OPTIONS (description = 'Název pobočky'),
ALTER COLUMN psc SET OPTIONS (description = 'Poštovní směrovací číslo pobočky'),
ALTER COLUMN nazev_okresu SET OPTIONS (description = 'Název okresu, ve kterém pobočka sídlí'),
ALTER COLUMN nazev_kraje SET OPTIONS (description = 'Název kraje, ve kterém pobočka sídlí');


-- C. ZDROJE (Stroj/Četa + Typ)
CREATE OR REPLACE TABLE gold.D_Zdroje AS
SELECT 
  z.id_zdroj,
  z.nazev_zdroje,
  tz.nazev_typu AS typ_zdroja
FROM silver.D_Zdroje z
LEFT JOIN silver.D_Typy_Zdroju tz 
  ON CAST(z.id_typ_zdroje AS INT64) = CAST(tz.id_typ_zdroje AS INT64);

ALTER TABLE gold.D_Zdroje ADD PRIMARY KEY (id_zdroj) NOT ENFORCED;

ALTER TABLE gold.D_Zdroje
SET OPTIONS (description = 'Denormalizovaná dimenze zdrojů propojující stroje a čety s jejich typovým zařazením');

ALTER TABLE gold.D_Zdroje
ALTER COLUMN id_zdroj SET OPTIONS (description = 'Unikátní identifikátor zdroja (PK)'),
ALTER COLUMN nazev_zdroje SET OPTIONS (description = 'Název nebo označení stroje / pracovní čety'),
ALTER COLUMN typ_zdroja SET OPTIONS (description = 'Typologické zařazení zdroje (např. Stroj, Pracovní četa)');


-- D. ZAMESTNANCI (Zaměstnanec + Funkce)
CREATE OR REPLACE TABLE gold.D_Zamestnanci AS
SELECT 
  z.id_zamestnanec,
  CONCAT(z.prijmeni, ' ', z.jmeno) AS cele_jmeno,
  z.m_plat,
  f.nazev_funkce,
  f.ohodnoceni,
  z.id_pobocka
FROM silver.D_Zamestnanci z
LEFT JOIN silver.D_Funkce f 
  ON CAST(z.id_funkce AS INT64) = CAST(f.id_funkce AS INT64);

ALTER TABLE gold.D_Zamestnanci ADD PRIMARY KEY (id_zamestnanec) NOT ENFORCED;

ALTER TABLE gold.D_Zamestnanci
SET OPTIONS (description = 'Denormalizovaná dimenze zaměstnanců propojující osobní údaje s pracovní pozicí a hodnocením');

ALTER TABLE gold.D_Zamestnanci
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Unikátní identifikátor zaměstnance (PK)'),
ALTER COLUMN cele_jmeno SET OPTIONS (description = 'Celé jméno zaměstnance ve formátu Příjmení Jméno'),
ALTER COLUMN m_plat SET OPTIONS (description = 'Základní platový výměr v CZK/EUR'),
ALTER COLUMN nazev_funkce SET OPTIONS (description = 'Název pracovní pozice / funkce (např. Obchodník, Dělník)'),
ALTER COLUMN ohodnoceni SET OPTIONS (description = 'Stupeň nebo hodnocení náročnosti práce'),
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Odkaz na domovskou pobočku (FK -> D_Pobocky)');


-- ====================================================================
-- FAKTOVÉ TABULKY (DATA MARTS)
-- ====================================================================

-- FAKT 1: CASHFLOW & FINANČNÍ POHLED
CREATE OR REPLACE TABLE gold.F_Cashflow_Mart AS
SELECT
  f.id_cashflow,
  f.id_ref_pol,
  f.id_cas,
  COALESCE(f.id_pobocka, z.id_pobocka, zk.id_pobocka) AS id_pobocka,
  f.id_zamestnanec,
  f.id_zdroje,
  f.id_kontraktu,

  CASE
    WHEN f.id_kategorie_pohybu = 1 THEN 'Nájem'
    WHEN f.id_kategorie_pohybu = 2 THEN 'Zdroje'
    WHEN f.id_kategorie_pohybu = 3 THEN 'Mzdy'
    WHEN f.id_kategorie_pohybu = 4 THEN 'Osobní'
    WHEN f.id_kategorie_pohybu = 5 THEN 'Režie'
    WHEN f.id_kategorie_pohybu = 6 THEN 'Tržby'
    ELSE 'Ostatní'
  END AS kategoria_pohybu,

  CASE WHEN f.id_typ_pohybu = 2 THEN 'Příjem' ELSE 'Výdaj' END AS typ_pohybu,

  f.is_plan,
  f.m_castka,

  CASE WHEN f.id_typ_pohybu = 2 AND f.is_plan = FALSE THEN f.m_castka ELSE 0 END AS prijem_skutocnost,
  CASE WHEN f.id_typ_pohybu = 1 AND f.is_plan = FALSE THEN f.m_castka ELSE 0 END AS vydaj_skutocnost,
  CASE WHEN f.id_kategorie_pohybu = 3 AND f.is_plan = FALSE THEN f.m_castka ELSE 0 END AS mzdy_skutocnost,
  CASE WHEN f.id_typ_pohybu = 2 AND f.is_plan = TRUE THEN f.m_castka ELSE 0 END AS prijem_plan,
  CASE WHEN f.id_typ_pohybu = 1 AND f.is_plan = TRUE THEN f.m_castka ELSE 0 END AS vydaj_plan,
  CASE WHEN f.id_kategorie_pohybu = 3 AND f.is_plan = TRUE THEN f.m_castka ELSE 0 END AS mzdy_plan,
FROM silver.F_Cashflow f
LEFT JOIN silver.D_Zamestnanci z            -- pobočka zaměstnance (mzdy, osobní)
  ON f.id_zamestnanec = z.id_zamestnanec
LEFT JOIN silver.F_Kontrakty_a_Faktury kf   -- obchodník kontraktu (příjmy)
  ON f.id_kontraktu = kf.id_kontrakt
LEFT JOIN silver.D_Zamestnanci zk
  ON kf.id_zamestnanec = zk.id_zamestnanec;

ALTER TABLE gold.F_Cashflow_Mart
SET OPTIONS (description = 'Gold Data Mart finančních toků. Univerzální metrika m_castka s atributy kategorie, typu pohybu a příznakem plán/skutečnost; pro hlavní metriky (příjmy, výdaje, mzdy) předpočítané dvojice skutečnost/plán. Výdaje se znaménkem minus.');

ALTER TABLE gold.F_Cashflow_Mart
ALTER COLUMN id_cashflow SET OPTIONS (description = 'Unikátní identifikátor řádku finančního pohybu (PK)'),
ALTER COLUMN id_ref_pol SET OPTIONS (description = 'Odkaz ze skutečné položky na plánovanou položku pro párování (FK)'),
ALTER COLUMN id_cas SET OPTIONS (description = 'Odkaz na časovou dimenzi ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Odkaz na zaměstnance u osobních/mzdových výdajů (FK -> D_Zamestnanci)'),
ALTER COLUMN id_zdroje SET OPTIONS (description = 'Odkaz na alokovaný zdroj (FK -> D_Zdroje)'),
ALTER COLUMN kategoria_pohybu SET OPTIONS (description = 'Zdenormalizovaný textový název kategorie (Nájem, Mzdy, Tržby atd.)'),
ALTER COLUMN typ_pohybu SET OPTIONS (description = 'Typ pohybu (Příjem / Výdaj)'),
ALTER COLUMN is_plan SET OPTIONS (description = 'Příznak, zda se jedná o plán (TRUE) nebo skutečnost (FALSE)'),
ALTER COLUMN mzdy_skutocnost SET OPTIONS (description = 'Předpočítaná částka pro skutečně vyplacené mzdy'),
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Pobočka pohybu: ze zdroje; u mezd a osobních nákladů dle zaměstnance; u příjmů dle obchodníka kontraktu; u nákladů na zdroje nepřiřazeno (celofiremní)'),
ALTER COLUMN id_kontraktu SET OPTIONS (description = 'Číslo kontraktu u příjmů – degenerovaná dimenze pouze pro audit, bez vazby na jinou tabulku'),
ALTER COLUMN prijem_skutocnost SET OPTIONS (description = 'Skutečné příjmy (pouze skutečnost, bez plánu)'),
ALTER COLUMN vydaj_skutocnost SET OPTIONS (description = 'Skutečné výdaje se znaménkem minus (pouze skutečnost, bez plánu)'),
ALTER COLUMN prijem_plan SET OPTIONS (description = 'Plánované příjmy (pouze plán)'),
ALTER COLUMN vydaj_plan SET OPTIONS (description = 'Plánované výdaje se znaménkem minus (pouze plán)'),
ALTER COLUMN mzdy_plan SET OPTIONS (description = 'Plánované mzdy se znaménkem minus (pouze plán)'),
ALTER COLUMN m_castka SET OPTIONS (description = 'Částka se znaménkem (příjem +, výdaj −); obsahuje plán i skutečnost, v reportu používat jen s filtrem is_plan');


-- FAKT 2: OBCHOD & PROFITABILITA
CREATE OR REPLACE TABLE gold.F_Kontrakty_Mart AS
SELECT
  kf.id_kontrakt,
  kf.cislo_faktury,
  kf.id_zakaznik,
  kf.id_zamestnanec,
  kf.id_zdroj,
  kf.id_cas_kontrakt_od,
  kf.id_cas_kontrakt_do,
  kf.id_faktura_vystaveni,
  kf.id_faktura_splatnost,

  kf.m_cena_kontraktu,
  kf.m_naklady_kontraktu,
  (kf.m_cena_kontraktu - kf.m_naklady_kontraktu) AS hruby_zisk,
  SAFE_DIVIDE(kf.m_cena_kontraktu - kf.m_naklady_kontraktu, kf.m_cena_kontraktu) * 100 AS marza_pct,
  kf.m_cena_faktury,

  CASE
    WHEN kf.id_faktura_splatnost != -1 AND kf.id_faktura_vystaveni != -1
    THEN DATE_DIFF(
           PARSE_DATE('%Y%m%d', CAST(kf.id_faktura_splatnost AS STRING)),
           PARSE_DATE('%Y%m%d', CAST(kf.id_faktura_vystaveni AS STRING)),
           DAY)
    ELSE NULL
  END AS dni_do_uhrady,

  CASE
    WHEN kf.id_faktura_splatnost = -1 OR kf.id_faktura_splatnost IS NULL OR kf.id_stav_uhrady = 0 THEN NULL
    WHEN kf.id_faktura_zaplaceno IS NOT NULL AND kf.id_faktura_zaplaceno != -1
    THEN DATE_DIFF(
           PARSE_DATE('%Y%m%d', CAST(kf.id_faktura_zaplaceno AS STRING)),
           PARSE_DATE('%Y%m%d', CAST(kf.id_faktura_splatnost AS STRING)),
           DAY)
    ELSE DATE_DIFF(
           DATE '2026-08-31',
           PARSE_DATE('%Y%m%d', CAST(kf.id_faktura_splatnost AS STRING)),
           DAY)
  END AS dni_po_splatnosti,

  CASE
    WHEN kf.m_cena_kontraktu < 50000 THEN 'Malá (< 50k)'
    WHEN kf.m_cena_kontraktu BETWEEN 50000 AND 200000 THEN 'Střední (50k - 200k)'
    ELSE 'Velká (> 200k)'
  END AS velkost_objednavky,

  kf.is_fakturovane,
  kf.is_zaplaceno,
  kf.id_faktura_zaplaceno,
  kf.nps,

  CASE kf.id_stav_uhrady
      WHEN 1 THEN 'Zaplaceno'
      WHEN 2 THEN 'Nezaplaceno'
      WHEN 0 THEN 'Není relevantní'
    END AS stav_uhrady

  , zam.id_pobocka
  , COALESCE(
      kf.id_cas_kontrakt_od > MIN(IF(kf.id_stav_uhrady = 2, kf.id_faktura_splatnost, NULL))
                                OVER (PARTITION BY kf.id_zakaznik),
      FALSE) AS je_po_vzniku_dluhu

    , CASE kf.id_stav_uhrady
      WHEN 1 THEN IF(kf.id_faktura_zaplaceno > kf.id_faktura_splatnost, 'Uhrazeno pozdě', 'Uhrazeno včas')
      WHEN 2 THEN 'Neuhrazeno'
      WHEN 0 THEN 'Není relevantní'
    END AS platebni_moralka
  , CASE
      WHEN kf.nps >= 9 THEN 'Promotér'
      WHEN kf.nps >= 7 THEN 'Pasivní'
      WHEN kf.nps IS NOT NULL THEN 'Kritik'
    END AS skupina_nps
    
FROM silver.F_Kontrakty_a_Faktury kf

LEFT JOIN silver.D_Zamestnanci zam
  ON kf.id_zamestnanec = zam.id_zamestnanec;



ALTER TABLE gold.F_Kontrakty_Mart
SET OPTIONS (description = 'Gold Data Mart pro obchod, ziskovost zakázek, fakturaci a platební morálku');

ALTER TABLE gold.F_Kontrakty_Mart
ALTER COLUMN id_kontrakt SET OPTIONS (description = 'Unikátní identifikátor kontraktu/zakázky (PK)'),
ALTER COLUMN cislo_faktury SET OPTIONS (description = 'Číslo vystavené faktury navázané na kontrakt'),
ALTER COLUMN id_zakaznik SET OPTIONS (description = 'Odkaz na zákazníka (FK -> D_Zakaznici)'),
ALTER COLUMN id_zamestnanec SET OPTIONS (description = 'Odkaz na pečujícího obchodníka (FK -> D_Zamestnanci)'),
ALTER COLUMN id_zdroj SET OPTIONS (description = 'Odkaz na alokovaný stroj/četu (FK -> D_Zdroje)'),
ALTER COLUMN id_cas_kontrakt_od SET OPTIONS (description = 'Datum zahájení kontraktu ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_cas_kontrakt_do SET OPTIONS (description = 'Datum ukončení kontraktu ve formátu YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_faktura_vystaveni SET OPTIONS (description = 'Datum vystavení podle zdrojové faktury YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN id_faktura_splatnost SET OPTIONS (description = 'Datum splatnosti podle zdrojové faktury YYYYMMDD (FK -> D_Cas)'),
ALTER COLUMN m_cena_kontraktu SET OPTIONS (description = 'Smluvní cena kontraktu bez DPH v CZK/EUR'),
ALTER COLUMN m_naklady_kontraktu SET OPTIONS (description = 'Celkové náklady na realizaci zakázky v CZK/EUR'),
ALTER COLUMN hruby_zisk SET OPTIONS (description = 'Plánovaný hrubý zisk (smluvní cena − plánované náklady), nikoli skutečný'),
ALTER COLUMN marza_pct SET OPTIONS (description = 'Vypočtená marže zakázky v procentech (Hrubý zisk / Cena * 100)'),
ALTER COLUMN m_cena_faktury SET OPTIONS (description = 'Fakturovaná částka na faktuře v CZK/EUR'),
ALTER COLUMN dni_do_uhrady SET OPTIONS (description = 'Počet dnů mezi vystavením a splatností faktury (INT64)'),
ALTER COLUMN dni_po_splatnosti SET OPTIONS (description = 'Dny po splatnosti; u neuhrazených faktur počítáno k datu konce dat 2026-08-31; záporné = uhrazeno před splatností'),
ALTER COLUMN velkost_objednavky SET OPTIONS (description = 'Kategorizace zakázky podle finančního objemu (Malá, Střední, Velká)'),
ALTER COLUMN is_fakturovane SET OPTIONS (description = 'Příznak, zda je zakázka vyfakturována (TRUE / FALSE)'),
ALTER COLUMN is_zaplaceno SET OPTIONS (description = 'Příznak, zda je faktura plně uhrazena (TRUE / FALSE)'),
ALTER COLUMN stav_uhrady SET OPTIONS (description = 'Stav úhrady dle zdroje: Zaplaceno / Nezaplaceno / Není relevantní (zrušený kontrakt bez skutečné faktury). Neuhrazené pohledávky = pouze Nezaplaceno.'),
ALTER COLUMN id_faktura_zaplaceno SET OPTIONS (description = 'Datum skutečné úhrady YYYYMMDD (FK -> kalendář); -1 = neuhrazeno'),
ALTER COLUMN nps SET OPTIONS (description = 'Hodnocení spokojenosti zákazníka s kontraktem na škále 0-10 (ve zdroji označeno NPS, nejde o index NPS)'),
ALTER COLUMN id_pobocka SET OPTIONS (description = 'Pobočka obchodníka, který zakázku sjednal (FK -> D_Pobocky)'),
ALTER COLUMN je_po_vzniku_dluhu SET OPTIONS (description = 'TRUE, pokud byla zakázka sjednána po splatnosti první neuhrazené faktury téhož zákazníka'),
ALTER COLUMN platebni_moralka SET OPTIONS (description = 'Platební morálka: Uhrazeno včas / Uhrazeno pozdě / Neuhrazeno / Není relevantní'),
ALTER COLUMN skupina_nps SET OPTIONS (description = 'Skupina podle hodnocení: Promotér (9-10), Pasivní (7-8), Kritik (0-6)');


-- =====================================================================
-- FAKT 3: F_Cashflow_Odhad – dopočet chybějící skutečnosti 04–12/2024
-- =====================================================================
CREATE OR REPLACE TABLE gold.F_Cashflow_Odhad
OPTIONS (
  description = "Statistický odhad chybějících skutečných peněžních toků za období 04–12/2024 (výpadek evidence ve zdrojovém systému; plány a režie jsou kompletní). Metoda: plán × realizační koeficient kategorie pohybu. Koeficient = průměr poměru skutečnost/plán za 04/2023–03/2024 a 03/2025–02/2026 (náběhové měsíce 01–02/2025 vyřazeny). Duben 2024 = odhad celého měsíce minus již evidovaná skutečnost. Režie se nedopočítává. Zpětná validace na 04–12/2022: odchylka −2,5 % příjmy, −0,2 % výdaje, −7,4 % čistý cash flow. Znaménka shodná s F_Cashflow_Mart (výdaje záporné). Interpretovat na úrovni čtvrtletí/roku. Nepoužívat pro čerpání mezd vůči plánu, pohledávky, platební morálku ani NPS."
)
AS
WITH mesicne AS (
  SELECT DIV(id_cas, 100) AS mesic, id_pobocka, kategoria_pohybu, typ_pohybu,
         SUM(prijem_plan + vydaj_plan)             AS plan,
         SUM(prijem_skutocnost + vydaj_skutocnost) AS skut
  FROM gold.F_Cashflow_Mart
  WHERE kategoria_pohybu <> 'Režie'
  GROUP BY 1, 2, 3, 4
),
koef AS (
  SELECT kategoria_pohybu,
    ( SAFE_DIVIDE(SUM(IF(mesic BETWEEN 202304 AND 202403, skut, 0)),
                  SUM(IF(mesic BETWEEN 202304 AND 202403, plan, 0)))
    + SAFE_DIVIDE(SUM(IF(mesic BETWEEN 202503 AND 202602, skut, 0)),
                  SUM(IF(mesic BETWEEN 202503 AND 202602, plan, 0))) ) / 2 AS koeficient
  FROM mesicne GROUP BY 1
),
odhad AS (
  SELECT m.mesic, m.id_pobocka, m.kategoria_pohybu, m.typ_pohybu, k.koeficient,
         m.plan * k.koeficient - m.skut AS dopocet,      -- pro 05–12/2024 je skut = 0
         m.plan * k.koeficient          AS odhad_celkem
  FROM mesicne m JOIN koef k USING (kategoria_pohybu)
  WHERE m.mesic BETWEEN 202404 AND 202412
),
vystup AS (
  SELECT *,
    ROUND(IF(SIGN(dopocet) = SIGN(odhad_celkem), dopocet, 0), 2) AS m_castka_odhad
  FROM odhad
)
SELECT
  mesic * 100 + 1                                   AS id_cas,
  id_pobocka,
  kategoria_pohybu,
  typ_pohybu,
  m_castka_odhad,
  IF(typ_pohybu = 'Příjem', m_castka_odhad, 0)      AS prijem_odhad,
  IF(typ_pohybu = 'Výdaj',  m_castka_odhad, 0)      AS vydaj_odhad,
  IF(kategoria_pohybu = 'Mzdy', m_castka_odhad, 0)  AS mzdy_odhad,
  ROUND(koeficient, 4)                              AS koeficient,
  IF(mesic = 202404, 'plán × koeficient − evidovaná skutečnost',
                     'plán × koeficient')           AS metoda
FROM vystup
WHERE m_castka_odhad <> 0;

-- ---------------------------------------------------------------------
-- Popisky sloupců
-- ---------------------------------------------------------------------
ALTER TABLE gold.F_Cashflow_Odhad
  ALTER COLUMN id_cas SET OPTIONS (description = "Klíč období ve formátu YYYYMMDD; vždy první den měsíce, ke kterému se odhad vztahuje (odhad je na měsíční úrovni). FK -> D_Cas."),
  ALTER COLUMN id_pobocka SET OPTIONS (description = "Pobočka, za kterou je odhad počítán (z plánu v F_Cashflow_Mart). FK na D_Pobocky."),
  ALTER COLUMN kategoria_pohybu SET OPTIONS (description = "Kategorie peněžního pohybu (Tržby, Zdroje, Mzdy, Osobní, Nájem). Režie není zahrnuta – její skutečnost je ve zdroji kompletní."),
  ALTER COLUMN typ_pohybu SET OPTIONS (description = "Typ pohybu: Příjem / Výdaj."),
  ALTER COLUMN m_castka_odhad SET OPTIONS (description = "Odhadnutá chybějící skutečná částka v Kč = plán × koeficient (u dubna 2024 minus již evidovaná skutečnost). Výdaje záporné, příjmy kladné – shodně s F_Cashflow_Mart."),
  ALTER COLUMN prijem_odhad SET OPTIONS (description = "Odhadnutý příjem v Kč (m_castka_odhad pro typ Příjem, jinak 0). Doplňuje prijem_skutocnost v F_Cashflow_Mart."),
  ALTER COLUMN vydaj_odhad SET OPTIONS (description = "Odhadnutý výdaj v Kč, záporný (m_castka_odhad pro typ Výdaj, jinak 0). Doplňuje vydaj_skutocnost v F_Cashflow_Mart."),
  ALTER COLUMN mzdy_odhad SET OPTIONS (description = "Odhadnuté mzdové výdaje v Kč, záporné (kategorie Mzdy, jinak 0). Pouze pro celkový cash flow – NEPOUŽÍVAT pro přečerpání mezd vůči plánu (odhad je z plánu odvozen)."),
  ALTER COLUMN koeficient SET OPTIONS (description = "Realizační koeficient kategorie = průměr poměru skutečnost/plán za 04/2023–03/2024 a 03/2025–02/2026."),
  ALTER COLUMN metoda SET OPTIONS (description = "Způsob výpočtu řádku: 'plán × koeficient' (05–12/2024) nebo 'plán × koeficient − evidovaná skutečnost' (částečný duben 2024).");
