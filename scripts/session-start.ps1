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
    deviceId = $env:COMPUTERNAME
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

# Always allow session to start
exit 0
