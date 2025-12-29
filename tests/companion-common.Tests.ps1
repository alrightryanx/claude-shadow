# Pester tests for companion-common.ps1
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "Get-CompanionConfig" {
    Context "When no config file exists" {
        $originalConfigFile = $script:CONFIG_FILE
        $script:CONFIG_FILE = "C:\nonexistent\path\config.json"

        It "Returns default configuration" {
            $config = Get-CompanionConfig
            $config.bridgeHost | Should Be "127.0.0.1"
            $config.bridgePort | Should Be 19286
            $config.enabled | Should Be $true
        }

        $script:CONFIG_FILE = $originalConfigFile
    }

    Context "When config file exists" {
        $originalConfigFile = $script:CONFIG_FILE
        $tempConfig = New-TempConfigFile -BridgeHost "192.168.1.50" -BridgePort 9999 -Enabled $false
        $script:CONFIG_FILE = $tempConfig

        It "Loads configuration from file" {
            $config = Get-CompanionConfig
            $config.bridgeHost | Should Be "192.168.1.50"
            $config.bridgePort | Should Be 9999
            $config.enabled | Should Be $false
        }

        Remove-Item $tempConfig -ErrorAction SilentlyContinue
        $script:CONFIG_FILE = $originalConfigFile
    }
}

Describe "Write-HookOutput" {
    It "Converts hashtable to JSON" {
        $output = Write-HookOutput -Output @{ decision = "approve" }
        $parsed = $output | ConvertFrom-Json
        $parsed.decision | Should Be "approve"
    }

    It "Handles nested objects" {
        $output = Write-HookOutput -Output @{
            decision = "approve"
            metadata = @{
                timestamp = 123456
                user = "test"
            }
        }
        $parsed = $output | ConvertFrom-Json
        $parsed.decision | Should Be "approve"
        $parsed.metadata.timestamp | Should Be 123456
        $parsed.metadata.user | Should Be "test"
    }

    It "Produces compact JSON (no newlines)" {
        $output = Write-HookOutput -Output @{ a = 1; b = 2; c = 3 }
        $output | Should Not Match "`n"
    }
}

Describe "Get-FriendlyToolDescription" {
    Context "Bash tool" {
        It "Describes short commands" {
            $desc = Get-FriendlyToolDescription -ToolName "Bash" -ToolInput @{ command = "ls -la" }
            $desc | Should Be "Run command: ls -la"
        }

        It "Truncates long commands" {
            $longCommand = "a" * 150
            $desc = Get-FriendlyToolDescription -ToolName "Bash" -ToolInput @{ command = $longCommand }
            $desc | Should Match "^Run command: a{100}\.\.\.$"
        }
    }

    Context "Write tool" {
        It "Shows file path" {
            $desc = Get-FriendlyToolDescription -ToolName "Write" -ToolInput @{ file_path = "C:\test\file.txt" }
            $desc | Should Be "Create/overwrite: C:\test\file.txt"
        }
    }

    Context "Edit tool" {
        It "Shows file path" {
            $desc = Get-FriendlyToolDescription -ToolName "Edit" -ToolInput @{ file_path = "C:\test\file.kt" }
            $desc | Should Be "Edit file: C:\test\file.kt"
        }
    }

    Context "Read tool" {
        It "Shows file path" {
            $desc = Get-FriendlyToolDescription -ToolName "Read" -ToolInput @{ file_path = "/home/user/code.py" }
            $desc | Should Be "Read file: /home/user/code.py"
        }
    }

    Context "WebFetch tool" {
        It "Shows URL" {
            $desc = Get-FriendlyToolDescription -ToolName "WebFetch" -ToolInput @{ url = "https://example.com/api" }
            $desc | Should Be "Fetch URL: https://example.com/api"
        }
    }

    Context "WebSearch tool" {
        It "Shows search query" {
            $desc = Get-FriendlyToolDescription -ToolName "WebSearch" -ToolInput @{ query = "Kotlin coroutines" }
            $desc | Should Be "Search web: Kotlin coroutines"
        }
    }

    Context "Unknown tool" {
        It "Shows tool name and JSON input" {
            $desc = Get-FriendlyToolDescription -ToolName "CustomTool" -ToolInput @{ foo = "bar" }
            $desc | Should Match "^CustomTool: "
        }
    }
}

Describe "Send-ToBridge" {
    Context "When disabled" {
        $originalConfigFile = $script:CONFIG_FILE
        $tempConfig = New-TempConfigFile -Enabled $false
        $script:CONFIG_FILE = $tempConfig

        It "Returns null when disabled" {
            $result = Send-ToBridge -Message @{ test = "data" }
            $result | Should Be $null
        }

        Remove-Item $tempConfig -ErrorAction SilentlyContinue
        $script:CONFIG_FILE = $originalConfigFile
    }

    Context "When bridge unavailable" {
        $originalConfigFile = $script:CONFIG_FILE
        $tempConfig = New-TempConfigFile -BridgeHost "127.0.0.1" -BridgePort 59999
        $script:CONFIG_FILE = $tempConfig

        It "Returns null on connection failure" {
            # Suppress error output and check result is null
            $result = Send-ToBridge -Message @{ test = "data" } -TimeoutSeconds 2 -ErrorAction SilentlyContinue
            $result | Should Be $null
        }

        Remove-Item $tempConfig -ErrorAction SilentlyContinue
        $script:CONFIG_FILE = $originalConfigFile
    }
}
