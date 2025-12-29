# Pester tests for permission-request.ps1
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "Permission Request - Approval ID Generation" {
    It "Generates valid approval ID format" {
        $approvalId = "approval_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        $approvalId | Should Match "^approval_\d{14}_[a-f0-9]{8}$"
    }

    It "Generates unique IDs" {
        $ids = @()
        for ($i = 0; $i -lt 10; $i++) {
            $ids += "approval_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        }
        ($ids | Select-Object -Unique).Count | Should Be 10
    }
}

Describe "Permission Request - Message Construction" {
    $hookInput = New-MockHookInput -ToolName "Write" -ToolInput @{ file_path = "C:\test\file.txt" }
    $sessionId = $hookInput.session_id
    $toolName = $hookInput.tool_name
    $toolInput = $hookInput.tool_input
    $toolUseId = $hookInput.tool_use_id
    $cwd = $hookInput.cwd

    $prompt = Get-FriendlyToolDescription -ToolName $toolName -ToolInput $toolInput
    $approvalId = "approval_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

    $message = @{
        type = "approval_request"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        sessionId = $sessionId
        deviceId = $env:COMPUTERNAME
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            approvalId = $approvalId
            toolName = $toolName
            toolInput = $toolInput
            toolUseId = $toolUseId
            prompt = $prompt
            promptType = "PERMISSION"
            options = @("Approve", "Deny")
            cwd = $cwd
        }
    }

    It "Has correct message type" {
        $message.type | Should Be "approval_request"
    }

    It "Has session ID" {
        $message.sessionId | Should Not BeNullOrEmpty
    }

    It "Has device ID (computer name)" {
        $message.deviceId | Should Be $env:COMPUTERNAME
    }

    It "Has timestamp" {
        $message.timestamp | Should BeGreaterThan 0
    }

    It "Has payload with required fields" {
        $message.payload | Should Not Be $null
        $message.payload.approvalId | Should Match "^approval_"
        $message.payload.toolName | Should Be "Write"
        $message.payload.promptType | Should Be "PERMISSION"
        # Check options array contains expected values
        $message.payload.options -contains "Approve" | Should Be $true
        $message.payload.options -contains "Deny" | Should Be $true
    }

    It "Has friendly prompt" {
        $message.payload.prompt | Should Be "Create/overwrite: C:\test\file.txt"
    }
}

Describe "Permission Request - Response Handling" {
    Context "Approved response" {
        It "Generates allow decision output" {
            $approved = $true
            $responseMessage = "Approved by user"

            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "allow"
                        message = if ($responseMessage) { $responseMessage } else { "Approved from ShadowAI" }
                    }
                }
            }

            $output.hookSpecificOutput.decision.behavior | Should Be "allow"
            $output.hookSpecificOutput.decision.message | Should Be "Approved by user"
        }

        It "Uses default message when none provided" {
            $responseMessage = $null

            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "allow"
                        message = if ($responseMessage) { $responseMessage } else { "Approved from ShadowAI" }
                    }
                }
            }

            $output.hookSpecificOutput.decision.message | Should Be "Approved from ShadowAI"
        }
    }

    Context "Denied response" {
        It "Generates deny decision output" {
            $approved = $false
            $responseMessage = "User denied the action"

            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "deny"
                        message = if ($responseMessage) { $responseMessage } else { "Denied from ShadowAI" }
                    }
                }
            }

            $output.hookSpecificOutput.decision.behavior | Should Be "deny"
            $output.hookSpecificOutput.decision.message | Should Be "User denied the action"
        }

        It "Uses default message when none provided" {
            $responseMessage = $null

            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "deny"
                        message = if ($responseMessage) { $responseMessage } else { "Denied from ShadowAI" }
                    }
                }
            }

            $output.hookSpecificOutput.decision.message | Should Be "Denied from ShadowAI"
        }
    }

    Context "JSON serialization" {
        It "Serializes approve decision correctly" {
            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "allow"
                        message = "Approved"
                    }
                }
            }

            $json = Write-HookOutput -Output $output
            $parsed = $json | ConvertFrom-Json

            $parsed.hookSpecificOutput.hookEventName | Should Be "PermissionRequest"
            $parsed.hookSpecificOutput.decision.behavior | Should Be "allow"
        }

        It "Serializes deny decision correctly" {
            $output = @{
                hookSpecificOutput = @{
                    hookEventName = "PermissionRequest"
                    decision = @{
                        behavior = "deny"
                        message = "Denied"
                    }
                }
            }

            $json = Write-HookOutput -Output $output
            $parsed = $json | ConvertFrom-Json

            $parsed.hookSpecificOutput.hookEventName | Should Be "PermissionRequest"
            $parsed.hookSpecificOutput.decision.behavior | Should Be "deny"
        }
    }
}
