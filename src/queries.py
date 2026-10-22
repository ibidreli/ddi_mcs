"""queries.py
Zweck: A-001 bis A-005 in beiden Datenbanken mit gleichen Parametern ausfuehren.
LE2, LE3. Ergebnisse sind Listen von Tupeln in gleicher Spaltenreihenfolge.
"""
from src import config
from src.db import read_cypher_blocks

#-----------------------------------------------------------------------------
# SQL-Aufrufe
# A-002 bis A-005 rufen die Funktionen aus schema.sql auf. COLLATE "C" sortiert
# nach Zeichencode wie Neo4j, damit die Reihenfolge direkt vergleichbar ist.
#-----------------------------------------------------------------------------
SQL = {
    "A-001": """SELECT c.course_id, c.title, c.hours
                FROM lernpfad.prerequisite AS p
                JOIN lernpfad.course AS c ON c.course_id = p.required_course_id
                WHERE p.course_id = %(course)s
                ORDER BY c.course_id COLLATE "C" """,
    "A-002": """SELECT * FROM lernpfad.all_prerequisites(%(course)s)
                ORDER BY course_id COLLATE "C" """,
    "A-003": """SELECT * FROM lernpfad.eligible_courses(%(learner)s)
                ORDER BY course_id COLLATE "C" """,
    "A-004": """SELECT * FROM lernpfad.missing_prerequisites(%(course)s, %(learner)s)
                ORDER BY course_id COLLATE "C" """,
    "A-005": """SELECT * FROM lernpfad.available_runs(%(learner)s, %(semester)s, %(location)s)
                ORDER BY course_id COLLATE "C", run_id""",
}

CYPHER = read_cypher_blocks(config.QUERIES_CYPHER)


#-----------------------------------------------------------------------------
# Ausfuehren
#-----------------------------------------------------------------------------
def run_sql(conn, query_id: str, **params) -> list[tuple]:
    with conn.cursor() as cur:
        cur.execute(SQL[query_id], params)
        return [tuple(row) for row in cur.fetchall()]


def run_cypher(session, query_id: str, timeout: float | None = None, **params) -> list[tuple]:
    from neo4j import Query
    result = session.run(Query(CYPHER[query_id], timeout=timeout), params)
    return [tuple(record.values()) for record in result]


#-----------------------------------------------------------------------------
# Demo-Ausgabe beider Datenbanken
# Aufruf: python -m src.queries
#-----------------------------------------------------------------------------
DEMO = [
    ("A-001", {"course": "PROJ"}),
    ("A-002", {"course": "PROJ"}),
    ("A-003", {"learner": 1}),
    ("A-004", {"course": "PROJ", "learner": 1}),
    ("A-005", {"learner": 1, "semester": "FS27", "location": 1}),
]

if __name__ == "__main__":
    from src.db import neo4j_driver, pg_connect
    with pg_connect() as conn, neo4j_driver() as driver, driver.session() as session:
        for query_id, params in DEMO:
            sql_rows = run_sql(conn, query_id, **params)
            cypher_rows = run_cypher(session, query_id, **params)
            status = "gleich" if sql_rows == cypher_rows else "UNTERSCHIEDLICH"
            print(f"\n{query_id} {params}: PostgreSQL und Neo4j {status}")
            for row in cypher_rows:
                print("  ", *row)
