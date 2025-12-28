# Claude Code Companion - Session Start Hook
# Notifies the phone when a Claude Code session starts

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
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
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow session to start
exit 0
