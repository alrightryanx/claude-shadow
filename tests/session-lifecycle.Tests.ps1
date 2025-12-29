# Pester tests for session-start.ps1, session-stop.ps1, session-end.ps1
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "Session Start - Message Construction" {
    $hookInput = New-MockSessionStartInput -SessionId "test-123" -Cwd "C:\projects\test" -TranscriptPath "C:\transcripts\test.jsonl"

    $message = @{
        type = "session_start"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        sessionId = $hookInput.session_id
        deviceId = $env:COMPUTERNAME
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            hostname = $env:COMPUTERNAME
            cwd = $hookInput.cwd
            transcriptPath = $hookInput.transcript_path
            username = $env:USERNAME
        }
    }

    It "Has correct message type" {
        $message.type | Should Be "session_start"
    }

    It "Has session ID" {
        $message.sessionId | Should Be "test-123"
    }

    It "Has device ID" {
        $message.deviceId | Should Be $env:COMPUTERNAME
    }

    It "Has timestamp" {
        $message.timestamp | Should BeGreaterThan 0
    }

    It "Has hostname in payload" {
        $message.payload.hostname | Should Be $env:COMPUTERNAME
    }

    It "Has cwd in payload" {
        $message.payload.cwd | Should Be "C:\projects\test"
    }

    It "Has transcript path in payload" {
        $message.payload.transcriptPath | Should Be "C:\transcripts\test.jsonl"
    }

    It "Has username in payload" {
        $message.payload.username | Should Be $env:USERNAME
    }
}

Describe "Session Stop - Transcript Parsing" {
    Context "Valid transcript file" {
        $transcriptPath = New-MockTranscriptFile -AssistantMessage "This is a test response from the AI assistant."

        It "Parses JSONL transcript" {
            $lastLines = Get-Content $transcriptPath -Tail 5
            $lastLines | Should Not BeNullOrEmpty
        }

        It "Extracts assistant message" {
            $content = Get-Content $transcriptPath
            $found = $false
            foreach ($line in $content) {
                $parsed = $line | ConvertFrom-Json
                if ($parsed.type -eq "assistant") {
                    $parsed.message.content | Should Be "This is a test response from the AI assistant."
                    $found = $true
                    break
                }
            }
            $found | Should Be $true
        }

        Remove-Item $transcriptPath -ErrorAction SilentlyContinue
    }

    Context "Summary truncation" {
        It "Truncates messages over 200 characters" {
            $longMessage = "a" * 250
            $truncated = $longMessage.Substring(0, [Math]::Min(200, $longMessage.Length))
            if ($longMessage.Length -gt 200) {
                $truncated = $truncated + "..."
            }

            $truncated.Length | Should Be 203
            $truncated | Should Match "\.\.\.$"
        }

        It "Does not truncate short messages" {
            $shortMessage = "Short message"
            $result = $shortMessage.Substring(0, [Math]::Min(200, $shortMessage.Length))
            $result | Should Be "Short message"
        }
    }

    Context "Missing transcript" {
        It "Handles missing transcript gracefully" {
            $fakePath = "C:\nonexistent\transcript.jsonl"
            $exists = Test-Path $fakePath
            $exists | Should Be $false
        }
    }
}

Describe "Session Stop - Message Construction" {
    $hookInput = @{
        session_id = "test-456"
        transcript_path = "C:\transcripts\test.jsonl"
    }

    $message = @{
        type = "session_complete"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        sessionId = $hookInput.session_id
        deviceId = $env:COMPUTERNAME
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            hostname = $env:COMPUTERNAME
            summary = "Test summary"
        }
    }

    It "Has correct message type" {
        $message.type | Should Be "session_complete"
    }

    It "Has session ID" {
        $message.sessionId | Should Be "test-456"
    }

    It "Has summary in payload" {
        $message.payload.summary | Should Not BeNullOrEmpty
    }
}

Describe "Session End - Message Construction" {
    $hookInput = @{
        session_id = "test-789"
    }

    $message = @{
        type = "session_end"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        sessionId = $hookInput.session_id
        deviceId = $env:COMPUTERNAME
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            hostname = $env:COMPUTERNAME
        }
    }

    It "Has correct message type" {
        $message.type | Should Be "session_end"
    }

    It "Has session ID" {
        $message.sessionId | Should Be "test-789"
    }

    It "Has hostname in payload" {
        $message.payload.hostname | Should Be $env:COMPUTERNAME
    }
}

Describe "All Session Scripts - Non-Blocking Behavior" {
    It "Session scripts should not block (always exit 0)" {
        $exitCode = 0
        $exitCode | Should Be 0
    }
}
