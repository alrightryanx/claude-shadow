# Claude Shadow - Test Helper Functions
# Shared mocks and utilities for Pester tests

# Mock stdin input for Read-HookInput
function Mock-StdinInput {
    param([string]$JsonInput)

    # Create a StringReader to simulate stdin
    $reader = [System.IO.StringReader]::new($JsonInput)
    return $reader
}

# Create a mock hook input object
function New-MockHookInput {
    param(
        [string]$SessionId = "test-session-123",
        [string]$ToolName = "Bash",
        [hashtable]$ToolInput = @{ command = "echo hello" },
        [string]$ToolUseId = "tool-use-456",
        [string]$Cwd = "C:\test\project"
    )

    return @{
        session_id = $SessionId
        tool_name = $ToolName
        tool_input = $ToolInput
        tool_use_id = $ToolUseId
        cwd = $Cwd
    }
}

# Create a mock session start input
function New-MockSessionStartInput {
    param(
        [string]$SessionId = "test-session-123",
        [string]$Cwd = "C:\test\project",
        [string]$TranscriptPath = "C:\Users\test\.claude\transcripts\test.jsonl"
    )

    return @{
        session_id = $SessionId
        cwd = $Cwd
        transcript_path = $TranscriptPath
    }
}

# Create mock bridge response
function New-MockBridgeResponse {
    param(
        [string]$Type = "approval_response",
        [bool]$Approved = $true,
        [string]$Message = ""
    )

    return @{
        type = $Type
        approved = $Approved
        message = $Message
    }
}

# Assert JSON structure has required keys
function Assert-HasKeys {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string[]]$Keys
    )

    foreach ($key in $Keys) {
        if (-not ($Object.PSObject.Properties.Name -contains $key)) {
            throw "Missing required key: $key"
        }
    }
    return $true
}

# Create a temporary config file for testing
function New-TempConfigFile {
    param(
        [string]$BridgeHost = "192.168.1.100",
        [int]$BridgePort = 19286,
        [bool]$Enabled = $true
    )

    $tempPath = [System.IO.Path]::GetTempFileName()
    $config = @{
        bridgeHost = $BridgeHost
        bridgePort = $BridgePort
        enabled = $Enabled
    }
    $config | ConvertTo-Json | Set-Content $tempPath
    return $tempPath
}

# Create a mock transcript file for testing
function New-MockTranscriptFile {
    param(
        [string]$AssistantMessage = "This is the AI response for testing purposes."
    )

    $tempPath = [System.IO.Path]::GetTempFileName()
    $lines = @(
        '{"type":"user","message":{"role":"user","content":"Hello"}}'
        '{"type":"assistant","message":{"role":"assistant","content":"' + $AssistantMessage + '"}}'
    )
    $lines | Set-Content $tempPath
    return $tempPath
}

Export-ModuleMember -Function *
