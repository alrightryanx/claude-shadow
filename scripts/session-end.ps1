# Claude Code Companion - Session End Hook
# Notifies the phone when a Claude Code session ends completely

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    exit 0
}

$sessionId = $hookInput.session_id

# Build session end message
$message = @{
    type = "session_end"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    # deviceId omitted - bridge sends to any connected device
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        hostname = $env:COMPUTERNAME
    }
}

# Send to bridge (fire and forget)
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow session to end
exit 0
