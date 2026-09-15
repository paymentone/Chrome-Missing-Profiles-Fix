@echo off
setlocal
set "CHROME_PROFILES_SELF=%~f0"
set "CHROME_PROFILES_MODE=%~1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$lines = Get-Content -LiteralPath $env:CHROME_PROFILES_SELF; $marker = '#' + '__POWERSHELL_BELOW__' + '#'; $i = [Array]::IndexOf($lines, $marker); if ($i -lt 0) { throw 'Embedded PowerShell section not found.' }; $code = ($lines[($i + 1)..($lines.Count - 1)] -join [Environment]::NewLine); Invoke-Expression $code"

set "CHROME_PROFILES_SELF="
set "CHROME_PROFILES_MODE="
endlocal
exit /b

#__POWERSHELL_BELOW__#
$ErrorActionPreference = 'Stop'

function Get-ChromeUserDataPath {
    # If this BAT is stored directly in Chrome's User Data folder, use that.
    $scriptFolder = Split-Path -Parent $env:CHROME_PROFILES_SELF
    if ($scriptFolder -and (Test-Path -LiteralPath (Join-Path $scriptFolder 'Local State'))) {
        return $scriptFolder
    }

    # Otherwise fall back to Chrome's normal Windows location.
    return (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data')
}

function Get-ChromeExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe')
    )

    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe')
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return $candidate
        }
    }

    try {
        $cmd = Get-Command chrome.exe -ErrorAction Stop
        return $cmd.Source
    }
    catch {
        return $null
    }
}

function Get-ProfileFolders {
    param([string]$UserDataPath)

    # Normal Chrome user profiles are stored as "Default" and "Profile N".
    # Requiring a Preferences file avoids counting unrelated directories.
    return @(
        Get-ChildItem -LiteralPath $UserDataPath -Directory -ErrorAction Stop |
            Where-Object {
                ($_.Name -eq 'Default' -or $_.Name -like 'Profile *') -and
                (Test-Path -LiteralPath (Join-Path $_.FullName 'Preferences'))
            } |
            Sort-Object @{
                Expression = {
                    if ($_.Name -eq 'Default') {
                        -1
                    }
                    elseif ($_.Name -match '^Profile\s+(\d+)$') {
                        [int]$Matches[1]
                    }
                    else {
                        999999
                    }
                }
            }, Name
    )
}

function Get-ProfileDetails {
    param(
        [System.IO.DirectoryInfo]$Profile,
        [string[]]$RegisteredFolders
    )

    $profileName = ''
    $email = ''
    $readStatus = 'OK'
    $prefPath = Join-Path $Profile.FullName 'Preferences'

    try {
        $prefs = Get-Content -LiteralPath $prefPath -Raw -Encoding UTF8 | ConvertFrom-Json

        if ($prefs.profile -and $prefs.profile.name) {
            $profileName = [string]$prefs.profile.name
        }

        $accounts = @($prefs.account_info)
        if ($accounts.Count -gt 0 -and $accounts[0] -and $accounts[0].email) {
            $email = [string]$accounts[0].email
        }
    }
    catch {
        $readStatus = 'Preferences read error'
    }

    $registered = $RegisteredFolders -contains $Profile.Name

    [PSCustomObject]@{
        'Folder Name'    = $Profile.Name
        'Profile Name'   = $profileName
        'Google Email'   = $email
        'Local State'    = $(if ($registered) { 'Registered' } else { 'MISSING' })
        'Preferences'    = $readStatus
    }
}

function Get-ChromeProfileReport {
    param([string]$UserDataPath)

    $localStatePath = Join-Path $UserDataPath 'Local State'
    $profileFolders = Get-ProfileFolders -UserDataPath $UserDataPath

    $localStateOk = $false
    $localStateError = $null
    $registeredFolders = @()

    if (Test-Path -LiteralPath $localStatePath) {
        try {
            $localState = Get-Content -LiteralPath $localStatePath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($localState.profile -and $localState.profile.info_cache) {
                $registeredFolders = @(
                    $localState.profile.info_cache.PSObject.Properties |
                        ForEach-Object { $_.Name }
                )
            }
            $localStateOk = $true
        }
        catch {
            $localStateError = $_.Exception.Message
        }
    }
    else {
        $localStateError = 'Local State file was not found.'
    }

    $results = @()
    if ($localStateOk) {
        foreach ($profile in $profileFolders) {
            $results += Get-ProfileDetails -Profile $profile -RegisteredFolders $registeredFolders
        }
    }
    else {
        foreach ($profile in $profileFolders) {
            $details = Get-ProfileDetails -Profile $profile -RegisteredFolders @()
            $details.'Local State' = 'UNKNOWN'
            $results += $details
        }
    }

    $missing = @()
    $stateOnly = @()
    if ($localStateOk) {
        $missing = @($results | Where-Object { $_.'Local State' -eq 'MISSING' })
        $diskNames = @($profileFolders | ForEach-Object { $_.Name })
        $stateOnly = @($registeredFolders | Where-Object { $diskNames -notcontains $_ })
    }

    [PSCustomObject]@{
        UserDataPath      = $UserDataPath
        LocalStatePath    = $localStatePath
        LocalStateOk      = $localStateOk
        LocalStateError   = $localStateError
        DiskCount         = $profileFolders.Count
        RegisteredCount   = $registeredFolders.Count
        Results           = $results
        Missing           = $missing
        StateOnly         = $stateOnly
    }
}

