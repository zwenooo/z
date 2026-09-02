param(
    [string]$Root,
    [switch]$All,
    [string[]]$Profiles,
    [switch]$DryRun,
    [switch]$List,
    [switch]$Restore,
    [string]$BackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ProfileDefinitions = [ordered]@{
    "node" = @{
        Label = "Node.js package caches"
        Variables = [ordered]@{
            "npm_config_cache" = "node\npm-cache"
            "PNPM_HOME"        = "node\pnpm-home"
            "XDG_DATA_HOME"    = "xdg\data"
            "XDG_CACHE_HOME"   = "xdg\cache"
        }
        Notes = @(
            "npm uses npm_config_cache.",
            "pnpm also reads PNPM_HOME for global binaries.",
            "XDG_* is used by many cross-platform developer tools."
        )
    }
    "python" = @{
        Label = "Python pip and virtualenv caches"
        Variables = [ordered]@{
            "PIP_CACHE_DIR"       = "python\pip-cache"
            "WORKON_HOME"         = "python\virtualenvs"
            "POETRY_CACHE_DIR"    = "python\poetry-cache"
            "PDM_CACHE_DIR"       = "python\pdm-cache"
            "UV_CACHE_DIR"        = "python\uv-cache"
            "RYE_HOME"            = "python\rye"
        }
        Notes = @(
            "Existing virtualenvs are not moved.",
            "New pip/poetry/pdm/uv caches will prefer the configured paths."
        )
    }
    "rust" = @{
        Label = "Rust cargo and rustup homes"
        Variables = [ordered]@{
            "CARGO_HOME"  = "rust\cargo"
            "RUSTUP_HOME" = "rust\rustup"
        }
        Notes = @(
            "This affects future rustup/cargo operations.",
            "Move existing .cargo/.rustup manually if you need to preserve installed toolchains."
        )
    }
    "go" = @{
        Label = "Go module and build caches"
        Variables = [ordered]@{
            "GOMODCACHE" = "go\pkg\mod"
            "GOCACHE"   = "go\build-cache"
        }
        Notes = @(
            "Go also uses GOPATH; this tool only moves heavy module/build caches."
        )
    }
    "java" = @{
        Label = "Java build caches"
        Variables = [ordered]@{
            "GRADLE_USER_HOME" = "java\gradle"
            "MAVEN_OPTS"       = "-Dmaven.repo.local={root}\java\maven-repo"
        }
        Notes = @(
            "Maven has no standard environment variable for repository path.",
            "This sets MAVEN_OPTS with -Dmaven.repo.local."
        )
    }
    "dotnet" = @{
        Label = ".NET NuGet packages"
        Variables = [ordered]@{
            "NUGET_PACKAGES" = "dotnet\nuget-packages"
        }
        Notes = @(
            "Existing NuGet packages are not moved automatically."
        )
    }
    "android" = @{
        Label = "Android SDK and Gradle-related caches"
        Variables = [ordered]@{
            "ANDROID_USER_HOME" = "android\user-home"
            "ANDROID_AVD_HOME"  = "android\avd"
        }
        Notes = @(
            "This does not move an installed Android SDK.",
            "AVDs can be large; create/move emulators carefully."
        )
    }
    "electron" = @{
        Label = "Electron and Playwright caches"
        Variables = [ordered]@{
            "ELECTRON_CACHE"              = "electron\cache"
            "ELECTRON_BUILDER_CACHE"      = "electron\builder-cache"
            "PLAYWRIGHT_BROWSERS_PATH"    = "playwright\browsers"
            "PUPPETEER_CACHE_DIR"         = "puppeteer\cache"
        }
        Notes = @(
            "Browsers already downloaded under C: are not moved automatically.",
            "New Playwright/Puppeteer browser downloads will use these paths."
        )
    }
    "ai" = @{
        Label = "AI/model/tool caches"
        Variables = [ordered]@{
            "HF_HOME"             = "ai\huggingface"
            "TRANSFORMERS_CACHE"  = "ai\huggingface\transformers"
            "HUGGINGFACE_HUB_CACHE" = "ai\huggingface\hub"
            "MODELSCOPE_CACHE"    = "ai\modelscope"
            "TORCH_HOME"          = "ai\torch"
        }
        Notes = @(
            "Useful for model and dataset downloads.",
            "Existing model caches are not moved automatically."
        )
    }
    "temp" = @{
        Label = "User temp directories"
        Variables = [ordered]@{
            "TEMP" = "temp"
            "TMP"  = "temp"
        }
        Notes = @(
            "This changes user-level TEMP/TMP for new processes.",
            "Some installers expect a fast local temp path; keep this on a reliable drive."
        )
    }
}

function Get-DefaultRoot {
    $drive = Split-Path -Qualifier $PWD.Path
    if ([string]::IsNullOrWhiteSpace($drive)) {
        return "D:\DevStorage"
    }

    return "$drive\DevStorage"
}

function Normalize-RootPath {
    param([string]$Path)

    $trimmed = $Path.Trim()
    if ($trimmed -match "^[A-Za-z]:[^\\/].*") {
        $trimmed = $trimmed.Insert(2, "\")
    }

    return [System.IO.Path]::GetFullPath($trimmed)
}

function Resolve-StoragePath {
    param(
        [string]$BaseRoot,
        [string]$Value
    )

    if ($Value -like "*{root}*") {
        return $Value.Replace("{root}", $BaseRoot.TrimEnd("\"))
    }

    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }

    return (Join-Path $BaseRoot $Value)
}

function Get-SelectedProfiles {
    if ($All) {
        return @($ProfileDefinitions.Keys)
    }

    if ($Profiles -and $Profiles.Count -gt 0) {
        $normalizedProfiles = New-Object System.Collections.Generic.List[string]
        foreach ($entry in $Profiles) {
            foreach ($name in $entry.Split(",")) {
                $trimmedName = $name.Trim()
                if (-not [string]::IsNullOrWhiteSpace($trimmedName)) {
                    $normalizedProfiles.Add($trimmedName)
                }
            }
        }

        foreach ($name in $normalizedProfiles) {
            if (-not $ProfileDefinitions.Contains($name)) {
                throw "Unknown profile '$name'. Use -List to see valid profiles."
            }
        }

        return @($normalizedProfiles)
    }

    Write-Host ""
    Write-Host "Select profiles to configure. Enter comma-separated numbers, or A for all."
    $index = 1
    $keys = @($ProfileDefinitions.Keys)
    foreach ($key in $keys) {
        Write-Host ("  {0,2}. {1,-10} {2}" -f $index, $key, $ProfileDefinitions[$key].Label)
        $index++
    }

    $answer = Read-Host "Selection"
    if ($answer.Trim().Equals("A", [System.StringComparison]::OrdinalIgnoreCase)) {
        return @($keys)
    }

    $selected = New-Object System.Collections.Generic.List[string]
    foreach ($part in $answer.Split(",")) {
        $trimmed = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        $number = 0
        if (-not [int]::TryParse($trimmed, [ref]$number)) {
            throw "Invalid selection '$trimmed'."
        }

        if ($number -lt 1 -or $number -gt $keys.Count) {
            throw "Selection '$number' is out of range."
        }

        $selected.Add($keys[$number - 1])
    }

    if ($selected.Count -eq 0) {
        throw "No profiles selected."
    }

    return @($selected)
}

function Export-CurrentUserEnvironment {
    param([string[]]$VariableNames)

    $snapshot = [ordered]@{
        CreatedAt = (Get-Date).ToString("o")
        Scope = "User"
        Variables = [ordered]@{}
    }

    foreach ($name in ($VariableNames | Sort-Object -Unique)) {
        $snapshot.Variables[$name] = [Environment]::GetEnvironmentVariable($name, "User")
    }

    return $snapshot
}

function Save-Backup {
    param(
        [object]$Snapshot,
        [string]$BaseRoot
    )

    $backupDir = Join-Path $BaseRoot "_backups"
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }

    $path = Join-Path $backupDir ("env-backup-{0}.json" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    $json = $Snapshot | ConvertTo-Json -Depth 6
    if (-not $DryRun) {
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
    }

    return $path
}

function Restore-Environment {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Use -Restore -BackupPath <path-to-env-backup.json>."
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Backup file not found: $Path"
    }

    $backup = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    foreach ($property in $backup.Variables.PSObject.Properties) {
        Write-Host ("Restore {0} = {1}" -f $property.Name, $property.Value)
        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable($property.Name, $property.Value, "User")
        }
    }

    Write-Host ""
    Write-Host "Restore complete. Open a new terminal to see restored user environment variables."
}

if ($List) {
    foreach ($key in $ProfileDefinitions.Keys) {
        Write-Host ""
        Write-Host ("[{0}] {1}" -f $key, $ProfileDefinitions[$key].Label)
        foreach ($variable in $ProfileDefinitions[$key].Variables.Keys) {
            Write-Host ("  {0} -> {1}" -f $variable, $ProfileDefinitions[$key].Variables[$variable])
        }
    }

    exit 0
}

if ($Restore) {
    Restore-Environment -Path $BackupPath
    exit 0
}

if ([string]::IsNullOrWhiteSpace($Root)) {
    $defaultRoot = Get-DefaultRoot
    $answer = Read-Host "Storage root [$defaultRoot]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        $Root = $defaultRoot
    } else {
        $Root = $answer
    }
}

