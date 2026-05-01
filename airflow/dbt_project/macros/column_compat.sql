{% macro get_column_name(relation, candidates) %}
    {% set cols = adapter.get_columns_in_relation(relation) %}
    {% set ns = namespace(found=none) %}

    {% for col in cols %}
        {% if col.name | lower in candidates %}
            {% set ns.found = col.name %}
        {% endif %}
    {% endfor %}

    {{ return(ns.found) }}
{% endmacro %}


{% macro column_or_null(relation, candidates) %}
    {% set col_name = get_column_name(relation, candidates) %}

    {% if col_name %}
        {{ adapter.quote(col_name) }}
    {% else %}
        null
    {% endif %}
{% endmacro %}