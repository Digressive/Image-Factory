# -------------------------------------------
# Script: Image-Factory-Deploy-v2-4.ps1
# Version: 2.4
# Author: Mike Galvin twitter.com/mikegalvin_
# Date: 18/08/2017
# -------------------------------------------

[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)]
    [alias("deploy")]
    $mdtdeploypath,
    [parameter(Mandatory=$true)]
    [alias("ts")]
    $tsid,
    [parameter(Mandatory=$true)]
    [alias("vh")]
    $vmhost,
    [parameter(Mandatory=$true)]
    [alias("vhd")]
    $vhdpath,
    [parameter(Mandatory=$true)]
    [alias("boot")]
    $bootmedia,
    [parameter(Mandatory=$true)]
    [alias("vnic")]
    $vmnic,
    [alias("L")]
    $logpath,
    [alias("sendto")]
    $mailto,
    [alias("from")]
    $mailfrom,
    [alias("smtp")]
    $smtpserver,
    [alias("user")]
    $smtpuser,
    [alias("pwd")]
    $smtppwd,
    [switch]$usessl,
    [switch]$compat,
    [switch]$remote)

# If logging is configured, start log
If ($LogPath) 
{
    $LogFile = "image-factory.log"
    $Log = "$LogPath\$LogFile"
    $LogT = Test-Path -Path $Log

# If the log file already exists, clear it
    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log started"
    Add-Content -Path $Log -Value ""
}

# If compat is configured, load the older Hyper-V PS module
If ($compat)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    }

    Write-Host "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
}

# Import MDT PS module
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -format g) Importing MDT PowerShell Module"
}

Write-Host "$(Get-Date -format g) Importing MDT PowerShell Module"

$mdt = "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
Import-Module $mdt

ForEach ($id in $tsid)
{
    # Setup MDT custom settings for VM auto deploy
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"
    }
    
    Write-Host "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"

    Copy-Item $mdtdeploypath\Control\CustomSettings.ini $mdtdeploypath\Control\CustomSettings-backup.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Setting up MDT CustomSettings.ini for Task Sequence ID: $id"
    }

    Write-Host "$(Get-Date -format g) Setting MDT CustomSettings.ini for Task Sequence ID: $id"

    Add-Content $mdtdeploypath\Control\CustomSettings.ini "TaskSequenceID=$id"
    Add-Content $mdtdeploypath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $mdtdeploypath\Control\CustomSettings.ini "SkipComputerName=YES"

    # Create VM
    $vmname = $id

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Creating VM: $vmname on $vmhost"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Adding VHD: $vhdpath\$vmname.vhdx"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Adding Virtual NIC: $vmnic"
    }

    Write-Host "$(Get-Date -format g) Creating VM: $vmname on $vmhost"
    Write-Host "$(Get-Date -format g) Adding VHD: $vhdpath\$vmname.vhdx"
    Write-Host "$(Get-Date -format g) Adding Virtual NIC: $vmnic"

    New-VM -name $vmname -MemoryStartupBytes 4096MB -BootDevice CD -Generation 1 -NewVHDPath $vhdpath\$vmname.vhdx -NewVHDSizeBytes 130048MB -SwitchName $vmnic -ComputerName $vmhost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM Processor Count"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM Static Memory"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM to boot from $bootmedia"
    }

    Write-Host "$(Get-Date -format g) Configuring VM Processor Count"
    Write-Host "$(Get-Date -format g) Configuring VM Static Memory"
    Write-Host "$(Get-Date -format g) Configuring VM to boot from $bootmedia"

    Set-VM $vmname -ProcessorCount 2 -StaticMemory -ComputerName $vmhost
    Set-VMDvdDrive -VMName $vmname -ControllerNumber 1 -ControllerLocation 0 -Path $bootmedia -ComputerName $vmhost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Starting $vmname on $vmhost with $id"
    }
    
    Write-Host "$(Get-Date -format g) Starting $vmname on $vmhost with $id"

    Start-VM $vmname -ComputerName $vmhost

    # Wait for VM to stop
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Waiting for $vmname to build $id"
    }

    Write-Host "$(Get-Date -format g) Waiting for $vmname to build $id"

    While ((Get-VM -Name $vmname -ComputerName $vmhost).state -ne 'Off') {Start-Sleep -s 5}

    # Change config back
    Set-VMDvdDrive -VMName $vmname -ControllerNumber 1 -ControllerLocation 0 -Path $null -ComputerName $vmhost
    #Set-VM -Name $VMName -DynamicMemory -MemoryStartupBytes 1GB -MemoryMinimumBytes 100MB -MemoryMaximumBytes 4GB -ComputerName $vmhost

    # Restore MDT custom settings
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"
    }
    
    Write-Host "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"

    Remove-Item $mdtdeploypath\Control\CustomSettings.ini
    Move-Item $mdtdeploypath\Control\CustomSettings-backup.ini $mdtdeploypath\Control\CustomSettings.ini
    Start-Sleep -s 5
}


# If log was configured stop the log
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    # If email was configured, set the variables for the email subject and body
    If ($smtpserver)
    {
        $mailsubject = "Lab: Image Factory Deploy Log"
        $mailbody = Get-Content -Path $log | Out-String

        # If an email password was configured, create a variable with the username and password
        If ($smtppwd)
        {
            $smtpcreds = New-Object System.Management.Automation.PSCredential -ArgumentList $smtpuser, $($smtppwd | ConvertTo-SecureString -AsPlainText -Force)

            # If ssl was configured, send the email with ssl
            If ($usessl)
            {
                Send-MailMessage -To $mailto -From $mailfrom -Subject $mailsubject -Body $mailbody -SmtpServer $smtpserver -UseSsl -Credential $smtpcreds
            }

            # If ssl wasn't configured, send the email without ssl
            Else
            {
                Send-MailMessage -To $mailto -From $mailfrom -Subject $mailsubject -Body $mailbody -SmtpServer $smtpserver -Credential $smtpcreds
            }
        }

        # If an email username and password were not configured, send the email without authentication
        Else
        {
            Send-MailMessage -To $mailto -From $mailfrom -Subject $mailsubject -Body $mailbody -SmtpServer $smtpserver
        }
    }
}

# End