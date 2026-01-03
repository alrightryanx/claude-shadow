# Pester tests for plugin manifest and structure validation
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot

Describe "Plugin Manifest Structure" {
    $manifestPath = Join-Path $ScriptRoot ".claude-plugin\plugin.json"

    Context "Manifest file exists" {
        It "plugin.json exists" {
            Test-Path $manifestPath | Should Be $true
        }

        It "plugin.json is valid JSON" {
            { Get-Content $manifestPath -Raw | ConvertFrom-Json } | Should Not Throw
        }
    }

    Context "Required fields" {
        It "Has name field" {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.name | Should Not BeNullOrEmpty
        }

        It "Has version field" {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.version | Should Not BeNullOrEmpty
        }

        It "Has description field" {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.description | Should Not BeNullOrEmpty
        }
    }

    Context "Version format" {
        It "Version is valid semver-like format" {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            $manifest.version | Should Match "^\d+\.\d+"
        }
    }
}

Describe "Hooks Directory Structure" {
    $hooksPath = Join-Path $ScriptRoot "hooks"

    Context "Hooks directory" {
        It "hooks directory exists" {
            Test-Path $hooksPath | Should Be $true
        }

        It "hooks directory contains files or subdirs" {
            (Get-ChildItem $hooksPath -ErrorAction SilentlyContinue).Count | Should BeGreaterThan 0
        }
    }

    Context "Hook configuration file" {
        It "hooks.json exists in hooks directory" {
            $hooksJsonPath = Join-Path $hooksPath "hooks.json"
            Test-Path $hooksJsonPath | Should Be $true
        }

        It "hooks.json is valid JSON" {
            $hooksJsonPath = Join-Path $hooksPath "hooks.json"
            if (Test-Path $hooksJsonPath) {
                { Get-Content $hooksJsonPath -Raw | ConvertFrom-Json } | Should Not Throw
            }
        }
    }
}

Describe "Scripts Directory Structure" {
    $scriptsPath = Join-Path $ScriptRoot "scripts"

    Context "Scripts directory" {
        It "scripts directory exists" {
            Test-Path $scriptsPath | Should Be $true
        }
    }

    Context "Required script files" {
        It "Has companion-common.ps1" {
            $scriptPath = Join-Path $scriptsPath "companion-common.ps1"
            Test-Path $scriptPath | Should Be $true
        }
    }

    Context "Script syntax" {
        It "companion-common.ps1 has valid PowerShell syntax" {
            $scriptPath = Join-Path $scriptsPath "companion-common.ps1"
            if (Test-Path $scriptPath) {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
                $errors.Count | Should Be 0
            }
        }
    }
}

Describe "Plugin Metadata" {
    $manifestPath = Join-Path $ScriptRoot ".claude-plugin\plugin.json"

    Context "Optional but recommended fields" {
        It "Has author or maintainer info" {
            if (Test-Path $manifestPath) {
                $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
                ($manifest.author -or $manifest.maintainer) | Should Be $true
            }
        }
    }
}

Describe "Marketplace Configuration" {
    $marketplacePath = Join-Path $ScriptRoot ".claude-plugin\marketplace.json"

    Context "Marketplace file" {
        It "marketplace.json exists" {
            Test-Path $marketplacePath | Should Be $true
        }

        It "marketplace.json is valid JSON" {
            if (Test-Path $marketplacePath) {
                { Get-Content $marketplacePath -Raw | ConvertFrom-Json } | Should Not Throw
            }
        }
    }

    Context "Marketplace structure" {
        It "Has plugins array" {
            if (Test-Path $marketplacePath) {
                $marketplace = Get-Content $marketplacePath -Raw | ConvertFrom-Json
                $marketplace.plugins | Should Not Be $null
            }
        }

        It "Plugins array is not empty" {
            if (Test-Path $marketplacePath) {
                $marketplace = Get-Content $marketplacePath -Raw | ConvertFrom-Json
                $marketplace.plugins.Count | Should BeGreaterThan 0
            }
        }
    }
}

Describe "File Encoding" {
    $scriptsPath = Join-Path $ScriptRoot "scripts"

    Context "PowerShell scripts" {
        $psScripts = Get-ChildItem (Join-Path $scriptsPath "*.ps1") -ErrorAction SilentlyContinue

        foreach ($script in $psScripts) {
            It "$($script.Name) is readable" {
                { Get-Content $script.FullName -Raw } | Should Not Throw
            }

            It "$($script.Name) has content" {
                $content = Get-Content $script.FullName -Raw
                $content.Length | Should BeGreaterThan 0
            }
        }
    }

    Context "JSON files" {
        $jsonFiles = Get-ChildItem $ScriptRoot -Recurse -Filter "*.json" -ErrorAction SilentlyContinue

        foreach ($jsonFile in $jsonFiles) {
            It "$($jsonFile.Name) is valid JSON" {
                { Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json } | Should Not Throw
            }
        }
    }
}

