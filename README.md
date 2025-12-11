# Terminal Setup

Automated configuration for Git aliases and PowerShell prompt customization with posh-git.

## Quick Start

Run this one-liner in PowerShell to automatically configure your machine:

```powershell
iwr https://raw.githubusercontent.com/Bimzee/TerminalSetup/main/Setup-GitConfig.ps1 | iex
```

**Or** download and run locally:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Bimzee/TerminalSetup/main/Setup-GitConfig.ps1" -OutFile "Setup-GitConfig.ps1"
.\Setup-GitConfig.ps1
```

## What Does This Do?

The `Setup-GitConfig.ps1` script automatically:

1. ✅ **Downloads Git aliases** from this repository's `Git.txt` file
2. ✅ **Configures Git aliases globally** using `git config --global`
3. ✅ **Installs posh-git** (if not already installed) from PowerShell Gallery
4. ✅ **Customizes your PowerShell prompt** to display git branches as `[ <branchName> ]`
5. ✅ **Backs up your existing PowerShell profile** before making changes
6. ✅ **Verifies installation** by listing all configured aliases

## Git Aliases Included

The following Git aliases are configured:

| Alias | Command | Description |
|-------|---------|-------------|
| `l1` | `log --oneline` | Compact one-line log view |
| `chp` | `cherry-pick` | Cherry-pick commits |
| `s` | `status` | Show working tree status |
| `co` | `checkout -b` | Create and checkout new branch |
| `squash` | `rebase -i` | Interactive rebase for squashing |
| `current` | `rev-parse --abbrev-ref HEAD` | Get current branch name |
| `remote-diff` | Complex shell command | Diff current branch with remote |
| `upload` / `u` | Smart push to origin | Push current branch to origin |
| `download` / `d` | Smart pull from origin | Pull current branch from origin |
| `ri` | `rebase -i HEAD~${1}` | Interactive rebase last N commits |
| `safe-rebase` | Complex shell function | Safely rebase with automatic backup |

### Example Usage

```bash
# Short status
git s

# View compact log
git l1

# Upload current branch
git u

# Create new branch
git co feature-branch

# Interactive rebase last 3 commits
git ri 3

# Safe rebase with automatic backup
git safe-rebase
```

## Posh-Git Prompt Customization

After installation, your PowerShell prompt will show Git branch information with proper spacing:

```
C:\Code\MyProject [ main ]>
C:\Code\MyProject [ feature-branch ]>
```

The format is: `[ <branchName> ]` (with spaces inside the brackets)

### Posh-Git Version Compatibility

The script automatically detects your posh-git version and uses the correct prompt property names. Different posh-git versions expose different property interfaces:

- **Recent versions (v2+)**: Uses `BeforeStatus`/`AfterStatus` properties
- **Older versions**: May use `BeforeText`/`AfterText` or `BeforePath`/`AfterPath`
- **Fallback**: If none are found, the script creates a simple `BeforeText`/`AfterText` object

The script handles all variants automatically with no additional configuration needed.

## Testing

Run the unit test suite to verify the alias parser:

```powershell
.\Test-GitAliasParser.ps1
```

This tests:
- Single-line and multi-line aliases
- Multi-line aliases with continuation characters (`\`)
- Invalid line handling
- Empty line handling
- Special characters in commands

## Script Parameters

### Using Local File

Test with a local `Git.txt` file before pushing to GitHub:

```powershell
.\Setup-GitConfig.ps1 -LocalPath "C:\path\to\Git.txt"
```

### Skip Posh-Git Installation

Configure only Git aliases without installing posh-git:

```powershell
.\Setup-GitConfig.ps1 -SkipPoshGit
```

### Custom Git Alias URL

Use a different branch or repository:

```powershell
.\Setup-GitConfig.ps1 -GitAliasUrl "https://raw.githubusercontent.com/username/repo/branch/Git.txt"
```

## Requirements

- **Windows** with PowerShell 5.1 or later
- **Git** installed and available in PATH
- **Internet connection** (for downloading from GitHub and installing posh-git)

If Git is not installed, download from: https://git-scm.com/download/win

## File Structure

```
TerminalSetup/
├── Git.txt                  # Git alias definitions
├── Setup-GitConfig.ps1      # Main installation script
└── README.md               # This file
```

## Safety Features

- ✅ **Profile Backup**: Automatically creates timestamped backup before modifying `$PROFILE`
- ✅ **Idempotent**: Safe to run multiple times without creating duplicates
- ✅ **Region Markers**: Uses `# region GitAliasManager` blocks for clean updates
- ✅ **Error Handling**: Comprehensive checks for Git installation, network issues, and permissions
- ✅ **Verification**: Shows all configured aliases after installation

## Troubleshooting

### "Cannot be loaded because running scripts is disabled"

Run this command to enable script execution:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Git is not installed or not in PATH"

Install Git from https://git-scm.com/download/win and restart PowerShell.

### "Failed to install posh-git"

Ensure you have internet connectivity and PowerShell Gallery is accessible. You may need to run:

```powershell
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
```

### Changes Not Appearing

After running the script, restart your PowerShell terminal or run:

```powershell
. $PROFILE
```

## Manual Installation

If you prefer manual setup:

1. Copy aliases from `Git.txt`
2. Add each alias manually:
   ```powershell
   git config --global alias.s "status"
   git config --global alias.l1 "log --oneline"
   # ... etc
   ```
3. Install posh-git:
   ```powershell
   Install-Module posh-git -Scope CurrentUser
   ```
4. Add to your PowerShell profile (`$PROFILE`):
   ```powershell
   Import-Module posh-git
   # Property names vary by posh-git version; use whichever exists:
   if ($GitPromptSettings.PSObject.Properties['BeforeText']) {
       $GitPromptSettings.BeforeText = '[ '
       $GitPromptSettings.AfterText = ' ]'
   }
   elseif ($GitPromptSettings.PSObject.Properties['BeforeStatus']) {
       $GitPromptSettings.BeforeStatus = '[ '
       $GitPromptSettings.AfterStatus = ' ]'
   }
   ```
   Or simply run the automated script above for automatic handling.

## Contributing

Feel free to fork and customize for your own use! This is a personal configuration repository.

## License

Public domain - use freely!
