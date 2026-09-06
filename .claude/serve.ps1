# Minimal static HTTP server for verifying the tool in a browser.
# TcpListener rather than HttpListener: the latter needs a URL ACL (admin) on
# Windows, this does not.
#
# GET  serves the mapped files.
# POST /save/<name>  writes the request body into .claude/shots/<name>, so the
#      page can hand rendered images back for inspection.
#
# Not part of the deliverable — test harness only.

param([int]$Port = 8787)

$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot
$shots = Join-Path $PSScriptRoot 'shots'
if (-not (Test-Path $shots)) { New-Item -ItemType Directory -Path $shots | Out-Null }

# Only the page itself needs an alias; fixtures are reached through /f/, which
# maps anything under the project folder. No route may point outside it — see
# CLAUDE.md.
$map = @{
    '/'                 = (Join-Path $root 'index.html')
    '/index.html'       = (Join-Path $root 'index.html')
    '/test/notfits.fit' = (Join-Path $PSScriptRoot 'notfits.fit')
}

# Reads one CRLF-terminated line straight off the socket. A StreamReader would
# buffer past the headers and swallow the start of a POST body.
function Read-Line($stream) {
    $sb = New-Object System.Text.StringBuilder
    while ($true) {
        $b = $stream.ReadByte()
        if ($b -lt 0) { if ($sb.Length -eq 0) { return $null } else { break } }
        if ($b -eq 10) { break }
        if ($b -ne 13) { [void]$sb.Append([char]$b) }
    }
    return $sb.ToString()
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Host "serving $root on http://127.0.0.1:$Port/"

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $client.NoDelay = $true
        $stream = $client.GetStream()

        $requestLine = Read-Line $stream
        if ([string]::IsNullOrWhiteSpace($requestLine)) { $client.Close(); continue }

        $contentLength = 0
        while ($true) {
            $h = Read-Line $stream
            if ($null -eq $h -or $h -eq '') { break }
            if ($h -match '^(?i)content-length:\s*(\d+)') { $contentLength = [int]$Matches[1] }
        }

        $parts  = $requestLine -split ' '
        $method = $parts[0]
        $path   = $parts[1]
        $q = $path.IndexOf('?'); if ($q -ge 0) { $path = $path.Substring(0, $q) }

        if ($method -eq 'POST' -and $path.StartsWith('/save/')) {
            $name = [System.IO.Path]::GetFileName($path.Substring(6))
            $buf  = New-Object byte[] $contentLength
            $read = 0
            while ($read -lt $contentLength) {
                $n = $stream.Read($buf, $read, $contentLength - $read)
                if ($n -le 0) { break }
                $read += $n
            }
            $dest = Join-Path $shots $name
            [System.IO.File]::WriteAllBytes($dest, $buf)
            $body = [System.Text.Encoding]::ASCII.GetBytes("saved $read bytes")
            $head = "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
            $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
            $stream.Write($hb, 0, $hb.Length)
            $stream.Write($body, 0, $body.Length)
            Write-Host "200 POST $path -> $dest ($read bytes)"
        }
        elseif ($path.StartsWith('/f/') -and -not $path.Contains('..')) {
            $rel = [System.Uri]::UnescapeDataString($path.Substring(3)) -replace '/', '\'
            $target = Join-Path $root $rel
            if (Test-Path -LiteralPath $target) {
                $info = Get-Item -LiteralPath $target
                $head = "HTTP/1.1 200 OK`r`nContent-Type: application/octet-stream`r`nContent-Length: $($info.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
                $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
                $stream.Write($hb, 0, $hb.Length)
                $fs = [System.IO.File]::OpenRead($info.FullName)
                try { $fs.CopyTo($stream, 1048576) } finally { $fs.Close() }
                Write-Host "200 $path ($($info.Length) bytes)"
            } else {
                $body = [System.Text.Encoding]::ASCII.GetBytes("not found: $rel")
                $head = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
                $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
                $stream.Write($hb, 0, $hb.Length)
                $stream.Write($body, 0, $body.Length)
                Write-Host "404 $path"
            }
        }
        elseif ($map[$path] -and (Test-Path -LiteralPath $map[$path])) {
            $info = Get-Item -LiteralPath $map[$path]
            if ($path.EndsWith('.html') -or $path -eq '/') {
                $type = 'text/html; charset=utf-8'
            } else {
                $type = 'application/octet-stream'
            }
            $head = "HTTP/1.1 200 OK`r`n" +
                    "Content-Type: $type`r`n" +
                    "Content-Length: $($info.Length)`r`n" +
                    "Cache-Control: no-store`r`n" +
                    "Connection: close`r`n`r`n"
            $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
            $stream.Write($hb, 0, $hb.Length)
            $fs = [System.IO.File]::OpenRead($info.FullName)
            try { $fs.CopyTo($stream, 1048576) } finally { $fs.Close() }
            Write-Host "200 $path ($($info.Length) bytes)"
        }
        else {
            $body = [System.Text.Encoding]::ASCII.GetBytes("not found: $path")
            $head = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
            $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
            $stream.Write($hb, 0, $hb.Length)
            $stream.Write($body, 0, $body.Length)
            Write-Host "404 $path"
        }
        $stream.Flush()
    } catch {
        Write-Host "error: $($_.Exception.Message)"
    } finally {
        try { $client.Close() } catch {}
    }
}
