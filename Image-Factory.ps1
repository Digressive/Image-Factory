<#PSScriptInfo

.VERSION 2.8

.GUID 251ae35c-cc4e-417c-970c-848b221477fa

.AUTHOR Mike Galvin twitter.com/digressive

.COMPANYNAME

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Microsoft Deployment Toolkit MDT Hyper-V Windows OSD

.LICENSEURI

.PROJECTURI https://gal.vin/2017/08/26/image-factory

.ICONURI

.EXTERNALMODULEDEPENDENCIES Microsoft Deployment Toolkit PowerShell Modules, Hyper-v Management PowerShell Modules

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
    The local or UNC path to the build share of MDT. This and the deploy switch can point to the same location.

    .PARAMETER Deploy
    The local or UNC path to the deploy share of MDT. This and the build switch can point to the same location.

    .PARAMETER Ts
    The comma-separated list of task sequence ID's to build.

    .PARAMETER Vh
    The name of the computer running Hyper-V. Can be local or remote.

    .PARAMETER Vhd
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
    Image-Factory.ps1 -Build \\mdt01\BuildShare$ -Deploy \\mdt01\DeploymentShare$ -Vh hyperv01 -Vhd D:\Hyper-V\VHD -Boot F:\iso\LiteTouchPE_x64.iso -VNic vSwitch-Ext -Remote -L E:\logs -SendTo me@contoso.com -From Image-Factory@contoso.com -Smtp exch01.contoso.com -User me@contoso.com -Pwd P@ssw0rd -UseSsl -Ts W10-1703,WS16-S

    This string will build two WIM from the two task sequences: W10-1703 & WS16-S. They will be imported to the deployment share on MDT01. The Hyper-V server used will be
    hyperv01, the VHD for the VMs generated will be stored in D:\Hyper-V\VHD on the server hyperv01. The boot iso file will be F:\iso\LiteTouchPE_x64.iso located on the
    Hyper-V server. The Virtual Switch used by the VM will be called vSwitch-Ext. The log file will be output to E:\logs and it will be emailed using an SSL conection.
#>

[CmdletBinding()]
Param(
    [parameter(Mandatory=$True)]
    [alias("Build")]
    $MdtBuildPath,
    [parameter(Mandatory=$True)]
    [alias("Deploy")]
    $MdtDeployPath,
    [parameter(Mandatory=$True)]
    [alias("Ts")]
    $TsId,
    [parameter(Mandatory=$True)]
    [alias("Vh")]
    $VmHost,
    [parameter(Mandatory=$True)]
    [alias("Vhd")]
    $VhdPath,
    [parameter(Mandatory=$True)]
    [alias("Boot")]
    $BootMedia,
    [parameter(Mandatory=$True)]
    [alias("VNic")]
    $VmNic,
    [alias("L")]
    $LogPath,
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

## If logging is configured, start log
If ($LogPath)
{
    $LogFile = ("Image-Factory-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"

    ## If the log file already exists, clear it
    $LogT = Test-Path -Path $Log

    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log started"
    Add-Content -Path $Log -Value ""
}

## If compat is configured, load the older Hyper-V PS module
If ($Compat) 
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing Hyper-V 1.1 PowerShell Module"
    }
    
    Write-Host "$(Get-Date -Format G) Importing Hyper-V 1.1 PowerShell Module"
    Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
}

## Import MDT PS module
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing MDT PowerShell Module"
}

Write-Host "$(Get-Date -Format G) Importing MDT PowerShell Module"
Import-Module "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

ForEach ($Id in $TsId)
{
    ## Test to see if the build environment is dirty.
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
    
    ## Setup MDT custom settings for VM auto deploy
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

    Copy-Item $MdtBuildPath\Control\CustomSettings.ini $MdtBuildPath\Control\CustomSettings-backup.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Setting up MDT CustomSettings.ini for Task Sequence ID: $Id"
    }

    Write-Host "$(Get-Date -Format G) Setting MDT CustomSettings.ini for Task Sequence ID: $Id"

    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $MdtBuildPath\Control\CustomSettings.ini "SkipComputerName=YES"

    ## Create VM
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

    Set-VM $VmName -ProcessorCount 2 -StaticMemory -AutomaticCheckpointsEnabled $false -ComputerName $VmHost
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Starting $VmName on $VmHost with $Id"
    }

    Write-Host "$(Get-Date -Format G) Starting $VmName on $VmHost with $Id"

    Start-VM $VmName -ComputerName $VmHost

    ## Wait for VM to stop
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Waiting for $VmName to build $Id"
    }

    Write-Host "$(Get-Date -Format G) Waiting for $VmName to build $Id"

    While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -s 10}

    ## Remove VM and VHD
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

    Remove-VM $VmName -ComputerName $VmHost -Force

    ## Restore MDT custom settings
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Restoring MDT CustomSettings.ini from backup"
    }

    Write-Host "$(Get-Date -Format G) Restoring MDT CustomSettings.ini from backup"

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

## Connect to MDT
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Creating PSDrive to $MdtDeployPath"
}

Write-Host "$(Get-Date -Format G) Creating PSDrive to $MdtDeployPath"

New-PSDrive -Name "DS002" -PSProvider MDTProvider -Root $MdtDeployPath

## Get the WIM files and store them in a variable
$Wims = Get-ChildItem $MdtBuildPath\Captures\*.wim

## Import the WIMs from the variable above into MDT
ForEach ($file in $Wims)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -Format G) Importing WIM File: $file"
    }

    Write-Host "$(Get-Date -Format G) Importing WIM File: $file"

    Import-MDTOperatingSystem -path "DS002:\Operating Systems" -SourceFile $file -DestinationFolder $file.Name
}

## Remove captured WIMs
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Removing captured WIM files"
}

Write-Host "$(Get-Date -Format G) Removing captured WIM files"

Remove-Item $MdtBuildPath\Captures\*.wim

## If log was configured stop the log
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -Format G) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    ## If email was configured, set the variables for the email subject and body
    If ($SmtpServer)
    {
        $MailSubject = "Image Factory Log"
        $MailBody = Get-Content -Path $Log | Out-String

        ## If an email password was configured, create a variable with the username and password
        If ($SmtpPwd)
        {
            $SmtpPwdEncrypt = Get-Content $SmtpPwd | ConvertTo-SecureString
            $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList ($SmtpUser, $SmtpPwdEncrypt)

            ## If ssl was configured, send the email with ssl
            If ($UseSsl)
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
            }

            ## If ssl wasn't configured, send the email without ssl
            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Credential $SmtpCreds
            }
        }

        ## If an email username and password were not configured, send the email without authentication
        Else
        {
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer
        }
    }
}

## End