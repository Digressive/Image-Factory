<#PSScriptInfo

.VERSION 2.9

.GUID 251ae35c-cc4e-417c-970c-848b221477fa

.AUTHOR Mike Galvin twitter.com/mikegalvin_

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Microsoft Deployment Toolkit MDT Hyper-V Windows OSD

.LICENSEURI

.PROJECTURI https://gal.vin/2017/08/26/image-factory

.ICONURI

.EXTERNALMODULEDEPENDENCIES Microsoft Deployment Toolkit PowerShell Modules Hyper-V Management PowerShell Modules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Automates the creation of WIM files for Windows deployment.

    .DESCRIPTION
    Automates the creation of WIM files for Windows deployment.

    This script will:
    
    Create disposable Hyper-V virtual machines to generate WIM files from Microsoft Deployment Toolkit task sequences.

    The process is as follows:

    Create a Hyper-V Virtual Machine.
    Boot it from the MDT LiteTouch boot media.
    Run the specified Task Sequence.
    Capture the .wim file to MDT.
    Destroy the Virtual Machine and VHD used.
    Move on to the next specified task sequence.
    Do the previous steps for all configured task sequences.
    Import the .wim files into the deployment share of MDT.
    Remove the captured .wim files from the capture folder.
    Optionally create a log file and email it to an address of your choice.

    Please note: to send a log file using ssl and an SMTP password you must generate an encrypted
    password file. The password file is unique to both the user and machine.
    
    The command is as follows:

    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content c:\foo\ps-script-pwd.txt
    
    .PARAMETER Build
    The local or UNC path to the build share of MDT. Both this and the deploy switch can point to the same location.

    .PARAMETER Deploy
    The local or UNC path to the deploy share of MDT. Both this and the build switch can point to the same location.

    .PARAMETER TS
    The comma-separated list of task sequence ID's to build.

    .PARAMETER VH
    The name of the computer running Hyper-V. Can be local or remote.

    .PARAMETER VHD
    The path relative to the Hyper-V server of where to store the VHD file for the VM(s).

    .PARAMETER Boot
    The path relative to the Hyper-V server of where the ISO file to boot from is stored.

    .PARAMETER VNic
    The name of the virtual switch that the VM should use to communicate with the network.

    .PARAMETER Compat
    Set if the Hyper-V server is WS2012 R2 and the script is running on Windows 10 or Windows Server 2016.
    This loads the older version of the Hyper-V module so it is able to manage WS2012 R2 Hyper-V VMs.

    .PARAMETER Remote
    Set if the Hyper-V server is a remote device.
    Do not include this switch if the script is running on the same device as Hyper-V.
    
    .PARAMETER L
    The path to output the log file to.
    The file name will be Image-Factory-YYYY-MM-dd-HH-mm-ss.log

    .PARAMETER Subject
    The email subject that the email should have. Encapulate with single or double quotes.

    .PARAMETER SendTo
    The e-mail address the log should be sent to.

    .PARAMETER From
    The from address the log should be sent from.

    .PARAMETER Smtp
    The DNS name or IP address of the SMTP server.

    .PARAMETER User
    The user account to connect to the SMTP server.

    .PARAMETER Pwd
    The password for the user account.

    .PARAMETER UseSsl
    Connect to the SMTP server using SSL.

    .EXAMPLE
    Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -VH hyperv01 -VHD C:\Hyper-V\VHD
    -Boot C:\iso\LiteTouchPE_x64.iso -VNic vSwitch-Ext -Remote -TS W10-1803,WS16-S -L C:\scripts\logs
    -Subject 'Server: Image Factory' -SendTo me@contoso.com -From hyperv@contoso.com -Smtp smtp.outlook.com -User user -Pwd C:\foo\pwd.txt -UseSsl

    This string will build a WIM file from each of the task sequences; W10-1803 & WS16-S. They will be imported to the deployment share on MDT01.
    The Hyper-V server used will be HYPERV01, the VHD for the VMs generated will be stored in C:\Hyper-V\VHD on the server HYPERV01.
    The boot iso file will be C:\iso\LiteTouchPE_x64.iso, located on the Hyper-V server. The Virtual Switch used by the VM will be called vSwitch-Ext.
    The log file will be output to C:\scripts\logs and it will be e-mailed with a custom subject line, using an SSL conection.
#>

