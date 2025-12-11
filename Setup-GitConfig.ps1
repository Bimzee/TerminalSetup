<#
.SYNOPSIS
    Automatically configures Git aliases and sets up posh-git with custom prompt formatting.

.DESCRIPTION
    This script downloads Git aliases from a GitHub repository, applies them to the global
    Git configuration, installs posh-git (if not already installed), and configures the
    PowerShell prompt to display branch names in the format "[ <branchName> ]".

.PARAMETER GitAliasUrl
    The URL to the Git.txt file containing alias definitions. Defaults to the public GitHub repository.

.PARAMETER LocalPath
    Path to a local Git.txt file. If specified, the script will use this instead of downloading from GitHub.

.PARAMETER SkipPoshGit
    Skip posh-git installation and configuration.

.EXAMPLE
    .\Setup-GitConfig.ps1
    Runs with default settings, downloading from GitHub.

.EXAMPLE
    .\Setup-GitConfig.ps1 -LocalPath "C:\temp\Git.txt"
    Uses a local Git.txt file instead of downloading.

.EXAMPLE
    iwr https://raw.githubusercontent.com/Bimzee/TerminalSetup/main/Setup-GitConfig.ps1 | iex
    One-liner to download and execute the script directly.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$GitAliasUrl = "https://raw.githubusercontent.com/Bimzee/TerminalSetup/main/Git.txt",
    
    [Parameter()]
    [string]$LocalPath,
    
    [Parameter()]
    [switch]$SkipPoshGit
)

# Set error action preference
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

#region Helper Functions

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    
    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        default   { "Cyan" }
    }
    
    Write-Host "[$Type] $Message" -ForegroundColor $color
}

function Test-GitInstalled {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Status "Git is not installed or not in PATH. Please install Git first." -Type "Error"
        Write-Status "Download from: https://git-scm.com/download/win" -Type "Info"
        return $false
    }
    return $true
}

function Get-GitAliasContent {
    param(
        [ValidateNotNullOrEmpty()][string]$Url,
        [string]$Local
    )
    
    if ($Local) {
        if (-not (Test-Path $Local)) {
            throw "Local file not found: $Local"
        }
        Write-Status "Reading Git aliases from local file: $Local"
        return Get-Content $Local -Raw
    }
    else {
        Write-Status "Downloading Git aliases from: $Url"
        try {
            $response = Invoke-WebRequest -Uri $Url -ErrorAction Stop
            return $response.Content
        }
        catch {
            throw "Failed to download Git.txt from GitHub. Error: $($_.Exception.Message)"
        }
    }
}

