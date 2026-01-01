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
$cwd = $hookInput.cwd

# Generate a unique notification ID for reply tracking
$notificationId = "notif_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

# Extract project name from cwd for context
$projectName = ""
if ($cwd) {
    # Extract the last directory name as project name
    # Handle both Windows (C:\path\project) and Unix (/path/project) paths
    $pathParts = $cwd -split '[/\\]' | Where-Object { $_ -ne '' }
    if ($pathParts.Count -gt 0) {
        $projectName = $pathParts[-1]
        # Clean up common project directory suffixes
        $projectName = $projectName -replace '-main$', '' -replace '-master$', '' -replace '-dev$', ''
    }
}

# Create a more informative summary for vague messages like "Waiting for user input"
$summary = $notificationMessage
$displayMessage = $notificationMessage
$projectContext = if ($projectName) { " in $projectName" } else { "" }

# Enhance vague notification messages with better context based on patterns
if ($notificationMessage -match "(?i)waiting.*input|user.*input|awaiting.*response|waiting on input") {
    # Check notification type for more context
    $contextHint = switch -Regex ($notificationType) {
        "(?i)question" { "Claude has a question$projectContext" }
        "(?i)confirm" { "Claude needs confirmation$projectContext" }
        "(?i)choice|select" { "Claude needs you to choose$projectContext" }
        "(?i)error|fail" { "Claude needs guidance$projectContext" }
        default { "Claude paused$projectContext" }
    }
    $summary = $contextHint
    $displayMessage = "$contextHint. Reply with your answer or tap Reply to respond."
} elseif ($notificationMessage -match "(?i)error|exception|fail|crash") {
    $summary = "Error$projectContext"
    $displayMessage = "An error occurred$projectContext`: $notificationMessage"
} elseif ($notificationMessage -match "(?i)complet|finish|done|success") {
    $summary = "Completed$projectContext"
    $displayMessage = if ($projectName) { "Task completed in $projectName" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)start|begin|running") {
    $summary = "Started$projectContext"
    $displayMessage = if ($projectName) { "Task started in $projectName" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)bash|command|shell|terminal|exec") {
    # Extract command if present in message
    $cmdMatch = [regex]::Match($notificationMessage, "(?:command|running|executing)[:\s]*(.+)", "IgnoreCase")
    if ($cmdMatch.Success) {
        $cmd = $cmdMatch.Groups[1].Value.Trim()
        if ($cmd.Length -gt 40) { $cmd = $cmd.Substring(0, 40) + "..." }
        $summary = "$cmd$projectContext"
    } else {
        $summary = "Command$projectContext"
    }
    $displayMessage = if ($projectName) { "$notificationMessage (in $projectName)" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)file|read|write|edit|save|creat") {
    $summary = "File op$projectContext"
    $displayMessage = if ($projectName) { "$notificationMessage (in $projectName)" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)build|compil|gradle|npm|cargo|make") {
    $summary = "Build$projectContext"
    $displayMessage = if ($projectName) { "Building $projectName" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)test|spec|assert") {
    $summary = "Testing$projectContext"
    $displayMessage = if ($projectName) { "Running tests in $projectName" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)git|commit|push|pull|merge|branch") {
    $summary = "Git$projectContext"
    $displayMessage = if ($projectName) { "$notificationMessage (in $projectName)" } else { $notificationMessage }
} else {
    # Default case - still add project context if available
    if ($projectName) {
        $summary = "Claude$projectContext"
        $displayMessage = "$notificationMessage (in $projectName)"
    }
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
        cwd = $cwd
        projectName = $projectName
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
