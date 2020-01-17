# ----------------------------------------------------------------------------
# Script: Image Factory Deploy
# Version: 2.6
# Author: Mike Galvin
# Contact: mike@gal.vin or twitter.com/mikegalvin_
# Date: 2020-01-17
# ----------------------------------------------------------------------------

[CmdletBinding()]
Param(
    [parameter(Mandatory=$true)]
    [alias("Deploy")]
    $MdtDeployPath,
    [parameter(Mandatory=$true)]
    [alias("TS")]
    $TsId,
    [parameter(Mandatory=$true)]
    [alias("VH")]
    $VmHost,
    [parameter(Mandatory=$true)]
    [alias("VHD")]
    $VhdPath,
    [parameter(Mandatory=$true)]
    [alias("Boot")]
    $BootMedia,
    [parameter(Mandatory=$true)]
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

# If logging is configured, start log.
If ($LogPath) 
{
    $LogFile = ("Image-Factory-Deploy-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"
    $LogT = Test-Path -Path $Log

# If the log file already exists, clear it.
    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log started"
    Add-Content -Path $Log -Value ""
}

# If compat is configured, load the older Hyper-V PS module.
If ($Compat)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    }

    Write-Host "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
}

# Import MDT PS module.
If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -format g) Importing MDT PowerShell Module"
}

Write-Host "$(Get-Date -format g) Importing MDT PowerShell Module"

$Mdt = "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
Import-Module $Mdt

ForEach ($Id in $TsId)
{
    # Setup MDT custom settings for VM auto deploy.
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"
    }
    
    Write-Host "$(Get-Date -format g) ###### Starting Task Sequence ID: $Id ######"
    Write-Host "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"

    Copy-Item $MdtDeployPath\Control\CustomSettings.ini $MdtDeployPath\Control\CustomSettings-backup.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Setting up MDT CustomSettings.ini for Task Sequence ID: $Id"
    }

    Write-Host "$(Get-Date -format g) Setting MDT CustomSettings.ini for Task Sequence ID: $Id"

    Add-Content $MdtDeployPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
    Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipComputerName=YES"

    # Create VM.
    $VmName = $Id

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Creating VM: $VmName on $VmHost"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Adding VHD: $VhdPath\$VmName.vhdx"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Adding Virtual NIC: $VmNic"
    }

    Write-Host "$(Get-Date -format g) Creating VM: $VmName on $VmHost"
    Write-Host "$(Get-Date -format g) Adding VHD: $VhdPath\$VmName.vhdx"
    Write-Host "$(Get-Date -format g) Adding Virtual NIC: $VmNic"

    New-VM -name $VmName -MemoryStartupBytes 4096MB -BootDevice CD -Generation 1 -NewVHDPath $VhdPath\$VmName.vhdx -NewVHDSizeBytes 130048MB -SwitchName $VmNic -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM Processor Count"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM Static Memory"
        Add-Content -Path $Log -Value "$(Get-Date -format g) Configuring VM to boot from $BootMedia"
    }

    Write-Host "$(Get-Date -format g) Configuring VM Processor Count"
    Write-Host "$(Get-Date -format g) Configuring VM Static Memory"
    Write-Host "$(Get-Date -format g) Configuring VM to boot from $BootMedia"

    Set-VM $VmName -ProcessorCount 2 -StaticMemory -ComputerName $VmHost
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Starting $VmName on $VmHost with $Id"
    }
    
    Write-Host "$(Get-Date -format g) Starting $VmName on $VmHost with $Id"

    Start-VM $VmName -ComputerName $VmHost

    # Wait for VM to stop.
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Waiting for $VmName to build $Id"
    }

    Write-Host "$(Get-Date -format g) Waiting for $VmName to build $Id"

    While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -s 5}

    # Change config back.
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $null -ComputerName $VmHost
    #Set-VM -Name $VMName -DynamicMemory -MemoryStartupBytes 1GB -MemoryMinimumBytes 100MB -MemoryMaximumBytes 4GB -ComputerName $VmHost

    # Restore MDT custom settings.
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"
    }
    
    Write-Host "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"
    Write-Host "$(Get-Date -format g) ###### End of Task Sequence ID: $Id ######"

    Remove-Item $MdtDeployPath\Control\CustomSettings.ini
    Move-Item $MdtDeployPath\Control\CustomSettings-backup.ini $MdtDeployPath\Control\CustomSettings.ini
    Start-Sleep -s 5
}


# If log was configured stop the log.
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    # If email was configured, set the variables for the email subject and body.
    If ($SmtpServer)
    {
        # If no subject is set, use the string below.
        If ($Null -eq $MailSubject)
        {
            $MailSubject = "Image Factory Deploy"
        }

        $MailBody = Get-Content -Path $Log | Out-String

        # If an email password was configured, create a variable with the username and password.
        If ($SmtpPwd)
        {
            $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPwd | ConvertTo-SecureString -AsPlainText -Force)

            # If ssl was configured, send the email with ssl.
            If ($UseSsl)
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -UseSsl -Credential $SmtpCreds
            }

            # If ssl wasn't configured, send the email without ssl.
            Else
            {
                Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Credential $SmtpCreds
            }
        }

        # If an email username and password were not configured, send the email without authentication.
        Else
        {
            Send-MailMessage -To $MailTo -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer
        }
    }
}

# End