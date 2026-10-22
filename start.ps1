# start.ps1
# Zweck: MC3 aufbauen, pruefen, abfragen und messen (PostgreSQL und Neo4j in Docker, Python in .venv)
# LE2, LE3. Aufruf im Projektordner: .\start.ps1 [-Aktion Start|Pruefen|Abfragen|Messen|Shell|Cypher|Stop]
param(
    [ValidateSet('Start', 'Pruefen', 'Abfragen', 'Messen', 'Shell', 'Cypher', 'Stop')]
    [string]$Aktion = 'Start'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:PYTHONIOENCODING = 'utf-8'
$Python = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'

#-----------------------------------------------------------------------------
# Hilfsfunktionen
#-----------------------------------------------------------------------------
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
    # Docker und psql schreiben normale Meldungen auf stderr, entscheidend ist der Exitcode
    $ErrorActionPreference = 'Continue'
    & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host "$_" }
    $Code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($Code -ne 0) { throw "$Exe $($Arguments -join ' ') fehlgeschlagen (Exitcode $Code)" }
}

function Invoke-Psql([string]$Database, [string[]]$Arguments) {
    Invoke-Native 'docker' (@('compose', 'exec', '-T', 'db', 'psql', '-X', '-q', '-U', 'ddi', '-d', $Database,
        '-v', 'ON_ERROR_STOP=1') + $Arguments)
}

function Invoke-Python([string[]]$Arguments) {
    Invoke-Native $Python $Arguments
}

function Initialize-Venv {
    if (-not (Test-Path $Python)) {
        Write-Host 'Python-Umgebung .venv wird angelegt'
        if (Get-Command py -ErrorAction SilentlyContinue) { Invoke-Native 'py' @('-3', '-m', 'venv', '.venv') }
        else { Invoke-Native 'python' @('-m', 'venv', '.venv') }
    }
    Invoke-Python @('-m', 'pip', 'install', '--quiet', '--disable-pip-version-check', '-r', 'requirements.txt')
}

function Show-Step([string]$Text) {
    Write-Host ''
    Write-Host "== $Text"
}

#-----------------------------------------------------------------------------
# Ablauf
#-----------------------------------------------------------------------------
try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker Desktop fehlt.' }
    & docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Bitte Docker Desktop starten und warten, bis die Engine laeuft.' }

    switch ($Aktion) {
        'Stop'  { Invoke-Native 'docker' @('compose', 'stop'); exit 0 }
        'Shell' { & docker compose exec db psql -X -U ddi -d lernpfad; exit 0 }
        'Cypher' { & docker compose exec neo4j cypher-shell -u neo4j -p ddi_lokal_demo; exit 0 }
    }

    if ($Aktion -eq 'Start') {
        Show-Step 'Container starten (PostgreSQL und Neo4j)'
        Invoke-Native 'docker' @('compose', 'up', '-d', '--wait', '--wait-timeout', '180')

        Show-Step 'PostgreSQL: Schema und Beispielbestand synthetic-v2'
        Invoke-Psql 'lernpfad' @('-f', '/work/le2-sql/schema.sql')
        Invoke-Psql 'lernpfad' @('-f', '/work/le2-sql/seed.sql')
        $Exists = & docker compose exec -T db psql -X -U ddi -d lernpfad -tAc "SELECT 1 FROM pg_database WHERE datname = 'benchmark'"
        if ("$Exists".Trim() -ne '1') { Invoke-Psql 'lernpfad' @('-c', 'CREATE DATABASE benchmark') }

        Show-Step 'Python-Umgebung'
        Initialize-Venv

        Show-Step 'Export nach data/seed.json und Import in Neo4j'
        Invoke-Python @('-m', 'src.export')
        Invoke-Python @('-m', 'src.load', 'data/seed.json', 'neo4j')
    }

    if ($Aktion -in @('Start', 'Pruefen')) {
        Show-Step 'PostgreSQL: tests.sql'
        Invoke-Psql 'lernpfad' @('-f', '/work/le2-sql/tests.sql')
        Show-Step 'Python: Import, Generator und K1 (pytest)'
        Invoke-Python @('-m', 'pytest', '-q')
    }

    if ($Aktion -in @('Start', 'Abfragen')) {
        Show-Step 'PostgreSQL: queries.sql'
        Invoke-Psql 'lernpfad' @('-f', '/work/le2-sql/queries.sql')
        Show-Step 'Neo4j: A-001 bis A-005 im Vergleich'
        Invoke-Python @('-m', 'src.queries')
    }

    if ($Aktion -eq 'Messen') {
        Show-Step 'Messung K2 und K3 (dauert einige Minuten)'
        Invoke-Python @('-m', 'src.benchmark')
    }

    Write-Host ''
    Write-Host 'Fertig.'
    Write-Host 'Neo4j Browser:  http://localhost:7474  (neo4j / ddi_lokal_demo)'
    Write-Host 'Weitere Aktionen: -Aktion Pruefen | Abfragen | Messen | Shell | Cypher | Stop'
} catch {
    Write-Host ''
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
