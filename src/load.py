"""load.py
Zweck: Datenbestand aus einer JSON-Datei in PostgreSQL und in Neo4j laden (Import).
LE2, LE3. Aufruf: python -m src.load <datei.json> [postgres|neo4j|beide]
"""
import sys
from pathlib import Path

from src import config, dataset
from src.db import neo4j_driver, pg_connect, read_cypher_blocks

# Spalten in der Reihenfolge der Tabellen in schema.sql
PG_COLUMNS = {
    "semesters": ("semester", ("semester_id", "name", "starts_on", "ends_on")),
    "locations": ("location", ("location_id", "name")),
    "lecturers": ("lecturer", ("lecturer_id", "display_name")),
    "courses": ("course", ("course_id", "title", "hours")),
    "learners": ("learner", ("learner_id", "display_name", "study_mode")),
    "prerequisites": ("prerequisite", ("course_id", "required_course_id")),
    "course_runs": ("course_run", ("run_id", "course_id", "semester_id", "location_id",
                                   "lecturer_id", "study_mode")),
    "completions": ("completion", ("learner_id", "course_id", "run_id", "completed_on")),
}


#-----------------------------------------------------------------------------
# PostgreSQL
# Schema neu aufbauen und alle Tabellen mit COPY laden. Die Constraints pruefen
# jede Zeile, ein Fehler bricht den Import vollstaendig ab.
#-----------------------------------------------------------------------------
def load_postgres(data: dict, dbname: str = config.PG_DB_BENCHMARK) -> None:
    with pg_connect(dbname) as conn:
        conn.execute(config.SCHEMA_SQL.read_text(encoding="utf-8"))
        with conn.transaction():
            for key in dataset.TABLES:
                table, columns = PG_COLUMNS[key]
                sql = f"COPY lernpfad.{table} ({', '.join(columns)}) FROM STDIN"
                with conn.cursor().copy(sql) as copy:
                    for row in data[key]:
                        copy.write_row([row[c] for c in columns])
        conn.execute("ANALYZE")


#-----------------------------------------------------------------------------
# Neo4j
# Bestand leeren, Eindeutigkeit festlegen, Bloecke aus import.cypher ausfuehren.
#-----------------------------------------------------------------------------
def load_neo4j(data: dict, driver=None) -> None:
    own = driver is None
    driver = driver or neo4j_driver()
    schema = read_cypher_blocks(config.SCHEMA_CYPHER)
    blocks = read_cypher_blocks(config.IMPORT_CYPHER)
    try:
        with driver.session() as session:
            session.run(blocks["clear"]).consume()
            for statement in schema.values():
                session.run(statement).consume()
            session.run("CALL db.awaitIndexes(300)").consume()
            for key in dataset.TABLES:
                rows = data[key]
                for start in range(0, len(rows), config.IMPORT_BATCH):
                    batch = rows[start:start + config.IMPORT_BATCH]
                    session.run(blocks[key], rows=batch).consume()
    finally:
        if own:
            driver.close()


#-----------------------------------------------------------------------------
# Aufruf ueber die Kommandozeile
#-----------------------------------------------------------------------------
if __name__ == "__main__":
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else config.SEED_JSON
    target = sys.argv[2] if len(sys.argv) > 2 else "beide"
    data = dataset.read_json(path)
    if target in ("postgres", "beide"):
        load_postgres(data)
        print(f"PostgreSQL ({config.PG_DB_BENCHMARK}): {path.name} geladen")
    if target in ("neo4j", "beide"):
        load_neo4j(data)
        print(f"Neo4j: {path.name} geladen")
