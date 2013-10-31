if (!$global:connected) {
    . .\fsx-simconnect.ps1
}

# Take off for 737 using Autopilot
# Make sure it is a 737
if ($global:response.Title -notmatch 'Boeing 737-800') {
    'This take off program is designed and tested with Boeing 737-800 only'
    exit
}

# Check whether plane is stationary
if ($global:response.Airspeed_Indicated -gt 1) {
    'The aircraft seems to be moving. Please bring it to a complete stop and position it at the start of a runway'
    exit
}

$runwayAlt = $global:response.Plane_Altitude

# Extend flaps to full
transmit -eventId FLAPS_DOWN
# Wait for flaps to be fully extended
Start-Sleep -Seconds 10
# Set AP speed to 280 knots
transmit -eventId AP_SPD_VAR_SET -param 280
# AP auto throttle arm
transmit -eventId AUTO_THROTTLE_ARM
# Enagage auto throttle and start rolling
transmit -eventId AP_AIRSPEED_ON
# Set AP altitude reference to 3000ft
transmit -eventId AP_ALT_VAR_SET_ENGLISH -param 3000
# AP Alt Hold on
transmit -eventId AP_ALT_HOLD_ON
# Wait for speed to reach 140 knots before engaging AP to take off
while ($global:response.Airspeed_Indicated -lt 140) {}
# Engage AP to take off!
transmit -eventId AUTOPILOT_ON
# Set rate of climb to 2500 ft/min
transmit -eventId AP_VS_VAR_SET_ENGLISH -param 2500
# Wait for altitude runway + 200 feet then retract landing gear and flaps
while (($global:response.Plane_Altitude - $runwayAlt) -lt 200) {}
# Retract flaps
transmit -eventId FLAPS_UP
Start-Sleep 8
# Retract landing gear
transmit -eventId GEAR_UP

# All done!
