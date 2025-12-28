# Claude Code Companion - Session Stop Hook
# Notifies the phone when Claude finishes a response

. "$PSScriptRoot\companion-common.ps1"

# Read hook input from stdin
$hookInput = Read-HookInput
if (-not $hookInput) {
    exit 0
}

$sessionId = $hookInput.session_id
$cwd = $hookInput.cwd
$transcriptPath = $hookInput.transcript_path

# Try to extract summary from transcript
$summary = "Claude finished working"
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    try {
        # Read last few lines of transcript to get summary
        $lastLines = Get-Content $transcriptPath -Tail 5 -ErrorAction SilentlyContinue
        if ($lastLines) {
            foreach ($line in $lastLines) {
                try {
                    $entry = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($entry.role -eq "assistant" -and $entry.content) {
                        # Get first 200 chars of last assistant message
                        $content = $entry.content
                        if ($content -is [array]) {
                            $textContent = ($content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
                            if ($textContent) {
                                $content = $textContent
                            }
                        }
                        if ($content -and $content.Length -gt 0) {
                            $summary = if ($content.Length -gt 200) { $content.Substring(0, 200) + "..." } else { $content }
                        }
                    }
                } catch {
                    # Ignore parse errors
                }
            }
        }
    } catch {
        # Ignore file read errors
    }
}

# Build session stop message
$message = @{
    type = "session_complete"
    id = "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
    sessionId = $sessionId
    deviceId = $env:COMPUTERNAME
    timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    payload = @{
        summary = $summary
        cwd = $cwd
    }
}

# Send to bridge (fire and forget)
$null = Send-ToBridge -Message $message -TimeoutSeconds 5

# Always allow stop to proceed
exit 0
