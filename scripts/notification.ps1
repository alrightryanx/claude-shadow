# Claude Code Companion - Notification Hook
# Forwards Claude Code notifications to the phone with rich context

. "$PSScriptRoot\companion-common.ps1"

# Debug logging
$logFile = "$env:USERPROFILE\.claude-shadow-debug.log"
$contextCacheFile = "$env:USERPROFILE\.claude-shadow-context.json"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    exit 0
}

"[$timestamp] Notification hook input: $($hookInput | ConvertTo-Json -Compress -Depth 5)" | Add-Content $logFile

$sessionId = $hookInput.session_id
$notificationMessage = $hookInput.message
$notificationType = $hookInput.notification_type
$cwd = $hookInput.cwd

# Check for additional context fields that Claude Code may provide
$questionText = $hookInput.question
$questionOptions = $hookInput.options
$questionHeader = $hookInput.header
$toolName = $hookInput.tool_name
$actionContext = $hookInput.context

# Generate a unique notification ID for reply tracking
$notificationId = "notif_$(Get-Date -Format 'yyyyMMddHHmmss')_$([guid]::NewGuid().ToString('N').Substring(0,8))"

# Extract project name from cwd for context
$projectName = ""
if ($cwd) {
    $pathParts = $cwd -split '[/\\]' | Where-Object { $_ -ne '' }
    if ($pathParts.Count -gt 0) {
        $projectName = $pathParts[-1]
        $projectName = $projectName -replace '-main$', '' -replace '-master$', '' -replace '-dev$', ''
    }
}

# Load recent context from cache (what Claude was last doing)
$recentContext = $null
if (Test-Path $contextCacheFile) {
    try {
        $contextCache = Get-Content $contextCacheFile -Raw | ConvertFrom-Json
        # Only use context from last 5 minutes
        $cacheAge = ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $contextCache.timestamp)
        if ($cacheAge -lt 300) {
            $recentContext = $contextCache
        }
    } catch { }
}

# Build rich context for the notification
$summary = $notificationMessage
$displayMessage = $notificationMessage
$projectContext = if ($projectName) { " [$projectName]" } else { "" }
$isInputRequest = $false

# Priority 1: If we have an explicit question, use it
if ($questionText) {
    $summary = "Question$projectContext"
    $displayMessage = $questionText
    if ($questionOptions -and $questionOptions.Count -gt 0) {
        $optionList = ($questionOptions | ForEach-Object { if ($_.label) { $_.label } else { $_ } }) -join ", "
        $displayMessage = "$questionText`n`nOptions: $optionList"
    }
    $isInputRequest = $true
}
# Priority 2: Check if this is a vague "waiting for input" message
elseif ($notificationMessage -match "(?i)waiting.*input|user.*input|awaiting.*response|waiting on input|need.*input|your (response|input)") {
    $isInputRequest = $true

    # Build context from what we know
    $contextParts = @()

    if ($recentContext) {
        if ($recentContext.lastTool) {
            $contextParts += "Last action: $($recentContext.lastTool)"
        }
        if ($recentContext.lastPromptPreview) {
            $contextParts += $recentContext.lastPromptPreview
        }
    }

    if ($toolName) {
        $contextParts += "Tool: $toolName"
    }

    if ($actionContext) {
        $contextParts += $actionContext
    }

    # Create informative message based on notification type and context
    $actionHint = switch -Regex ($notificationType) {
        "(?i)question" { "Claude has a question for you" }
        "(?i)confirm" { "Claude needs your confirmation" }
        "(?i)choice|select|option" { "Claude needs you to make a choice" }
        "(?i)error|fail" { "Claude encountered an issue" }
        "(?i)plan|review" { "Claude wants you to review a plan" }
        default {
            if ($contextParts.Count -gt 0) {
                "Claude is waiting for your response"
            } else {
                "Claude Code needs your input"
            }
        }
    }

    $summary = "$actionHint$projectContext"

    if ($contextParts.Count -gt 0) {
        $contextInfo = $contextParts -join " | "
        $displayMessage = "$actionHint`n`n$contextInfo`n`nCheck Claude Code to respond, or tap Reply."
    } else {
        $displayMessage = "$actionHint$projectContext.`n`nOpen Claude Code to see the question and respond."
    }
}
# Priority 3: Detect specific patterns in the message
elseif ($notificationMessage -match "(?i)error|exception|fail|crash") {
    $summary = "Error$projectContext"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)complet|finish|done|success") {
    $summary = "Complete$projectContext"
    $displayMessage = if ($projectName) { "Task completed in $projectName" } else { $notificationMessage }
} elseif ($notificationMessage -match "(?i)start|begin|running") {
    $summary = "Started$projectContext"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)bash|command|shell|terminal|exec") {
    $cmdMatch = [regex]::Match($notificationMessage, "(?:command|running|executing)[:\s]*(.+)", "IgnoreCase")
    if ($cmdMatch.Success) {
        $cmd = $cmdMatch.Groups[1].Value.Trim()
        if ($cmd.Length -gt 50) { $cmd = $cmd.Substring(0, 50) + "..." }
        $summary = "Running: $cmd"
    } else {
        $summary = "Command$projectContext"
    }
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)file|read|write|edit|save|creat") {
    $summary = "File operation$projectContext"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)build|compil|gradle|npm|cargo|make") {
    $summary = "Building$projectContext"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)test|spec|assert") {
    $summary = "Testing$projectContext"
    $displayMessage = $notificationMessage
} elseif ($notificationMessage -match "(?i)git|commit|push|pull|merge|branch") {
    $summary = "Git$projectContext"
    $displayMessage = $notificationMessage
} else {
    # Default: use message but add project context
    if ($projectName) {
        $summary = "Claude$projectContext"
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