## Configuring options.
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
    [parameter(Mandatory=$True)]
    [alias("VH")]
    $VmHost,
    [parameter(Mandatory=$True)]
    [alias("VHD")]
    $VhdPath,
    [parameter(Mandatory=$True)]
    [alias("Boot")]
    $BootMedia,
    [parameter(Mandatory=$True)]
    [alias("VNic")]
    $VmNic,
    [alias("L")]
    $LogPath,
    [alias("Subject")]
    $MailSubject,
    [alias("SendTo")]
    $MailTo,
    [alias("From")]
    $MailFrom,
    [alias("Smtp")]
    $SmtpServer,
    [alias("User")]
    $SmtpUser,
    [alias("Pwd")]
    $SmtpPwd,
    [switch]$UseSsl,
    [switch]$Compat,
    [switch]$Remote)

## If logging is configured and one already exists, clear it and start a new log.
If ($LogPath)
{
    $LogFile = ("Image-Factory-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"

    $LogT = Test-Path -Path $Log

    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log started"
    Add-Content -Path $Log -Value ""
}

## If the -compat switch is used, load the older Hyper-V PS module.
If ($Compat) 
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing Hyper-V 1.1 PowerShell Module"
    }
    
    Write-Host "$(Get-Date -Format G) Importing Hyper-V 1.1 PowerShell Module"
    Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
}

## Import the Deployment Toolkit PowerShell module.
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing MDT PowerShell Module"
}

Write-Host "$(Get-Date -Format G) Importing MDT PowerShell Module"
Import-Module "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

