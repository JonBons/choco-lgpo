# LGPO - Local Group Policy Object Tool

## Overview
This Chocolatey package installs Microsoft's Local Group Policy Object (LGPO.exe) tool, which is part of the Microsoft Security Compliance Toolkit. LGPO.exe helps automate the management of Local Group Policy by providing command-line options to import and apply policy settings.

## Features
- Import settings from Registry Policy files (Registry.pol)
- Apply settings from security templates
- Import settings from Advanced Auditing backup files
- Export local policy to a GPO backup
- Export Registry Policy contents to editable LGPO text
- Build Registry Policy files from LGPO text

## Installation
```powershell
choco install lgpo
```

## Usage
After installation, `lgpo` is available from any command prompt through Chocolatey's shim:
```cmd
lgpo /?    # Show help and available commands
```

## Notes
- This package downloads LGPO directly from Microsoft's official download servers
- No system PATH modifications are made (uses Chocolatey's shim functionality)
- Supports both installation and clean uninstallation

## Source
- Official Tool: [Microsoft Security Compliance Toolkit](https://learn.microsoft.com/en-us/windows/security/operating-system-security/device-management/windows-security-configuration-framework/security-compliance-toolkit-10#what-is-the-local-group-policy-object-lgpo-tool)
