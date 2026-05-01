WITH city_geo AS (
    SELECT 'Mannheim' AS city, 49.4875 AS latitude, 8.4660 AS longitude
    UNION ALL SELECT 'Munich', 48.1351, 11.5820
    UNION ALL SELECT 'Hamburg', 53.5511, 9.9937
    UNION ALL SELECT 'The Hague', 52.0705, 4.3007
    UNION ALL SELECT 'Paris', 48.8566, 2.3522
    UNION ALL SELECT 'Düsseldorf', 51.2277, 6.7735
    UNION ALL SELECT 'Brussels', 50.8503, 4.3517
    UNION ALL SELECT 'Milan', 45.4642, 9.1900
    UNION ALL SELECT 'Copenhagen', 55.6761, 12.5683
    UNION ALL SELECT 'Vienna', 48.2082, 16.3738
    UNION ALL SELECT 'Lisbon', 38.7223, -9.1393
    UNION ALL SELECT 'Helsinki', 60.1699, 24.9384
    UNION ALL SELECT 'Nordic-Baltic', NULL, NULL

    UNION ALL SELECT 'Amsterdam', 52.3676, 4.9041
    UNION ALL SELECT 'Berlin', 52.5200, 13.4050
    UNION ALL SELECT 'Rome', 41.9028, 12.4964
    UNION ALL SELECT 'Madrid', 40.4168, -3.7038
    UNION ALL SELECT 'Stockholm', 59.3293, 18.0686
    UNION ALL SELECT 'Luxembourg', 49.6116, 6.1319
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
)

SELECT
    b.case_number,
    b.patent_number,
    b.case_date,
    b.year,
    b.npe_flag,
    b.sep_flag,
    b.city,
    g.latitude,
    g.longitude
FROM cases_base b
LEFT JOIN city_geo g
    ON TRIM(b.city) = TRIM(g.city)
WHERE g.latitude IS NOT NULL
  AND g.longitude IS NOT NULL
;