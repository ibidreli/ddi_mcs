param(
    [ValidateSet('Start', 'Pruefen', 'Abfragen', 'Shell', 'Export', 'Stop')]
    [string]$Aktion = 'Start'
)

$ErrorActionPreference = 'Stop'
$ComposeArgs = @('compose', '--project-directory', $PSScriptRoot, '-f', (Join-Path $PSScriptRoot 'compose.yaml'))
$ResultDir = Join-Path $PSScriptRoot 'ergebnisse'
$Utf8 = [System.Text.UTF8Encoding]::new($false)

function Invoke-Docker([string[]]$Arguments) {
    # Compose schreibt normale Fortschrittsmeldungen ebenfalls auf stderr.
    $ErrorActionPreference = 'Continue'
    & docker @Arguments
    $ResultCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($ResultCode -ne 0) { throw "Docker-Aufruf fehlgeschlagen (Exitcode $ResultCode)." }
}

function Invoke-SqlFile([string]$File) {
    $Arguments = $ComposeArgs + @('exec', '-T', 'db', 'psql', '-X', '-U', 'ddi', '-d', 'le2', '-v', 'ON_ERROR_STOP=1', '-f', "/work/$File")
    # Windows PowerShell 5 behandelt selbst erfolgreiche psql-NOTICEs auf
    # stderr als ErrorRecords. Entscheidend ist deshalb der native Exitcode.
    $ErrorActionPreference = 'Continue'
    $Lines = & docker @Arguments 2>&1
    $ResultCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    $Lines | ForEach-Object { Write-Host "$_" }
    if ($ResultCode -ne 0) { throw "$File fehlgeschlagen. Siehe Terminalausgabe." }
}

function Export-Data {
    $Query = 'SELECT jsonb_pretty(payload) FROM le2.export_data;'
    $Arguments = $ComposeArgs + @('exec', '-T', 'db', 'psql', '-X', '-U', 'ddi', '-d', 'le2', '-v', 'ON_ERROR_STOP=1', '-A', '-t', '-c', $Query)
    $Lines = & docker @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'JSON-Export fehlgeschlagen.' }
    $Json = $Lines -join "`n"
    $null = ConvertFrom-Json -InputObject $Json
    $null = New-Item -ItemType Directory -Force -Path $ResultDir
    [System.IO.File]::WriteAllText((Join-Path $ResultDir 'datenexport.json'), $Json + "`n", $Utf8)
    Write-Host 'Export: ergebnisse/datenexport.json'
}

try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker Desktop fehlt. Bitte installieren/starten und erneut ausfuehren.'
    }
    & docker info --format '{{.ServerVersion}}' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Bitte Docker Desktop starten und auf die laufende Engine warten.' }
    if ($Aktion -eq 'Stop') {
        Invoke-Docker ($ComposeArgs + @('stop'))
        exit 0
    }
    if ($Aktion -eq 'Shell') {
        Invoke-Docker ($ComposeArgs + @('exec', 'db', 'psql', '-X', '-U', 'ddi', '-d', 'le2'))
        exit 0
    }
    if ($Aktion -eq 'Start') {
        Invoke-Docker ($ComposeArgs + @('up', '-d', '--wait', '--wait-timeout', '90'))
        Invoke-SqlFile 'datenbank.sql'
    }
    if ($Aktion -in @('Start', 'Pruefen')) {
        Invoke-SqlFile 'pruefung.sql'
    }
    if ($Aktion -in @('Start', 'Abfragen')) {
        Invoke-SqlFile 'abfragen.sql'
    }
    if ($Aktion -eq 'Export') { Export-Data }
    Write-Host ''
    Write-Host 'Fertig. Bericht und Startplan im Projektordner: LE2_DRAFT.md'
    Write-Host 'Im Projektordner: .\le2\start.ps1 -Aktion Shell'
    Write-Host 'Beenden:          .\le2\start.ps1 -Aktion Stop (Daten bleiben erhalten)'
} catch {
    Write-Error $_
    exit 1
}
