# Image Factory for Microsoft Deployment Toolkit
PowerShell based WIM file generation factory of custom Windows builds.

My Image Factory script can also be downloaded from:

* [The Microsoft TechNet Gallery](https://gallery.technet.microsoft.com/PowerShell-Image-Factory-d6c133b9?redir=0)
* [The PowerShell Gallery](https://www.powershellgallery.com/packages/Image-Factory/2.8/DisplayScript)
* For full instructions and documentation, [visit my blog post](https://gal.vin/2017/08/26/image-factory/)

-Mike

Tweet me if you have questions: [@Digressive](https://twitter.com/digressive)

## Features and Requirements

* The script is designed to run on a device with MDT installed.
* The device must also have Hyper-V management tools installed.
* The MDT shares can be local or on a remote device.
* The Hyper-V host can be local or on a remote device.

The script has been tested on Hyper-V installations on Windows 10, Windows Server 2016 (Datacenter and Core installations) and Windows Server 2012 R2 (Datacenter and Core Installations) and MDT installations on Windows 10 and Windows Server 2016 (GUI installs only).

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

```
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

```
-Build
```
The local or UNC path to the build share of MDT. This and the deploy switch can point to the same location.
```
-Deploy
```
The local or UNC path to the deploy share of MDT. This and the build switch can point to the same location.
```
-Ts
```
The comma-separated list of task sequence ID's to build.
```
-Vh
```
The name of the computer running Hyper-V. Can be local or remote.
```
-Vhd
```
The path relative to the Hyper-V server of where to store the VHD file for the VM(s).
```
-Boot
```
The path relative to the Hyper-V server of where the ISO file to boot from is stored.
```
-VNic
```
The name of the virtual switch that the VM should use to communicate with the network.
```
-Compat
```
Set if the Hyper-V server is WS2012 R2 and the script is running on Windows 10 or Windows Server 2016. This loads the older version of the Hyper-V module so it is able to manage WS2012 R2 Hyper-V VMs.
```
-Remote
```
Set if the Hyper-V server is a remote device. Do not include this switch if the script is running on the same device as Hyper-V.
``` 
-L
```
The path to output the log file to. The file name will be Image-Factory-YYYY-MM-dd-HH-mm-ss.log
```
-SendTo
```
The e-mail address the log should be sent to.
```
-From
```
The e-mail address the log should be sent from.
```
-Smtp
```
The DNS name or IP address of the SMTP server.
```
-User
```
The user account to connect to the SMTP server.
```
-Pwd
```
The txt file containing the encrypted password for the user account.
```
-UseSsl
```
Configures the script to connect to the SMTP server using SSL.

Example:
```
Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -Vh hyperv01 -Vhd D:\Hyper-V\VHD -Boot F:\iso\LiteTouchPE_x64.iso -VNic vSwitch-Ext -Remote -Ts W10-1803,WS16-S -L E:\scripts -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl
```

This string will build two WIM from the two task sequences: W10-1803 & WS16-S. They will be imported to the deployment share on MDT01. The Hyper-V server used will be hyperv01, the VHD for the VMs generated will be stored in D:\Hyper-V\VHD on the server hyperv01. The boot iso file will be F:\iso\LiteTouchPE_x64.iso, located on the Hyper-V server. The Virtual Switch used by the VM will be called vSwitch-Ext. The log file will be output to E:\logs and it will be emailed using an SSL conection.
