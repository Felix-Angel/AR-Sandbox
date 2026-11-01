$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$backendDir = Join-Path $projectRoot 'backend'
$frontendDir = Join-Path $projectRoot 'visualizacion_3d'
$pythonExe = Join-Path $backendDir 'venv\Scripts\python.exe'
$npmCommand = (Get-Command 'npm.cmd' -ErrorAction SilentlyContinue).Source
$runtimeDir = Join-Path $env:LOCALAPPDATA 'AR Sandbox\runtime'
$registryPath = Join-Path $runtimeDir 'started-processes.json'
$backendUrl = 'http://127.0.0.1:8000/health'
$frontendUrl = 'http://127.0.0.1:5173/'

function Test-Service([string] $Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 400
    } catch {
        return $false
    }
}

function Wait-Service([string] $Url, [string] $Name) {
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        if (Test-Service $Url) { return $true }
        Start-Sleep -Milliseconds 500
    }
    Write-Host "ERROR: $Name no respondió en 30 segundos ($Url)." -ForegroundColor Red
    return $false
}

function Save-Registry {
    ConvertTo-Json -InputObject @($script:trackedProcesses) -Depth 4 |
        Set-Content -LiteralPath $registryPath -Encoding UTF8
}

function Register-StartedProcess([string] $Name, [System.Diagnostics.Process] $Process) {
    Start-Sleep -Milliseconds 300
    $Process.Refresh()
    if ($Process.HasExited) {
        throw "No se pudo iniciar $Name. Revisa los registros en $runtimeDir."
    }
    $script:trackedProcesses = @($script:trackedProcesses | Where-Object { $_.name -ne $Name })
    $script:trackedProcesses += [pscustomobject]@{
        name = $Name
        pid = $Process.Id
        startTimeUtcTicks = $Process.StartTime.ToUniversalTime().Ticks
    }
    Save-Registry
}

if (-not (Test-Path -LiteralPath $pythonExe)) {
    Write-Host "ERROR: No se encontró el Python del entorno virtual: $pythonExe" -ForegroundColor Red
    exit 1
}
if (-not $npmCommand -or -not (Test-Path -LiteralPath (Join-Path $frontendDir 'node_modules'))) {
    Write-Host 'ERROR: No se encontró npm.cmd o visualizacion_3d/node_modules. No se instalaron dependencias.' -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
$launcherMutex = New-Object System.Threading.Mutex($false, 'Local\ARSandboxLauncher')
$mutexAcquired = $false
try {
    try {
        $mutexAcquired = $launcherMutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexAcquired = $true
    }
    if (-not $mutexAcquired) {
        Write-Host 'El inicio ya está en curso; no se abrirá otra instancia.' -ForegroundColor Yellow
        exit 0
    }

$script:trackedProcesses = @()
if (Test-Path -LiteralPath $registryPath) {
    try {
        $script:trackedProcesses = @(Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json)
    } catch {
        Write-Host "ERROR: No se pudo leer el registro de procesos $registryPath. No iniciaré servidores para evitar duplicados." -ForegroundColor Red
        exit 1
    }
}

$backendReady = Test-Service $backendUrl
if ($backendReady) {
    Write-Host 'FastAPI ya está disponible en http://127.0.0.1:8000; se reutilizará la instancia existente.'
} else {
    Write-Host 'Iniciando FastAPI...'
    try {
        $backendProcess = Start-Process -FilePath $pythonExe `
            -ArgumentList @('-m', 'uvicorn', 'main:app', '--host', '127.0.0.1', '--port', '8000') `
            -WorkingDirectory $backendDir -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $runtimeDir 'backend.stdout.log') `
            -RedirectStandardError (Join-Path $runtimeDir 'backend.stderr.log')
        Register-StartedProcess 'backend' $backendProcess
        $backendReady = Wait-Service $backendUrl 'FastAPI'
    } catch {
        Write-Host "ERROR: Falló el inicio de FastAPI: $($_.Exception.Message)" -ForegroundColor Red
    }
}

$frontendReady = Test-Service $frontendUrl
if ($frontendReady) {
    Write-Host 'Vue/Vite ya está disponible en http://127.0.0.1:5173; se reutilizará la instancia existente.'
} else {
    Write-Host 'Iniciando Vue/Vite...'
    try {
        $frontendProcess = Start-Process -FilePath $env:ComSpec `
            -ArgumentList '/d /s /c "npm.cmd run dev -- --host 127.0.0.1"' `
            -WorkingDirectory $frontendDir -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $runtimeDir 'frontend.stdout.log') `
            -RedirectStandardError (Join-Path $runtimeDir 'frontend.stderr.log')
        Register-StartedProcess 'frontend' $frontendProcess
        $frontendReady = Wait-Service $frontendUrl 'Vue/Vite'
    } catch {
        Write-Host "ERROR: Falló el inicio de Vue/Vite: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($backendReady -and $frontendReady) {
    Write-Host 'Backend y frontend están disponibles. Abriendo la ventana de controles...'
    try {
        Start-Process $frontendUrl | Out-Null
    } catch {
        Write-Host "No se pudo abrir el navegador automáticamente. Abre $frontendUrl manualmente." -ForegroundColor Yellow
    }
    Write-Host 'Listo. Para abrir proyección, usa el botón «Abrir ventana de proyección» en controles.' -ForegroundColor Green
    exit 0
}

Write-Host 'AR Sandbox no pudo iniciar todos los servicios; revisa los mensajes anteriores y los registros en:' -ForegroundColor Red
Write-Host $runtimeDir
Write-Host 'Usa stop_ar_sandbox.ps1 para detener solamente los procesos iniciados por este script.'
exit 1
} finally {
    if ($mutexAcquired) { $launcherMutex.ReleaseMutex() }
    $launcherMutex.Dispose()
}
