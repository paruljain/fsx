# Requires fsx.simconnect.ps1 in the same folder

$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition

if (!$global:fsxConnected) {
    . "$scriptPath\fsxSimconnect.ps1"
}

# Shorthand to send string data back to client over HTTP
function SendData($response, $text) {
    if ($text) {
        [byte[]] $buffer = [System.Text.Encoding]::UTF8.GetBytes($text)
        $response.ContentLength64 = $buffer.length
        $output = $response.OutputStream
        $output.Write($buffer, 0, $buffer.length)
        $output.Close()
    }
}

# The following .Net 4.5 library is required to find correct mime type for file extensions
[System.Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8000/') # Must exactly match the netsh command issued part of install procedure

$listener.Start()
write-host 'Listening ...'
while ($global:fsxConnected) {
    $context = $listener.GetContext() # blocks until request is received
    $request = $context.Request
    $response = $context.Response

    # Equivalent to 'routes' in other frameworks
    if ($request.RawUrl -match '/cmd' -and $request.HttpMethod -eq'POST' `
        -and $request.HasEntityBody -and $request.ContentType -match 'application/json') {
        $sr = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
        $json = $sr.ReadToEnd() | ConvertFrom-Json
        $cmd =$json.cmd
        $param = $json.param

        try {
            transmit -eventid ([EventId]::Parse([EventId], $cmd)) -param $param
        } catch {}
        $response.Close()
    }

    elseif ($request.RawUrl -match '/getall') {
        $response.ContentType = 'application/json'
        SendData -response $response -text ($global:sim | ConvertTo-Json)
        $response.Close()
    }

    # This will terminate the script (WebServer)
    elseif ($request.RawUrl -match '/end$') { $response.close(); break }

    else { # Serve file
        $rawUrl = $request.RawUrl
        if ($rawUrl -eq '/') { $rawUrl = '/index.html' }
        $file = $scriptPath + $rawUrl -replace '/','\'
        if (Test-Path $file) {
            if ($file -match '\.(\w+)$') {
                $response.ContentType = [System.Web.MimeMapping]::GetMimeMapping($matches[0])
            }
            $buffer = Get-Content $file -Encoding Byte -ReadCount 0
            $response.ContentLength64 = $buffer.length
            $output = $response.OutputStream
            $output.Write($buffer, 0, $buffer.length)
            $output.Close()
            $response.Close()
        }
        else {
            $response.StatusCode = 404
            $response.StatusDescription = 'Not Found'
            $response.Close()
        }
    }
}

$listener.Stop()
