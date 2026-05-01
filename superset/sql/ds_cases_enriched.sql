SELECT
    c.CaseNumber AS case_number,
    c.Patentnumber AS patent_number,
    c.Claimants AS claimant,
    c.Defendants AS defendant,
    c.Courtdivision AS courtdivision_full,

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
    ) AS city,

    CAST(c.Date AS DATE) AS case_date,
    EXTRACT(YEAR FROM CAST(c.Date AS DATE)) AS year,

    CASE
        WHEN CAST(c.NPE AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 'True'
        ELSE 'False'
    END AS npe_flag,

    c.Languageofproceeding AS language_of_proceeding,
    c.Outcome AS outcome,

    CASE
        WHEN CAST(p.SEP AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 'True'
        ELSE 'False'
    END AS sep_flag,

    p.Application_Year AS application_year,
    p.Patent_Value AS patent_value,
    p.Technology_35_classes AS technology_35_classes

FROM raw_cases c
LEFT JOIN raw_patents p
    ON c.Patentnumber = p.Patentnumber
;