# Claude Shadow - Common Functions
# Shared utilities for all hook scripts

$script:BRIDGE_PORT = 19286
$script:CONFIG_FILE = "$env:USERPROFILE\.claude-shadow-config.json"

function Get-CompanionConfig {
    if (Test-Path $script:CONFIG_FILE) {
        return Get-Content $script:CONFIG_FILE | ConvertFrom-Json
    }
    return @{
        bridgeHost = "127.0.0.1"
        bridgePort = $script:BRIDGE_PORT
        enabled = $true
    }
}

function Send-LengthPrefixedMessage {
    param($writer, $message)
    $jsonString = $message | ConvertTo-Json -Depth 10 -Compress
    $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonString)
    $lengthBytes = [BitConverter]::GetBytes([int32]$jsonBytes.Length)
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($lengthBytes) }
    $writer.Write($lengthBytes)
    $writer.Write($jsonBytes)
    $writer.Flush()
}

function Read-LengthPrefixedMessage {
    param($reader)
    $responseLengthBytes = $reader.ReadBytes(4)
    if ($responseLengthBytes.Length -lt 4) { return $null }
    if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($responseLengthBytes) }
    $responseLength = [BitConverter]::ToInt32($responseLengthBytes, 0)
    if ($responseLength -le 0 -or $responseLength -gt 1000000) { return $null }
    $responseBytes = $reader.ReadBytes($responseLength)
    return [System.Text.Encoding]::UTF8.GetString($responseBytes) | ConvertFrom-Json
}

function Send-ToBridge {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Message,
        [int]$TimeoutSeconds = 60  # Reduced from 300s for better UX
    )

    $debugLog = "$env:USERPROFILE\.claude-shadow-debug.log"
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $config = Get-CompanionConfig
    if (-not $config.enabled) {
        return $null
    }

    $tcpClient = $null
    $stream = $null
    $reader = $null
    $writer = $null

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.ReceiveTimeout = $TimeoutSeconds * 1000
        $tcpClient.SendTimeout = 10000

        # Try to connect
        $connectTask = $tcpClient.ConnectAsync($config.bridgeHost, $config.bridgePort)
        if (-not $connectTask.Wait(5000)) {
            "[$ts] Send-ToBridge: Connection timed out" | Add-Content $debugLog
            return $null
        }

        $stream = $tcpClient.GetStream()
        $reader = New-Object System.IO.BinaryReader($stream)
        $writer = New-Object System.IO.BinaryWriter($stream)

        # Step 1: Send handshake (no deviceId = plugin client)
        $handshake = @{ type = "handshake" }
        "[$ts] Send-ToBridge: Sending handshake" | Add-Content $debugLog
        Send-LengthPrefixedMessage -writer $writer -message $handshake

        # Wait for handshake ack
        $ack = Read-LengthPrefixedMessage -reader $reader
        if (-not $ack -or $ack.type -ne "handshake_ack") {
            "[$ts] Send-ToBridge: Handshake failed, got: $($ack | ConvertTo-Json -Compress)" | Add-Content $debugLog
            return $null
        }
        "[$ts] Send-ToBridge: Handshake successful" | Add-Content $debugLog

        # Step 2: Send the actual message
        "[$ts] Send-ToBridge: Sending message type=$($Message.type)" | Add-Content $debugLog
        Send-LengthPrefixedMessage -writer $writer -message $Message

        # Step 3: Wait for response (could be immediate ack or approval_response from device)
        $response = Read-LengthPrefixedMessage -reader $reader
        "[$ts] Send-ToBridge: Got response type=$($response.type)" | Add-Content $debugLog

        return $response

    } catch {
        "[$ts] Send-ToBridge: Error - $_" | Add-Content $debugLog
        return $null
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($tcpClient) { $tcpClient.Dispose() }
    }
}

function Read-HookInput {
    # Read JSON from stdin - when launched via "powershell -File"
    # Debug log path
    $debugLog = "$env:USERPROFILE\.claude-shadow-debug.log"
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    try {
        # Method 1: Try reading via .NET Console.In
        $inputJson = ""
        $reader = [Console]::In
        if ($reader) {
            $inputJson = $reader.ReadToEnd()
        }

        "[$ts] Read-HookInput: Got $($inputJson.Length) chars via Console.In" | Add-Content $debugLog

        if ([string]::IsNullOrWhiteSpace($inputJson)) {
            "[$ts] Read-HookInput: Input was empty" | Add-Content $debugLog
            return $null
        }

        # Show first 200 chars of input for debugging
        $preview = if ($inputJson.Length -gt 200) { $inputJson.Substring(0, 200) + "..." } else { $inputJson }
        "[$ts] Read-HookInput: Input preview: $preview" | Add-Content $debugLog

        $parsed = $inputJson | ConvertFrom-Json
        "[$ts] Read-HookInput: Parsed successfully, type=$($parsed.GetType().Name)" | Add-Content $debugLog
        return $parsed
    } catch {
        "[$ts] Read-HookInput: Error - $_" | Add-Content $debugLog
        return $null
    }
}

