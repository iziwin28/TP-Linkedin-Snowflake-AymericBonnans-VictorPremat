import streamlit as st

import pandas as pd

import altair as alt

from snowflake.snowpark.context import get_active_session

session = get_active_session()
 
#avec streamlit, on va envoyer des requêtes basiques pour pouvoir visualiser claireemeent les résultats de notre code sql. On affichera les diagrammes différents demandés pour chaque question, ainsi que le tableau correspondant en dessous.

st.set_page_config(layout="wide")

st.title("📊 LinkedIn Job Postings – Dashboard")

@st.cache_data

def run(sql):

    return session.sql(sql).to_pandas()

tab1, tab2, tab3, tab4, tab5 = st.tabs([

    "Q1 – Top titres",

    "Q2 – Top salaires",

    "Q3 – Taille entreprise",

    "Q4 – Secteur d'activité",

    "Q5 – Type d'emploi",

])

# affichage de la question 1

with tab1:

    st.subheader("Top 10 des titres de postes les plus publiés")

    df1 = run("""

        SELECT title, COUNT(*) AS nb_postes

        FROM linkedin.public.job_postings

        GROUP BY title

        ORDER BY nb_postes DESC

        LIMIT 10

    """)

    chart1 = (

        alt.Chart(df1)

        .mark_bar(color="#4F8EF7")

        .encode(

            x=alt.X("NB_POSTES:Q", title="Nombre d'offres"),

            y=alt.Y("TITLE:N", sort="-x", title="Titre du poste"),

            tooltip=["TITLE", "NB_POSTES"],

        )

        .properties(height=400)

    )

    st.altair_chart(chart1, use_container_width=True)

    st.dataframe(df1, use_container_width=True, hide_index=True)

# affichage de la question 2

with tab2:

    st.subheader("Top 10 des postes les mieux rémunérés")

    df2 = run("""

        SELECT title, ROUND(MAX(max_salary), 2) AS salaire_max

        FROM linkedin.public.job_postings

        WHERE max_salary IS NOT NULL

        GROUP BY title

        ORDER BY salaire_max DESC

        LIMIT 10

    """)

    chart2 = (

        alt.Chart(df2)

        .mark_bar(color="#F4A261")

        .encode(

            x=alt.X("SALAIRE_MAX:Q", title="Salaire max ($)"),

            y=alt.Y("TITLE:N", sort="-x", title="Titre du poste"),

            tooltip=["TITLE", "SALAIRE_MAX"],

        )

        .properties(height=400)

    )

    st.altair_chart(chart2, use_container_width=True)

    st.dataframe(df2, use_container_width=True, hide_index=True)

# affichage de la question 3

with tab3:

    st.subheader("Répartition des offres par taille d'entreprise")

    df3 = run("""

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

            company_size,

            COUNT(*) AS nb_offres

        FROM linkedin.public.companies

        GROUP BY company_size, taille_entreprise

        ORDER BY company_size NULLS LAST

    """)

    chart3 = (

        alt.Chart(df3)

        .mark_bar(color="#2A9D8F")

        .encode(

            x=alt.X("TAILLE_ENTREPRISE:N", sort=None,

                    title="Taille d'entreprise",

                    axis=alt.Axis(labelAngle=-30)),

            y=alt.Y("NB_OFFRES:Q", title="Nombre d'entreprises"),

            tooltip=["TAILLE_ENTREPRISE", "NB_OFFRES"],

        )

        .properties(height=400)

    )

    st.altair_chart(chart3, use_container_width=True)

    st.dataframe(df3[["TAILLE_ENTREPRISE", "NB_OFFRES"]], use_container_width=True, hide_index=True)

# affichage de la question 4

with tab4:

    st.subheader("Répartition des offres par secteur d'activité (Top 20)")

    df4 = run("""

        SELECT industry AS secteur, COUNT(*) AS nb_offres

        FROM linkedin.public.company_industries

        WHERE industry IS NOT NULL

        GROUP BY industry

        ORDER BY nb_offres DESC

        LIMIT 20

    """)

    chart4 = (

        alt.Chart(df4)

        .mark_bar(color="#E76F51")

        .encode(

            x=alt.X("NB_OFFRES:Q", title="Nombre d'offres"),

            y=alt.Y("SECTEUR:N", sort="-x", title="Secteur"),

            tooltip=["SECTEUR", "NB_OFFRES"],

        )

        .properties(height=500)

    )

    st.altair_chart(chart4, use_container_width=True)

    st.dataframe(df4, use_container_width=True, hide_index=True)

# affichage de la question 5

with tab5:

    st.subheader("Répartition des offres par type d'emploi")

    df5 = run("""

        SELECT type_emploi AS TYPE_EMPLOI,

               nb_offres   AS NB_OFFRES,

               pourcentage AS POURCENTAGE

        FROM linkedin.public.v_q5_offres_par_type

    """)

    chart5 = (

        alt.Chart(df5)

        .mark_arc(innerRadius=80)

        .encode(

            theta=alt.Theta("NB_OFFRES:Q"),

            color=alt.Color("TYPE_EMPLOI:N",

                            legend=alt.Legend(title="Type d'emploi")),

            tooltip=["TYPE_EMPLOI", "NB_OFFRES", "POURCENTAGE"],

        )

        .properties(height=400)

    )

    st.altair_chart(chart5, use_container_width=True)

    st.dataframe(

        df5.rename(columns={

            "TYPE_EMPLOI": "Type d'emploi",

            "NB_OFFRES": "Nombre d'offres",

            "POURCENTAGE": "% du total"

        }),

        use_container_width=True,

        hide_index=True,

    )

st.caption("Source : LinkedIn Job Postings – Snowflake Lab")
 