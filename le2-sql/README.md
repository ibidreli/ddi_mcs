# **LE2 PostgreSQL**

Relationale Umsetzung der Lernpfadplanung mit 6 Entitäten.

| Datei | Inhalt |
|---|---|
| `schema.sql` | Tabellen, Constraints, Indizes, Funktionen A-001 bis A-005, Exportansicht |
| `seed.sql` | Beispielbestand `synthetic-v2` |
| `queries.sql` | A-001 bis A-005, CRUD-Demo mit `ROLLBACK`, Ausführungsplan |
| `tests.sql` | 35 Prüfungen, laufen in einer Transaktion ohne bleibende Änderungen |
| `model/` | konzeptionelles Modell (Chen) und relationales Modell als `.dot`, `.png`, `.svg` |

Aufbau und Prüfung über `.\start.ps1` im Projektordner, SQL-Konsole mit `.\start.ps1 -Aktion Shell`.
