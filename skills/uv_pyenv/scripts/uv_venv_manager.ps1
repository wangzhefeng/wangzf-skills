param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('init', 'sync', 'add', 'remove', 'lock', 'list')]
    [string]$Action,
    [string]$ProjectPath = (Get-Location).Path,
    [string]$Packages = '',
    [string]$PythonVersion = '3.12'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Uv {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        throw 'uv is required but not found in PATH.'
    }
}

function Parse-Packages([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }
    return @($raw.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}

function Normalize-MajorMinor([string]$ver) {
    $m = [regex]::Match($ver, '^(\d+)\.(\d+)')
    if (-not $m.Success) { throw "Invalid PythonVersion: $ver" }
    return "$($m.Groups[1].Value).$($m.Groups[2].Value)"
}

function Update-RequiresPython([string]$projectFile, [string]$targetVersion) {
    $targetMM = Normalize-MajorMinor $targetVersion
    $newReq = ">=$targetMM"
    $content = Get-Content -Path $projectFile -Raw

    if ($content -match '(?m)^requires-python\s*=\s*"[^"]*"\s*$') {
        $updated = [regex]::Replace($content, '(?m)^requires-python\s*=\s*"[^"]*"\s*$', "requires-python = `"$newReq`"")
        Set-Content -Path $projectFile -Value $updated -Encoding UTF8
        return
    }

    if ($content -match '(?m)^\[project\]\s*$') {
        $updated = [regex]::Replace($content, '(?m)^\[project\]\s*$', "[project]`r`nrequires-python = `"$newReq`"", 1)
        Set-Content -Path $projectFile -Value $updated -Encoding UTF8
        return
    }

    throw 'Unable to update requires-python: [project] section not found.'
}

function Invoke-Uv {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & uv @Args
    if ($LASTEXITCODE -ne 0) {
        throw "uv command failed: uv $($Args -join ' ')"
    }
}

function Invoke-UvProject {
    param(
        [string]$Project,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args
    )
    & uv --project $Project @Args
    if ($LASTEXITCODE -ne 0) {
        throw "uv command failed: uv --project $Project $($Args -join ' ')"
    }
}

function Find-LockFile([string]$startPath) {
    $current = (Resolve-Path $startPath).Path
    while ($true) {
        $candidate = Join-Path $current 'uv.lock'
        if (Test-Path $candidate) { return $candidate }
        $parent = Split-Path -Path $current -Parent
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
    }
    return $null
}

function Require-ProjectFiles([string]$project) {
    $pyproject = Join-Path $project 'pyproject.toml'
    if (-not (Test-Path $pyproject)) {
        throw "pyproject.toml not found in $project. Run init first."
    }
}

Ensure-Uv
$project = (Resolve-Path -Path $ProjectPath).Path

Push-Location $project
try {
    switch ($Action) {
        'init' {
            if (-not (Test-Path 'pyproject.toml')) {
                $projectName = Split-Path -Path $project -Leaf
                Invoke-Uv init --bare --no-workspace --name $projectName .
            }

            Update-RequiresPython (Join-Path $project 'pyproject.toml') $PythonVersion
            Invoke-UvProject $project python pin $PythonVersion

            if (Test-Path '.venv') {
                Remove-Item -Path '.venv' -Recurse -Force
            }

            try {
                Invoke-UvProject $project sync
            }
            catch {
                Invoke-UvProject $project lock
                Invoke-UvProject $project sync
            }

            $lockPath = Find-LockFile $project
            if (-not $lockPath) { throw 'uv.lock was not created in project/workspace hierarchy.' }
            if (-not (Test-Path '.python-version')) { throw '.python-version was not created.' }
            if (-not (Test-Path '.venv')) { throw '.venv was not created.' }

            Write-Output "Initialized/recreated uv project at: $project"
            Write-Output "Lockfile path: $lockPath"
            Write-Output "Pinned Python via .python-version, updated requires-python, recreated .venv, and synced dependencies."
        }
        'sync' {
            Require-ProjectFiles $project
            Invoke-UvProject $project sync
            Write-Output 'Synced environment from lock state'
        }
        'add' {
            Require-ProjectFiles $project
            [string[]]$pkgs = @(Parse-Packages $Packages)
            if ($pkgs.Count -eq 0) { throw 'add requires -Packages, e.g. -Packages "requests,pytest"' }
            Invoke-UvProject $project add @pkgs
            Write-Output 'Added package(s) and updated lock state'
        }
        'remove' {
            Require-ProjectFiles $project
            [string[]]$pkgs = @(Parse-Packages $Packages)
            if ($pkgs.Count -eq 0) { throw 'remove requires -Packages, e.g. -Packages "requests"' }
            Invoke-UvProject $project remove @pkgs
            Write-Output 'Removed package(s) and updated lock state'
        }
        'lock' {
            Require-ProjectFiles $project
            Invoke-UvProject $project lock
            Write-Output 'Updated lockfile'
        }
        'list' {
            Require-ProjectFiles $project
            Invoke-UvProject $project tree
        }
    }
}
finally {
    Pop-Location
}
