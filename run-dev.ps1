param(
    [ValidateSet("start", "stop", "restart", "status", "logs")]
    [string]$Action = "start",
    [ValidateSet("frontend", "backend", "all")]
    [string]$Target = "all",
    [switch]$Follow
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FrontendDir = Join-Path $RootDir "frontend"
$BackendDir = Join-Path $RootDir "backend"
$BackendPython = Join-Path $BackendDir "venv\Scripts\python.exe"
$StateDir = Join-Path $env:TEMP "web_stock_trainning_dev_state"
$FrontendPidFile = Join-Path $StateDir "frontend.pid"
$BackendPidFile = Join-Path $StateDir "backend.pid"
$FrontendOutLogFile = Join-Path $StateDir "frontend.out.log"
$FrontendErrLogFile = Join-Path $StateDir "frontend.err.log"
$BackendOutLogFile = Join-Path $StateDir "backend.out.log"
$BackendErrLogFile = Join-Path $StateDir "backend.err.log"

function Ensure-StateDir {
    if (-not (Test-Path $StateDir)) {
        New-Item -Path $StateDir -ItemType Directory | Out-Null
    }
}

function Read-PidFile([string]$PidFile) {
    if (-not (Test-Path $PidFile)) {
        return $null
    }
    $raw = (Get-Content -Path $PidFile -Raw).Trim()
    if (-not $raw) {
        return $null
    }
    $pidValue = 0
    if ([int]::TryParse($raw, [ref]$pidValue)) {
        return $pidValue
    }
    return $null
}

function Write-PidFile([string]$PidFile, [int]$PidValue) {
    Set-Content -Path $PidFile -Value $PidValue -Encoding Ascii
}

function Remove-PidFile([string]$PidFile) {
    if (Test-Path $PidFile) {
        Remove-Item -Path $PidFile -Force
    }
}

function Is-ProcessAlive([int]$PidValue) {
    try {
        Get-Process -Id $PidValue -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-ListeningPidByPort([int]$Port) {
    $line = netstat -ano -p tcp | Select-String -Pattern (":$Port\s+.*LISTENING\s+(\d+)$") | Select-Object -First 1
    if (-not $line) {
        return $null
    }
    if ($line.Matches.Count -gt 0) {
        return [int]$line.Matches[0].Groups[1].Value
    }
    return $null
}

function Stop-ProcessTree([int]$PidValue) {
    if (-not (Is-ProcessAlive $PidValue)) {
        return $true
    }

    cmd /c "taskkill /PID $PidValue /T /F" | Out-Null
    Start-Sleep -Milliseconds 500
    if (-not (Is-ProcessAlive $PidValue)) {
        return $true
    }

    try {
        Stop-Process -Id $PidValue -Force -ErrorAction Stop
    } catch {
        # keep checking below
    }
    Start-Sleep -Milliseconds 300
    return (-not (Is-ProcessAlive $PidValue))
}

function Wait-HttpReady([string]$Url, [int]$TimeoutSec = 45) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $res = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 3
            if ($res.StatusCode -ge 200 -and $res.StatusCode -lt 500) {
                return $true
            }
        } catch {
            # keep waiting
        }
        Start-Sleep -Milliseconds 600
    }
    return $false
}

function Sync-TrackedPidWithPort([string]$Name, [string]$PidFile, [int]$Port) {
    $trackedPid = Read-PidFile $PidFile
    $portPid = Get-ListeningPidByPort $Port
    if ($portPid) {
        if (-not $trackedPid -or $trackedPid -ne $portPid) {
            Write-PidFile -PidFile $PidFile -PidValue $portPid
            Write-Output "[$Name] synced tracked pid -> $portPid (port $Port)"
        }
    } elseif ($trackedPid -and -not (Is-ProcessAlive $trackedPid)) {
        Remove-PidFile $PidFile
    }
}

