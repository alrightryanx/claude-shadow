# Claude Code Companion - User Prompt Hook
# Sends user prompts to the phone for conversation sync

. "$PSScriptRoot\companion-common.ps1"

# Debug logging
$logFile = "$env:USERPROFILE\.claude-shadow-debug.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"[$timestamp] User-prompt hook invoked" | Add-Content $logFile

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    "[$timestamp] No hook input, exiting" | Add-Content $logFile
    exit 0
}

$sessionId = $hookInput.session_id
$prompt = $hookInput.prompt
$cwd = $hookInput.cwd

"[$timestamp] User prompt: sessionId=$sessionId, prompt=$($prompt.Substring(0, [Math]::Min(50, $prompt.Length)))..." | Add-Content $logFile

# Build session message for user prompt
$message = @{
    type = "session_message"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        role = "user"
        content = $prompt
        hostname = $env:COMPUTERNAME
        cwd = $cwd
    }
}

# Send to bridge (fire and forget - don't block user input)
"[$timestamp] Sending user message to bridge" | Add-Content $logFile
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow prompt to proceed
exit 0
