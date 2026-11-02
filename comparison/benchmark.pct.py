# ---
# jupyter:
#   jupytext:
#     formats: ipynb,pct.py:percent
#     text_representation:
#       extension: .py
#       format_name: percent
#   kernelspec:
#     display_name: Python 3
#     language: python
#     name: python3
# ---

# %% [markdown]
# # **Auswertung der Messung**
#
# Wertet `comparison/results/benchmark.csv` aus, die `.\start.ps1 -Aktion Messen` erzeugt.
# Gemessen werden A-001 und A-003 in PostgreSQL und Neo4j, jeweils inklusive Ergebnisübertragung.
# Bei Neo4j liegt zusätzlich die Serverzeit ohne Übertragung vor (`server_ms`).
# LE2, LE3.

# %% [markdown]
# ## **1) Daten laden**
#
# Pro Szenario, Datenbank und Abfrage liegen 20 gewertete Läufe vor. Ausgewertet wird der Median,
# dazu das 25. und 75. Perzentil als Streuung.

# %%
#-----------------------------------------------------------------------------
# Messdaten und Umgebung
#-----------------------------------------------------------------------------
import json
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path.cwd() if (Path.cwd() / "src").exists() else Path.cwd().parent
sys.path.insert(0, str(ROOT))
from src import config  # noqa: E402

raw = pd.read_csv(config.BENCHMARK_CSV)
environment = json.loads(config.ENVIRONMENT_JSON.read_text(encoding="utf-8"))
print(json.dumps(environment, indent=2))
print("Timeouts:", (raw["status"] == "timeout").sum())

# %% [markdown]
# ## **2) Kennzahlen pro Szenario**

# %%
#-----------------------------------------------------------------------------
# Median und Quartile
#-----------------------------------------------------------------------------
ok = raw[raw["status"] == "ok"]
summary = (
    ok.groupby(["series", "scenario", "depth", "width", "courses", "prerequisites", "recursion_depth",
                "query", "database"])
    .agg(rows=("result_rows", "first"), median_ms=("ms", "median"),
         q25_ms=("ms", lambda s: s.quantile(0.25)), q75_ms=("ms", lambda s: s.quantile(0.75)),
         server_ms=("server_ms", "median"))
    .reset_index()
)
wide = summary.pivot_table(index=["series", "depth", "width", "courses", "recursion_depth", "query", "rows"],
                           columns="database", values="median_ms").reset_index()
server = summary[summary["database"] == "Neo4j"][["series", "depth", "courses", "query", "server_ms"]]
wide = wide.merge(server.rename(columns={"server_ms": "Neo4j_server"}), on=["series", "depth", "courses", "query"])
wide["faktor_pg_zu_neo4j"] = wide["PostgreSQL"] / wide["Neo4j"]
wide.round(2)

# %%
#-----------------------------------------------------------------------------
# Tabelle fuer den Bericht (Markdown)
#-----------------------------------------------------------------------------
lines = ["| Reihe | Tiefe | Schritte | Kurse | Abfrage | Zeilen | PostgreSQL ms | Neo4j ms | Neo4j Server ms | Faktor |",
         "|---|---:|---:|---:|---|---:|---:|---:|---:|---:|"]
for r in wide.sort_values(["series", "query", "depth", "courses"]).itertuples():
    lines.append(f"| {r.series} | {r.depth} | {r.recursion_depth} | {r.courses:,} | {r.query} | {int(r.rows):,} | "
                 f"{r.PostgreSQL:.2f} | {r.Neo4j:.2f} | {r.Neo4j_server:.1f} | {r.faktor_pg_zu_neo4j:.2f} |"
                 .replace(",", "'"))
table_md = "\n".join(lines)
(config.RESULTS_DIR / "benchmark-summary.md").write_text(table_md + "\n", encoding="utf-8")
print(table_md)

# %% [markdown]
# ## **3) K3 Skalierung**
#
# Links wächst die Tiefe mit Zusatzkanten, in der Mitte ohne Zusatzkanten (Tiefe gleich Rekursionsschritte),
# rechts die Anzahl Kurse pro Stufe bei Tiefe 10.

# %%
#-----------------------------------------------------------------------------
# Median mit Quartilen ueber Tiefe und Kurszahl
#-----------------------------------------------------------------------------
colors = {"PostgreSQL": "#336791", "Neo4j": "#018bff"}
titles = {"depth": "Tiefe mit Zusatzkanten", "chain": "Tiefe ohne Zusatzkanten", "width": "Kurse variiert"}
fig, axes = plt.subplots(2, 3, figsize=(15, 7), sharey="row")
for row, query_id in enumerate(config.BENCHMARK_QUERIES):
    for col, (series, x) in enumerate((("depth", "depth"), ("chain", "depth"), ("width", "courses"))):
        ax = axes[row, col]
        part = summary[(summary["series"] == series) & (summary["query"] == query_id)]
        for db, group in part.groupby("database"):
            group = group.sort_values(x)
            ax.plot(group[x], group["median_ms"], marker="o", label=db, color=colors[db])
            ax.fill_between(group[x], group["q25_ms"], group["q75_ms"], alpha=0.2, color=colors[db])
        ax.set_title(f"{query_id}, {titles[series]}")
        ax.set_xlabel("Anzahl Kurse" if series == "width" else "Tiefe (Stufen)")
        ax.set_ylabel("Median ms")
        ax.grid(alpha=0.3)
        ax.legend()
fig.tight_layout()
fig.savefig(config.RESULTS_DIR / "benchmark-k3.png", dpi=150)
plt.show()

# %% [markdown]
# ## **4) Verhältnis der Datenbanken**
#
# Faktor grösser 1 bedeutet, dass PostgreSQL langsamer ist als Neo4j.

# %%
#-----------------------------------------------------------------------------
# Faktor PostgreSQL zu Neo4j ueber die Tiefe
#-----------------------------------------------------------------------------
fig, ax = plt.subplots(figsize=(6, 4))
for (series, query_id), group in wide[wide["series"].isin(["depth", "chain"])].groupby(["series", "query"]):
    style = "-" if series == "depth" else "--"
    ax.plot(group["depth"], group["faktor_pg_zu_neo4j"], style, marker="o", label=f"{query_id} {series}")
ax.axhline(1, color="grey", linestyle="--")
ax.set_xlabel("Tiefe (Stufen)")
ax.set_ylabel("Median PostgreSQL / Median Neo4j")
ax.legend()
ax.grid(alpha=0.3)
fig.tight_layout()
fig.savefig(config.RESULTS_DIR / "benchmark-faktor.png", dpi=150)
plt.show()

# %% [markdown]
# ## **5) Serverzeit gegenüber Übertragung**
#
# Die Serverzeit von Neo4j enthält die Ausführung ohne Übertragung zum Client. Die Differenz zur
# Client-Zeit ist Übertragung und Treiber. So zeigt sich, ob der Abstand zu PostgreSQL aus der
# Traversierung oder aus der Übertragung kommt.

# %%
#-----------------------------------------------------------------------------
# Anteil Serverzeit an der Client-Zeit von Neo4j
#-----------------------------------------------------------------------------
share = wide[["series", "depth", "courses", "recursion_depth", "query", "rows", "PostgreSQL", "Neo4j", "Neo4j_server"]].copy()
share["Neo4j_uebertragung"] = share["Neo4j"] - share["Neo4j_server"]
share["anteil_server"] = share["Neo4j_server"] / share["Neo4j"]
share.sort_values(["series", "query", "depth", "courses"]).round(2)