function Get-GitAliases {
    param([ValidateNotNullOrEmpty()][string]$Content)

    $aliases = @()
    $lines = $Content -split "`r?`n"
    $currentLine = ""

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        if ($line -match '\\$') {
            $currentLine += $line.TrimEnd('\').Trim() + ' '
            continue
        }

        $currentLine += $line.Trim()

        if ($currentLine -match '^([a-zA-Z0-9_-]+)\s*=\s*(.+)$') {
            $aliasName = $matches[1].Trim()
            $aliasCommand = $matches[2].Trim()

            $aliases += [PSCustomObject]@{
                Name    = $aliasName
                Command = $aliasCommand
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($currentLine)) {
            Write-Status "Skipping invalid line: $currentLine" -Type "Warning"
        }

        $currentLine = ''
    }

    return $aliases
}

function Set-GitAliases {
    param([array]$Aliases)
    
    $successCount = 0
    $failCount = 0
    
    foreach ($alias in $Aliases) {
        try {
            # Use git config to set the alias
            # For commands starting with !, we need proper quoting
            $command = $alias.Command
            
            # Execute git config command
            git config --global alias.$($alias.Name) $command
            
            Write-Status "Set alias: $($alias.Name)" -Type "Success"
            $successCount++
        }
        catch {
            Write-Status "Failed to set alias '$($alias.Name)': $($_.Exception.Message)" -Type "Error"
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Status "Alias configuration complete: $successCount succeeded, $failCount failed" -Type "Info"
}

function Set-GitSettings {
    Write-Host ""
    Write-Status "Configuring Git settings..." -Type "Info"
    
    try {
        # Set VS Code as default editor
        git config --global core.editor "code --wait"
        Write-Status "Set VS Code as default editor" -Type "Success"
    }
    catch {
        Write-Status "Failed to set core.editor: $($_.Exception.Message)" -Type "Warning"
    }
    
    try {
        # Set pull to use rebase instead of merge
        git config --global pull.rebase true
        Write-Status "Configured pull to use rebase" -Type "Success"
    }
    catch {
        Write-Status "Failed to set pull.rebase: $($_.Exception.Message)" -Type "Warning"
    }
}

function Install-PoshGit {
    Write-Host ""
    Write-Status "Checking posh-git installation..." -Type "Info"
    
    # Check if posh-git is already installed
    $poshGitModule = Get-Module -ListAvailable -Name posh-git
    
    if ($poshGitModule) {
        Write-Status "posh-git is already installed (version $($poshGitModule.Version))" -Type "Success"
    }
    else {
        Write-Status "Installing posh-git from PowerShell Gallery..." -Type "Info"
        try {
            Install-Module posh-git -Scope CurrentUser -Force -ErrorAction Stop
            Write-Status "posh-git installed successfully" -Type "Success"
        }
        catch {
            Write-Status "Failed to install posh-git: $($_.Exception.Message)" -Type "Error"
            Write-Status "You may need to run: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser" -Type "Warning"
            return $false
        }
    }
    
    return $true
}

function Configure-PoshGitPrompt {
    Write-Host ""
    Write-Status "Configuring PowerShell profile for posh-git..." -Type "Info"
    
    # Check if profile exists
    if (-not (Test-Path $PROFILE)) {
        Write-Status "Creating PowerShell profile at: $PROFILE" -Type "Info"
        New-Item -Path $PROFILE -ItemType File -Force | Out-Null
    }
    
    # Backup existing profile
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = "$PROFILE.backup-$timestamp"
    Copy-Item -Path $PROFILE -Destination $backupPath -Force
    Write-Status "Profile backed up to: $backupPath" -Type "Info"
    
    # Read current profile content
    $profileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    
    # Check if our configuration already exists
    if ($profileContent -match '# region GitAliasManager') {
        Write-Status "GitAliasManager configuration already exists in profile. Updating..." -Type "Warning"
        
        # Remove existing region
        $profileContent = $profileContent -replace '(?s)# region GitAliasManager.*?# endregion GitAliasManager\r?\n?', ''
    }
    
        # Configuration to add
        $configBlock = @"

    # region GitAliasManager
    # Auto-generated by Setup-GitConfig.ps1 on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    # Do not manually edit this region - it will be regenerated

    # Import posh-git module
    Import-Module posh-git -ErrorAction SilentlyContinue

    # Configure prompt to show branch as "[ <branchName> ]"
    if (Get-Module posh-git) {
        # Work with the module's settings object if present
        if (`$null -ne `$GitPromptSettings) {
            # Choose the property names that exist in this posh-git version
            if (`$GitPromptSettings.PSObject.Properties['BeforeText'] -and `$GitPromptSettings.PSObject.Properties['AfterText']) {
                `$GitPromptSettings.BeforeText = '[ '
                `$GitPromptSettings.AfterText  = ' ]'
            }
            elseif (`$GitPromptSettings.PSObject.Properties['BeforeStatus'] -and `$GitPromptSettings.PSObject.Properties['AfterStatus']) {
                `$GitPromptSettings.BeforeStatus = '[ '
                `$GitPromptSettings.AfterStatus  = ' ]'
            }
            elseif (`$GitPromptSettings.PSObject.Properties['BeforePath'] -and `$GitPromptSettings.PSObject.Properties['AfterPath']) {
                `$GitPromptSettings.BeforePath = '[ '
                `$GitPromptSettings.AfterPath  = ' ]'
            }
            else {
                # Last resort: try to add portable note properties
                try {
                    `$GitPromptSettings | Add-Member -NotePropertyName 'BeforeText' -NotePropertyValue '[ ' -Force
                    `$GitPromptSettings | Add-Member -NotePropertyName 'AfterText' -NotePropertyValue ' ]' -Force
                }
                catch {
                    # If we can't add members, replace with a simple settings object (safe fallback)
                    `$GitPromptSettings = [PSCustomObject]@{
                        BeforeText = '[ '
                        AfterText  = ' ]'
                    }
                }
            }
        }
        else {
            # If the module didn't initialize it, create a simple settings object
            `$GitPromptSettings = [PSCustomObject]@{
                BeforeText = '[ '
                AfterText  = ' ]'
            }
        }
    }
    # endregion GitAliasManager
"@

    # Append configuration
    Set-Content -Path $PROFILE -Value ($profileContent + $configBlock) -NoNewline
    
    Write-Status "PowerShell profile configured successfully" -Type "Success"
    Write-Status "To apply changes, restart PowerShell or run: . `$PROFILE" -Type "Info"
}

function Show-InstalledAliases {
    Write-Host ""
    Write-Status "Verifying installed Git aliases..." -Type "Info"
    Write-Host ""
    
    try {
        $aliases = git config --global --get-regexp '^alias\.' 2>$null
        if ($aliases) {
            $aliases | ForEach-Object {
                Write-Host "  $_" -ForegroundColor Gray
            }
            Write-Host ""
            $aliasCount = ($aliases | Measure-Object).Count
            Write-Status "Total aliases configured: $aliasCount" -Type "Success"
        }
        else {
            Write-Status "No aliases found in git config" -Type "Warning"
        }
    }
    catch {
        Write-Status "Could not retrieve git aliases: $($_.Exception.Message)" -Type "Warning"
    }
}

#endregion

#region Main Script Execution

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Git Configuration & Posh-Git Setup  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify Git is installed
if (-not (Test-GitInstalled)) {
    exit 1
}

# Step 2: Download/Read Git aliases
try {
    $aliasContent = Get-GitAliasContent -Url $GitAliasUrl -Local $LocalPath
}
catch {
    Write-Status $_.Exception.Message -Type "Error"
    exit 1
}

# Step 3: Parse aliases
Write-Status "Parsing Git aliases..."
$aliases = Get-GitAliases -Content $aliasContent

if ($aliases.Count -eq 0) {
    Write-Status "No valid aliases found in the file" -Type "Error"
    exit 1
}

Write-Status "Found $($aliases.Count) aliases to configure" -Type "Success"
Write-Host ""

# Step 4: Set Git aliases
Set-GitAliases -Aliases $aliases

# Step 5: Configure Git settings (editor and pull behavior)
Set-GitSettings

# Step 6: Show installed aliases
Show-InstalledAliases

# Step 7: Install and configure posh-git (if not skipped)
if (-not $SkipPoshGit) {
    if (Install-PoshGit) {
        Configure-PoshGitPrompt
    }
}
else {
    Write-Status "Skipping posh-git installation (SkipPoshGit flag set)" -Type "Warning"
}

# Final message
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Configuration Complete!              " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Status "Next steps:" -Type "Info"
Write-Host "  1. Restart your PowerShell terminal, or run: . `$PROFILE" -ForegroundColor Yellow
Write-Host "  2. Navigate to a git repository to see the new prompt format" -ForegroundColor Yellow
Write-Host "  3. Try your new git aliases (e.g., 'git s' for status)" -ForegroundColor Yellow
Write-Host ""

#endregion
