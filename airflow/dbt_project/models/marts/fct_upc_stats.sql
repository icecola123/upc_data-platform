{{ config(materialized='table') }}

{% set raw_patents = source('raw_data_source', 'raw_patents') %}

with staging as (

    select *
    from {{ ref('stg_upc_data') }}

),

patents_info as (

    select
        cast({{ column_or_null(raw_patents, [
            'patentnumber',
            'patent_number',
            'patent_id'
        ]) }} as text) as patentnumber,

        cast({{ column_or_null(raw_patents, [
            'technology_35_classes',
            'technology35classes',
            'tech_sector',
            'technology_sector'
        ]) }} as text) as tech_sector

    from {{ raw_patents }}

)

select
    s.proceeding_language,
    s.case_outcome,
    s.is_sep_patent,
    s.court_division,
    s.is_npe,
    p.tech_sector,

    count(s.case_id) as total_cases,
    count(distinct s.patent_id) as total_unique_patents

from staging s
left join patents_info p
    on s.patent_id = p.patentnumber

group by
    s.proceeding_language,
    s.case_outcome,
    s.is_sep_patent,
    s.court_division,
    s.is_npe,
    p.tech_sector