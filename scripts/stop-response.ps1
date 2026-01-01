# Claude Code Companion - Stop Hook (Response Sync)
# Sends Claude's response to the phone when Claude finishes responding

. "$PSScriptRoot\companion-common.ps1"

# Debug logging
$logFile = "$env:USERPROFILE\.claude-shadow-debug.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$timestamp] Stop-response hook invoked" | Add-Content $logFile

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    "[$timestamp] No hook input, exiting" | Add-Content $logFile
    exit 0
}

$sessionId = $hookInput.session_id
$transcriptPath = $hookInput.transcript_path
$cwd = $hookInput.cwd

"[$timestamp] Stop hook: sessionId=$sessionId, transcript=$transcriptPath" | Add-Content $logFile

# Try to read the latest assistant message from transcript
$assistantMessage = ""
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $transcriptContent = Get-Content $transcriptPath -Raw -ErrorAction SilentlyContinue

        # Parse JSON transcript to get last assistant message
        # Claude Code transcripts are JSON arrays of message objects
        if ($transcriptContent) {
            $transcript = $transcriptContent | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($transcript -is [array]) {
                # Find the last assistant message
                for ($i = $transcript.Count - 1; $i -ge 0; $i--) {
                    $msg = $transcript[$i]
                    if ($msg.type -eq "assistant" -or $msg.role -eq "assistant") {
                        # Extract content - could be string or array of content blocks
                        if ($msg.message.content -is [string]) {
                            $assistantMessage = $msg.message.content
                        } elseif ($msg.message.content -is [array]) {
                            # Join text blocks
                            $textBlocks = $msg.message.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }
                            $assistantMessage = $textBlocks -join "`n"
                        } elseif ($msg.content -is [string]) {
                            $assistantMessage = $msg.content
                        }
                        break
                    }
                }
            }
        }

        "[$timestamp] Extracted assistant message: $($assistantMessage.Substring(0, [Math]::Min(100, $assistantMessage.Length)))..." | Add-Content $logFile
    } catch {
        "[$timestamp] Error reading transcript: $_" | Add-Content $logFile
    }
}

# Only send if we have content
if ($assistantMessage) {
    # Truncate very long messages for notification display
    $displayMessage = if ($assistantMessage.Length -gt 2000) {
        $assistantMessage.Substring(0, 2000) + "..."
    } else {
        $assistantMessage
    }

    $message = @{
        type = "session_message"
        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
        sessionId = $sessionId
        timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        payload = @{
            role = "assistant"
            content = $displayMessage
            hostname = $env:COMPUTERNAME
            cwd = $cwd
        }
    }

    "[$timestamp] Sending assistant message to bridge" | Add-Content $logFile
    $null = Send-ToBridge -Message $message -TimeoutSeconds 5
} else {
    "[$timestamp] No assistant message found in transcript" | Add-Content $logFile
}

# Always allow stop to proceed
exit 0
