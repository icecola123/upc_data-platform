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
        c.Defendants
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
    u.party,

    COUNT(DISTINCT u.case_number) AS total_cases,

    COUNT(DISTINCT CASE
        WHEN u.role = 'Claimant' THEN u.case_number
    END) AS claimant_cases,

    COUNT(DISTINCT CASE
        WHEN u.role = 'Defendant' THEN u.case_number
    END) AS defendant_cases,

    AVG(u.patent_value) AS avg_patent_value,

    COUNT(DISTINCT CASE
        WHEN u.npe_flag = 'True' THEN u.case_number
    END) AS npe_cases,

    COUNT(DISTINCT CASE
        WHEN u.sep_flag = 'True' THEN u.case_number
    END) AS sep_cases,

    MAX(rp.Country_headquarter) AS country_headquarter,
    MAX(rp.NaceMainv2) AS nacemainv2

FROM unioned u
LEFT JOIN latest_parties rp
    ON UPPER(TRIM(u.party)) = UPPER(TRIM(rp.Party))
WHERE u.party IS NOT NULL
  AND TRIM(u.party) <> ''
GROUP BY u.party;
