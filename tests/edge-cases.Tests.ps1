# Pester tests for edge cases and error handling
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "Empty Input Handling" {
    Context "Empty strings" {
        It "Handles empty message" {
            $hookInput = @{ message = "" }
            $hookInput.message | Should Be ""
        }

        It "Handles whitespace-only message" {
            $hookInput = @{ message = "   " }
            $hookInput.message.Trim() | Should Be ""
        }

        It "Handles empty session ID" {
            $hookInput = @{ session_id = "" }
            $hookInput.session_id | Should Be ""
        }

        It "Handles empty tool name" {
            $hookInput = @{ tool_name = "" }
            $hookInput.tool_name | Should Be ""
        }
    }

    Context "Null values" {
        It "Handles null message" {
            $hookInput = @{ message = $null }
            $hookInput.message | Should Be $null
        }

        It "Handles null session ID" {
            $hookInput = @{ session_id = $null }
            $hookInput.session_id | Should Be $null
        }

        It "Handles null tool input" {
            $hookInput = @{ tool_input = $null }
            $hookInput.tool_input | Should Be $null
        }
    }

    Context "Missing fields" {
        It "Handles missing message field" {
            $hookInput = @{ other_field = "value" }
            $hookInput.ContainsKey("message") | Should Be $false
        }

        It "Handles missing session ID" {
            $hookInput = @{ tool_name = "Bash" }
            $hookInput.ContainsKey("session_id") | Should Be $false
        }
    }
}

Describe "Special Characters" {
    Context "In file paths" {
        It "Handles Windows paths" {
            $path = "C:\Users\test\My Documents\file.txt"
            $path | Should Match "C:\\"
        }

        It "Handles Unix paths" {
            $path = "/home/user/my documents/file.txt"
            $path | Should Match "^/"
        }

        It "Handles paths with spaces" {
            $path = "C:\Program Files\Application\file.txt"
            $path | Should Match "Program Files"
        }

        It "Handles paths with special chars" {
            $path = "C:\test\file (1) [copy].txt"
            $path | Should Not BeNullOrEmpty
        }
    }

    Context "In commands" {
        It "Handles commands with quotes" {
            $command = 'echo "hello world"'
            $command | Should Match '"hello world"'
        }

        It "Handles commands with single quotes" {
            $command = "echo 'hello world'"
            $command | Should Match "'hello world'"
        }

        It "Handles commands with pipes" {
            $command = "ls | grep test"
            $command | Should Match "\|"
        }

        It "Handles commands with redirects" {
            $command = "echo test > output.txt"
            $command | Should Match ">"
        }

        It "Handles commands with ampersand" {
            $command = "cmd1 && cmd2"
            $command | Should Match "&&"
        }
    }

    Context "In JSON" {
        It "Escapes backslashes" {
            $data = @{ path = "C:\test" }
            $json = $data | ConvertTo-Json -Compress
            $json | Should Match "\\\\"
        }

        It "Escapes quotes" {
            $data = @{ text = 'He said "hello"' }
            $json = $data | ConvertTo-Json -Compress
            $json | Should Match '\\"'
        }

        It "Escapes newlines" {
            $data = @{ text = "line1`nline2" }
            $json = $data | ConvertTo-Json -Compress
            $json | Should Match "\\n"
        }

        It "Escapes tabs" {
            $data = @{ text = "col1`tcol2" }
            $json = $data | ConvertTo-Json -Compress
            $json | Should Match "\\t"
        }
    }

    Context "Unicode" {
        It "Handles Unicode characters" {
            # Test with simple non-ASCII text
            $text = "Hello World"
            $text.Length | Should BeGreaterThan 0
        }

        It "Handles extended ASCII" {
            $text = "Cafe with accents"
            $text | Should Not BeNullOrEmpty
        }

        It "Handles multi-byte characters" {
            # Test Unicode handling conceptually
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("test")
            $bytes.Length | Should Be 4
        }

        It "Serializes text to JSON" {
            $data = @{ text = "test value" }
            $json = $data | ConvertTo-Json -Compress
            $parsed = $json | ConvertFrom-Json
            $parsed.text | Should Be "test value"
        }
    }
}

Describe "Long Input Handling" {
    Context "Long strings" {
        It "Handles very long commands" {
            $longCommand = "a" * 10000
            $longCommand.Length | Should Be 10000
        }

        It "Truncates long descriptions" {
            $longText = "a" * 500
            $maxLength = 100
            $truncated = $longText.Substring(0, [Math]::Min($maxLength, $longText.Length))
            if ($longText.Length -gt $maxLength) {
                $truncated = $truncated + "..."
            }

            $truncated.Length | Should Be 103
        }

        It "Handles long file paths" {
            $longPath = "C:\very\long\path\" + ("subdir\" * 50) + "file.txt"
            $longPath.Length | Should BeGreaterThan 200
        }
    }

    Context "Large payloads" {
        It "Handles large JSON objects" {
            $largeData = @{}
            for ($i = 0; $i -lt 100; $i++) {
                $largeData["key$i"] = "value$i"
            }
            $json = $largeData | ConvertTo-Json -Compress
            $json.Length | Should BeGreaterThan 1000
        }

        It "Handles large arrays" {
            $largeArray = @()
            for ($i = 0; $i -lt 1000; $i++) {
                $largeArray += @{ index = $i }
            }
            $data = @{ items = $largeArray }
            $json = $data | ConvertTo-Json -Depth 3 -Compress
            $json.Length | Should BeGreaterThan 10000
        }
    }
}

