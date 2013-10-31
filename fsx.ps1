# Path where script is located
$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition

# If running on 64 bit OS make sure that 32 bit version of PowerShell is being used
if ((Get-WMIObject win32_OperatingSystem).OsArchitecture -match '64-bit') {
    if ([System.Diagnostics.Process]::GetCurrentProcess().Path -notmatch '\\syswow64\\') {
        'Please run this script with 32-bit version of PowerShell'
        'Both 32-bit and 64-bit versions are installed by default on a 64-bit OS'
        'The 32-bit of PowerShell is usually ' + $env:windir + '\SysWOW64\WindowsPowerShell\v1.0\powershell.exe'
        'The 32-bit of PowerShell Development Tool is usually ' + $env:windir + '\SysWOW64\WindowsPowerShell\v1.0\powershell_ise.exe'
        exit
    }
}

# Make sure that SP2 SIMCONNECT DLL is available
$ref = @($env:windir + '\assembly\GAC_32\Microsoft.FlightSimulator.SimConnect\10.0.61259.0__31bf3856ad364e35\Microsoft.FlightSimulator.SimConnect.dll')
if (!(Test-Path $ref)) {
    "Cannot find $ref"
    'Make sure FSX SP2 is installed'
    exit
}

try { $config = [xml](gc "$scriptPath\fsx.xml") }
catch { 'Unable to find fsx.xml in script folder, or fsx.xml not in proper xml form'; exit }

# Start of embedded c# program
$type = @"
using Microsoft.FlightSimulator.SimConnect;
using System.Runtime.InteropServices;
using System.Threading;
using System;

public class fsx
    {
        private const int WM_USER_SIMCONNECT = 0x0402;
        private SimConnect simconnect;
        public bool connected = false;
        public Struct1 response;

        private enum DEFINITIONS
        {
            Struct1
        }

        private enum DATA_REQUESTS
        {
            REQUEST_1
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi, Pack = 1)]
        public struct Struct1
        {

"@

foreach ($var in $config.fsx.var) {
    $var.type = $var.type.ToLower()
    if ($var.type -eq 'string') { $type += "`t`t`t[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]`r`n" }
    $type += "`t`t`tpublic " + $var.type + ' ' + ($var.name -replace '[\s,:]','_') + ";`r`n"
}

$type += @"
        };

        public enum EVENTID
        {

"@

foreach ($eventid in $config.fsx.eventid) {
    $type += "`t`t`t" + $eventid.name.ToUpper() + ",`r`n"
}

$type += @"
        }

        private enum GROUPS
        {
            group1
        }
        
        private void getMessage()
        {
            while (connected)
            {
                simconnect.ReceiveMessage();
                Thread.Sleep(1000);
            }
        }

        // The case where the user closes FSX
        private void simconnect_OnRecvQuit(SimConnect sender, SIMCONNECT_RECV data)
        {
            connected = false;
            simconnect.Dispose();
        }

        private void simconnect_OnRecvSimobjectData(SimConnect sender, SIMCONNECT_RECV_SIMOBJECT_DATA data)
        {
            if ((DATA_REQUESTS)data.dwRequestID == DATA_REQUESTS.REQUEST_1)
            {
                response = (Struct1)data.dwData[0];
            }
        }
        
        public void transmit(string eventIdString, int param = 0)
        {
            if (connected)
            {
                try
                {
                    EVENTID eventId = (EVENTID)Enum.Parse(typeof(EVENTID), eventIdString);
                    uint newParam;
                    if (param < 0)
                    {
                        newParam = Convert.ToUInt32(Convert.ToString(param, 16), 16);
                    }
                    else
                    {
                        newParam = (uint)param;
                    }
                    simconnect.TransmitClientEvent(0, eventId, newParam, GROUPS.group1, SIMCONNECT_EVENT_FLAG.GROUPID_IS_PRIORITY);
                }
                catch {}
            }
        }

        public fsx()
        {
            simconnect = new SimConnect("FSXController", IntPtr.Zero, WM_USER_SIMCONNECT, null, 0);
            connected = true;
            simconnect.OnRecvQuit += new SimConnect.RecvQuitEventHandler(simconnect_OnRecvQuit);

"@

$dataDefTypeMap = @{
    string = 'SIMCONNECT_DATATYPE.STRING256'
    int = 'SIMCONNECT_DATATYPE.INT32'
    long = 'SIMCONNECT_DATATYPE.INT64'
    float = 'SIMCONNECT_DATATYPE.FLOAT32'
    double = 'SIMCONNECT_DATATYPE.FLOAT64'
}

foreach ($var in $config.fsx.var) {
    $var.type = $var.type.ToLower()
    if ($dataDefTypeMap.ContainsKey($var.type)) {
        if ($var.unit) { $unit = '"' + $var.unit + '"' } else { $unit = 'null' }
        $type += "`t`t`tsimconnect.AddToDataDefinition(DEFINITIONS.Struct1, "
        $type += '"' + $var.name + '", ' + $unit + ', ' + $dataDefTypeMap[$var.type] + ', 0, SimConnect.SIMCONNECT_UNUSED);' + "`r`n"
    }
}

$type += @" 
            simconnect.RegisterDataDefineStruct<Struct1>(DEFINITIONS.Struct1);

            // catch a simobject data request
            simconnect.OnRecvSimobjectData += new SimConnect.RecvSimobjectDataEventHandler(simconnect_OnRecvSimobjectData);
            simconnect.RequestDataOnSimObject(DATA_REQUESTS.REQUEST_1, DEFINITIONS.Struct1, SimConnect.SIMCONNECT_OBJECT_ID_USER, SIMCONNECT_PERIOD.SECOND, 0, 0, 0, 0);

            foreach (EVENTID value in Enum.GetValues(typeof(EVENTID)))
            {
                simconnect.MapClientEventToSimEvent(value, value.ToString());
            }

            new Thread(getMessage).Start();
        }

        public void Disconnect()
        {
            if (connected)
            {
                connected = false;
                simconnect.Dispose();
            }
        }
    }
"@
# End of embedded c# program

# Add the above c# program as a type so that it can be used from PowerShell
if (-not ("fsx" -as [type])) {
    Add-Type -ReferencedAssemblies $ref -TypeDefinition $type
}

# Shorthand to send string data back to client over HTTP
function SendData($response, $text) {
    [byte[]] $buffer = [System.Text.Encoding]::UTF8.GetBytes($text)
    $response.ContentLength64 = $buffer.length
    $output = $response.OutputStream
    $output.Write($buffer, 0, $buffer.length)
    $output.Close()
}

# The following .Net 4.5 library is required to find correct mime type for file extensions
[System.Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null

try { $fsx = New-Object fsx }
catch { 'Looks like FSX is not running. Please start FSX and then run this script'; exit }

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8000/') # Must exactly match the netsh command issued part of install procedure

$listener.Start()
write-host 'Listening ...'
while ($fsx.connected) {
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

        if ($cmd -eq 'end') { $response.Close(); break }
        $fsx.transmit($cmd, $param)
        $response.Close()
    }

    elseif ($request.RawUrl -match '/getall') {
        $response.ContentType = 'application/json'
        SendData -response $response -text ($fsx.response | ConvertTo-Json)
        $response.Close()
    }

    # This will terminate the script. Remove from production!
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
$fsx.Disconnect()
