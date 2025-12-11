<#
.SYNOPSIS
    Unit tests for the Git alias parser in Setup-GitConfig.ps1

.DESCRIPTION
    Tests the Get-GitAliases function to ensure correct parsing of alias definitions,
    including multi-line aliases with continuation characters.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import the parser function
. (Join-Path $PSScriptRoot 'Setup-GitConfig.ps1') -SkipPoshGit

#region Test Cases

function Test-SingleLineAlias {
    $content = "st = status"
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 1 -and $result[0].Name -eq 'st' -and $result[0].Command -eq 'status') {
        Write-Host "[PASS] Single-line alias" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Single-line alias" -ForegroundColor Red
        Write-Host "  Expected: Name='st', Command='status'"
        Write-Host "  Got: $($result | ConvertTo-Json)"
        return $false
    }
}

function Test-MultiLineAlias {
    $content = @"
log-graph = log --graph --oneline \
    --all --decorate
"@
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 1 -and $result[0].Name -eq 'log-graph' -and $result[0].Command -like '*--graph*--all*') {
        Write-Host "[PASS] Multi-line alias with continuation" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Multi-line alias with continuation" -ForegroundColor Red
        Write-Host "  Got: $($result | ConvertTo-Json)"
        return $false
    }
}

function Test-MultipleAliases {
    $content = @"
st = status
add = add -A
commit = commit -m
push = push origin HEAD
"@
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 4 -and $result[0].Name -eq 'st' -and $result[3].Name -eq 'push') {
        Write-Host "[PASS] Multiple aliases" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Multiple aliases" -ForegroundColor Red
        Write-Host "  Expected: 4 aliases, Got: $($result.Count)"
        return $false
    }
}

function Test-EmptyLinesIgnored {
    $content = @"
st = status

add = add -A

commit = commit -m
"@
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 3) {
        Write-Host "[PASS] Empty lines ignored" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Empty lines ignored" -ForegroundColor Red
        Write-Host "  Expected: 3 aliases, Got: $($result.Count)"
        return $false
    }
}

function Test-InvalidLinesSkipped {
    $content = @"
st = status
invalid line without equals
add = add -A
"@
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 2 -and $result[0].Name -eq 'st' -and $result[1].Name -eq 'add') {
        Write-Host "[PASS] Invalid lines skipped" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Invalid lines skipped" -ForegroundColor Red
        Write-Host "  Expected: 2 valid aliases, Got: $($result.Count)"
        return $false
    }
}

function Test-SpecialCharactersInCommand {
    $content = 'foo = !echo "Hello, World!"'
    $result = Get-GitAliases -Content $content
    
    if ($result.Count -eq 1 -and $result[0].Command -like '*!echo*') {
        Write-Host "[PASS] Special characters in command" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "[FAIL] Special characters in command" -ForegroundColor Red
        Write-Host "  Got: $($result | ConvertTo-Json)"
        return $false
    }
}

#endregion

#region Run Tests

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Git Alias Parser Unit Tests           " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$tests = @(
    'Test-SingleLineAlias',
    'Test-MultiLineAlias',
    'Test-MultipleAliases',
    'Test-EmptyLinesIgnored',
    'Test-InvalidLinesSkipped',
    'Test-SpecialCharactersInCommand'
)

$passed = 0
$failed = 0

foreach ($test in $tests) {
    if (& $test) {
        $passed++
    }
    else {
        $failed++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Results                          " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Write-Host ""

exit $(if ($failed -eq 0) { 0 } else { 1 })

#endregion
