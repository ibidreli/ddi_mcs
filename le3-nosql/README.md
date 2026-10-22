# **LE3 Neo4j**

Graphumsetzung derselben Problemstellung mit denselben Daten wie PostgreSQL.

| Datei | Inhalt |
|---|---|
| `schema.cypher` | eindeutige `id` für alle 6 Knotentypen |
| `import.cypher` | Import aus `data/seed.json`, ausgeführt durch `src/load.py` |
| `queries.cypher` | A-001 bis A-005 mit denselben Parametern wie die SQL-Funktionen |
| `model/` | Property-Graph-Modell als `.dot`, `.png`, `.svg` |

Gleiche Ergebnisse wie PostgreSQL prüft `tests/test_equivalence.py` (K1). Neo4j Browser unter <http://localhost:7474>, Cypher-Konsole mit `.\start.ps1 -Aktion Cypher`.
