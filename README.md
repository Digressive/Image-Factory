# Image Factory Utility

Automate Creation of WIM Files

For full change log and more information, [visit my site.](https://gal.vin/utils/image-factory-utility/)

Image Factory Utility is available from:

* [GitHub](https://github.com/Digressive/Image-Factory)
* [The Microsoft PowerShell Gallery](https://www.powershellgallery.com/packages/Image-Factory)

Please consider supporting my work:

* Sign up using [Patreon](https://www.patreon.com/mikegalvin).
* Support with a one-time donation using [PayPal](https://www.paypal.me/digressive).

Please report any problems via the ‘issues’ tab on GitHub.

-Mike

## Features and Requirements

* This utility is designed to run on a computer with Microsoft Deployment Toolkit installed.
* The computer must have either the Hyper-V management PowerShell modules installed, or Virtual Box.
* The primary function of this utility is to automate the creation of wim files from MDT task sequences.
* The utility requires at least PowerShell 5.0.
* This utility has been tested on Windows 11, Windows 10, Windows Server 2019, Windows Server 2016 and Windows Server 2012 R2.

## Virtual Box Support

This utility expects Oracle Virtual Box to be installed in the default location of: ```C:\Program Files\Oracle\VirtualBox```

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
DeployRoot=[path\]BuildShare$
UserDomain=contoso.com
UserID=mdt_admin
UserPassword=P@ssw0rd
SkipBDDWelcome=YES
```

## Generating A Password File For SMTP Authentication

The password used for SMTP server authentication must be in an encrypted text file. To generate the password file, run the following command in PowerShell on the computer and logged in with the user that will be running the utility. When you run the command, you will be prompted for a username and password. Enter the username and password you want to use to authenticate to your SMTP server.

Please note: This is only required if you need to authenticate to the SMTP server when send the log via e-mail.

``` powershell
$creds = Get-Credential
$creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt
```

After running the commands, you will have a text file containing the encrypted password. When configuring the -Pwd switch enter the path and file name of this file.

## Configuration

Here’s a list of all the command line switches and example configurations.

| Command Line Switch | Description | Example |
| ------------------- | ----------- | ------- |
| -Build | Location of the build share. It can be the same as the deployment share, and it can be a local or UNC path. | [path\] |
| -Deploy | Location of the deployment share. It can be the same as the deployment share, and it can be a local or UNC path. | [path\] |
| -Vh | Hyper-V Only - Name of the Hyper-V host if remote. If not set it will default to local. | [hostname] |
| -Vhd | The path to store the virtual hard disk file(s). If using a remote Hyper-V server the path should be relative for that server. | [path\] |
| -Boot | The path to the iso file to boot from. If using a remote Hyper-V server the path should be relative for that server. | [path\]LiteTouchPE_x64.iso |
| -Vnic | Hyper-V Only - Name of the virtual switch that the VM should use to communicate. | "'virtual NIC name'" |
| -Ts | The comma-separated list of task sequence ID's to build. | [W11-21H2,W10-21H2] |
| -VBox | Use this switch to use Oracle Virtual Box instead of Hyper-V | N/A |
| -Compat | Legacy Hyper-V Only - Use this switch if the Hyper-V host is Windows Server 2012 R2 and the script is running on Windows 10 or Windows Server 2016/2019. This loads the older version of the Hyper-V module, so it can manage WS2012 R2 Hyper-V VMs. | N/A |
| -Remote | Hyper-V Only - Use this switch if the Hyper-V server is a remote device. | N/A |
| -L | The path to output the log file to. | [path\] |
| -LogRotate | Remove logs produced by the utility older than X days | [number] |
| -NoBanner | Use this option to hide the ASCII art title in the console. | N/A |
| -Help | Display usage information. No arguments also displays help. | N/A |
| -Subject | Specify a subject line. If you leave this blank the default subject will be used | "'[Server: Notification]'" |
| -SendTo | The e-mail address the log should be sent to. For multiple address, separate with a comma. | [example@contoso.com] |
| -From | The e-mail address the log should be sent from. | [example@contoso.com] |
| -Smtp | The DNS name or IP address of the SMTP server. | [smtp server address] |
| -Port | The Port that should be used for the SMTP server. If none is specified then the default of 25 will be used. | [port number] |
| -User | The user account to authenticate to the SMTP server. | [example@contoso.com] |
| -Pwd | The txt file containing the encrypted password for SMTP authentication. | [path\]ps-script-pwd.txt |
| -UseSsl | Configures the utility to connect to the SMTP server using SSL. | N/A |

## Example

``` txt
[path\]Image-Factory.ps1 -Build [path\] -Deploy [path\] -Boot [path\]LiteTouchPE_x64.iso -Vnic [virtual NIC name] -Ts W11-21H2,W10-21H2
```

This will use Hyper-V VMs on the local machine to build wim files from the task sequences W11-21H2 and W10-21H2. The wim files will be imported to the deployment share specified.
