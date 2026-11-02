# **Vergleich**

Messung von A-001 und A-003 in PostgreSQL und Neo4j mit erzeugten Datensätzen (K1 bis K3).

- **Reihen:** `depth` (Tiefe 5 bis 80 mit Zusatzkanten), `width` (Tiefe 10, 20 bis 400 Kurse pro Stufe) und `chain` (Tiefe 5 bis 80 ohne Zusatzkanten, Tiefe gleich Rekursionsschritte)
- **Zeiten:** `ms` misst im Client inklusive Übertragung, `server_ms` bei Neo4j die Serverzeit bis zum ersten Datensatz
- **`recursion_depth`:** tatsächliche Anzahl Rekursionsschritte von A-001 im Szenario

| Datei | Inhalt |
|---|---|
| `benchmark.pct.py` | Notebook zur Auswertung, erzeugt Tabelle und Diagramme |
| `results/benchmark.csv` | Einzelmessungen, je 20 Läufe pro Szenario, Abfrage und Datenbank |
| `results/environment.json` | Versionen und Messparameter |
| `results/benchmark-summary.md` | Medianwerte pro Szenario |
| `results/*.png` | Diagramme K3 und Faktor |

Messung mit `.\start.ps1 -Aktion Messen`, K4 mit `.venv\Scripts\python -m src.k4`.
