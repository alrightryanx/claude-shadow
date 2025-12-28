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

function Send-ToBridge {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Message,
        [int]$TimeoutSeconds = 300
    )

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
            Write-Error "Connection to ShadowBridge timed out"
            return $null
        }

        $stream = $tcpClient.GetStream()
        $reader = New-Object System.IO.BinaryReader($stream)
        $writer = New-Object System.IO.BinaryWriter($stream)

        # Convert message to JSON bytes
        $jsonString = $Message | ConvertTo-Json -Depth 10 -Compress
        $jsonBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonString)

        # Send length-prefixed message (big-endian int32 + bytes)
        $lengthBytes = [BitConverter]::GetBytes([int32]$jsonBytes.Length)
        if ([BitConverter]::IsLittleEndian) {
            [Array]::Reverse($lengthBytes)
        }
        $writer.Write($lengthBytes)
        $writer.Write($jsonBytes)
        $writer.Flush()

        # Read response (length-prefixed)
        $responseLengthBytes = $reader.ReadBytes(4)
        if ([BitConverter]::IsLittleEndian) {
            [Array]::Reverse($responseLengthBytes)
        }
        $responseLength = [BitConverter]::ToInt32($responseLengthBytes, 0)

        if ($responseLength -le 0 -or $responseLength -gt 1000000) {
            Write-Error "Invalid response length: $responseLength"
            return $null
        }

        $responseBytes = $reader.ReadBytes($responseLength)
        $responseJson = [System.Text.Encoding]::UTF8.GetString($responseBytes)

        return $responseJson | ConvertFrom-Json

    } catch {
        Write-Error "Bridge communication error: $_"
        return $null
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($tcpClient) { $tcpClient.Dispose() }
    }
}

function Read-HookInput {
    # Read JSON from stdin
    $inputJson = $input | Out-String
    if ([string]::IsNullOrWhiteSpace($inputJson)) {
        return $null
    }
    return $inputJson | ConvertFrom-Json
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
