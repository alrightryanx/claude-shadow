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

# Enhance vague notification messages with better context based on patterns
if ($notificationMessage -match "(?i)waiting.*input|user.*input|awaiting.*response|waiting on input") {
    # Check notification type for more context
    $contextHint = switch -Regex ($notificationType) {
        "(?i)question" { "Claude has a question for you" }
        "(?i)confirm" { "Claude needs confirmation to proceed" }
        "(?i)choice|select" { "Claude needs you to make a choice" }
        "(?i)error|fail" { "Claude encountered an issue and needs guidance" }
        default { "Claude Code paused for your input" }
    }
    $summary = $contextHint
    $displayMessage = "$contextHint. Reply with your answer or tap Reply to respond via voice/text."
} elseif ($notificationMessage -match "(?i)error|exception|fail|crash") {
    $summary = "Error notification"
    $displayMessage = "An error occurred: $notificationMessage"
} elseif ($notificationMessage -match "(?i)complet|finish|done|success") {
    $summary = "Task completed"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)start|begin|running") {
    $summary = "Task started"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)bash|command|shell|terminal|exec") {
    # Extract command if present in message
    $cmdMatch = [regex]::Match($notificationMessage, "(?:command|running|executing)[:\s]*(.+)", "IgnoreCase")
    if ($cmdMatch.Success) {
        $cmd = $cmdMatch.Groups[1].Value.Trim()
        if ($cmd.Length -gt 50) { $cmd = $cmd.Substring(0, 50) + "..." }
        $summary = "Running: $cmd"
    } else {
        $summary = "Command notification"
    }
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)file|read|write|edit|save|creat") {
    $summary = "File operation"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)build|compil|gradle|npm|cargo|make") {
    $summary = "Build notification"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)test|spec|assert") {
    $summary = "Test notification"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)git|commit|push|pull|merge|branch") {
    $summary = "Git operation"
    $displayMessage = $notificationMessage
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
