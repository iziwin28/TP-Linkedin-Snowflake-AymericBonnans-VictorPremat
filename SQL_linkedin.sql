-- création de la base de données, stage et choix des formats
CREATE OR REPLACE DATABASE linkedin;
USE DATABASE linkedin;
 
CREATE STAGE linkedin_stage
    URL = 's3://snowflake-lab-bucket/';
-- on garde les formats csv et json
CREATE FILE FORMAT csv_format
    TYPE = CSV
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    SKIP_HEADER = 1;
 
CREATE FILE FORMAT json_format
    TYPE = JSON;
 
-- creation des tables (avec les types et noms des variables) a partir de csv
CREATE OR REPLACE TABLE benefits (
    job_id  STRING,
    inferred BOOLEAN,
    type    STRING
);
 
CREATE OR REPLACE TABLE employee_counts (
    company_id     STRING,
    employee_count INTEGER,
    follower_count INTEGER,
    time_recorded  INTEGER
);
 
CREATE OR REPLACE TABLE job_postings (
    job_id                    STRING,
    company_name              STRING,
    title                     STRING,
    description               STRING,
    max_salary                FLOAT,
    med_salary                FLOAT,
    min_salary                FLOAT,
    pay_period                STRING,
    formatted_work_type       STRING,
    location                  STRING,
    applies                   INTEGER,
    original_listed_time      STRING,
    remote_allowed            FLOAT,
    views                     INTEGER,
    job_posting_url           STRING,
    application_url           STRING,
    application_type          STRING,
    expiry                    STRING,
    closed_time               STRING,
    formatted_experience_level STRING,
    skills_desc               STRING,
    listed_time               STRING,
    posting_domain            STRING,
    sponsored                 FLOAT,
    work_type                 STRING,
    currency                  STRING,
    compensation_type         STRING
);
 
-- creation des tables en type de data VARIANT a partir de json
CREATE OR REPLACE TABLE companies_raw          (data VARIANT);
CREATE OR REPLACE TABLE company_industries_raw (data VARIANT);
CREATE OR REPLACE TABLE company_specialities_raw (data VARIANT);
CREATE OR REPLACE TABLE job_industries_raw     (data VARIANT);
 
-- copy into et import des données depuis le stage
COPY INTO benefits
    FROM @linkedin_stage/benefits.csv
    FILE_FORMAT = (FORMAT_NAME = csv_format);
 
COPY INTO employee_counts
    FROM @linkedin_stage/employee_counts.csv
    FILE_FORMAT = (FORMAT_NAME = csv_format);
 
COPY INTO job_postings
    FROM @linkedin_stage/job_postings.csv
    FILE_FORMAT = (FORMAT_NAME = csv_format);
 
COPY INTO companies_raw
    FROM @linkedin_stage/companies.json
    FILE_FORMAT = (FORMAT_NAME = json_format);
 
COPY INTO company_industries_raw
    FROM @linkedin_stage/company_industries.json
    FILE_FORMAT = (FORMAT_NAME = json_format);
 
COPY INTO company_specialities_raw
    FROM @linkedin_stage/company_specialities.json
    FILE_FORMAT = (FORMAT_NAME = json_format);
 
COPY INTO job_industries_raw
    FROM @linkedin_stage/job_industries.json
    FILE_FORMAT = (FORMAT_NAME = json_format);
 
 
-- structuration des tables :
-- entreprises
CREATE OR REPLACE TABLE companies AS
SELECT
    value:company_id::STRING    AS company_id,
    value:name::STRING          AS name,
    value:description::STRING   AS description,
    value:company_size::INTEGER AS company_size,
    value:state::STRING         AS state,
    value:country::STRING       AS country,
    value:city::STRING          AS city,
    value:zip_code::STRING      AS zip_code,
    value:address::STRING       AS address,
    value:url::STRING           AS url
FROM companies_raw,
LATERAL FLATTEN(input => data);
 
-- industries par entreprise
CREATE OR REPLACE TABLE company_industries AS
SELECT
    value:company_id::STRING   AS company_id,
    value:industry::STRING     AS industry
FROM company_industries_raw,
LATERAL FLATTEN(input => data);
 
