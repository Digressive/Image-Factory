# Image Factory for Microsoft Deployment Toolkit

PowerShell based WIM file generation factory of custom Windows builds.

Please consider donating to support my work:

* You can support me on a monthly basis [using Patreon.](https://www.patreon.com/mikegalvin)
* You can support me with a one-time payment [using PayPal](https://www.paypal.me/digressive) or by [using Kofi.](https://ko-fi.com/mikegalvin)

* For full instructions and documentation, [visit my blog post](https://gal.vin/2017/08/26/image-factory/)

My Image Factory script can also be downloaded from:

* [The Microsoft TechNet Gallery](https://gallery.technet.microsoft.com/PowerShell-Image-Factory-d6c133b9?redir=0)
* [The PowerShell Gallery](https://www.powershellgallery.com/packages/Image-Factory)

-Mike

Tweet me if you have questions: [@mikegalvin_](https://twitter.com/mikegalvin_)

## Features and Requirements

* The script is designed to run on a device with MDT installed.
* The device must also have Hyper-V management tools installed.
* The MDT shares can be local or on a remote device.
* The Hyper-V host can be local or on a remote device.

The script has been tested on Hyper-V installations on Windows 10, Windows Server 2016 (Datacenter and Core installations) and Windows Server 2012 R2 (Datacenter and Core Installations) and MDT installations on Windows 10 and Windows Server 2016 (GUI installs only).

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell, on the computer that is going to run the script and logged in with the user that will be running the script. When you run the command you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

``` txt
-Build
```

The local or UNC path to the build share of MDT. This and the deploy switch can point to the same location.

``` txt
-Deploy
```

The local or UNC path to the deploy share of MDT. This and the build switch can point to the same location.

``` txt
-ts
```

The comma-separated list of task sequence ID's to build.

``` txt
-vh
```

The name of the computer running Hyper-V. Can be local or remote.

``` txt
-vhd
```

The path relative to the Hyper-V server of where to store the VHD file for the VM(s).

``` txt
-Boot
```

The path relative to the Hyper-V server of where the ISO file to boot from is stored.

``` txt
-vnic
```

The name of the virtual switch that the VM should use to communicate with the network.

``` txt
-Compat
```

Set if the Hyper-V server is WS2012 R2 and the script is running on Windows 10 or Windows Server 2016. This loads the older version of the Hyper-V module so it is able to manage WS2012 R2 Hyper-V VMs.

``` txt
-Remote
```

Set if the Hyper-V server is a remote device. Do not include this switch if the script is running on the same device as Hyper-V.

``` txt
-L
```

The path to output the log file to. The file name will be Image-Factory-YYYY-MM-dd-HH-mm-ss.log

``` txt
-Subject
```

The email subject that the email should have. Encapulate with single or double quotes.

``` txt
-SendTo
```

The e-mail address the log should be sent to.

``` txt
-From
```

The e-mail address the log should be sent from.

``` txt
-Smtp
```

The DNS name or IP address of the SMTP server.

``` txt
-User
```

The user account to connect to the SMTP server.

``` txt
-Pwd
```

The txt file containing the encrypted password for the user account.

``` txt
-UseSsl
```

Configures the script to connect to the SMTP server using SSL.

### Example

``` txt
Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -VH hyperv01 -VHD C:\Hyper-V\VHD -Boot C:\iso\LiteTouchPE_x64.iso -VNic vSwitch-Ext -Remote -TS W10-1803,WS16-S -L C:\scripts\logs -Subject 'Server: Image Factory' -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl
```

This string will build two WIM from the two task sequences: W10-1803 & WS16-S. They will be imported to the deployment share on MDT01. The Hyper-V server used will be hyperv01, the VHD for the VMs generated will be stored in C:\Hyper-V\VHD on the server hyperv01. The boot iso file will be C:\iso\LiteTouchPE_x64.iso, located on the Hyper-V server. The Virtual Switch used by the VM will be called vSwitch-Ext. The log file will be output to C:\scripts\logs and it will be e-mailed with a custom subject line, using an SSL conection.
