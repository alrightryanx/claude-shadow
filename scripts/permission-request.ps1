# Claude Code Companion - Permission Request Hook
# Sends approval request to phone and waits for response

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    # No input, allow action to proceed normally
    exit 0
}

$sessionId = $hookInput.session_id
$toolName = $hookInput.tool_name
$toolInput = $hookInput.tool_input
$toolUseId = $hookInput.tool_use_id
$cwd = $hookInput.cwd

# Generate approval ID
$approvalId = "approval_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

# Get friendly description
$prompt = Get-FriendlyToolDescription -ToolName $toolName -ToolInput $toolInput

# Build approval request message
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

# Send to bridge and wait for response (5 minute timeout)
$response = Send-ToBridge -Message $message -TimeoutSeconds 300

if (-not $response) {
    # Bridge not available or timeout - let Claude Code handle normally
    # Return empty output with exit 0 to allow normal flow
    exit 0
}

# Process response
if ($response.type -eq "approval_response") {
    $approved = $response.payload.approved
    $responseMessage = $response.payload.message

    if ($approved) {
        # Approved - return allow decision
        $output = @{
            hookSpecificOutput = @{
                hookEventName = "PermissionRequest"
                decision = @{
                    behavior = "allow"
                    message = if ($responseMessage) { $responseMessage } else { "Approved from ShadowAI" }
                }
            }
        }
        Write-HookOutput -Output $output
        exit 0
    } else {
        # Denied - return deny decision
        $output = @{
            hookSpecificOutput = @{
                hookEventName = "PermissionRequest"
                decision = @{
                    behavior = "deny"
                    message = if ($responseMessage) { $responseMessage } else { "Denied from ShadowAI" }
                }
            }
        }
        Write-HookOutput -Output $output
        exit 0
    }
} elseif ($response.type -eq "timeout") {
    # Timeout from bridge - let normal flow continue
    exit 0
} else {
    # Unknown response - let normal flow continue
    exit 0
}