-- industries par offre d'emploi
CREATE OR REPLACE TABLE job_industries AS
SELECT
    value:job_id::STRING       AS job_id,
    value:industry_id::STRING  AS industry_id
FROM job_industries_raw,
LATERAL FLATTEN(input => data);
 
-- nombre total d'offres
SELECT COUNT(*) AS total_offres FROM job_postings;
 
-- nombre d'offres avec une entreprise matchée
SELECT COUNT(*) AS offres_matchees
FROM job_postings j
JOIN companies c
    ON LOWER(TRIM(j.company_name)) = LOWER(TRIM(c.name));
 
-- vérification si job_postings contient un company_id caché dans d'autres colonnes :
SELECT company_name, COUNT(*) FROM job_postings GROUP BY 1 ORDER BY 2 DESC LIMIT 5;
SELECT name, company_id         FROM companies                              LIMIT 5;
 
 
-- Q1 : TOP 10 TITRES LES PLUS PUBLIÉS PAR INDUSTRIE
SELECT 
    title,
    COUNT(*) AS nb_postes
FROM job_postings
GROUP BY title
ORDER BY nb_postes DESC
LIMIT 10;
 
-- Q2 : TOP 10 POSTES LES MIEUX RÉMUNÉRÉS PAR INDUSTRIE
SELECT 
    title,
    ROUND(MAX(max_salary), 2) AS salaire_max
FROM job_postings
WHERE max_salary IS NOT NULL
GROUP BY title
ORDER BY salaire_max DESC
LIMIT 10;
 
 
-- Q3 : RÉPARTITION DES OFFRES PAR TAILLE D'ENTREPRISE
SELECT 
    CASE company_size
        WHEN 0 THEN '0 – Indépendant'
        WHEN 1 THEN '1 – 1-10 employés'
        WHEN 2 THEN '2 – 11-50 employés'
        WHEN 3 THEN '3 – 51-200 employés'
        WHEN 4 THEN '4 – 201-500 employés'
        WHEN 5 THEN '5 – 501-1000 employés'
        WHEN 6 THEN '6 – 1001-5000 employés'
        WHEN 7 THEN '7 – 5000+ employés'
        ELSE 'Inconnu'
    END AS taille_entreprise,
    COUNT(*) AS nb_offres
FROM companies
GROUP BY company_size, taille_entreprise
ORDER BY company_size NULLS LAST;
 
-- si nos lignes vont dans 'inconnu' créé plus tôt, on vérifie ici les companies sans id
SELECT DISTINCT j.company_name
FROM job_postings j
LEFT JOIN companies c
    ON LOWER(TRIM(j.company_name)) = LOWER(TRIM(c.name))
WHERE c.company_id IS NULL
LIMIT 20;
 
 
-- Q4 : RÉPARTITION DES OFFRES PAR SECTEUR D'ACTIVITÉ
SELECT 
    industry AS secteur,
    COUNT(*) AS nb_offres
FROM company_industries
WHERE industry IS NOT NULL
GROUP BY industry
ORDER BY nb_offres DESC
LIMIT 20;
 
 
-- Q5 : RÉPARTITION DES OFFRES PAR TYPE D'EMPLOI
 
-- formatted_work_type contient : FULL_TIME, PART_TIME, CONTRACT, INTERNSHIP, etc., on veut donc changer les noms pour l'affichage :
CREATE OR REPLACE VIEW v_q5_offres_par_type AS
SELECT
    CASE UPPER(TRIM(formatted_work_type))
        WHEN 'FULL-TIME'  THEN 'Temps plein'
        WHEN 'PART-TIME'  THEN 'Temps partiel'
        WHEN 'INTERNSHIP' THEN 'Stage'
        WHEN 'CONTRACT'   THEN 'Contrat / Freelance'
        WHEN 'TEMPORARY'  THEN 'Temporaire'
        WHEN 'VOLUNTEER'  THEN 'Bénévolat'
        WHEN 'OTHER'      THEN 'Autre'
        ELSE COALESCE(formatted_work_type, 'Non renseigné')
    END AS type_emploi,
    COUNT(*) AS nb_offres,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    )  AS pourcentage
FROM job_postings
GROUP BY formatted_work_type
ORDER BY nb_offres DESC;
 
SELECT * FROM v_q5_offres_par_type;