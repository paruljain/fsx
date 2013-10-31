Microsoft Flight Simulator (FSX) RESTful API and user interface to control user aircraft
========================================================================================

Provides easy to use interface to FSX via SIMCONNECT. This makes it easy to build scripts to control user aircraft, and also build web technology RESTful interface for direct consumption by Javascript apps running within web browsers for rich user interface on any device including PC, tablets, and smart phones.

The *fsx-simmconnect.ps1* script is a pure PowerShell interface to SIMCONNECT.DLL managed interface library for FSX. It allows event IDs (events that you want to trasmit to FSX to control aircraft) and simulation variables (these variables represent the current state of simulation) to be specified in fsx.xml file. You can then use the *trasnmit* function to send events and use *$global:response* variable to monitor the variables. *$global:response* is automatically updated once every second.

The script solves two common issues when working with SIMCONNECT managed library. It does not need a Windows Form element to work (so it works with PowerShell console app) and the *transmit* function accepts negative integers used for reversing engine thrust, operating brakes, and controlling AXIS type controls.

FEATURES
--------
    * Open source
    * Pure PowerShell with no dependencies
    * Control aircraft from tablets, smart phones, PC, Mac
    * Use multiple devices at once (no limit)
    * Very easy to develop your own control dashboards using HTML (and Javascript for advanced customization)
    * Create user interface for each aircraft, for each screen size, and then load the appropriate one
    * Load different interface on each device. For example, use tablet 1 for Auto Pilot controls, tablet 2 for Radio etc.
    * No tools required to extend and customize. All you need is Notepad

REQUIRES
--------
    PowerShell v3 or higher, FSX SP2, .Net 4.5, fsx.xml (included with the script)

INSTALL
-------
      1  Copy the script fsx.ps1 and configuration file fsx.xml to any folder.
      
      2  If you are running Windows Vista or better from an administratively privileged command prompt run the following command:
          netsh http add urlacl url=http://+:8000/ user=DOMAIN\user
          The url should exactly match the url provided to listener.prefixes.add in the script
      
          For other operating systems please refer to:
          http://msdn.microsoft.com/en-us/library/ms733768.aspx
          
      3  Allow inbound TCP connections to port 8000 from your network in Windows firewall
      
      4  If you are running 64 bit OS, start the 32 bit (x86) version of PowerShell with administrative privileges.     
          if you are running 32 bit OS, start PowerShell with administrative privileges
          Execute the following command on PowerShell prompt:
          
          set-executionpolicy bypass
          
          This will allow 32 bit PowerShell scripts to run on your system unrestricted. If you get access denied error
          while running this command you are not running PowerShell in administratively privileged mode

USAGE
-----
Start FSX. Now run the script. On 64 bit OS use the 32 bit (x86) version of PowerShell. This is because SIMCONNECT library and FSX are 32 bit apps. From a command prompt change to folder where script is located and then type:
    
    powershell .\fsx.ps1
    
If all goes well you will see "Listening ..." on the console
    
To test the RESTful interface you can use the Chrome browser with the "Simple REST Client" plugin available free from Chrome market place. On the computer where the script is running start Chrome, and start the Simple REST Client:
    
    URL: http://localhost:8000/getall
    Method: GET

Press Send.

You should see all the simulation variable values such as altitude of user aircraft etc. You can add or remove simulation variables (there are hundreds) in the fsx.xml file. You will have to restart the script whenever you make changes to the fsx.xml file.

You can also send a command to FSX from Chrome Simple REST Client.

    URL: http://localhost:8000/cmd
    Method: POST
    Headers: Content-type: application/json (the space between : and application is important)
    Data: {"cmd":"AUTOPILOT_ON"}

Press Send. The Autopilot on your aircraft should be engaged. To turn it off send AUTOPILOT_OFF. Look at the fsx.xml event IDs to see what commands you can send. You can add more events to fsx.xml.

You can test connection from other computers as well. Instead of localhost use the IP address of the computer running the script. You can now write programs in any language on any computer to control FSX. You can also write Javascript programs to run within browser so that you can have rich user interface. Sample browser apps will be provided in the near future.
