"""export.py
Zweck: Beispielbestand aus der Ansicht lernpfad.export_data als JSON-Datei speichern.
LE2 (Export), Quelle fuer den Neo4j-Import. Aufruf: python -m src.export
"""
from src import config, dataset
from src.db import pg_connect

if __name__ == "__main__":
    with pg_connect() as conn:
        payload = conn.execute("SELECT payload FROM lernpfad.export_data").fetchone()[0]
    dataset.write_json(payload, config.SEED_JSON)
    counts = ", ".join(f"{key} {len(payload[key])}" for key in dataset.TABLES)
    print(f"Export: {config.SEED_JSON.relative_to(config.ROOT)} ({counts})")
