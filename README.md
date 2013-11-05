Microsoft Flight Simulator (FSX) RESTful API
============================================

Provides easy to use interfaces to FSX via SIMCONNECT:

* PowerShell scripts
* AJAX from Javascript within browser for rich GUI apps that can run on any device (including tablets!)
* Languages such as Ruby, Python, Java, c#, PERL that make it easy to consume RESTful API

FEATURES
--------
* Open source
* Pure PowerShell with no dependencies
* Micro web server in PowerShell; IIS not required
* Control aircraft from tablets, smart phones, PC, Mac
* Use multiple devices at once (no limit)
* Very easy to develop your own apps using PowerShell, HTML + Javascript or any language that can consume RESTful API
* No tools required to extend and customize. All you need is Notepad

REQUIRES
--------
* PowerShell v3 or higher
* FSX SP2
* .Net 4.5

INSTALL
-------

1. Copy everything to any folder

2. If you are running Windows Vista or better from an administratively privileged command prompt run the following command:
   
   netsh http add urlacl url=http://+:8000/ user=DOMAIN\user
   
   The url should exactly match the url provided to listener.prefixes.add in the script. For other operating systems please refer to:
   
   http://msdn.microsoft.com/en-us/library/ms733768.aspx
    
3. Allow inbound TCP connections to port 8000 from your network in Windows firewall

4. If you are running 64 bit OS, start the 32 bit (x86) version of PowerShell with administrative privileges. If you are running 32 bit OS, start PowerShell with administrative privileges and execute the following command on PowerShell prompt:
    
   set-executionpolicy bypass
    
  This will allow 32 bit PowerShell scripts to run on your system unrestricted. If you get access denied error    while running this command you are not running PowerShell in administratively privileged mode.

USAGE
-----
Start FSX. Now run the scripts. On 64 bit OS use the 32 bit (x86) version of PowerShell. This is because SIMCONNECT library and FSX are 32 bit apps.

* fsxSimConnect.ps1

   This script provides the interface to FSX via SIMCONNECT and is the basis for all other scripts
    
* fsxWebServer.ps1

   This script is a micro web server that servers SIMCONNECT over a RESTful API.
   * HTTP GET to /getall gets value of simulation variables configured in fsx.xml in JSON format
   * HTTP POST to /cmd allows transmission of events to FSX used to control user aircraft. The HTTP header must have Content-Type set to application/json. The body must be a JSON object as follows:

```
   {"cmd":<name of eventid to send to FSX per fsx.xml>}

      or

   {"cmd":<name of eventid to send to FSX per fsx.xml>, "param":<parameter that needs to be sent with the command>}

   Turn on Autopilot: {"cmd":"AUTOPILOT_ON'}
   Set autopilot ALT reference to 3000ft:  {"cmd":"AP_ALT_VAR_SET_ENGLISH", "param":3000}
   Release left brake: {"cmd":"AXIS_LEFT_BRAKE_SET", "param":-16383}
```

To test the RESTful interface you can use the Chrome browser with the "Simple REST Client" plugin available free from Chrome market place. On the computer where the script is running start Chrome, and start the Simple REST Client:
    
    URL: http://localhost:8000/getall
    Method: GET

You should see all the simulation variable values such as altitude of user aircraft etc. You can add or remove simulation variables (there are hundreds) in the fsx.xml file. You will have to restart the script whenever you make changes to the fsx.xml file.

You can also send a command to FSX from Chrome Simple REST Client.

    URL: http://localhost:8000/cmd
    Method: POST
    Headers: Content-type: application/json (the space between : and application is important)
    Data: {"cmd":"AUTOPILOT_ON"}

Press Send. The Autopilot on your aircraft should be engaged. To turn it off send AUTOPILOT_OFF. Look at the fsx.xml event IDs to see what commands you can send. You can add more events to fsx.xml.

* googleMaps.html
   
   This Javascript app is a demonstration of how the RESTful API can be consumed in a browser to build great UI apps that can run on any device. This app shows the position of user aircraft on Google Maps refreshed every second. Hover above the plane icon to see the aircraft's true heading, altitude in feet, and indicated airspeed in knots. To use this application open the following URL from a browser that supports HTML5:

```   
   http://localhost:8000/googleMaps.html

   or
   
   http://<ip address of computer running script>:8000/googleMaps.html
```
