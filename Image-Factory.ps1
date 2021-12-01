<#PSScriptInfo

.VERSION 21.12.01

.GUID 251ae35c-cc4e-417c-970c-848b221477fa

.AUTHOR Mike Galvin Contact: mike@gal.vin / twitter.com/mikegalvin_

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Microsoft Deployment Toolkit MDT Hyper-V Windows OSD

.LICENSEURI

.PROJECTURI https://gal.vin/posts/image-factory/

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Image Factory Utility - Automate creation of WIM files.

    .DESCRIPTION
    This script will create disposable Hyper-V virtual machines to generate WIM files from Microsoft Deployment
    Toolkit task sequences.

    This script should be run on a device with the MDT and Hyper-V PowerShell management modules installed.

    To send a log file via e-mail using ssl and an SMTP password you must generate an encrypted password file.
    The password file is unique to both the user and machine.

    To create the password file run this command as the user and on the machine that will use the file:

    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content c:\scripts\ps-script-pwd.txt

    .PARAMETER Build
    Location of the build share. It can be the same as the deployment share, and it can be a local or UNC path.

    .PARAMETER Deploy
    Location of the deployment share. It can be the same as the deployment share, and it can be a local or UNC path.

    .PARAMETER VH
    Name of the Hyper-V host. Can be a local or remote device.

    .PARAMETER VHD
    The path relative to the Hyper-V server of where to put the VHD file for the VM(s) that will be generated.

    .PARAMETER Boot
    The path relative to the Hyper-V server of where the ISO file is to boot from.

    .PARAMETER VNic
    Name of the virtual switch that the virtual machine should use to communicate with the network.
    If the name of the switch contains a space encapsulate with single or double quotes.

    .PARAMETER TS
    The comma-separated list of task sequence ID's to build.

    .PARAMETER Compat
    Use this switch if the Hyper-V server is Windows Server 2012 R2 and the script is running on
    Windows 10 or Windows Server 2016/2019. This loads the older version of the Hyper-V module, so
    it can manage WS2012 R2 Hyper-V VMs.

    .PARAMETER Remote
    Use this switch if the Hyper-V server is a remote device.
    Do not use this switch if the script is running on the same device as Hyper-V.

    .PARAMETER NoBanner
    Use this option to hide the ASCII art title in the console.

    .PARAMETER L
    The path to output the log file to.
    The file name will be Image-Factory_YYYY-MM-dd_HH-mm-ss.log.
    Do not add a trailing \ backslash.

    .PARAMETER Subject
    The subject line for the e-mail log.
    Encapsulate with single or double quotes.
    If no subject is specified, the default of "Image Factory Utility Log" will be used.

    .PARAMETER SendTo
    The e-mail address the log should be sent to.

    .PARAMETER From
    The e-mail address the log should be sent from.

    .PARAMETER Smtp
    The DNS name or IP address of the SMTP server.

    .PARAMETER Port
    The Port that should be used for the SMTP server.

    .PARAMETER User
    The user account to authenticate to the SMTP server.

    .PARAMETER Pwd
    The txt file containing the encrypted password for SMTP authentication.

    .PARAMETER UseSsl
    Configures the utility to connect to the SMTP server using SSL.

    .EXAMPLE
    Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -Vh VS01 -VHD C:\Hyper-V\VHD
    -Boot C:\iso\LiteTouchPE_x64.iso -Vnic vSwitch-Ext -Remote -Ts W10-21H1,WS19-DC -L C:\scripts\logs -Subject 'Server: Image Factory'
    -SendTo me@contoso.com -From imgfactory@contoso.com -Smtp smtp.outlook.com -User example@contoso.com -Pwd c:\scripts\ps-script-pwd.txt -UseSsl

    The above command will build WIM files from the task sequences W10-1909 and WS19-DC. They will be imported to the deployment share on MDT01.
    The Hyper-V host used will be VS01 and the VHDs for the VMs generated will be stored in C:\Hyper-V\VHD on the host.
    The boot ISO file will be C:\iso\LiteTouchPE_x64.iso, also located on the Hyper-V host.
    The virtual switch used by the VMs will be called vSwitch-Ext. The log file will be output to C:\scripts\logs and e-mailed with a custom subject line.
#>

