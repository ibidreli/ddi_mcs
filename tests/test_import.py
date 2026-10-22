"""test_import.py
Zweck: Import aus der Exportdatei data/seed.json in eine leere PostgreSQL-Datenbank.
LE2 (Import und Export). Vergleicht alle acht Tabellen mit dem Bestand in lernpfad.
"""
import pytest

from src import config, dataset
from src.db import pg_connect
from src.load import PG_COLUMNS, load_postgres


@pytest.fixture(scope="module")
def imported():
    load_postgres(dataset.read_json(config.SEED_JSON), dbname=config.PG_DB_BENCHMARK)
    with pg_connect(config.PG_DB_SEED) as source, pg_connect(config.PG_DB_BENCHMARK) as target:
        yield source, target


@pytest.mark.parametrize("key", dataset.TABLES)
def test_table_identical_after_import(imported, key):
    source, target = imported
    table, columns = PG_COLUMNS[key]
    sql = f"SELECT {', '.join(columns)} FROM lernpfad.{table} ORDER BY {', '.join(columns[:2])}"
    assert source.execute(sql).fetchall() == target.execute(sql).fetchall()


def test_import_rejects_invalid_data():
    # Die Constraints gelten auch beim Import: ein Vorkurs ohne Kurs bricht ab
    data = dataset.read_json(config.SEED_JSON)
    data["prerequisites"].append({"course_id": "ML", "required_course_id": "FEHLT"})
    with pytest.raises(Exception):
        load_postgres(data, dbname=config.PG_DB_BENCHMARK)