function Start-Backend {
    Ensure-StateDir
    if (-not (Test-Path $BackendPython)) {
        throw "Backend python not found: $BackendPython"
    }

    $trackedPid = Read-PidFile $BackendPidFile
    $portPid = Get-ListeningPidByPort 8000
    if ($trackedPid -and (Is-ProcessAlive $trackedPid) -and $portPid -and $trackedPid -eq $portPid) {
        Write-Output "[backend] already running (pid=$trackedPid)"
        return
    }

    if ($trackedPid -and -not (Is-ProcessAlive $trackedPid)) {
        Remove-PidFile $BackendPidFile
        $trackedPid = $null
    }

    if ($portPid) {
        if (-not $trackedPid -or $trackedPid -ne $portPid) {
            Write-Warning "[backend] port 8000 occupied by stale/untracked pid=$portPid. Replacing with latest process."
            Stop-ProcessTree -PidValue $portPid
            Start-Sleep -Milliseconds 800
            $portPid = Get-ListeningPidByPort 8000
            if ($portPid) {
                throw "[backend] failed to release port 8000 (pid=$portPid)"
            }
        }
    }

    foreach ($log in @($BackendOutLogFile, $BackendErrLogFile)) {
        if (Test-Path $log) {
            Remove-Item -Path $log -Force
        }
    }

    $proc = Start-Process -FilePath $BackendPython `
        -ArgumentList "-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", "8000" `
        -WorkingDirectory $BackendDir `
        -RedirectStandardOutput $BackendOutLogFile `
        -RedirectStandardError $BackendErrLogFile `
        -PassThru

    if (Wait-HttpReady -Url "http://127.0.0.1:8000/api/v1/health" -TimeoutSec 50) {
        $listenPid = Get-ListeningPidByPort 8000
        if ($listenPid) {
            Write-PidFile -PidFile $BackendPidFile -PidValue $listenPid
            Write-Output "[backend] started (pid=$listenPid, url=http://127.0.0.1:8000)"
        } else {
            Write-PidFile -PidFile $BackendPidFile -PidValue $proc.Id
            Write-Warning "[backend] health ok but listening pid lookup failed. fallback pid=$($proc.Id)"
        }
    } else {
        Write-PidFile -PidFile $BackendPidFile -PidValue $proc.Id
        Write-Warning "[backend] started process but health check timed out. See logs: $BackendOutLogFile / $BackendErrLogFile"
    }
}

function Start-Frontend {
    Ensure-StateDir
    $trackedPid = Read-PidFile $FrontendPidFile
    $portPid = Get-ListeningPidByPort 3000
    if ($trackedPid -and (Is-ProcessAlive $trackedPid) -and $portPid -and $trackedPid -eq $portPid) {
        Write-Output "[frontend] already running (pid=$trackedPid)"
        return
    }

    if ($trackedPid -and -not (Is-ProcessAlive $trackedPid)) {
        Remove-PidFile $FrontendPidFile
        $trackedPid = $null
    }

    if ($portPid) {
        if (-not $trackedPid -or $trackedPid -ne $portPid) {
            Write-Warning "[frontend] port 3000 occupied by stale/untracked pid=$portPid. Replacing with latest process."
            Stop-ProcessTree -PidValue $portPid
            Start-Sleep -Milliseconds 800
            $portPid = Get-ListeningPidByPort 3000
            if ($portPid) {
                throw "[frontend] failed to release port 3000 (pid=$portPid)"
            }
        }
    }

    foreach ($log in @($FrontendOutLogFile, $FrontendErrLogFile)) {
        if (Test-Path $log) {
            Remove-Item -Path $log -Force
        }
    }

    $proc = Start-Process -FilePath "npm.cmd" `
        -ArgumentList "run", "dev", "--", "--hostname", "127.0.0.1", "--port", "3000" `
        -WorkingDirectory $FrontendDir `
        -RedirectStandardOutput $FrontendOutLogFile `
        -RedirectStandardError $FrontendErrLogFile `
        -PassThru

    if (Wait-HttpReady -Url "http://127.0.0.1:3000" -TimeoutSec 70) {
        $listenPid = Get-ListeningPidByPort 3000
        if ($listenPid) {
            Write-PidFile -PidFile $FrontendPidFile -PidValue $listenPid
            Write-Output "[frontend] started (pid=$listenPid, url=http://127.0.0.1:3000)"
        } else {
            Write-PidFile -PidFile $FrontendPidFile -PidValue $proc.Id
            Write-Warning "[frontend] ready check ok but listening pid lookup failed. fallback pid=$($proc.Id)"
        }
    } else {
        Write-PidFile -PidFile $FrontendPidFile -PidValue $proc.Id
        Write-Warning "[frontend] started process but readiness timed out. See logs: $FrontendOutLogFile / $FrontendErrLogFile"
    }
}

function Stop-Backend {
    $trackedPid = Read-PidFile $BackendPidFile
    $portPid = Get-ListeningPidByPort 8000
    $targets = @()
    if ($trackedPid) { $targets += $trackedPid }
    if ($portPid -and ($targets -notcontains $portPid)) { $targets += $portPid }

    if ($targets.Count -gt 0) {
        foreach ($procPid in $targets) {
            $ok = Stop-ProcessTree -PidValue $procPid
            if ($ok) {
                Write-Output "[backend] stopped (pid=$procPid)"
            } else {
                Write-Warning "[backend] failed to stop pid=$procPid"
            }
        }
        Remove-PidFile $BackendPidFile
    } else {
        Write-Output "[backend] no tracked process"
    }

    $leftPortPid = Get-ListeningPidByPort 8000
    if ($leftPortPid) {
        $ok = Stop-ProcessTree -PidValue $leftPortPid
        if ($ok) {
            Write-Output "[backend] stopped remaining port process (pid=$leftPortPid)"
        } else {
            Write-Warning "[backend] port 8000 still occupied by pid=$leftPortPid"
        }
    }

    Sync-TrackedPidWithPort -Name "backend" -PidFile $BackendPidFile -Port 8000
}

