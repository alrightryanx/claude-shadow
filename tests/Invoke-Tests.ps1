# Claude Shadow - Test Runner
# Runs all Pester tests for the plugin
# Compatible with Pester 3.x and 5.x

param(
    [switch]$Detailed
)

$ErrorActionPreference = "Stop"

Import-Module Pester

$testPath = $PSScriptRoot

Write-Host "`n=== Claude Shadow Plugin Tests ===" -ForegroundColor Cyan
Write-Host "Test path: $testPath" -ForegroundColor Gray
Write-Host ""

# Run tests - syntax works with both Pester 3.x and 5.x
$results = Invoke-Pester -Path $testPath -PassThru

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Run: $($results.TotalCount)" -ForegroundColor White
Write-Host "Passed: $($results.PassedCount)" -ForegroundColor Green
Write-Host "Failed: $($results.FailedCount)" -ForegroundColor $(if ($results.FailedCount -gt 0) { "Red" } else { "Green" })

if ($results.FailedCount -gt 0) {
    Write-Host "`n=== Failed Tests ===" -ForegroundColor Red
    foreach ($test in $results.TestResult | Where-Object { $_.Result -eq "Failed" }) {
        Write-Host "  FAIL: $($test.Name)" -ForegroundColor Red
        Write-Host "        $($test.FailureMessage)" -ForegroundColor DarkRed
    }
    exit 1
}

Write-Host "`nAll tests passed!" -ForegroundColor Green
exit 0
