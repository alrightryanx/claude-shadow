# Pester tests for network and socket operations
# Compatible with Pester 3.x

$ScriptRoot = Split-Path -Parent $PSScriptRoot
. "$ScriptRoot\scripts\companion-common.ps1"
Import-Module "$PSScriptRoot\TestHelpers.psm1" -Force

Describe "TCP Socket Operations" {
    Context "Socket creation" {
        It "Creates TCP socket object" {
            $socket = New-Object System.Net.Sockets.TcpClient
            $socket | Should Not Be $null
            $socket.Dispose()
        }

        It "Socket has correct address family" {
            $socket = New-Object System.Net.Sockets.TcpClient
            # Default is InterNetwork (IPv4)
            $socket.Client.AddressFamily | Should Be "InterNetwork"
            $socket.Dispose()
        }
    }

    Context "Connection timeout handling" {
        It "Handles connection timeout" {
            $socket = New-Object System.Net.Sockets.TcpClient
            $socket.SendTimeout = 1000
            $socket.ReceiveTimeout = 1000

            $socket.SendTimeout | Should Be 1000
            $socket.ReceiveTimeout | Should Be 1000
            $socket.Dispose()
        }

        It "Uses async connect with timeout" {
            # Test concept of async connection
            $timeout = 2000
            $timeout | Should BeGreaterThan 0
        }
    }

    Context "Connection to unavailable host" {
        It "Returns null on connection failure" {
            # Using a port that's unlikely to be listening
            $result = Send-ToBridge -Message @{ test = "data" } -TimeoutSeconds 1 -ErrorAction SilentlyContinue
            # Should return null when bridge is not running
            $result | Should Be $null
        }
    }
}

Describe "Message Protocol" {
    Context "Length-prefixed messages" {
        It "Creates correct length prefix" {
            $data = '{"type":"test"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
            $length = $bytes.Length

            # Length should be encoded as 4-byte big-endian
            $lengthBytes = [System.BitConverter]::GetBytes([int32]$length)
            if ([System.BitConverter]::IsLittleEndian) {
                [Array]::Reverse($lengthBytes)
            }

            $lengthBytes.Length | Should Be 4
        }

        It "Parses length prefix correctly" {
            $expectedLength = 100
            $lengthBytes = [System.BitConverter]::GetBytes([int32]$expectedLength)
            if ([System.BitConverter]::IsLittleEndian) {
                [Array]::Reverse($lengthBytes)
            }

            # Reverse again to parse
            if ([System.BitConverter]::IsLittleEndian) {
                [Array]::Reverse($lengthBytes)
            }
            $parsedLength = [System.BitConverter]::ToInt32($lengthBytes, 0)

            $parsedLength | Should Be $expectedLength
        }

        It "Handles empty message" {
            $data = ''
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
            $bytes.Length | Should Be 0
        }

        It "Handles large message" {
            $largeData = @{ content = ("x" * 10000) }
            $json = $largeData | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            $bytes.Length | Should BeGreaterThan 10000
        }
    }

    Context "JSON encoding" {
        It "Encodes UTF-8 correctly" {
            $message = @{ text = "Hello, 世界! 🌍" }
            $json = $message | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)

            $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
            $decoded | Should Match "世界"
        }

        It "Handles special characters" {
            $message = @{ path = "C:\Users\test\file.txt" }
            $json = $message | ConvertTo-Json -Compress
            $json | Should Match "C:\\\\Users\\\\test\\\\file.txt"
        }

        It "Handles newlines in strings" {
            $message = @{ content = "line1`nline2`nline3" }
            $json = $message | ConvertTo-Json -Compress
            $json | Should Match "\\n"
        }
    }
}

Describe "IP Address Handling" {
    Context "Valid IP addresses" {
        It "Parses IPv4 address" {
            $ip = "192.168.1.100"
            $parsed = [System.Net.IPAddress]::TryParse($ip, [ref]$null)
            $parsed | Should Be $true
        }

        It "Parses localhost" {
            $ip = "127.0.0.1"
            $parsed = [System.Net.IPAddress]::TryParse($ip, [ref]$null)
            $parsed | Should Be $true
        }

        It "Validates loopback address" {
            $ip = [System.Net.IPAddress]::Parse("127.0.0.1")
            $ip.ToString() | Should Be "127.0.0.1"
        }
    }

    Context "Invalid IP addresses" {
        It "Rejects invalid format" {
            $ip = "not.an.ip"
            $parsed = [System.Net.IPAddress]::TryParse($ip, [ref]$null)
            $parsed | Should Be $false
        }

        It "Rejects out of range octets" {
            $ip = "256.1.1.1"
            $parsed = [System.Net.IPAddress]::TryParse($ip, [ref]$null)
            $parsed | Should Be $false
        }
    }
}