Describe "Required Functions" {
    $scriptsPath = Join-Path $ScriptRoot "scripts\companion-common.ps1"

    Context "Exported functions" {
        BeforeAll {
            . $scriptsPath
        }

        It "Get-CompanionConfig is defined" {
            Get-Command Get-CompanionConfig -ErrorAction SilentlyContinue | Should Not Be $null
        }

        It "Send-ToBridge is defined" {
            Get-Command Send-ToBridge -ErrorAction SilentlyContinue | Should Not Be $null
        }

        It "Write-HookOutput is defined" {
            Get-Command Write-HookOutput -ErrorAction SilentlyContinue | Should Not Be $null
        }

        It "Get-FriendlyToolDescription is defined" {
            Get-Command Get-FriendlyToolDescription -ErrorAction SilentlyContinue | Should Not Be $null
        }
    }
}

Describe "Default Configuration Values" {
    $scriptsPath = Join-Path $ScriptRoot "scripts\companion-common.ps1"

    Context "Default values" {
        BeforeAll {
            . $scriptsPath
        }

        It "Default bridge host is localhost" {
            $config = Get-CompanionConfig
            $config.bridgeHost | Should Match "^(127\.0\.0\.1|localhost)$"
        }

        It "Default bridge port is 19286" {
            $config = Get-CompanionConfig
            $config.bridgePort | Should Be 19286
        }

        It "Default enabled is true" {
            $config = Get-CompanionConfig
            $config.enabled | Should Be $true
        }
    }
}

Describe "Tool Description Formatting" {
    $scriptsPath = Join-Path $ScriptRoot "scripts\companion-common.ps1"

    Context "Tool descriptions" {
        BeforeAll {
            . $scriptsPath
        }

        It "Formats Bash command" {
            $desc = Get-FriendlyToolDescription -ToolName "Bash" -ToolInput @{ command = "ls -la" }
            $desc | Should Be "Run: ls -la"
        }

        It "Formats Write path" {
            $desc = Get-FriendlyToolDescription -ToolName "Write" -ToolInput @{ file_path = "/test/file.txt" }
            $desc | Should Be "Create file: .../test/file.txt"
        }

        It "Formats Edit path" {
            $desc = Get-FriendlyToolDescription -ToolName "Edit" -ToolInput @{ file_path = "/test/code.py" }
            $desc | Should Be "Edit: .../test/code.py"
        }

        It "Formats Read path" {
            $desc = Get-FriendlyToolDescription -ToolName "Read" -ToolInput @{ file_path = "/data/config.json" }
            $desc | Should Be "Read: .../data/config.json"
        }

        It "Formats WebFetch URL" {
            $desc = Get-FriendlyToolDescription -ToolName "WebFetch" -ToolInput @{ url = "https://api.example.com" }
            $desc | Should Be "Fetch: api.example.com"
        }

        It "Formats WebSearch query" {
            $desc = Get-FriendlyToolDescription -ToolName "WebSearch" -ToolInput @{ query = "PowerShell testing" }
            $desc | Should Be "Search: PowerShell testing"
        }

        It "Handles unknown tool" {
            $desc = Get-FriendlyToolDescription -ToolName "UnknownTool" -ToolInput @{ param = "value" }
            $desc | Should Match "^UnknownTool:"
        }
    }
}

Describe "Output Formatting" {
    $scriptsPath = Join-Path $ScriptRoot "scripts\companion-common.ps1"

    Context "JSON output" {
        BeforeAll {
            . $scriptsPath
        }

        It "Produces compact JSON" {
            $output = Write-HookOutput -Output @{ decision = "approve" }
            $output | Should Not Match "`n"
        }

        It "Output is valid JSON" {
            $output = Write-HookOutput -Output @{ decision = "approve" }
            { $output | ConvertFrom-Json } | Should Not Throw
        }

        It "Preserves nested structure" {
            $nested = @{
                outer = @{
                    inner = "value"
                }
            }
            $output = Write-HookOutput -Output $nested
            $parsed = $output | ConvertFrom-Json
            $parsed.outer.inner | Should Be "value"
        }
    }
}
