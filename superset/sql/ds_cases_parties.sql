WITH cases_base AS (
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
    FROM raw_cases c
    LEFT JOIN raw_patents p
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
    rp.BVD_number AS bvd_number,
    rp.Nace4digitv2description AS nace4digitv2description,
    rp.NaceMainv2 AS nacemainv2
FROM unioned u
LEFT JOIN raw_parties rp
    ON UPPER(TRIM(u.party)) = UPPER(TRIM(rp.Party))
;