function Show-Report {
    param($Report)

    Clear-Host
    Write-Host 'Chrome Profile Audit' -ForegroundColor Cyan
    Write-Host '====================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host ('User Data folder: {0}' -f $Report.UserDataPath)
    Write-Host ''

    Write-Host ('Profiles found on disk:              {0}' -f $Report.DiskCount) -ForegroundColor White

    if ($Report.LocalStateOk) {
        Write-Host ('Profiles registered in Local State: {0}' -f $Report.RegisteredCount) -ForegroundColor White
        Write-Host ('Profiles MISSING from Local State:   {0}' -f $Report.Missing.Count) -ForegroundColor $(if ($Report.Missing.Count -gt 0) { 'Yellow' } else { 'Green' })
    }
    else {
        Write-Host 'Profiles registered in Local State: ERROR' -ForegroundColor Red
        Write-Host ('Local State error: {0}' -f $Report.LocalStateError) -ForegroundColor Red
    }

    Write-Host ''
    if ($Report.Results.Count -gt 0) {
        $Report.Results | Format-Table -AutoSize
    }
    else {
        Write-Host 'No Chrome profile folders were found.' -ForegroundColor Yellow
    }

    if ($Report.LocalStateOk) {
        Write-Host ''
        Write-Host 'Profiles on disk but NOT found in Local State:' -ForegroundColor Cyan
        if ($Report.Missing.Count -gt 0) {
            $Report.Missing |
                Select-Object 'Folder Name', 'Profile Name', 'Google Email' |
                Format-Table -AutoSize
        }
        else {
            Write-Host 'None.' -ForegroundColor Green
        }

        if ($Report.StateOnly.Count -gt 0) {
            Write-Host ''
            Write-Host 'Note: Local State also contains profile entries with no matching profile folder:' -ForegroundColor DarkYellow
            foreach ($name in $Report.StateOnly) {
                Write-Host ('  - {0}' -f $name) -ForegroundColor DarkYellow
            }
        }
    }
}

function Register-MissingProfiles {
    param(
        $Report,
        [switch]$NoPrompt
    )

    if (-not $Report.LocalStateOk) {
        Write-Host ''
        Write-Host 'Cannot restore profiles because Local State could not be read.' -ForegroundColor Red
        return
    }

    if ($Report.Missing.Count -eq 0) {
        Write-Host ''
        Write-Host 'There are no missing profiles to restore.' -ForegroundColor Green
        return
    }

    $chromeExe = Get-ChromeExe
    if (-not $chromeExe) {
        Write-Host ''
        Write-Host 'Google Chrome could not be located.' -ForegroundColor Red
        Write-Host 'Expected chrome.exe under the normal LocalAppData or Program Files locations.' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host 'Restore method:' -ForegroundColor Cyan
    Write-Host 'Chrome will be asked to load each existing missing profile directory.'
    Write-Host 'This does NOT directly rewrite the Local State JSON file.'
    Write-Host ('Chrome executable: {0}' -f $chromeExe)
    Write-Host ''
    Write-Host 'This will open one Chrome window for each missing profile.' -ForegroundColor Yellow

    if (-not $NoPrompt) {
        $answer = Read-Host 'Continue? [Y/N]'
        if ($answer -notmatch '^(?i)y(es)?$') {
            Write-Host 'Cancelled.' -ForegroundColor Yellow
            return
        }
    }

    foreach ($profile in $Report.Missing) {
        $folder = [string]$profile.'Folder Name'
        Write-Host ('Opening {0} ...' -f $folder) -ForegroundColor Cyan

        $profileArg = '--profile-directory="{0}"' -f $folder
        Start-Process -FilePath $chromeExe -ArgumentList @(
            $profileArg,
            '--new-window',
            '--no-first-run',
            'chrome://version'
        )

        Start-Sleep -Milliseconds 900
    }

    Write-Host ''
    Write-Host 'Chrome has been asked to load all missing profile folders.' -ForegroundColor Green
    Write-Host 'After the windows finish loading, choose Refresh (R) or run this BAT again.' -ForegroundColor White
    Write-Host 'If a profile still remains missing, close Chrome completely and try the restore command once more.' -ForegroundColor Yellow
}

$userDataPath = Get-ChromeUserDataPath

if (-not (Test-Path -LiteralPath $userDataPath)) {
    Write-Host 'Chrome User Data folder not found:' -ForegroundColor Red
    Write-Host $userDataPath
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit 1
}

$mode = [string]$env:CHROME_PROFILES_MODE
$report = Get-ChromeProfileReport -UserDataPath $userDataPath

if ($mode -match '^(?i)(restore|/restore|--restore)$') {
    Show-Report -Report $report
    Register-MissingProfiles -Report $report -NoPrompt
    Write-Host ''
    Read-Host 'Press Enter to close'
    exit
}

while ($true) {
    Show-Report -Report $report
    Write-Host ''
    Write-Host '[R] Refresh report' -ForegroundColor Cyan
    Write-Host '[A] Add/re-register ALL missing profiles in Chrome' -ForegroundColor Cyan
    Write-Host '[Q] Quit' -ForegroundColor Cyan
    Write-Host ''

    $choice = Read-Host 'Select an option'

    switch -Regex ($choice) {
        '^(?i)r$' {
            $report = Get-ChromeProfileReport -UserDataPath $userDataPath
            continue
        }
        '^(?i)a$' {
            Register-MissingProfiles -Report $report
            Write-Host ''
            Read-Host 'Press Enter to return to the report'
            $report = Get-ChromeProfileReport -UserDataPath $userDataPath
            continue
        }
        '^(?i)q$' {
            exit 0
        }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }
}