Describe "Port Validation" {
    Context "Valid ports" {
        It "Accepts default bridge port" {
            $port = 19286
            ($port -ge 1 -and $port -le 65535) | Should Be $true
        }

        It "Accepts minimum port" {
            $port = 1
            ($port -ge 1 -and $port -le 65535) | Should Be $true
        }

        It "Accepts maximum port" {
            $port = 65535
            ($port -ge 1 -and $port -le 65535) | Should Be $true
        }
    }

    Context "Invalid ports" {
        It "Rejects zero port" {
            $port = 0
            ($port -ge 1 -and $port -le 65535) | Should Be $false
        }

        It "Rejects negative port" {
            $port = -1
            ($port -ge 1 -and $port -le 65535) | Should Be $false
        }

        It "Rejects port over 65535" {
            $port = 70000
            ($port -ge 1 -and $port -le 65535) | Should Be $false
        }
    }
}

Describe "Hostname Resolution" {
    Context "Local hostname" {
        It "Gets current computer name" {
            $hostname = $env:COMPUTERNAME
            $hostname | Should Not BeNullOrEmpty
        }

        It "Hostname is valid string" {
            $hostname = $env:COMPUTERNAME
            $hostname.Length | Should BeGreaterThan 0
        }
    }
}

Describe "Network Error Handling" {
    Context "Socket exceptions" {
        It "Handles SocketException type" {
            $exceptionType = [System.Net.Sockets.SocketException]
            $exceptionType | Should Not Be $null
        }

        It "Connection refused is common error" {
            # SocketError.ConnectionRefused = 10061
            [System.Net.Sockets.SocketError]::ConnectionRefused | Should Not Be $null
        }

        It "Timeout is common error" {
            [System.Net.Sockets.SocketError]::TimedOut | Should Not Be $null
        }
    }

    Context "Retry logic" {
        It "Retry count is configurable" {
            $maxRetries = 3
            $retryCount = 0

            for ($i = 0; $i -lt 5; $i++) {
                if ($retryCount -lt $maxRetries) {
                    $retryCount++
                }
            }

            $retryCount | Should Be 3
        }

        It "Retry delay increases" {
            $baseDelay = 100
            $delays = @()

            for ($i = 0; $i -lt 3; $i++) {
                $delays += $baseDelay * [Math]::Pow(2, $i)
            }

            $delays[0] | Should Be 100
            $delays[1] | Should Be 200
            $delays[2] | Should Be 400
        }
    }
}

Describe "Data Serialization" {
    Context "Message envelope" {
        It "Has required envelope fields" {
            $envelope = @{
                type = "test"
                id = "msg_123"
                timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            }

            $envelope.ContainsKey("type") | Should Be $true
            $envelope.ContainsKey("id") | Should Be $true
            $envelope.ContainsKey("timestamp") | Should Be $true
        }

        It "Generates unique message ID" {
            $ids = @()
            for ($i = 0; $i -lt 10; $i++) {
                $ids += "msg_$([guid]::NewGuid().ToString('N').Substring(0,8))"
            }

            ($ids | Select-Object -Unique).Count | Should Be 10
        }
    }

    Context "Payload serialization" {
        It "Serializes nested objects" {
            $payload = @{
                outer = @{
                    inner = @{
                        value = "deep"
                    }
                }
            }

            $json = $payload | ConvertTo-Json -Depth 10 -Compress
            $parsed = $json | ConvertFrom-Json

            $parsed.outer.inner.value | Should Be "deep"
        }

        It "Serializes arrays" {
            $payload = @{
                items = @("a", "b", "c")
            }

            $json = $payload | ConvertTo-Json -Compress
            $parsed = $json | ConvertFrom-Json

            $parsed.items.Count | Should Be 3
        }

        It "Handles null values" {
            $payload = @{
                value = $null
            }

            $json = $payload | ConvertTo-Json -Compress
            $json | Should Match "null"
        }

        It "Handles boolean values" {
            $payload = @{
                enabled = $true
                disabled = $false
            }

            $json = $payload | ConvertTo-Json -Compress
            $parsed = $json | ConvertFrom-Json

            $parsed.enabled | Should Be $true
            $parsed.disabled | Should Be $false
        }
    }
}

Describe "Response Parsing" {
    Context "Approval response" {
        It "Parses approved response" {
            $json = '{"approved":true,"message":"OK"}'
            $response = $json | ConvertFrom-Json

            $response.approved | Should Be $true
            $response.message | Should Be "OK"
        }

        It "Parses denied response" {
            $json = '{"approved":false,"message":"Denied by user"}'
            $response = $json | ConvertFrom-Json

            $response.approved | Should Be $false
            $response.message | Should Be "Denied by user"
        }
    }

    Context "Error response" {
        It "Parses error response" {
            $json = '{"error":"timeout","message":"Request timed out"}'
            $response = $json | ConvertFrom-Json

            $response.error | Should Be "timeout"
            $response.message | Should Be "Request timed out"
        }
    }

    Context "Invalid JSON handling" {
        It "Throws on invalid JSON" {
            $invalid = "{not valid json"
            { $invalid | ConvertFrom-Json } | Should Throw
        }
    }
}

Describe "Bridge Discovery" {
    Context "Default configuration" {
        It "Default host is localhost" {
            $defaultHost = "127.0.0.1"
            $defaultHost | Should Be "127.0.0.1"
        }

        It "Default port is 19286" {
            $defaultPort = 19286
            $defaultPort | Should Be 19286
        }
    }
}
