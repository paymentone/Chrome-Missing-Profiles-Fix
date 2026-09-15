# Chrome Missing Profiles Fix for Windows

A small Windows batch/PowerShell utility that can help recover **Google Chrome profiles that still exist on disk but no longer appear in Chrome's profile list**.

This script was created after encountering a situation where Chrome profile folders were still present under the Chrome `User Data` directory, including their profile data, but one or more profiles were missing from Chrome's `Local State` profile registry and therefore no longer appeared normally in Chrome.

Instead of manually editing Chrome's `Local State` JSON file, this tool detects the missing profiles and asks Chrome to open the existing profile directories so Chrome can re-register them itself.

> **Important:** This utility can only help when the actual Chrome profile folder still exists on disk. It cannot recover a profile whose files have already been deleted.

---

## What the script does

The script:

1. Locates the Chrome **User Data** directory.
2. Finds valid Chrome profile folders such as:
   - `Default`
   - `Profile 1`
   - `Profile 2`
   - `Profile 3`
   - etc.
3. Reads each profile's `Preferences` file to display, when available:
   - Profile folder name
   - Chrome profile name
   - Google account email
4. Reads Chrome's `Local State` file.
5. Compares the profile folders found on disk with the profiles registered in `Local State`.
6. Identifies profiles that exist on disk but are **missing from Local State**.
7. Gives you the option to open/re-register all missing profiles using Chrome's own `--profile-directory` command-line option.

The script **does not directly rewrite the `Local State` file**.

---

## When this may help

This utility may be useful if:

- One or more Chrome profiles suddenly disappeared from the Chrome profile picker.
- Chrome only shows some of your profiles even though the other profile folders still exist.
- Your Chrome `User Data` folder contains `Profile 1`, `Profile 2`, etc., but Chrome no longer lists all of them.
- A Chrome update, crash, profile-state problem, or other issue left the profile data on disk but removed the profile from Chrome's registered profile list.

This script does **not** attempt to determine what originally caused the profile registration to disappear.

---

## Requirements

- Windows 10 or Windows 11
- Google Chrome installed
- Windows PowerShell
- The missing Chrome profile folder must still exist and contain a valid `Preferences` file

Administrator privileges are normally **not required**.

---

## Before you use it

Although the script is designed to avoid directly modifying Chrome's `Local State` file, backing up your Chrome data first is strongly recommended.

Chrome's default user-data directory is:

```text
%LOCALAPPDATA%\Google\Chrome\User Data
```

A simple precaution is to close Chrome completely and make a copy of the entire `User Data` folder before attempting recovery.

At minimum, consider backing up:

```text
%LOCALAPPDATA%\Google\Chrome\User Data\Local State
```

and any affected profile folders, for example:

```text
%LOCALAPPDATA%\Google\Chrome\User Data\Profile 1
%LOCALAPPDATA%\Google\Chrome\User Data\Profile 2
```

---

## Download

Download the `.bat` file from this repository.

For convenience, you can rename it to something simpler, such as:

```text
ChromeProfiles.bat
```

No installation is required.

---

## Usage

### Interactive mode

Double-click the batch file, or run it from Command Prompt:

```bat
ChromeProfiles.bat
```

The utility will display a profile audit similar to:

```text
Chrome Profile Audit
====================

User Data folder: C:\Users\YourName\AppData\Local\Google\Chrome\User Data

Profiles found on disk:              5
Profiles registered in Local State: 3
Profiles MISSING from Local State:   2
```

It will then display the profiles it found and their status.

Example:

```text
Folder Name  Profile Name  Google Email          Local State  Preferences
-----------  ------------  ------------          -----------  -----------
Default      Personal      name@gmail.com        Registered   OK
Profile 1    Work          work@example.com      Registered   OK
Profile 2    Testing       test@example.com      MISSING      OK
```

Available options are:

```text
[R] Refresh report
[A] Add/re-register ALL missing profiles in Chrome
[Q] Quit
```

Choose **A** to have Chrome open each missing profile folder.

Chrome will open one window for each missing profile using a command similar to:

```text
chrome.exe --profile-directory="Profile 2" --new-window --no-first-run chrome://version
```

After Chrome finishes opening the profiles, return to the utility and select **R** to refresh the report.

---

## Automatic restore mode

The script also supports a command-line restore mode:

```bat
ChromeProfiles.bat restore
```

You can also use:

```bat
ChromeProfiles.bat /restore
```

or:

```bat
ChromeProfiles.bat --restore
```

In restore mode, the script will:

1. Run the audit.
2. Find profiles that exist on disk but are missing from `Local State`.
3. Automatically ask Chrome to load each missing profile without displaying the interactive confirmation prompt.