function Stop-Frontend {
    $trackedPid = Read-PidFile $FrontendPidFile
    $portPid = Get-ListeningPidByPort 3000
    $targets = @()
    if ($trackedPid) { $targets += $trackedPid }
    if ($portPid -and ($targets -notcontains $portPid)) { $targets += $portPid }

    if ($targets.Count -gt 0) {
        foreach ($procPid in $targets) {
            $ok = Stop-ProcessTree -PidValue $procPid
            if ($ok) {
                Write-Output "[frontend] stopped (pid=$procPid)"
            } else {
                Write-Warning "[frontend] failed to stop pid=$procPid"
            }
        }
        Remove-PidFile $FrontendPidFile
    } else {
        Write-Output "[frontend] no tracked process"
    }

    $leftPortPid = Get-ListeningPidByPort 3000
    if ($leftPortPid) {
        $ok = Stop-ProcessTree -PidValue $leftPortPid
        if ($ok) {
            Write-Output "[frontend] stopped remaining port process (pid=$leftPortPid)"
        } else {
            Write-Warning "[frontend] port 3000 still occupied by pid=$leftPortPid"
        }
    }

    Sync-TrackedPidWithPort -Name "frontend" -PidFile $FrontendPidFile -Port 3000
}

function Show-Status {
    Sync-TrackedPidWithPort -Name "frontend" -PidFile $FrontendPidFile -Port 3000
    Sync-TrackedPidWithPort -Name "backend" -PidFile $BackendPidFile -Port 8000
    $frontendPid = Read-PidFile $FrontendPidFile
    $backendPid = Read-PidFile $BackendPidFile
    $frontendPortPid = Get-ListeningPidByPort 3000
    $backendPortPid = Get-ListeningPidByPort 8000

    Write-Output "== Dev Server Status =="
    Write-Output ("frontend: trackedPid={0}, trackedAlive={1}, port3000Pid={2}" -f `
            ($(if ($frontendPid) { $frontendPid } else { "-" })), `
            ($(if ($frontendPid) { Is-ProcessAlive $frontendPid } else { $false })), `
            ($(if ($frontendPortPid) { $frontendPortPid } else { "-" })))
    Write-Output ("backend : trackedPid={0}, trackedAlive={1}, port8000Pid={2}" -f `
            ($(if ($backendPid) { $backendPid } else { "-" })), `
            ($(if ($backendPid) { Is-ProcessAlive $backendPid } else { $false })), `
            ($(if ($backendPortPid) { $backendPortPid } else { "-" })))
    Write-Output "frontend url: http://127.0.0.1:3000"
    Write-Output "backend  url: http://127.0.0.1:8000/api/v1/health"
}

function Show-Logs {
    Ensure-StateDir
    if ($Target -in @("frontend", "all")) {
        if ((Test-Path $FrontendOutLogFile) -or (Test-Path $FrontendErrLogFile)) {
            Write-Output "== frontend stdout: $FrontendOutLogFile =="
            if ($Follow) {
                if (Test-Path $FrontendOutLogFile) { Get-Content -Path $FrontendOutLogFile -Tail 80 }
                Write-Output "== frontend stderr (follow): $FrontendErrLogFile =="
                if (Test-Path $FrontendErrLogFile) {
                    Get-Content -Path $FrontendErrLogFile -Tail 80 -Wait
                }
            } else {
                if (Test-Path $FrontendOutLogFile) { Get-Content -Path $FrontendOutLogFile -Tail 80 }
                Write-Output "== frontend stderr: $FrontendErrLogFile =="
                if (Test-Path $FrontendErrLogFile) { Get-Content -Path $FrontendErrLogFile -Tail 80 }
            }
        } else {
            Write-Output "frontend log not found."
        }
    }
    if ($Target -in @("backend", "all")) {
        if ((Test-Path $BackendOutLogFile) -or (Test-Path $BackendErrLogFile)) {
            Write-Output "== backend stdout: $BackendOutLogFile =="
            if ($Follow) {
                if (Test-Path $BackendOutLogFile) { Get-Content -Path $BackendOutLogFile -Tail 80 }
                Write-Output "== backend stderr (follow): $BackendErrLogFile =="
                if (Test-Path $BackendErrLogFile) {
                    Get-Content -Path $BackendErrLogFile -Tail 80 -Wait
                }
            } else {
                if (Test-Path $BackendOutLogFile) { Get-Content -Path $BackendOutLogFile -Tail 80 }
                Write-Output "== backend stderr: $BackendErrLogFile =="
                if (Test-Path $BackendErrLogFile) { Get-Content -Path $BackendErrLogFile -Tail 80 }
            }
        } else {
            Write-Output "backend log not found."
        }
    }
}

switch ($Action) {
    "start" {
        if ($Target -in @("backend", "all")) { Start-Backend }
        if ($Target -in @("frontend", "all")) { Start-Frontend }
        Show-Status
    }
    "stop" {
        if ($Target -in @("frontend", "all")) { Stop-Frontend }
        if ($Target -in @("backend", "all")) { Stop-Backend }
        Show-Status
    }
    "restart" {
        if ($Target -in @("frontend", "all")) { Stop-Frontend }
        if ($Target -in @("backend", "all")) { Stop-Backend }
        if ($Target -in @("backend", "all")) { Start-Backend }
        if ($Target -in @("frontend", "all")) { Start-Frontend }
        Show-Status
    }
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs
    }
}
