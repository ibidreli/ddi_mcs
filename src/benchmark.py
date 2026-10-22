"""benchmark.py
Zweck: Messung K1 bis K3 fuer A-002 und A-004 mit erzeugten Datensaetzen.
LE2, LE3. Aufruf: python -m src.benchmark [--schnell]

Ablauf pro Szenario
1. Datensatz erzeugen (fester Seed) und in beide Datenbanken laden
2. K1: Ergebnisse beider Datenbanken vergleichen, bei Abweichung Abbruch
3. Aufwaermlaeufe, danach gewertete Laeufe abwechselnd je Datenbank
4. Zeit inklusive Ergebnisuebertragung zum Client messen
Am Ende wird der Beispielbestand wieder in Neo4j geladen.
"""
import csv
import json
import platform
import statistics
import sys
import time
from datetime import datetime

from src import config, dataset
from src.db import neo4j_driver, pg_connect
from src.load import load_neo4j, load_postgres
from src.queries import run_cypher, run_sql

FIELDS = ["series", "scenario", "depth", "width", "courses", "prerequisites", "result_rows",
          "database", "query", "run", "ms", "status"]


def is_timeout(error: Exception) -> bool:
    """Abbruch durch statement_timeout (PostgreSQL) oder Transaktions-Timeout (Neo4j)."""
    import psycopg
    from neo4j.exceptions import Neo4jError
    if isinstance(error, psycopg.errors.QueryCanceled):
        return True
    return isinstance(error, Neo4jError) and "TimedOut" in (error.code or "")


#-----------------------------------------------------------------------------
# Hilfsfunktionen
#-----------------------------------------------------------------------------
def timed(call) -> tuple[float, list]:
    start = time.perf_counter()
    rows = call()
    return (time.perf_counter() - start) * 1000, rows


def environment(conn, session) -> dict:
    pg_version = conn.execute("SHOW server_version").fetchone()[0]
    neo = session.run("CALL dbms.components() YIELD versions, edition "
                      "RETURN versions[0] AS version, edition").single()
    return {
        "measured_at": datetime.now().isoformat(timespec="seconds"),
        "postgresql": pg_version,
        "neo4j": f"{neo['version']} {neo['edition']}",
        "python": platform.python_version(),
        "platform": platform.platform(),
        "processor": platform.processor(),
        "warmup_runs": config.WARMUP_RUNS,
        "measured_runs": config.MEASURED_RUNS,
        "random_state": config.RANDOM_STATE,
    }


#-----------------------------------------------------------------------------
# Messung eines Szenarios
#-----------------------------------------------------------------------------
def measure(series, depth, width, conn, driver, session, writer, runs, warmup) -> None:
    data = dataset.generate(depth, width)
    load_postgres(data)
    load_neo4j(data, driver=driver)

    target = dataset.target_course(depth)
    params = {"A-002": {"course": target}, "A-004": {"course": target, "learner": 1}}
    scenario = f"{series}-d{depth}-w{width}"
    base = {"series": series, "scenario": scenario, "depth": depth, "width": width,
            "courses": len(data["courses"]), "prerequisites": len(data["prerequisites"])}

    for query_id in config.BENCHMARK_QUERIES:
        p = params[query_id]

        def sql_call():
            return run_sql(conn, query_id, **p)

        def cypher_call():
            return run_cypher(session, query_id, timeout=config.QUERY_TIMEOUT_S, **p)

        # K1: Ohne gleiche Ergebnisse ist die Zeitmessung nicht vergleichbar.
        # Laeuft eine Abfrage in den Timeout, wird das festgehalten und nur
        # die andere Datenbank weiter gemessen.
        calls = {"PostgreSQL": sql_call, "Neo4j": cypher_call}
        first = {}
        for name, call in list(calls.items()):
            try:
                first[name] = call()
            except Exception as error:
                if not is_timeout(error):
                    raise
                writer.writerow({**base, "result_rows": "", "database": name, "query": query_id,
                                 "run": 0, "ms": "", "status": "timeout"})
                print(f"  {query_id}: {name} Timeout nach {config.QUERY_TIMEOUT_S} s")
                del calls[name]
        if len(first) == 2 and first["PostgreSQL"] != first["Neo4j"]:
            raise AssertionError(f"K1 verletzt: {scenario} {query_id}")

        for _ in range(warmup):
            for call in calls.values():
                call()
        for run in range(1, runs + 1):
            # Reihenfolge wechselt, damit keine Datenbank systematisch zuerst laeuft
            order = list(calls.items())
            for name, call in (order if run % 2 else order[::-1]):
                ms, rows = timed(call)
                writer.writerow({**base, "result_rows": len(rows), "database": name,
                                 "query": query_id, "run": run, "ms": f"{ms:.3f}", "status": "ok"})
        rows_info = ", ".join(f"{n} {len(r)} Zeilen" for n, r in first.items())
        k1 = "K1 erfuellt" if len(first) == 2 else "K1 nicht pruefbar"
        print(f"  {query_id}: {rows_info}, {k1}")


#-----------------------------------------------------------------------------
# Zusammenfassung im Terminal
#-----------------------------------------------------------------------------
def summarize(path) -> None:
    groups: dict[tuple, list[float]] = {}
    with open(path, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            key = (row["scenario"], row["courses"], row["query"], row["database"])
            if row["status"] == "ok":
                groups.setdefault(key, []).append(float(row["ms"]))
            else:
                groups.setdefault(key, [])
    print(f"\n{'Szenario':<16} {'Kurse':>6} {'Abfrage':<7} {'Datenbank':<11} {'Median ms':>10}")
    for (scenario, courses, query_id, db), values in groups.items():
        median = f"{statistics.median(values):.2f}" if values else "Timeout"
        print(f"{scenario:<16} {courses:>6} {query_id:<7} {db:<11} {median:>10}")


#-----------------------------------------------------------------------------
# Hauptablauf
#-----------------------------------------------------------------------------
def main(quick: bool = False) -> None:
    scenarios = list(dict.fromkeys(config.SCENARIOS_DEPTH + config.SCENARIOS_WIDTH))
    runs, warmup = (config.MEASURED_RUNS, config.WARMUP_RUNS)
    out_path = config.BENCHMARK_CSV
    if quick:
        scenarios, runs, warmup = scenarios[:2], 3, 1
        out_path = config.RESULTS_DIR / "benchmark-quick.csv"
    config.RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    with pg_connect(config.PG_DB_BENCHMARK) as conn, neo4j_driver() as driver:
        conn.execute(f"SET statement_timeout = '{config.QUERY_TIMEOUT_S}s'")
        with driver.session() as session, open(out_path, "w", newline="", encoding="utf-8") as f:
            env = environment(conn, session)
            writer = csv.DictWriter(f, fieldnames=FIELDS)
            writer.writeheader()
            for series, depth, width in scenarios:
                print(f"Szenario {series}: Tiefe {depth}, {width} Kurse pro Stufe")
                measure(series, depth, width, conn, driver, session, writer, runs, warmup)
                f.flush()
        load_neo4j(dataset.read_json(config.SEED_JSON), driver=driver)

    if not quick:
        config.ENVIRONMENT_JSON.write_text(json.dumps(env, indent=2) + "\n", encoding="utf-8")
    print(f"Resultate: {out_path.relative_to(config.ROOT)}")
    summarize(out_path)


if __name__ == "__main__":
    main(quick="--schnell" in sys.argv)
