# Claude Code Companion - Notification Hook
# Forwards Claude Code notifications to the phone with reply capability

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    exit 0
}

$sessionId = $hookInput.session_id
$notificationMessage = $hookInput.message
$notificationType = $hookInput.notification_type

# Generate a unique notification ID for reply tracking
$notificationId = "notif_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

# Create a more informative summary for vague messages like "Waiting for user input"
$summary = $notificationMessage
$displayMessage = $notificationMessage

# Enhance vague notification messages with better context
if ($notificationMessage -match "(?i)waiting.*input|user.*input|awaiting.*response") {
    $summary = "Claude Code needs your input"
    $displayMessage = "Claude Code is waiting for your response. Tap Reply to respond or queue a message."
} elseif ($notificationMessage -match "(?i)bash|command|shell|terminal") {
    $summary = "Command notification"
    # Keep the original message but ensure it's actionable
}

# Build notification message with reply capability
$message = @{
    type = "notification"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    # deviceId omitted - bridge sends to any connected device
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        notificationId = $notificationId
        message = $displayMessage
        summary = $summary
        originalMessage = $notificationMessage
        notificationType = $notificationType
        hostname = $env:COMPUTERNAME
        # Always include Reply option so user can respond or queue messages
        options = @("Reply", "Dismiss")
        # Include prompt info so Android knows this is actionable
        promptType = "NOTIFICATION"
        allowReply = $true
    }
}

# Send to bridge (fire and forget - notifications don't wait for response)
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow notification to proceed
exit 0