Chrome windows will still be opened for the affected profiles.

---

## How profiles are detected

The script considers these to be normal Chrome profile directories:

```text
Default
Profile 1
Profile 2
Profile 3
...
```

A directory is only treated as a profile if it also contains a Chrome `Preferences` file.

This prevents unrelated folders in the Chrome `User Data` directory from being counted as profiles.

---

## How the Chrome User Data directory is located

The utility first checks whether the batch file itself is located directly inside a Chrome `User Data` directory by looking for a `Local State` file beside it.

If not, it uses Chrome's normal Windows location:

```text
%LOCALAPPDATA%\Google\Chrome\User Data
```

This makes it possible to either run the script from another folder or place it directly inside the Chrome `User Data` directory.

---

## How Chrome is located

The script searches the normal Windows Chrome installation paths, including:

```text
%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe
%ProgramFiles%\Google\Chrome\Application\chrome.exe
%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe
```

If necessary, it also attempts to locate `chrome.exe` through the system command path.

---

## What `MISSING` means

A profile marked:

```text
MISSING
```

means:

- The profile directory exists on disk.
- The directory contains a `Preferences` file.
- The profile's folder name is **not present in Chrome's `Local State -> profile -> info_cache` registry**.

That is the situation this utility is intended to repair.

---

## What `UNKNOWN` means

If the script cannot read or parse Chrome's `Local State` file, profile registration status will be shown as:

```text
UNKNOWN
```

The script will **not attempt a restore** when `Local State` cannot be read successfully.

---

## Extra Local State entries

The audit can also detect the opposite condition: Chrome's `Local State` file contains a registered profile name, but there is no matching profile directory on disk.

Those entries are reported for informational purposes only.

The script does not delete them.

---

## Troubleshooting

### The missing profile is not detected

Check the Chrome User Data directory:

```text
%LOCALAPPDATA%\Google\Chrome\User Data
```

Look for the missing profile's folder, such as:

```text
Profile 4
```

The folder must still exist and contain a file named:

```text
Preferences
```

If the actual profile directory has been deleted, this utility cannot recreate its data.

### Chrome opens, but the profile still does not appear

Try the following:

1. Close **all** Chrome windows.
2. Check Task Manager and make sure no `chrome.exe` processes remain running.
3. Run the script again.
4. Choose **A** to re-register the missing profiles.
5. Allow the Chrome windows to finish loading.
6. Refresh the audit with **R**.

### Chrome cannot be found

The script checks the standard per-user and system-wide Chrome installation locations.

If Chrome was installed in a non-standard location and is not available through the system path, the script may not be able to locate `chrome.exe`.

### Preferences read error

If the utility displays:

```text
Preferences read error
```

for a profile, that profile's `Preferences` file could not be parsed successfully.

Back up the profile folder before attempting manual repairs.

---

## Security / privacy

The script reads local Chrome configuration files in order to identify profiles.

It may display the Google email address associated with a local Chrome profile in the console.

It does **not**:

- Upload profile information anywhere
- Send data over the Internet
- Read or export saved passwords
- Read browsing history
- Read cookies
- Modify Chrome extensions
- Directly rewrite Chrome's `Local State` JSON

Everything runs locally on the Windows computer.

---

## Technical overview

The `.bat` file is a hybrid Batch + PowerShell script.

The batch portion launches the embedded PowerShell section using:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass
```

The PowerShell portion performs the profile audit and recovery logic.

For each missing profile, recovery is attempted with Chrome's existing profile-directory support rather than manually injecting entries into `Local State`.

---

## Limitations

This utility:

- Is intended for **Google Chrome on Windows**.
- Does not recover deleted profile files.
- Does not restore corrupted Chrome profile contents.
- Does not reset or recover Google account passwords.
- Does not attempt to repair a corrupted `Local State` file.
- Does not guarantee recovery in every Chrome profile-loss scenario.
- Has not been designed for Chromium-based browsers such as Edge, Brave, or Opera without modification.

---

## Disclaimer

Use this script at your own risk.

Always back up important browser data before performing profile recovery or configuration changes. The author is not responsible for lost browser data, damaged profiles, or other problems resulting from use of this utility.

---

## Contributing

If this script helped you, or if you encounter a Chrome profile-loss scenario it does not handle, feel free to open an issue or submit a pull request.

Useful issue details include:

- Windows version
- Chrome version
- Number of profile folders found on disk
- Number of profiles shown by Chrome
- Console output from the audit, with email addresses or other personal information removed

---

## License

No license is included. You can freely use, modify, and redistribute the script.