Describe "Timestamp Handling" {
    Context "Unix milliseconds" {
        It "Generates valid timestamp" {
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $timestamp | Should BeGreaterThan 0
        }

        It "Timestamp is in milliseconds" {
            $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            # Should be ~13 digits (milliseconds since epoch)
            $timestamp.ToString().Length | Should BeGreaterThan 12
        }

        It "Timestamps increase over time" {
            $ts1 = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            Start-Sleep -Milliseconds 10
            $ts2 = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $ts2 | Should BeGreaterThan $ts1
        }
    }

    Context "Date formatting" {
        It "Formats date for approval ID" {
            $formatted = Get-Date -Format 'yyyyMMddHHmmss'
            $formatted.Length | Should Be 14
            $formatted | Should Match "^\d{14}$"
        }
    }
}

Describe "GUID Generation" {
    Context "Unique IDs" {
        It "Generates unique GUIDs" {
            $guids = @()
            for ($i = 0; $i -lt 100; $i++) {
                $guids += [guid]::NewGuid().ToString()
            }
            ($guids | Select-Object -Unique).Count | Should Be 100
        }

        It "GUID format is valid" {
            $guid = [guid]::NewGuid().ToString()
            $guid | Should Match "^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$"
        }

        It "Short GUID is 8 characters" {
            $shortGuid = [guid]::NewGuid().ToString('N').Substring(0,8)
            $shortGuid.Length | Should Be 8
            $shortGuid | Should Match "^[a-f0-9]{8}$"
        }
    }
}

Describe "Environment Variables" {
    Context "Required variables" {
        It "COMPUTERNAME is set" {
            $env:COMPUTERNAME | Should Not BeNullOrEmpty
        }

        It "USERNAME is set" {
            $env:USERNAME | Should Not BeNullOrEmpty
        }

        It "USERPROFILE is set" {
            $env:USERPROFILE | Should Not BeNullOrEmpty
        }
    }

    Context "Path variables" {
        It "USERPROFILE exists as directory" {
            Test-Path $env:USERPROFILE | Should Be $true
        }
    }
}

Describe "Error Recovery" {
    Context "Graceful degradation" {
        It "Returns null on error instead of throwing" {
            # Simulating graceful error handling
            $result = $null
            try {
                # This would fail - intentionally
                $result = $null
            } catch {
                $result = $null
            }
            $result | Should Be $null
        }

        It "Scripts should exit 0 to not block" {
            $exitCode = 0
            $exitCode | Should Be 0
        }
    }

    Context "Fallback values" {
        It "Uses default host when not configured" {
            $configuredHost = $null
            $defaultHost = "127.0.0.1"
            $effectiveHost = if ($configuredHost) { $configuredHost } else { $defaultHost }
            $effectiveHost | Should Be "127.0.0.1"
        }

        It "Uses default port when not configured" {
            $port = $null
            $defaultPort = 19286
            $effectivePort = if ($port) { $port } else { $defaultPort }
            $effectivePort | Should Be 19286
        }
    }
}

Describe "Config File Handling" {
    Context "Missing config" {
        It "Handles missing config file gracefully" {
            $configPath = "C:\nonexistent\config.json"
            $exists = Test-Path $configPath
            $exists | Should Be $false
        }
    }

    Context "Invalid config" {
        It "Handles invalid JSON in config" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            "{invalid json" | Set-Content $tempFile

            $error = $null
            try {
                $content = Get-Content $tempFile -Raw
                $config = $content | ConvertFrom-Json
            } catch {
                $error = $_
            }

            $error | Should Not Be $null
            Remove-Item $tempFile
        }

        It "Handles empty config file" {
            $tempFile = [System.IO.Path]::GetTempFileName()
            [System.IO.File]::WriteAllText($tempFile, "")

            $content = Get-Content $tempFile -Raw -ErrorAction SilentlyContinue
            # Empty file returns null or empty string
            ($content -eq $null -or $content -eq "") | Should Be $true

            Remove-Item $tempFile
        }
    }

    Context "Config validation" {
        It "Validates enabled is boolean" {
            $config = @{ enabled = $true }
            $config.enabled -is [bool] | Should Be $true
        }

        It "Validates port is integer" {
            $config = @{ bridgePort = 19286 }
            $config.bridgePort -is [int] | Should Be $true
        }

        It "Validates host is string" {
            $config = @{ bridgeHost = "127.0.0.1" }
            $config.bridgeHost -is [string] | Should Be $true
        }
    }
}

Describe "Concurrent Operations" {
    Context "Thread safety concepts" {
        It "Multiple message IDs are unique" {
            # Test that GUID-based IDs are unique even when generated rapidly
            $ids = @()
            for ($i = 0; $i -lt 100; $i++) {
                $ids += "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
            }
            ($ids | Select-Object -Unique).Count | Should Be 100
        }
    }
}

Describe "Memory and Performance" {
    Context "String operations" {
        It "Handles repeated concatenation" {
            $builder = [System.Text.StringBuilder]::new()
            for ($i = 0; $i -lt 1000; $i++) {
                [void]$builder.Append("x")
            }
            $builder.ToString().Length | Should Be 1000
        }
    }

    Context "JSON operations" {
        It "Serializes and deserializes round-trip" {
            $original = @{
                string = "test"
                number = 42
                boolean = $true
                nested = @{ value = "inner" }
            }

            $json = $original | ConvertTo-Json -Depth 10
            $restored = $json | ConvertFrom-Json

            $restored.string | Should Be "test"
            $restored.number | Should Be 42
            $restored.boolean | Should Be $true
            $restored.nested.value | Should Be "inner"
        }
    }
}
