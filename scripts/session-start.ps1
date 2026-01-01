# Claude Code Companion - Session Start Hook
# Notifies the phone when a Claude Code session starts

. "$PSScriptRoot\companion-common.ps1"

# Debug logging
$logFile = "$env:USERPROFILE\.claude-shadow-debug.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$timestamp] Session-start hook invoked" | Add-Content $logFile

# Read hook input from stdin
$hookInput = Read-HookInput
"[$timestamp] Hook input: $($hookInput | ConvertTo-Json -Compress -ErrorAction SilentlyContinue)" | Add-Content $logFile

if (-not $hookInput) {
    "[$timestamp] No hook input, exiting" | Add-Content $logFile
    exit 0
}

$sessionId = $hookInput.session_id
$cwd = $hookInput.cwd
$transcriptPath = $hookInput.transcript_path

# Build session start message
$message = @{
    type = "session_start"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    # deviceId omitted - bridge will send to any connected device
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        hostname = $env:COMPUTERNAME
        cwd = $cwd
        transcriptPath = $transcriptPath
        username = $env:USERNAME
    }
}

# Send to bridge (fire and forget, don't wait for response)
"[$timestamp] Sending message to bridge: $($message | ConvertTo-Json -Compress)" | Add-Content $logFile
$result = Send-ToBridge -Message $message -TimeoutSeconds 5
"[$timestamp] Bridge response: $result" | Add-Content $logFile

# Sync transcript history if available (for session resumption)
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        $transcriptContent = Get-Content $transcriptPath -Raw -ErrorAction SilentlyContinue

        if ($transcriptContent) {
            $transcript = $transcriptContent | ConvertFrom-Json -ErrorAction SilentlyContinue

            if ($transcript -is [array] -and $transcript.Count -gt 0) {
                "[$timestamp] Found transcript with $($transcript.Count) messages, syncing recent history" | Add-Content $logFile

                # Send last 10 messages to provide context
                $recentMessages = $transcript | Select-Object -Last 10

                foreach ($msg in $recentMessages) {
                    $role = if ($msg.type -eq "human" -or $msg.role -eq "user") { "user" }
                            elseif ($msg.type -eq "assistant" -or $msg.role -eq "assistant") { "assistant" }
                            else { $null }

                    if (-not $role) { continue }

                    # Extract content
                    $content = ""
                    if ($msg.message.content -is [string]) {
                        $content = $msg.message.content
                    } elseif ($msg.message.content -is [array]) {
                        $textBlocks = $msg.message.content | Where-Object { $_.type -eq "text" } | ForEach-Object { $_.text }
                        $content = $textBlocks -join "`n"
                    } elseif ($msg.content -is [string]) {
                        $content = $msg.content
                    }

                    if (-not $content) { continue }

                    # Truncate long messages
                    if ($content.Length -gt 2000) {
                        $content = $content.Substring(0, 2000) + "..."
                    }

                    $historyMessage = @{
                        type = "session_message"
                        id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
                        sessionId = $sessionId
                        timestamp = if ($msg.timestamp) { $msg.timestamp } else { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
                        payload = @{
                            role = $role
                            content = $content
                            hostname = $env:COMPUTERNAME
                            cwd = $cwd
                            isHistory = $true
                        }
                    }

                    $null = Send-ToBridge -Message $historyMessage -TimeoutSeconds 2
                }

                "[$timestamp] Synced $($recentMessages.Count) history messages" | Add-Content $logFile
            }
        }
    } catch {
        "[$timestamp] Error syncing transcript history: $_" | Add-Content $logFile
    }
}

# Always allow session to start
exit 0
