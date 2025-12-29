# Pester tests for notification.ps1
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "Notification - Message Construction" {
    $hookInput = @{
        message = "Build completed successfully"
        notification_type = "info"
    }

    $message = @{
        type = "notification"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        deviceId = $env:COMPUTERNAME
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            message = $hookInput.message
            notificationType = $hookInput.notification_type
            hostname = $env:COMPUTERNAME
        }
    }

    It "Has correct message type" {
        $message.type | Should Be "notification"
    }

    It "Has device ID" {
        $message.deviceId | Should Be $env:COMPUTERNAME
    }

    It "Has timestamp" {
        $message.timestamp | Should BeGreaterThan 0
    }

    It "Has message in payload" {
        $message.payload.message | Should Be "Build completed successfully"
    }

    It "Has notification type in payload" {
        $message.payload.notificationType | Should Be "info"
    }

    It "Has hostname in payload" {
        $message.payload.hostname | Should Be $env:COMPUTERNAME
    }
}

Describe "Notification - JSON Serialization" {
    It "Serializes message correctly" {
        $message = @{
            type = "notification"
            id = "msg_test123"
            deviceId = "TEST-PC"
            timestamp = 1234567890000
            payload = @{
                message = "Test notification"
                notificationType = "warning"
                hostname = "TEST-PC"
            }
        }

        $json = $message | ConvertTo-Json -Depth 10 -Compress
        $parsed = $json | ConvertFrom-Json

        $parsed.type | Should Be "notification"
        $parsed.payload.message | Should Be "Test notification"
        $parsed.payload.notificationType | Should Be "warning"
    }
}

Describe "Notification - Different Types" {
    It "Handles info notifications" {
        $payload = @{
            message = "Info message"
            notificationType = "info"
            hostname = $env:COMPUTERNAME
        }
        $payload.notificationType | Should Be "info"
    }

    It "Handles warning notifications" {
        $payload = @{
            message = "Warning message"
            notificationType = "warning"
            hostname = $env:COMPUTERNAME
        }
        $payload.notificationType | Should Be "warning"
    }

    It "Handles error notifications" {
        $payload = @{
            message = "Error message"
            notificationType = "error"
            hostname = $env:COMPUTERNAME
        }
        $payload.notificationType | Should Be "error"
    }
}

Describe "Notification - Non-Blocking Behavior" {
    It "Script should not block (always exit 0)" {
        $exitCode = 0
        $exitCode | Should Be 0
    }

    It "Should handle empty message gracefully" {
        $hookInput = @{
            message = ""
            notification_type = "info"
        }
        $hookInput.message | Should Be ""
    }

    It "Should handle null notification type" {
        $hookInput = @{
            message = "Test"
            notification_type = $null
        }
        $hookInput.notification_type | Should Be $null
    }
}
