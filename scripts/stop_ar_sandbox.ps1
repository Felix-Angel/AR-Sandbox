$ErrorActionPreference = 'Stop'
$runtimeDir = Join-Path $env:LOCALAPPDATA 'AR Sandbox\runtime'
$registryPath = Join-Path $runtimeDir 'started-processes.json'

if (-not (Test-Path -LiteralPath $registryPath)) {
    Write-Host 'No hay procesos registrados de AR Sandbox. No se detuvo ningún proceso.'
    exit 0
}

try {
    $rawRegistry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Host "ERROR: No se pudo leer el registro $registryPath; no se detuvo ningún proceso." -ForegroundColor Red
    exit 1
}

# ConvertFrom-Json puede devolver un objeto (un proceso), un array de objetos,
# o registros antiguos que contengan arrays anidados. Aplanamos registros,
# pero procesamos el valor de cada PID individualmente más abajo.
$registryEntries = @()
$pendingEntries = New-Object 'System.Collections.Generic.Stack[object]'
foreach ($item in @($rawRegistry)) { $pendingEntries.Push($item) }
while ($pendingEntries.Count -gt 0) {
    $item = $pendingEntries.Pop()
    if ($null -eq $item) { continue }
    if ($item -is [System.Array] -or $item -is [System.Collections.ArrayList]) {
        foreach ($nestedItem in $item) { $pendingEntries.Push($nestedItem) }
    } else {
        $registryEntries += $item
    }
}

$remainingProcesses = @()
$hadErrors = $false
$orderedEntries = @($registryEntries | Sort-Object @{ Expression = { if ($_.name -eq 'frontend') { 0 } else { 1 } } })
foreach ($entry in $orderedEntries) {
    $pids = @($entry.pid)
    $startTimes = @($entry.startTimeUtcTicks)

    if ($pids.Count -eq 0 -or $startTimes.Count -eq 0 -or ($pids.Count -gt 1 -and $startTimes.Count -ne $pids.Count)) {
        Write-Host "ERROR: Registro inválido para '$($entry.name)'; se conserva para revisión." -ForegroundColor Yellow
        $remainingProcesses += $entry
        $hadErrors = $true
        continue
    }

    for ($index = 0; $index -lt $pids.Count; $index++) {
        $pidValue = 0
        $ticksValue = 0L
        $tickIndex = if ($startTimes.Count -eq 1) { 0 } else { $index }
        $pidValid = [int]::TryParse([string]$pids[$index], [ref]$pidValue) -and $pidValue -gt 0
        $ticksValid = [long]::TryParse([string]$startTimes[$tickIndex], [ref]$ticksValue) -and $ticksValue -gt 0

        if (-not $pidValid -or -not $ticksValid) {
            Write-Host "ERROR: PID u hora de inicio inválidos en '$($entry.name)'; se conserva la entrada." -ForegroundColor Yellow
            $remainingProcesses += [pscustomobject]@{
                name = $entry.name
                pid = $pids[$index]
                startTimeUtcTicks = $startTimes[$tickIndex]
            }
            $hadErrors = $true
            continue
        }

        $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
        if (-not $process) {
            Write-Host "$($entry.name): PID $pidValue ya estaba detenido."
            continue
        }

        try {
            $actualStartTicks = $process.StartTime.ToUniversalTime().Ticks
        } catch {
            Write-Host "$($entry.name): no se pudo verificar el PID $pidValue; se deja intacto y se conserva su registro." -ForegroundColor Yellow
            $remainingProcesses += [pscustomobject]@{ name = $entry.name; pid = $pidValue; startTimeUtcTicks = $ticksValue }
            $hadErrors = $true
            continue
        }

        if ($actualStartTicks -ne $ticksValue) {
            Write-Host "$($entry.name): el PID $pidValue pertenece ahora a otro proceso; se deja intacto." -ForegroundColor Yellow
            continue
        }

        & taskkill.exe /PID $pidValue /T /F | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Start-Sleep -Milliseconds 300
            $stillRunning = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
            if (-not $stillRunning) {
                Write-Host "$($entry.name): PID $pidValue detenido."
                continue
            }

            try {
                $stillRunningTicks = $stillRunning.StartTime.ToUniversalTime().Ticks
            } catch {
                $stillRunningTicks = $ticksValue
            }
            if ($stillRunningTicks -ne $ticksValue) {
                Write-Host "$($entry.name): el proceso original terminó; el PID $pidValue ya pertenece a otra ejecución."
                continue
            }

            Write-Host "$($entry.name): PID $pidValue sigue activo; se conserva para reintentar." -ForegroundColor Yellow
            $remainingProcesses += [pscustomobject]@{ name = $entry.name; pid = $pidValue; startTimeUtcTicks = $ticksValue }
            $hadErrors = $true
        } else {
            Write-Host "$($entry.name): Windows no pudo detener el PID $pidValue; se conserva para reintentar." -ForegroundColor Yellow
            $remainingProcesses += [pscustomobject]@{ name = $entry.name; pid = $pidValue; startTimeUtcTicks = $ticksValue }
            $hadErrors = $true
        }
    }
}

if ($remainingProcesses.Count -gt 0) {
    ConvertTo-Json -InputObject @($remainingProcesses) -Depth 4 | Set-Content -LiteralPath $registryPath -Encoding UTF8
} else {
    Remove-Item -LiteralPath $registryPath -Force
}

if ($hadErrors) {
    Write-Host "Detención parcial. Vuelve a ejecutar este script; el registro pendiente está en $registryPath." -ForegroundColor Yellow
    exit 1
}

Write-Host 'Detención terminada. No se finalizaron las instancias que ya funcionaban antes del inicio.' -ForegroundColor Green
