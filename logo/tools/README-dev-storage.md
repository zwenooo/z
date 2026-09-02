# Dev Storage Environment Tool

`Set-DevStorage.ps1` configures user-level Windows environment variables so common developer caches and package stores go to a storage root you choose, such as `D:\DevStorage`.

It does not move or delete existing caches. It only changes future behavior for new terminals and newly started apps.

## Usage

Run from Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1
```

List available profiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1 -List
```

Configure everything under `D:\DevStorage`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1 -Root D:\DevStorage -All
```

Configure selected profiles:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1 -Root D:\DevStorage -Profiles node,python,rust,electron,ai,temp
```

Preview without applying:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1 -Root D:\DevStorage -All -DryRun
```

Restore from a backup created by the tool:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\Set-DevStorage.ps1 -Restore -BackupPath D:\DevStorage\_backups\env-backup-YYYYMMDD-HHMMSS.json
```

## Profiles

- `node`: `npm_config_cache`, `PNPM_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`
- `python`: `PIP_CACHE_DIR`, `WORKON_HOME`, `POETRY_CACHE_DIR`, `PDM_CACHE_DIR`, `UV_CACHE_DIR`, `RYE_HOME`
- `rust`: `CARGO_HOME`, `RUSTUP_HOME`
- `go`: `GOMODCACHE`, `GOCACHE`
- `java`: `GRADLE_USER_HOME`, `MAVEN_OPTS`
- `dotnet`: `NUGET_PACKAGES`
- `android`: `ANDROID_USER_HOME`, `ANDROID_AVD_HOME`
- `electron`: `ELECTRON_CACHE`, `ELECTRON_BUILDER_CACHE`, `PLAYWRIGHT_BROWSERS_PATH`, `PUPPETEER_CACHE_DIR`
- `ai`: `HF_HOME`, `TRANSFORMERS_CACHE`, `HUGGINGFACE_HUB_CACHE`, `MODELSCOPE_CACHE`, `TORCH_HOME`
- `temp`: `TEMP`, `TMP`

## Notes

- The tool writes environment variables to the current Windows user, not the whole machine.
- New settings apply to new processes. Close and reopen terminals, IDEs, Docker Desktop, and package managers.
- Existing caches under `C:\Users\Administrator` are not moved automatically.
- Some tools ignore environment variables or also keep metadata in `%APPDATA%`; those may still need app-specific settings.
- For Docker Desktop and WSL distributions, use their own settings or export/import flows instead of only environment variables.