## Set up command line switches.
[CmdletBinding()]
Param(
    [parameter(Mandatory=$True)]
    [alias("Build")]
    $MdtBuildPath,
    [parameter(Mandatory=$True)]
    [alias("Deploy")]
    $MdtDeployPath,
    [parameter(Mandatory=$True)]
    [alias("TS")]
    $TsId,
    [alias("VH")]
    $VmHost,
    [parameter(Mandatory=$True)]
    [alias("VHD")]
    $VhdPath,
    [parameter(Mandatory=$True)]
    [alias("Boot")]
    $BootMedia,
    [alias("VNic")]
    $VmNic,
    [alias("L")]
    [ValidateScript({Test-Path $_ -PathType 'Container'})]
    $LogPath,
    [alias("Subject")]
    $MailSubject,
    [alias("SendTo")]
    $MailTo,
    [alias("From")]
    $MailFrom,
    [alias("Smtp")]
    $SmtpServer,
    [alias("Port")]
    $SmtpPort,
    [alias("User")]
    $SmtpUser,
    [alias("Pwd")]
    [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
    $SmtpPwd,
    [switch]$UseSsl,
    [switch]$Compat,
    [switch]$VBox,
    [switch]$Remote,
    [switch]$NoBanner)

    If ($NoBanner -eq $False)
    {
        Write-Host -Object ""
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "                                                                                                                      "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "  .___                  ___________              __                         ____ ___   __  .__.__  .__  __            "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "  |   | _____    ____   \_   _____/____    _____/  |_  ___________ ___.__. |    |   \_/  |_|__|  | |__|/  |_ ___.__.  "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "  |   |/     \  / ___\   |    __) \__  \ _/ ___\   __\/  _ \_  __ <   |  | |    |   /\   __\  |  | |  \   __<   |  |  "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "  |   |  Y Y  \/ /_/  >  |     \   / __ \\  \___|  | (  <_> )  | \/\___  | |    |  /  |  | |  |  |_|  ||  |  \___  |  "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "  |___|__|_|  /\___  /   \___  /  (____  /\___  >__|  \____/|__|   / ____| |______/   |__| |__|____/__||__|  / ____|  "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "            \//_____/        \/        \/     \/                   \/                                        \/       "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "                                                                                                                      "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "                Mike Galvin    https://gal.vin      Version 21.12.01                                                  "
        Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "                                                                                                                      "
        Write-Host -Object ""
    }

## If logging is configured, start logging.
## If the log file already exists, clear it.
If ($LogPath)
{
    ## Make sure the log directory exists.
    $LogPathFolderT = Test-Path $LogPath

    If ($LogPathFolderT -eq $False)
    {
        New-Item $LogPath -ItemType Directory -Force | Out-Null
    }

    $LogFile = ("Image-Factory_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"

    $LogT = Test-Path -Path $Log

    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Encoding ASCII -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO] Log started"
}

## Function to get date in specific format.
Function Get-DateFormat
{
    Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

## Function for logging.
Function Write-Log($Type, $Evt)
{
    If ($Type -eq "Info")
    {
        If ($Null -ne $LogPath)
        {
            Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [INFO] $Evt"
        }
        
        Write-Host -Object "$(Get-DateFormat) [INFO] $Evt"
    }

    If ($Type -eq "Succ")
    {
        If ($Null -ne $LogPath)
        {
            Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [SUCCESS] $Evt"
        }

        Write-Host -ForegroundColor Green -Object "$(Get-DateFormat) [SUCCESS] $Evt"
    }

    If ($Type -eq "Err")
    {
        If ($Null -ne $LogPath)
        {
            Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [ERROR] $Evt"
        }

        Write-Host -ForegroundColor Red -BackgroundColor Black -Object "$(Get-DateFormat) [ERROR] $Evt"
    }

    If ($Type -eq "Conf")
    {
        If ($Null -ne $LogPath)
        {
            Add-Content -Path $Log -Encoding ASCII -Value "$Evt"
        }

        Write-Host -ForegroundColor Cyan -Object "$Evt"
    }
}

## Setting an easier to use variable for computer name of the Hyper-V server.
$Hostn = $Env:ComputerName

## getting Windows Version info
$OSVMaj = [environment]::OSVersion.Version | Select-Object -expand major
$OSVMin = [environment]::OSVersion.Version | Select-Object -expand minor
$OSVBui = [environment]::OSVersion.Version | Select-Object -expand build
$OSV = "$OSVMaj" + "." + "$OSVMin" + "." + "$OSVBui"

##
## Display the current config and log if configured.
##
Write-Log -Type Conf -Evt "************ Running with the following config *************."
Write-Log -Type Conf -Evt "Utility Version:.......21.12.01"
Write-Log -Type Conf -Evt "Hostname:..............$Hostn."
Write-Log -Type Conf -Evt "Windows Version:.......$OSV."
Write-Log -Type Conf -Evt "Build share:...........$MdtBuildPath."
Write-Log -Type Conf -Evt "Deploy share:..........$MdtDeployPath."
Write-Log -Type Conf -Evt "No. of TS ID's:........$($TsId.count)."
Write-Log -Type Conf -Evt "TS ID's:...............$TsId."

If ($Null -ne $VmHost)
{
    Write-Log -Type Conf -Evt "VM Host:...............$VmHost."
}

else {
    Write-Log -Type Conf -Evt "VM Host:...............No Config"
}

Write-Log -Type Conf -Evt "VHD path:..............$VhdPath."
Write-Log -Type Conf -Evt "Boot media path:.......$BootMedia."

If ($Null -ne $VmHost)
{
    Write-Log -Type Conf -Evt "Virtual NIC name:......$VmNic."
}

else {
    Write-Log -Type Conf -Evt "Virtual NIC name:......No Config"
}

If ($Null -ne $LogPath)
{
    Write-Log -Type Conf -Evt "Logs directory:........$LogPath."
}

else {
    Write-Log -Type Conf -Evt "Logs directory:........No Config"
}

If ($MailTo)
{
    Write-Log -Type Conf -Evt "E-mail log to:.........$MailTo."
}

else {
    Write-Log -Type Conf -Evt "E-mail log to:.........No Config"
}

If ($MailFrom)
{
    Write-Log -Type Conf -Evt "E-mail log from:.......$MailFrom."
}

else {
    Write-Log -Type Conf -Evt "E-mail log from:.......No Config"
}

If ($MailSubject)
{
    Write-Log -Type Conf -Evt "E-mail subject:........$MailSubject."
}

else {
    Write-Log -Type Conf -Evt "E-mail subject:........Default"
}

If ($SmtpServer)
{
    Write-Log -Type Conf -Evt "SMTP server:...........$SmtpServer."
}

else {
    Write-Log -Type Conf -Evt "SMTP server:...........No Config"
}

If ($SmtpPort)
{
    Write-Log -Type Conf -Evt "SMTP Port:...............$SmtpPort."
}

else {
    Write-Log -Type Conf -Evt "SMTP Port:...............Default"
}

If ($SmtpUser)
{
    Write-Log -Type Conf -Evt "SMTP user:.............$SmtpUser."
}

else {
    Write-Log -Type Conf -Evt "SMTP user:.............No Config"
}

If ($SmtpPwd)
{
    Write-Log -Type Conf -Evt "SMTP pwd file:.........$SmtpPwd."
}

else {
    Write-Log -Type Conf -Evt "SMTP pwd file:.........No Config"
}

Write-Log -Type Conf -Evt "-UseSSL switch:........$UseSsl."
Write-Log -Type Conf -Evt "-VBox switch:..........$VBox."
Write-Log -Type Conf -Evt "-Compat switch:........$Compat."
Write-Log -Type Conf -Evt "-Remote switch:........$Remote."
Write-Log -Type Conf -Evt "************************************************************"
Write-Log -Type Info -Evt "Process started"
##
## Display current config ends here.
##

## If the -compat switch is used, load the older Hyper-V PS module.
If ($Vbox -eq $false)
{
    If ($Compat)
    {
        Write-Log -Type Info -Evt "Importing Hyper-V 1.1 PowerShell Module"
        Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
    }
}

else {
    $VBoxLoc = "C:\Program Files\Oracle\VirtualBox"
}

## Import the Deployment Toolkit PowerShell module.
Write-Log -Type Info -Evt "Importing MDT PowerShell Module"
Import-Module "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

## Create a new PSDrive to the configured MDT deploy path.
Write-Log -Type Info -Evt "Creating PSDrive to $MdtDeployPath"
New-PSDrive -Name "ImgFacDeploy" -PSProvider MDTProvider -Root $MdtDeployPath | Out-Null

## For Progress bar
$i = 0

##
## For each of the Task Sequence ID's configured, run the build process.
##
ForEach ($Id in $TsId)
{
    ## Progress Bar based on progress through the TS ID's
    Write-Progress -Id 0 -Activity "Processing" -Status "Current TSID: $Id" -PercentComplete ($i/$TsId.count*100)

    ## Test to see if the build environment is dirty from another run, if it is exit the script.
    $EnvDirtyTest = Test-Path -Path $MdtBuildPath\Control\CustomSettings-backup.ini
    If ($EnvDirtyTest)
    {
        Write-Log -Type Err -Evt "CustomSettings-backup.ini already exists."
        Write-Log -Type Err -Evt "The build environment is dirty."
        Write-Log -Type Err -Evt "Did the script finish successfully last time it was run?"
        Exit
    }

    Write-Log -Type Info -Evt "Start of Task Sequence ID: $Id"
    Write-Log -Type Info -Evt "(TSID: $Id) Backing up current MDT CustomSettings.ini"

    ## Backup the existing CustomSettings.ini.
    Copy-Item $MdtBuildPath\Control\CustomSettings.ini $MdtBuildPath\Control\CustomSettings-backup.ini
    Start-Sleep -Seconds 5

    Write-Log -Type Info -Evt "(TSID: $Id) Setting MDT CustomSettings.ini for Task Sequence"

    ## Setup MDT CustomSettings.ini for auto deploy.
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipComputerName=YES"

    ## Set the VM name as build + the date and time.
    $VmName = ("$Id`_{0:yyyy-MM-dd_HH-mm-ss}" -f (Get-Date))

    Write-Log -Type Info -Evt "(TSID: $Id) Creating VM: $VmName on $VmHost"
    Write-Log -Type Info -Evt "(TSID: $Id) Adding VHD: $VhdPath\$VmName.vhdx"
    Write-Log -Type Info -Evt "(TSID: $Id) Adding Virtual NIC: $VmNic"

    If ($Vbox -eq $false)
    {
        ## Create the VM with 4GB Dynamic RAM, Gen 1, 127GB VHD, and add the configured vNIC.
        New-VM -name $VmName -MemoryStartupBytes 4096MB -BootDevice CD -Generation 1 -NewVHDPath $VhdPath\$VmName.vhdx -NewVHDSizeBytes 130048MB -SwitchName $VmNic -ComputerName $VmHost | Out-Null
    }

    else {
        & $VBoxLoc\VBoxManage createvm --name $VmName --ostype "Windows10_64" --register
    }

    Write-Log -Type Info -Evt "(TSID: $Id) Configuring VM Processor Count"
    Write-Log -Type Info -Evt "(TSID: $Id) Configuring VM Static Memory"
    Write-Log -Type Info -Evt "(TSID: $Id) Configuring VM to boot from $BootMedia"

    If ($Vbox -eq $false)
    {
        ## Configure the VM with 2 vCPUs, static RAM and disable checkpoints.
        ## Set the boot CD to the configured ISO.
        ## Start the VM
        Set-VM $VmName -ProcessorCount 2 -StaticMemory -AutomaticCheckpointsEnabled $false -ComputerName $VmHost
        Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost
        Write-Log -Type Info -Evt "(TSID: $Id) Starting $VmName on $VmHost"
        Start-VM $VmName -ComputerName $VmHost
    }

    else {
        & $VBoxLoc\VBoxManage modifyvm $VmName --cpus 2
        & $VBoxLoc\VBoxManage modifyvm $VmName --memory 2048 --vram 128
        ## Testing
        # & $VBoxLoc\VBoxManage modifyvm $VmName --memory 4096 --vram 128
        & $VBoxLoc\VBoxManage modifyvm $VmName --nic1 nat
        & $VBoxLoc\VBoxManage createhd --filename $VhdPath\$VmName.vdi --size 130048 --format VDI
        & $VBoxLoc\VBoxManage storagectl $VmName --name "SATA Controller" --add sata --controller IntelAhci
        & $VBoxLoc\VBoxManage storageattach $VmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $VhdPath\$VmName.vdi
        & $VBoxLoc\VBoxManage storagectl $VmName --name "IDE Controller" --add ide --controller PIIX4
        & $VBoxLoc\VBoxManage storageattach $VmName --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium $BootMedia
        & $VBoxLoc\VBoxManage modifyvm $VmName --boot1 dvd --boot2 disk --boot3 none --boot4 none
        Write-Log -Type Info -Evt "(TSID: $Id) Waiting for $VmName to shutdown"
        & $VBoxLoc\VBoxHeadless --startvm $VmName
    }

    If ($Vbox -eq $false)
    {
        ## Wait until the VM is turned off.
        Write-Log -Type Info -Evt "(TSID: $Id) Waiting for $VmName to shutdown"
        While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -Seconds 5}
    }

    If ($Vbox -eq $false)
    {
        ## If -remote switch is set, remove the VMs VHD's from the remote server.
        ## If switch is not set, the VM's VHDs are removed from the local computer.
        If ($Remote)
        {
            $VmBye = Get-VM -Name $VmName -ComputerName $VmHost
            $Disks = Get-VHD -VMId $VmBye.Id -ComputerName $VmHost
            Write-Log -Type Info -Evt "(TSID: $Id) Deleting $VmName on $VmHost"
            Invoke-Command {Remove-Item $using:disks.path -Force} -ComputerName $VmBye.ComputerName
            Start-Sleep -Seconds 5
        }

        else {
            $VmLocal = Get-VM -Name $VmName -ComputerName $VmHost
            Write-Log -Type Info -Evt "(TSID: $Id) Deleting $VmName on $VmHost"
            Remove-Item $VmLocal.HardDrives.Path -Force
        }
    }

    If ($Vbox -eq $false)
    {
        Remove-VM $VmName -ComputerName $VmHost -Force
    }

    else {
        ## Remove VBox VM and Files here
        & $VBoxLoc\VBoxManage unregistervm $VmName --delete
    }

    ## Restore CustomSettings.ini from the backup.
    Write-Log -Type Info -Evt "(TSID: $Id) Restoring MDT CustomSettings.ini from backup"
    Remove-Item $MdtBuildPath\Control\CustomSettings.ini
    Move-Item $MdtBuildPath\Control\CustomSettings-backup.ini $MdtBuildPath\Control\CustomSettings.ini

    ## For each of the the WIM files in the captures folder of the build share, import
    ## them into the MDT Operating Systems folder.
    $Wims = Get-ChildItem $MdtBuildPath\Captures\$Id`_*-*-*-*-*.wim

    ForEach ($File in $Wims)
    {
        Write-Log -Type Info -Evt "(TSID: $Id) Importing WIM File: $File"
        Import-MDTOperatingSystem -Path "ImgFacDeploy:\Operating Systems" -SourceFile $File -DestinationFolder $File.Name | Out-Null
        Rename-Item -Path "ImgFacDeploy:\Operating Systems\$Id* in $Id`_*-*-*-*-*.wim $Id`_*-*-*-*-*.wim" -NewName ("$Id`_{0:yyyy-MM-dd_HH-mm-ss}" -f (Get-Date))
    }

    ## Cleanup the WIM files in the captures folder of the build share.
    Write-Log -Type Info -Evt "(TSID: $Id) Removing captured WIM file"
    Remove-Item $MdtBuildPath\Captures\$Id`_*-*-*-*-*.wim
    Write-Log -Type Info -Evt "End of Task Sequence ID: $Id"

    ## Increase count for progress bar
    $i = $i+1
}
##
## End of the build and capture process for TS's
##

Write-Log -Type Info -Evt "Process finished"

## If logging is configured then finish the log file.
If ($LogPath)
{
    Add-Content -Path $Log -Encoding ASCII -Value "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") [INFO] Log finished"

    ## This whole block is for e-mail, if it is configured.
    If ($SmtpServer)
    {
        ## Default e-mail subject if none is configured.
        If ($Null -eq $MailSubject)
        {
            $MailSubject = "Image Factory Utility Log"
        }

        ## Default Smtp Port if none is configured.
        If ($Null -eq $SmtpPort)
        {
            $SmtpPort = "25"
        }

        ## Setting the contents of the log to be the e-mail body.
        $MailBody = Get-Content -Path $Log | Out-String

        ## If an smtp password is configured, get the username and password together for authentication.
        ## If an smtp password is not provided then send the e-mail without authentication and obviously no SSL.
        If ($SmtpPwd)
        {
            $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
            $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

            ## If -ssl switch is used, send the email with SSL.
            ## If it isn't then don't use SSL, but still authenticate with the credentials.
            If ($UseSsl)
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
            }

            else {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Credential $SmtpCreds
            }
        }

        else {
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer
        }
    }
    ## End of Email block
}

## End