## For each of the Task Sequence ID's configured, run the build process.
ForEach ($Id in $TsId)
{
    ## Test to see if the build environment is dirty from another run, if it is exit the script.
    $EnvDirtyTest = Test-Path -Path $MdtBuildPath\Control\CustomSettings-backup.ini
    If ($EnvDirtyTest)
    {
        Write-Host "$(Get-Date -Format G) CustomSettings-backup.ini already exists."
        Write-Host "$(Get-Date -Format G) The build environment is dirty."
        Write-Host "$(Get-Date -Format G) Did the script finish successfully last time it was run?"

        If ($LogPath)
        {
            Add-Content -Path $Log -Value "$(Get-Date -Format G) CustomSettings-backup.ini already exists."
            Add-Content -Path $Log -Value "The build environment is dirty."
            Add-Content -Path $Log -Value "Did the script finish successfully last time it was run?"
        }

        Exit
    }
    
    If ($LogPath)
    {
        Add-Content -Path $Log -Value ""
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Starting process for $Id"
        Add-Content -Path $Log -Value ""
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Backing up current MDT CustomSettings.ini"
    }
    
    Write-Host ""
    Write-Host "$(Get-Date -Format G) Starting process for $Id"
    Write-Host ""
    Write-Host "$(Get-Date -Format G) Backing up current MDT CustomSettings.ini"

    ## Backup the exisiting CustomSettings.ini.
    Copy-Item $MdtBuildPath\Control\CustomSettings.ini $MdtBuildPath\Control\CustomSettings-backup.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Setting up MDT CustomSettings.ini for Task Sequence ID: $Id"
    }

    Write-Host "$(Get-Date -Format G) Setting MDT CustomSettings.ini for Task Sequence ID: $Id"

    ## Setup MDT CustomSettings.ini for auto deploy.
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipComputerName=YES"

    ## Set the VM name as build + the date and time.
    $VmName = ("build-{0:yyyy-MM-dd-HH-mm-ss}" -f (Get-Date))

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Creating VM: $VmName on $VmHost"
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Adding VHD: $VhdPath\$VmName.vhdx"
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Adding Virtual NIC: $VmNic"
    }

    Write-Host "$(Get-Date -Format G) Creating VM: $VmName on $VmHost"
    Write-Host "$(Get-Date -Format G) Adding VHD: $VhdPath\$VmName.vhdx"
    Write-Host "$(Get-Date -Format G) Adding Virtual NIC: $VmNic"

    ## Create the VM with 4GB Dynamic RAM, Gen 1, 127GB VHD, and add the configured vNIC.
    New-VM -name $VmName -MemoryStartupBytes 4096MB -BootDevice CD -Generation 1 -NewVHDPath $VhdPath\$VmName.vhdx -NewVHDSizeBytes 130048MB -SwitchName $VmNic -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Configuring VM Processor Count"
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Configuring VM Static Memory"
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Configuring VM to boot from $BootMedia"
    }

    Write-Host "$(Get-Date -Format G) Configuring VM Processor Count"
    Write-Host "$(Get-Date -Format G) Configuring VM Static Memory"
    Write-Host "$(Get-Date -Format G) Configuring VM to boot from $BootMedia"

    ## Configure the VM with 2 vCPUs, static RAM and disable checkpoints. Finally, set the boot CD to the configured ISO.
    Set-VM $VmName -ProcessorCount 2 -StaticMemory -AutomaticCheckpointsEnabled $false -ComputerName $VmHost
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Starting $VmName on $VmHost with $Id"
    }

    Write-Host "$(Get-Date -Format G) Starting $VmName on $VmHost with $Id"

    ## Start the VM.
    Start-VM $VmName -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Waiting for $VmName to build $Id"
    }

    Write-Host "$(Get-Date -Format G) Waiting for $VmName to build $Id"

    ## Wait until the VM is turned off.
    While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -s 10}

    ## If -remote switch is set, remove the VMs VHD's from the remote server.
    ## If switch is not set, the VM's VHDs are removed from the local computer.
    If ($Remote)
    {
        $VmBye = Get-VM -Name $VmName -ComputerName $VmHost
        $Disks = Get-VHD -VMId $VmBye.Id -ComputerName $VmHost

        If ($LogPath)
        {
            Add-Content -Path $Log -Value "$(Get-Date -Format G) Deleting $VmName on $VmHost"
        }

        Write-Host "$(Get-Date -Format G) Deleting $VmName on $VmHost"

        Invoke-Command {Remove-Item $using:disks.path -Force} -ComputerName $VmBye.ComputerName
        Start-Sleep -s 5
    }

    Else
    {
        $VmLocal = Get-VM -Name $VmName -ComputerName $VmHost

        If ($LogPath)
        {
            Add-Content -Path $Log -Value "$(Get-Date -Format G) Deleting $VmName on $VmHost"
        }

        Write-Host "$(Get-Date -Format G) Deleting $VmName on $VmHost"

        Remove-Item $VmLocal.HardDrives.Path -Force
        Start-Sleep -s 5
    }

    ## Delete the VM.
    Remove-VM $VmName -ComputerName $VmHost -Force

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Restoring MDT CustomSettings.ini from backup"
    }

    Write-Host "$(Get-Date -Format G) Restoring MDT CustomSettings.ini from backup"

    ## Restore CustomSettings.ini from the backup.
    Remove-Item $MdtBuildPath\Control\CustomSettings.ini
    Move-Item $MdtBuildPath\Control\CustomSettings-backup.ini $MdtBuildPath\Control\CustomSettings.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value ""
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Finished process for $Id"
        Add-Content -Path $Log -Value ""
    }

    Write-Host "$(Get-Date -Format G) Finished process for $Id"
}

If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Creating PSDrive to $MdtDeployPath"
}

Write-Host "$(Get-Date -Format G) Creating PSDrive to $MdtDeployPath"

## Create a new PSDrive to the configured MDT deploy path.
New-PSDrive -Name "DS002" -PSProvider MDTProvider -Root $MdtDeployPath

$Wims = Get-ChildItem $MdtBuildPath\Captures\*.wim

## For each of the the WIM files in the captures folder of the build share, import them into the MDT Operating Systems folder.
ForEach ($File in $Wims)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing WIM File: $File"
    }

    Write-Host "$(Get-Date -Format G) Importing WIM File: $File"

    Import-MDTOperatingSystem -path "DS002:\Operating Systems" -SourceFile $File -DestinationFolder $File.Name
}

If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing captured WIM files"
}

Write-Host "$(Get-Date -Format G) Removing captured WIM files"

## Delete all of the WIM files in the captures folder of the build share.
Remove-Item $MdtBuildPath\Captures\*.wim

## If logging is configured then finish the log file.
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    ## This whole block is for e-mail, if it is configured.
    If ($SmtpServer)
    {
        
        ## Default e-mail subject if none is configured.
        If ($Null -eq $MailSubject)
        {
            $MailSubject = "Image Factory Log"
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

            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Credential $SmtpCreds
            }
        }

        Else
        {
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer
        }
    }
}

## End