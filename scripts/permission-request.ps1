# Claude Code Companion - Permission Request Hook
# Sends approval request to phone and waits for response

. "$PSScriptRoot\companion-common.ps1"

# Debug logging
$logFile = "$env:USERPROFILE\.claude-shadow-debug.log"
$contextCacheFile = "$env:USERPROFILE\.claude-shadow-context.json"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

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

# Update context cache with current tool (for notification enrichment)
try {
    $existingContext = @{}
    if (Test-Path $contextCacheFile) {
        $existingContext = Get-Content $contextCacheFile -Raw | ConvertFrom-Json -AsHashtable
    }
    $existingContext.timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $existingContext.lastTool = $toolName
    $existingContext.sessionId = $sessionId
    $existingContext.cwd = $cwd
    $existingContext | ConvertTo-Json -Compress | Set-Content $contextCacheFile -Force
} catch {
    "[$timestamp] Error updating context cache: $_" | Add-Content $logFile
}

# Generate approval ID
$approvalId = "approval_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

# Get friendly description
$prompt = Get-FriendlyToolDescription -ToolName $toolName -ToolInput $toolInput

# Build approval request message
$message = @{
    type = "approval_request"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    # deviceId omitted - bridge sends to any connected device
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        approvalId = $approvalId
        toolName = $toolName
        toolInput = $toolInput
        toolUseId = $toolUseId
        prompt = $prompt
        promptType = "PERMISSION"
        # Always include Reply option so user can respond with context or queue messages
        options = @("Approve", "Deny", "Reply")
        allowReply = $true
        cwd = $cwd
    }
}

# Send to bridge and wait for response (60 second timeout - reduced from 5 min for better UX)
$response = Send-ToBridge -Message $message -TimeoutSeconds 60

if (-not $response) {
    # Bridge not available or timeout - let Claude Code handle normally
    # Send dismiss message to clear notification on phone (user will approve on PC)
    $dismissMessage = @{
        type = "approval_dismiss"
        sessionId = $sessionId
        payload = @{
            approvalId = $approvalId
            reason = "timeout"
        }
    }
    $null = Send-ToBridge -Message $dismissMessage -TimeoutSeconds 2
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
    # Timeout from bridge - send dismiss and let normal flow continue
    $dismissMessage = @{
        type = "approval_dismiss"
        sessionId = $sessionId
        payload = @{
            approvalId = $approvalId
            reason = "timeout"
        }
    }
    $null = Send-ToBridge -Message $dismissMessage -TimeoutSeconds 2
    exit 0
} else {
    # Unknown response - let normal flow continue
    exit 0
}
