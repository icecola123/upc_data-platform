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

cases_enriched AS (
    SELECT
        c.CaseNumber AS case_number,
        c.Patentnumber AS patent_number,

        CASE
            WHEN CAST(c.NPE AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 1
            ELSE 0
        END AS npe_case,

        CASE
            WHEN CAST(p.SEP AS VARCHAR) IN ('1', 'true', 'True', 'TRUE') THEN 'True'
            ELSE 'False'
        END AS sep_flag,

        CAST(NULLIF(CAST(p.Application_Year AS VARCHAR), '') AS NUMERIC) AS application_year,
        CAST(NULLIF(CAST(p.Patent_Value AS VARCHAR), '') AS NUMERIC) AS patent_value,
        p.Technology_35_classes AS technology_35_classes

    FROM latest_cases c
    LEFT JOIN latest_patents p
        ON c.Patentnumber = p.Patentnumber
)

SELECT
    patent_number,

    MAX(application_year) AS application_year_x,
    MAX(patent_value) AS patent_value_y,
    MAX(technology_35_classes) AS technology_35_classes,
    MAX(sep_flag) AS sep_flag,

    CASE
        WHEN MAX(npe_case) = 1 THEN 'True'
        ELSE 'False'
    END AS has_npe_case,

    COUNT(DISTINCT case_number) AS case_count

FROM cases_enriched
WHERE patent_number IS NOT NULL
  AND application_year IS NOT NULL
  AND patent_value IS NOT NULL

GROUP BY
    patent_number;
