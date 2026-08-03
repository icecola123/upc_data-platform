WITH latest_source AS (
    SELECT source_file
    FROM raw_cases
    ORDER BY import_date DESC
    LIMIT 1
),

latest_cases AS (
    SELECT *
    FROM raw_cases
    WHERE source_file = (SELECT source_file FROM latest_source)
),

latest_patents AS (
    SELECT *
    FROM raw_patents
    WHERE source_file = (SELECT source_file FROM latest_source)
),

latest_parties AS (
    SELECT *
    FROM raw_parties
    WHERE source_file = (SELECT source_file FROM latest_source)
),

country_map AS (
    SELECT 'AU' AS code, 'Australia' AS country_name
    UNION ALL SELECT 'KR', 'South Korea'
    UNION ALL SELECT 'FR', 'France'
    UNION ALL SELECT 'IT', 'Italy'
    UNION ALL SELECT 'BE', 'Belgium'
    UNION ALL SELECT 'US', 'United States'
    UNION ALL SELECT 'LV', 'Latvia'
    UNION ALL SELECT 'CN', 'China'
    UNION ALL SELECT 'DE', 'Germany'
    UNION ALL SELECT 'HR', 'Croatia'
    UNION ALL SELECT 'JP', 'Japan'
    UNION ALL SELECT 'IL', 'Israel'
    UNION ALL SELECT 'SE', 'Sweden'
    UNION ALL SELECT 'AR', 'Argentina'
    UNION ALL SELECT 'AT', 'Austria'
    UNION ALL SELECT 'BR', 'Brazil'
    UNION ALL SELECT 'CA', 'Canada'
    UNION ALL SELECT 'CH', 'Switzerland'
    UNION ALL SELECT 'CL', 'Chile'
    UNION ALL SELECT 'CZ', 'Czech Republic'
    UNION ALL SELECT 'DK', 'Denmark'
    UNION ALL SELECT 'EE', 'Estonia'
    UNION ALL SELECT 'ES', 'Spain'
    UNION ALL SELECT 'FI', 'Finland'
    UNION ALL SELECT 'GB', 'United Kingdom'
    UNION ALL SELECT 'HK', 'Hong Kong'
    UNION ALL SELECT 'IE', 'Ireland'
    UNION ALL SELECT 'IN', 'India'
    UNION ALL SELECT 'KY', 'Cayman Islands'
    UNION ALL SELECT 'LT', 'Lithuania'
    UNION ALL SELECT 'LU', 'Luxembourg'
    UNION ALL SELECT 'MT', 'Malta'
    UNION ALL SELECT 'NL', 'Netherlands'
    UNION ALL SELECT 'NO', 'Norway'
    UNION ALL SELECT 'PL', 'Poland'
    UNION ALL SELECT 'PT', 'Portugal'
    UNION ALL SELECT 'RO', 'Romania'
    UNION ALL SELECT 'RS', 'Serbia'
    UNION ALL SELECT 'SG', 'Singapore'
    UNION ALL SELECT 'TW', 'Taiwan'
    UNION ALL SELECT 'SI', 'Slovenia'
    UNION ALL SELECT 'TH', 'Thailand'
    UNION ALL SELECT 'TR', 'Turkey'
),

cases_base AS (
    SELECT
        c.CaseNumber AS case_number,
        c.Patentnumber AS patent_number,
        CAST(c.Date AS DATE) AS case_date,
        EXTRACT(YEAR FROM CAST(c.Date AS DATE)) AS year,

        CASE
            WHEN CAST(c.NPE AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 'True'
            ELSE 'False'
        END AS npe_flag,

        CASE
            WHEN CAST(p.SEP AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 'True'
            ELSE 'False'
        END AS sep_flag,

        c.Languageofproceeding AS language_of_proceeding,
        c.Outcome AS outcome,
        p.Application_Year AS application_year,
        p.Patent_Value AS patent_value,
        p.Technology_35_classes AS technology_35_classes,
        c.Claimants,
        c.Defendants,

        CASE
            WHEN c.Courtdivision LIKE 'First instance, Local division - %' THEN 'First instance'
            WHEN c.Courtdivision LIKE 'firstInstance - regional - %' THEN 'First instance'
            WHEN c.Courtdivision LIKE 'First instance, Central division - %' THEN 'First instance'
            ELSE NULL
        END AS courtinstance,

        CASE
            WHEN c.Courtdivision LIKE 'First instance, Local division - %' THEN 'Local division'
            WHEN c.Courtdivision LIKE 'firstInstance - regional - %' THEN 'Regional'
            WHEN c.Courtdivision LIKE 'First instance, Central division - %' THEN 'Central division'
            ELSE NULL
        END AS courtdivision_type,

        TRIM(
            CASE
                WHEN c.Courtdivision LIKE 'First instance, Local division - %'
                    THEN REPLACE(c.Courtdivision, 'First instance, Local division - ', '')
                WHEN c.Courtdivision LIKE 'firstInstance - regional - %'
                    THEN REPLACE(c.Courtdivision, 'firstInstance - regional - ', '')
                WHEN c.Courtdivision LIKE 'First instance, Central division - %'
                    THEN REPLACE(c.Courtdivision, 'First instance, Central division - ', '')
                ELSE c.Courtdivision
            END
        ) AS city
    FROM latest_cases c
    LEFT JOIN latest_patents p
        ON c.Patentnumber = p.Patentnumber
),

claimant_side AS (
    SELECT
        case_number,
        patent_number,
        case_date,
        year,
        npe_flag,
        sep_flag,
        language_of_proceeding,
        outcome,
        application_year,
        patent_value,
        technology_35_classes,
        courtinstance,
        courtdivision_type,
        city,
        TRIM(Claimants) AS party,
        'Claimant' AS role
    FROM cases_base
    WHERE Claimants IS NOT NULL
      AND TRIM(Claimants) <> ''
),

defendant_side AS (
    SELECT
        case_number,
        patent_number,
        case_date,
        year,
        npe_flag,
        sep_flag,
        language_of_proceeding,
        outcome,
        application_year,
        patent_value,
        technology_35_classes,
        courtinstance,
        courtdivision_type,
        city,
        TRIM(Defendants) AS party,
        'Defendant' AS role
    FROM cases_base
    WHERE Defendants IS NOT NULL
      AND TRIM(Defendants) <> ''
),

unioned AS (
    SELECT * FROM claimant_side
    UNION ALL
    SELECT * FROM defendant_side
)

SELECT
    u.case_number,
    u.patent_number,
    u.case_date,
    u.year,
    u.party,
    u.role,
    u.npe_flag,
    u.sep_flag,
    u.language_of_proceeding,
    u.outcome,
    u.application_year,
    u.patent_value,
    u.technology_35_classes,
    u.courtinstance,
    u.courtdivision_type,
    u.city,

    rp.Country_headquarter AS country_headquarter,

    COALESCE(cm.country_name, 'Unknown') AS country_headquarter_full,

    rp.BVD_number AS bvd_number,
    rp.Nace4digitv2description AS nace4digitv2description,
    rp.NaceMainv2 AS nacemainv2
FROM unioned u
LEFT JOIN latest_parties rp
    ON UPPER(TRIM(u.party)) = UPPER(TRIM(rp.Party))
LEFT JOIN country_map cm
    ON UPPER(TRIM(rp.Country_headquarter)) = cm.code
;
