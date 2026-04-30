{{ config(materialized='view') }}

{% set raw_cases = source('raw_data_source', 'raw_cases') %}

with raw_upc as (

    select *
    from {{ raw_cases }}

),

cleaned as (

    select
        cast({{ column_or_null(raw_cases, [
            'casenumber',
            'case_number',
            'case_id'
        ]) }} as text) as case_id,

        cast({{ column_or_null(raw_cases, [
            'patentnumber',
            'patent_number',
            'patent_id'
        ]) }} as text) as patent_id,

        cast({{ column_or_null(raw_cases, [
            'courtdivision',
            'court_division'
        ]) }} as text) as court_division,

        cast({{ column_or_null(raw_cases, [
            'languageofproceeding',
            'language_of_proceeding',
            'proceeding_language'
        ]) }} as text) as proceeding_language,

        cast({{ column_or_null(raw_cases, [
            'outcome',
            'case_outcome'
        ]) }} as text) as case_outcome,

        cast({{ column_or_null(raw_cases, [
            'defendants',
            'defendant_name'
        ]) }} as text) as defendant_name,

        case
            when lower(cast({{ column_or_null(raw_cases, [
                'npe',
                'is_npe'
            ]) }} as text)) in ('1', 'true', 'yes', 'y') then 'Yes'
            when lower(cast({{ column_or_null(raw_cases, [
                'npe',
                'is_npe'
            ]) }} as text)) in ('0', 'false', 'no', 'n') then 'No'
            else null
        end as is_npe,

        case
            when lower(cast({{ column_or_null(raw_cases, [
                'sep',
                'is_sep',
                'sep_patent',
                'is_sep_patent',
                'standard_essential_patent',
                'standardessentialpatent'
            ]) }} as text)) in ('1', 'true', 'yes', 'y') then 'Yes'
            when lower(cast({{ column_or_null(raw_cases, [
                'sep',
                'is_sep',
                'sep_patent',
                'is_sep_patent',
                'standard_essential_patent',
                'standardessentialpatent'
            ]) }} as text)) in ('0', 'false', 'no', 'n') then 'No'
            else null
        end as is_sep_patent,

        current_timestamp as transformed_at

    from raw_upc

)

select *
from cleaned