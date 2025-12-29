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
        [int]$TimeoutSeconds = 300
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

    switch ($ToolName) {
        "Bash" {
            $cmd = $ToolInput.command
            if ($cmd.Length -gt 100) {
                $cmd = $cmd.Substring(0, 100) + "..."
            }
            return "Run command: $cmd"
        }
        "Write" {
            return "Create/overwrite: $($ToolInput.file_path)"
        }
        "Edit" {
            return "Edit file: $($ToolInput.file_path)"
        }
        "Read" {
            return "Read file: $($ToolInput.file_path)"
        }
        "WebFetch" {
            return "Fetch URL: $($ToolInput.url)"
        }
        "WebSearch" {
            return "Search web: $($ToolInput.query)"
        }
        default {
            $inputStr = $ToolInput | ConvertTo-Json -Compress
            if ($inputStr.Length -gt 100) {
                $inputStr = $inputStr.Substring(0, 100) + "..."
            }
            return "${ToolName}: $inputStr"
        }
    }
}
