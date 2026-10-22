"""config.py
Zweck: Konstanten, Pfade und Verbindungsdaten fuer Import, Pruefung und Messung.
LE2, LE3. Werte koennen ueber Umgebungsvariablen ueberschrieben werden.
"""
import os
from pathlib import Path

#-----------------------------------------------------------------------------
# Pfade
#-----------------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "le2-sql"
CYPHER_DIR = ROOT / "le3-nosql"
SCHEMA_SQL = SQL_DIR / "schema.sql"
SCHEMA_CYPHER = CYPHER_DIR / "schema.cypher"
IMPORT_CYPHER = CYPHER_DIR / "import.cypher"
QUERIES_CYPHER = CYPHER_DIR / "queries.cypher"
SEED_JSON = ROOT / "data" / "seed.json"
RESULTS_DIR = ROOT / "comparison" / "results"
BENCHMARK_CSV = RESULTS_DIR / "benchmark.csv"
ENVIRONMENT_JSON = RESULTS_DIR / "environment.json"

#-----------------------------------------------------------------------------
# Verbindungen (lokale Docker-Container, bewusst einfache Demo-Passwoerter)
#-----------------------------------------------------------------------------
# 127.0.0.1 statt localhost: Windows versucht sonst zuerst IPv6 (::1) und wartet
PG_HOST = os.environ.get("DDI_PG_HOST", "127.0.0.1")
PG_PORT = int(os.environ.get("DDI_PG_PORT", "55432"))
PG_USER = os.environ.get("DDI_PG_USER", "ddi")
PG_PASSWORD = os.environ.get("DDI_PG_PASSWORD", "ddi_lokal_demo")
PG_DB_SEED = "lernpfad"
PG_DB_BENCHMARK = "benchmark"

NEO4J_URI = os.environ.get("DDI_NEO4J_URI", "bolt://127.0.0.1:7687")
NEO4J_USER = "neo4j"
NEO4J_PASSWORD = os.environ.get("DDI_NEO4J_PASSWORD", "ddi_lokal_demo")

#-----------------------------------------------------------------------------
# Messdaten und Messablauf
#-----------------------------------------------------------------------------
RANDOM_STATE = 42

# Szenarien (Name, Tiefe, Kurse pro Stufe). Tiefe = Anzahl Stufen der Kette.
SCENARIOS_DEPTH = [("depth", d, 20) for d in (5, 10, 20, 40, 80)]
SCENARIOS_WIDTH = [("width", 10, w) for w in (20, 100, 400)]

LEARNERS = 20               # Personen pro Messdatensatz
EXTRA_EDGE_SHARE = 0.5      # Anteil Kurse mit zusaetzlichem Vorkurs aus tieferer Stufe
WARMUP_RUNS = 5             # Aufwaermlaeufe, nicht gewertet
MEASURED_RUNS = 20          # gewertete Laeufe pro Abfrage und Datenbank
QUERY_TIMEOUT_S = 120       # Abbruch einzelner Abfragen
BENCHMARK_QUERIES = ("A-001", "A-003")
IMPORT_BATCH = 5000         # Zeilen pro Neo4j-Importaufruf
