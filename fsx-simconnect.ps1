# Path where script is located
$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition

# If running on 64 bit OS make sure that 32 bit version of PowerShell is being used
if ((Get-WMIObject win32_OperatingSystem).OsArchitecture -match '64-bit') {
    if ([System.Diagnostics.Process]::GetCurrentProcess().Path -notmatch '\\syswow64\\') {
        throw 'Please run this script with 32-bit version of PowerShell'
    }
}

# Make sure that SP2 SIMCONNECT DLL is available
$ref = @($env:windir + '\assembly\GAC_32\Microsoft.FlightSimulator.SimConnect\10.0.61259.0__31bf3856ad364e35\Microsoft.FlightSimulator.SimConnect.dll')
if (!(Test-Path $ref)) {
    throw "Cannot find $ref. Make sure FSX SP2 is installed"
}

[System.Reflection.Assembly]::LoadFrom($ref) | Out-Null

try { $config = [xml](gc "$scriptPath\fsx.xml") }
catch { throw 'Unable to find fsx.xml in script folder, or fsx.xml not in proper xml form' }


if (-not ('DataRequests' -as [type])) {
Add-Type -TypeDefinition @"
public enum DataRequests
    {
        Request1
    }
"@
}


if (-not ('Definitions' -as [type])) {
Add-Type -TypeDefinition @"
public enum Definitions
    {
        Struct1,
        Init
    }
"@
}

if (-not ('Struct1' -as [type])) {
    $type = 'using System.Runtime.InteropServices;'
    $type += '[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi, Pack = 1)]'
    $type += 'public struct Struct1 {'
 
    foreach ($var in $config.fsx.var) {
        $var.type = $var.type.ToLower()
        if ($var.type -eq 'string') { $type += "[MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]" }
        $type += "public " + $var.type + ' ' + ($var.name -replace '[\s,:]','_') + ";"
    }

    $type += '}'
    Add-Type -TypeDefinition $type
}


if (-not ('EventId' -as [type])) {
    $type = 'public enum EventId {'
    foreach ($eventid in $config.fsx.eventid) {
        $type += $eventid.name.ToUpper() + ","
    }
    $type += '}'
    Add-Type -TypeDefinition $type
}

if (-not ('Groups' -as [type])) {
Add-Type -TypeDefinition @"
   public enum Groups
   {
      group1
   }
"@
}
 
function transmit([EventId]$eventId, [int32]$param=0) {
    [uint32]$newParam = 0
    if ($param -lt 0) { $newParam = convert-IntToUint $param } else { $newParam = $param }
    $global:fsx.TransmitClientEvent(0, $eventId, $newParam, [Groups]::group1, 
        [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_EVENT_FLAG]::GROUPID_IS_PRIORITY)
}

function convert-IntToUint([int32]$number) {
    $bytes = [bitconverter]::GetBytes($number)
    [bitconverter]::ToUInt32($bytes, 0)
}

try { $global:fsx = New-Object Microsoft.FlightSimulator.SimConnect.SimConnect('PowerShell', 0, 1026, $null, 0) }
catch { throw 'Unable to connect to FSX. Please make sure FSX is started' }

[EventId].GetEnumValues() | % { 
    $global:fsx.MapClientEventToSimEvent($_, $_.ToString())
}

$dataDefTypeMap = @{
    string = [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_DATATYPE]::STRING256
    int = [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_DATATYPE]::INT32
    long = [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_DATATYPE]::INT64
    float = [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_DATATYPE]::FLOAT32
    double = [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_DATATYPE]::FLOAT64
}

foreach ($var in $config.fsx.var) {
    $var.type = $var.type.ToLower()
    if ($dataDefTypeMap.ContainsKey($var.type)) {
        $global:fsx.AddToDataDefinition([Definitions]::Struct1, $var.name, $var.unit, $dataDefTypeMap[$var.type], 0, [Microsoft.FlightSimulator.SimConnect.SimConnect]::SIMCONNECT_UNUSED)
    }
    else { throw 'Error: fsx.xml: The Type for variable ' + $var.name + ' is not recognized' }
}

# Many thanks to Lee Holmes for the following three lines that enables calling generic SIMCONNECT function from PowerShell
# http://www.leeholmes.com/blog/2006/08/18/creating-generic-types-in-powershell/
$method = [Microsoft.FlightSimulator.SimConnect.SimConnect].GetMethod('RegisterDataDefineStruct')
$closedMethod = $method.MakeGenericMethod([Struct1])
$closedMethod.Invoke($global:fsx, [Definitions]::Struct1)

$global:fsxConnected = $true
$global:fsxError = $false
Unregister-Event *
Register-ObjectEvent -InputObject $global:fsx -EventName OnRecvException -Action { $global:fsxError = $true } | out-null
Register-ObjectEvent -InputObject $global:fsx -EventName OnRecvQuit -Action { $global:fsxConnected = $false } | out-null
Register-ObjectEvent -InputObject $global:fsx -EventName OnRecvSimobjectData -Action { try { $global:sim = $args.dwData[0] } catch {} } | out-null

$global:fsx.RequestDataOnSimObject([DataRequests]::Request1, [Definitions]::Struct1, [Microsoft.FlightSimulator.SimConnect.SimConnect]::SIMCONNECT_OBJECT_ID_USER, [Microsoft.FlightSimulator.SimConnect.SIMCONNECT_PERIOD]::SECOND, 0, 0, 0, 0);

$timer = New-Object System.Timers.Timer
$timer.Interval = 1000
$timer.AutoReset = $true
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action { $global:fsx.ReceiveMessage() } | out-null
$timer.Start()

if ($global:fsxError) {
    $timer.Stop()
    $global:fsx.Dispose()
    throw 'Error: fsx.xml: There is at least one variable that SIMCONNECT does not recognize'
}

# Example transmit
# Set Autopilot altitude reference in feet
# transmit -eventId AP_ALT_VAR_SET_ENGLISH -param 4000

# Print simulation variables
# $global:sim

# Print altitude
# $global:sim.altitude
