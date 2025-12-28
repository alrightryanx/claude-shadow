# Claude Code Companion - Notification Hook
# Forwards Claude Code notifications to the phone

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    exit 0
}

$sessionId = $hookInput.session_id
$notificationMessage = $hookInput.message
$notificationType = $hookInput.notification_type

# Build notification message
$message = @{
    type = "notification"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    deviceId = $env:COMPUTERNAME
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        message = $notificationMessage
        notificationType = $notificationType
        hostname = $env:COMPUTERNAME
    }
}

# Send to bridge (fire and forget)
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow notification to proceed
exit 0