$Root = Normalize-RootPath -Path $Root
$selectedProfiles = Get-SelectedProfiles

$changes = New-Object System.Collections.Generic.List[object]
$directories = New-Object System.Collections.Generic.HashSet[string]
$variableNames = New-Object System.Collections.Generic.List[string]

foreach ($profileName in $selectedProfiles) {
    $profile = $ProfileDefinitions[$profileName]
    foreach ($variableName in $profile.Variables.Keys) {
        $rawValue = $profile.Variables[$variableName]
        $resolvedValue = Resolve-StoragePath -BaseRoot $Root -Value $rawValue
        $currentValue = [Environment]::GetEnvironmentVariable($variableName, "User")
        $changes.Add([pscustomobject]@{
            Profile = $profileName
            Name = $variableName
            Current = $currentValue
            New = $resolvedValue
        })
        $variableNames.Add($variableName)

        if ($variableName -eq "MAVEN_OPTS" -and $resolvedValue -match "-Dmaven\.repo\.local=([^ ]+)") {
            [void]$directories.Add($Matches[1])
        } elseif ($resolvedValue -match "^[A-Za-z]:\\") {
            if ($variableName -ne "MAVEN_OPTS") {
                [void]$directories.Add($resolvedValue)
            }
        }
    }
}

Write-Host ""
Write-Host "Storage root: $Root"
Write-Host "Selected profiles: $($selectedProfiles -join ', ')"
Write-Host ""
Write-Host "Planned user environment changes:"
$changes | Format-Table Profile, Name, Current, New -AutoSize

Write-Host "Directories to create:"
foreach ($directory in ($directories | Sort-Object)) {
    Write-Host "  $directory"
}

Write-Host ""
Write-Host "Notes:"
foreach ($profileName in $selectedProfiles) {
    foreach ($note in $ProfileDefinitions[$profileName].Notes) {
        Write-Host "  [$profileName] $note"
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "Dry run only. No environment variables were changed."
    exit 0
}

Write-Host ""
$confirm = Read-Host "Apply these user-level environment variables? Type YES to continue"
if ($confirm -ne "YES") {
    Write-Host "Cancelled. No changes were applied."
    exit 1
}

New-Item -ItemType Directory -Path $Root -Force | Out-Null
foreach ($directory in $directories) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$backup = Export-CurrentUserEnvironment -VariableNames $variableNames
$savedBackup = Save-Backup -Snapshot $backup -BaseRoot $Root

foreach ($change in $changes) {
    [Environment]::SetEnvironmentVariable($change.Name, $change.New, "User")
}

Write-Host ""
Write-Host "Applied user-level environment variables."
Write-Host "Backup saved to: $savedBackup"
Write-Host "Open a new terminal or restart apps for changes to take effect."