function Write-HookOutput {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Output
    )
    $Output | ConvertTo-Json -Depth 10 -Compress
}

function Get-FriendlyToolDescription {
    param(
        [string]$ToolName,
        [object]$ToolInput
    )

    # Get short filename from full path
    function Get-ShortPath {
        param([string]$Path)
        if (-not $Path) { return "" }
        $parts = $Path -split '[/\\]' | Where-Object { $_ -ne '' }
        if ($parts.Count -ge 2) {
            return ".../$($parts[-2])/$($parts[-1])"
        } elseif ($parts.Count -eq 1) {
            return $parts[-1]
        }
        return $Path
    }

    switch ($ToolName) {
        "Bash" {
            $cmd = $ToolInput.command
            # Parse command to show meaningful summary
            if ($cmd -match "^(git\s+\w+)") {
                $gitCmd = $matches[1]
                if ($cmd.Length -gt 80) { $cmd = $cmd.Substring(0, 80) + "..." }
                return "$gitCmd`: $cmd"
            } elseif ($cmd -match "^(npm|yarn|pnpm)\s+(\w+)") {
                return "$($matches[1]) $($matches[2])"
            } elseif ($cmd -match "^(gradlew?|./gradlew)\s+(\w+)") {
                return "Gradle: $($matches[2])"
            } elseif ($cmd -match "^(python|python3|py)\s+(.+)") {
                $script = $matches[2]
                if ($script.Length -gt 60) { $script = $script.Substring(0, 60) + "..." }
                return "Python: $script"
            } elseif ($cmd -match "^(adb)\s+(.+)") {
                return "ADB: $($matches[2].Substring(0, [Math]::Min(60, $matches[2].Length)))"
            } else {
                if ($cmd.Length -gt 80) { $cmd = $cmd.Substring(0, 80) + "..." }
                return "Run: $cmd"
            }
        }
        "Write" {
            $shortPath = Get-ShortPath $ToolInput.file_path
            return "Create file: $shortPath"
        }
        "Edit" {
            $shortPath = Get-ShortPath $ToolInput.file_path
            $changePreview = ""
            if ($ToolInput.old_string) {
                $oldLen = $ToolInput.old_string.Length
                $newLen = if ($ToolInput.new_string) { $ToolInput.new_string.Length } else { 0 }
                if ($newLen -gt $oldLen) {
                    $changePreview = " (+$($newLen - $oldLen) chars)"
                } elseif ($oldLen -gt $newLen) {
                    $changePreview = " (-$($oldLen - $newLen) chars)"
                }
            }
            return "Edit: $shortPath$changePreview"
        }
        "Read" {
            $shortPath = Get-ShortPath $ToolInput.file_path
            return "Read: $shortPath"
        }
        "Glob" {
            return "Find files: $($ToolInput.pattern)"
        }
        "Grep" {
            $pattern = $ToolInput.pattern
            if ($pattern.Length -gt 40) { $pattern = $pattern.Substring(0, 40) + "..." }
            return "Search code: $pattern"
        }
        "WebFetch" {
            $url = $ToolInput.url
            # Extract domain for cleaner display
            if ($url -match "https?://([^/]+)") {
                $domain = $matches[1]
                return "Fetch: $domain"
            }
            return "Fetch URL"
        }
        "WebSearch" {
            $query = $ToolInput.query
            if ($query.Length -gt 50) { $query = $query.Substring(0, 50) + "..." }
            return "Search: $query"
        }
        "Task" {
            $desc = $ToolInput.description
            if (-not $desc) { $desc = "Run subtask" }
            return "Agent: $desc"
        }
        "TodoWrite" {
            $count = if ($ToolInput.todos) { $ToolInput.todos.Count } else { 0 }
            return "Update todos ($count items)"
        }
        "AskUserQuestion" {
            $questions = $ToolInput.questions
            if ($questions -and $questions.Count -gt 0) {
                $q = $questions[0].question
                if ($q.Length -gt 60) { $q = $q.Substring(0, 60) + "..." }
                return "Question: $q"
            }
            return "Asking question"
        }
        "LSP" {
            return "Code nav: $($ToolInput.operation)"
        }
        "NotebookEdit" {
            return "Edit notebook"
        }
        default {
            $inputStr = $ToolInput | ConvertTo-Json -Compress -ErrorAction SilentlyContinue
            if ($inputStr -and $inputStr.Length -gt 80) {
                $inputStr = $inputStr.Substring(0, 80) + "..."
            }
            return "${ToolName}: $inputStr"
        }
    }
}
