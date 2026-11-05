"""profile_completed.py
Zweck: Nutzen der abgeleiteten Kante COMPLETED belegen. A-002 und A-003 laufen einmal
mit COMPLETED und einmal ueber ATTENDED und OF (ohne abgeleitete Kante).
LE3. Aufruf: python -m src.profile_completed
Gemessen werden db hits aus PROFILE und der Median der Zeit. Am Ende wird der
Beispielbestand wieder in Neo4j geladen.
"""
import statistics
import time

from src import config, dataset
from src.db import neo4j_driver
from src.load import load_neo4j
from src.queries import CYPHER

#-----------------------------------------------------------------------------
# Varianten ohne COMPLETED
# Gleiche Abfragen, der Abschluss wird ueber die Durchfuehrung gesucht.
#-----------------------------------------------------------------------------
VIA_RUN = "(l)-[:ATTENDED]->(:Run)-[:OF]->"
VARIANTS = {
    "A-002": CYPHER["A-002"].replace("(l)-[:COMPLETED]->", VIA_RUN),
    "A-003": CYPHER["A-003"].replace("(l)-[:COMPLETED]->", VIA_RUN),
}
RUNS = 20


#-----------------------------------------------------------------------------
# Hilfsfunktionen
#-----------------------------------------------------------------------------
def db_hits(plan) -> int:
    """Summe der db hits ueber alle Operatoren des Profils."""
    if plan is None:
        return 0
    own = plan.get("dbHits", plan.get("db_hits", 0)) or 0
    return own + sum(db_hits(child) for child in plan.get("children", []))


def profile(session, query: str, params: dict) -> tuple[list, int]:
    result = session.run("PROFILE " + query, params)
    rows = [tuple(r.values()) for r in result]
    return rows, db_hits(result.consume().profile)


def median_ms(session, query: str, params: dict) -> float:
    for _ in range(5):
        session.run(query, params).consume()
    times = []
    for _ in range(RUNS):
        start = time.perf_counter()
        list(session.run(query, params))
        times.append((time.perf_counter() - start) * 1000)
    return statistics.median(times)


#-----------------------------------------------------------------------------
# Hauptablauf
# Datensatz der Reihe depth mit Tiefe 20: Person 1 hat die untere Haelfte abgeschlossen.
#-----------------------------------------------------------------------------
def main() -> None:
    depth, width = 20, 20
    data = dataset.generate(depth, width)
    target = dataset.target_course(depth)
    params = {"A-002": {"learner": 1}, "A-003": {"course": target, "learner": 1}}

    with neo4j_driver() as driver:
        load_neo4j(data, driver=driver)
        with driver.session() as session:
            print(f"Datensatz depth Tiefe {depth}, {len(data['courses'])} Kurse, "
                  f"{len(data['completions'])} Abschluesse")
            print("| Abfrage | Variante | Zeilen | db hits | Median ms |")
            print("|---|---|---:|---:|---:|")
            for query_id, variant in VARIANTS.items():
                p = params[query_id]
                rows_c, hits_c = profile(session, CYPHER[query_id], p)
                rows_v, hits_v = profile(session, variant, p)
                assert rows_c == rows_v, f"{query_id}: Varianten liefern unterschiedliche Ergebnisse"
                ms_c = median_ms(session, CYPHER[query_id], p)
                ms_v = median_ms(session, variant, p)
                print(f"| {query_id} | mit COMPLETED | {len(rows_c)} | {hits_c} | {ms_c:.2f} |")
                print(f"| {query_id} | ueber ATTENDED und OF | {len(rows_v)} | {hits_v} | {ms_v:.2f} |")
        load_neo4j(dataset.read_json(config.SEED_JSON), driver=driver)
    print("Beispielbestand wieder geladen.")


if __name__ == "__main__":
    main()
