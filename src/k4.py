"""k4.py
Zweck: K4 Abfrageumfang. Zeilen und Klauseln der SQL-Funktionen und Cypher-Abfragen zaehlen.
LE2, LE3. Aufruf: python -m src.k4
SQL zaehlt inklusive aller aufgerufenen Funktionen, weil sie Teil der Loesung sind.
"""
import re

from src import config
from src.db import read_cypher_blocks

SQL_FUNCTIONS = {
    "A-001": ["all_prerequisites"],
    "A-002": ["eligible_courses", "all_prerequisites"],
    "A-003": ["missing_prerequisites", "all_prerequisites"],
    "A-004": ["course_offers", "eligible_courses", "all_prerequisites"],
    "A-005": ["lecturer_courses"],
}
SQL_CLAUSES = r"\b(SELECT|FROM|JOIN|WHERE|UNION|WITH RECURSIVE|EXISTS|ORDER BY|GROUP BY)\b"
CYPHER_CLAUSES = r"\b(MATCH|WHERE|WITH|EXISTS|RETURN|ORDER BY)\b"


#-----------------------------------------------------------------------------
# Hilfsfunktionen
#-----------------------------------------------------------------------------
def code_lines(text: str) -> list[str]:
    return [l for l in text.splitlines() if l.strip() and not l.strip().startswith(("--", "//"))]


def sql_body(name: str, schema: str) -> str:
    match = re.search(rf"CREATE FUNCTION lernpfad\.{name}\(.*?\$\$(.*?)\$\$;", schema, re.S)
    return match.group(1)


def count() -> list[tuple]:
    schema = config.SCHEMA_SQL.read_text(encoding="utf-8")
    cypher = read_cypher_blocks(config.QUERIES_CYPHER)
    rows = []
    for query_id, functions in SQL_FUNCTIONS.items():
        sql = "\n".join(sql_body(f, schema) for f in functions)
        cy = cypher[query_id]
        rows.append((query_id,
                     len(code_lines(sql)), len(re.findall(SQL_CLAUSES, sql)),
                     len(code_lines(cy)), len(re.findall(CYPHER_CLAUSES, cy))))
    return rows


if __name__ == "__main__":
    print("| Abfrage | SQL Zeilen | SQL Klauseln | Cypher Zeilen | Cypher Klauseln |")
    print("|---|---:|---:|---:|---:|")
    for row in count():
        print("| {} | {} | {} | {} | {} |".format(*row))
