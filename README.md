# Image Factory Utility

Automate Creation of WIM Files

```txt
.___                  ___________              __                         ____ ___   __  .__.__  .__  __
|   | _____    ____   \_   _____/____    _____/  |_  ___________ ___.__. |    |   \_/  |_|__|  | |__|/  |_ ___.__.
|   |/     \  / ___\   |    __) \__  \ _/ ___\   __\/  _ \_  __ <   |  | |    |   /\   __\  |  | |  \   __<   |  |
|   |  Y Y  \/ /_/  >  |     \   / __ \\  \___|  | (  <_> )  | \/\___  | |    |  /  |  | |  |  |_|  ||  |  \___  |
|___|__|_|  /\___  /   \___  /  (____  /\___  >__|  \____/|__|   / ____| |______/   |__| |__|____/__||__|  / ____|
          \//_____/        \/        \/     \/                   \/                                        \/

             Mike Galvin    https://gal.vin      Version 21.12.01
```

For full instructions and documentation, [visit my site.](https://gal.vin/posts/image-factory/)

A demonstration video is available on [my YouTube channel.](https://youtu.be/BdNwWwxo7Ug)

Please consider donating to support my work:

* Sign up [using Patreon.](https://www.patreon.com/mikegalvin)
* Support with a one-time payment [using PayPal.](https://www.paypal.me/digressive)

Image Factory Utility can also be downloaded from:

* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Image-Factory)

Tweet me if you have questions: [@mikegalvin_](https://twitter.com/mikegalvin_)

-Mike

## Features and Requirements

* This utility is designed to run on a computer with Microsoft Deployment Toolkit installed.
* The computer must have the Hyper-V management PowerShell modules installed.
* The primary function of this utility is to automate the production of WIM files from MDT task sequences.
* The utility requires at least PowerShell 5.0.
* This utility has been tested on Windows 10, Windows Server 2019, Windows Server 2016 and Windows Server 2012 R2.

## Important Information

The utility will make changes to your customsettings.ini file, although it will make a backup first. These changes are necessary so that the build process runs automated. Depending on your environment, you may need to make additional changes to your customsettings.ini.

## Separating your build and deployment shares

I would recommend running with a separate build share so that:

* The Image Factory Utility doesn't tie up the main deployment share whilst running.
* The build environment can be configured separately.
* The boot media for the build share can be configured to automatically log into the deployment environment.

Here are the settings you'll need to add to your Bootstrap.ini to automatically log into the build share. Don't forget to update your build share in MDT and regenerate the boot images.

```txt
[Settings]
Priority=Default

[Default]
DeployRoot=\\mdt19\BuildShare$
UserDomain=contoso.com
UserID=mdt_admin
UserPassword=P@ssw0rd
SkipBDDWelcome=YES
```

### Generating A Password File

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell on the computer and logged in with the user that will be running the utility. When you run the command, you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

### Configuration

Here’s a list of all the command line switches and example configurations.

| Command Line Switch | Description | Example |
| ------------------- | ----------- | ------- |
| -Build | Location of the build share. It can be the same as the deployment share, and it can be a local or UNC path. | \\\server\buildshare$ OR C:\BuildShare |
| -Deploy | Location of the deployment share. It can be the same as the deployment share, and it can be a local or UNC path. | \\\server\deploymentshare$ OR C:\DeploymentShare |
| -Vh | Name of the Hyper-V host. Can be a local or remote device. | VS01 |
| -Vhd | The path relative to the Hyper-V server of where to put the VHD file for the VM(s) that will be generated. | C:\Hyper-V\VHD |
| -Boot | The path relative to the Hyper-V server of where the ISO file is to boot from. | C:\iso\LiteTouchPE_x64.iso |
| -Vnic | Name of the virtual switch that the virtual machine should use to communicate with the network. If the name of the switch contains a space encapsulate with single or double quotes. | vSwitch-Ext |
| -Ts | The comma-separated list of task sequence ID's to build. | W10-21H1,WS19-DC |
| -Compat | Use this switch if the Hyper-V server is Windows Server 2012 R2 and the script is running on Windows 10 or Windows Server 2016/2019. This loads the older version of the Hyper-V module, so it can manage WS2012 R2 Hyper-V VMs. | N/A |
| -Remote | Use this switch if the Hyper-V server is a remote device. Do not use this switch if the script is running on the same device as Hyper-V. | N/A |
| -NoBanner | Use this option to hide the ASCII art title in the console. | N/A |
| -L | The path to output the log file to. The file name will be Image-Factory_YYYY-MM-dd_HH-mm-ss.log. Do not add a trailing \ backslash. | C:\scripts\logs |
| -Subject | The subject line for the e-mail log. Encapsulate with single or double quotes. If no subject is specified, the default of "Image Factory Utility Log" will be used. | 'Server: Notification' |
| -SendTo | The e-mail address the log should be sent to. | me@contoso.com |
| -From | The e-mail address the log should be sent from. | ImgFactory@contoso.com |
| -Smtp | The DNS name or IP address of the SMTP server. | smtp.live.com OR smtp.office365.com |
| -User | The user account to authenticate to the SMTP server. | example@contoso.com |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | C:\scripts\ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

### Example

``` txt
Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -Vh VS01 -VHD C:\Hyper-V\VHD -Boot C:\iso\LiteTouchPE_x64.iso -Vnic vSwitch-Ext -Remote -Ts W10-21H1,WS19-DC -L C:\scripts\logs -Subject 'Server: Image Factory' -SendTo me@contoso.com -From imgfactory@contoso.com -Smtp smtp.outlook.com -User example@contoso.com -Pwd c:\scripts\ps-script-pwd.txt -UseSsl
```

The above command will build WIM files from the task sequences W10-1909 and WS19-DC. They will be imported to the deployment share on MDT01. The Hyper-V host used will be VS01 and the VHDs for the VMs generated will be stored in C:\Hyper-V\VHD on the host. The boot ISO file will be C:\iso\LiteTouchPE_x64.iso, also located on the Hyper-V host. The virtual switch used by the VMs will be called vSwitch-Ext. The log file will be output to C:\scripts\logs and e-mailed with a custom subject line.
