"""db.py
Zweck: Verbindungen zu PostgreSQL und Neo4j sowie Lesen benannter Cypher-Bloecke.
LE2, LE3.
"""
import re
from pathlib import Path

import psycopg
from neo4j import GraphDatabase

from src import config

#-----------------------------------------------------------------------------
# Verbindungen
#-----------------------------------------------------------------------------
def pg_connect(dbname: str = config.PG_DB_SEED, autocommit: bool = True) -> psycopg.Connection:
    """Oeffnet eine Verbindung zur PostgreSQL-Datenbank im Docker-Container."""
    return psycopg.connect(
        host=config.PG_HOST, port=config.PG_PORT, user=config.PG_USER,
        password=config.PG_PASSWORD, dbname=dbname, autocommit=autocommit,
    )


def neo4j_driver():
    """Oeffnet einen Treiber fuer die Neo4j-Datenbank im Docker-Container."""
    driver = GraphDatabase.driver(config.NEO4J_URI, auth=(config.NEO4J_USER, config.NEO4J_PASSWORD))
    driver.verify_connectivity()
    return driver


#-----------------------------------------------------------------------------
# Cypher-Dateien
# Bloecke beginnen mit einer Zeile "// name: <Name>" und enden vor dem naechsten.
#-----------------------------------------------------------------------------
_NAME = re.compile(r"^//\s*name:\s*(\S+)\s*$")


def read_cypher_blocks(path: Path) -> dict[str, str]:
    """Liest alle benannten Bloecke einer .cypher-Datei, ohne Kommentare und Semikolon."""
    blocks: dict[str, list[str]] = {}
    current = None
    for line in path.read_text(encoding="utf-8").splitlines():
        match = _NAME.match(line.strip())
        if match:
            current = match.group(1)
            blocks[current] = []
        elif current and not line.strip().startswith("//"):
            blocks[current].append(line)
    return {name: "\n".join(lines).strip().rstrip(";").strip() for name, lines in blocks.items()}
