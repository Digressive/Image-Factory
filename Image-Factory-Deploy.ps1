###########################################################
# Script: Image Factory Deploy
# Version: 2.6
# Author: Mike Galvin
# Contact: mike@gal.vin or twitter.com/mikegalvin_
# Date: 2020-02-01
###########################################################

## Configuring options.
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

## If logging is configured and one already exists, clear it and start a new log.
If ($LogPath) 
{
    $LogFile = ("Image-Factory-Deploy-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date))
    $Log = "$LogPath\$LogFile"

    $LogT = Test-Path -Path $Log

    If ($LogT)
    {
        Clear-Content -Path $Log
    }

    Add-Content -Path $Log -Value "****************************************"
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log started"
    Add-Content -Path $Log -Value ""
}

## If the -compat switch is used, load the older Hyper-V PS module.
If ($Compat)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    }

    Write-Host "$(Get-Date -format g) Importing Hyper-V 1.1 PowerShell Module"
    Import-Module $env:windir\System32\WindowsPowerShell\v1.0\Modules\Hyper-V\1.1\Hyper-V.psd1
}

If ($LogPath)
{
    Add-Content -Path $Log -Value "$(Get-Date -format g) Importing MDT PowerShell Module"
}

Write-Host "$(Get-Date -format g) Importing MDT PowerShell Module"

## Import the MDT PowerShell module.
$Mdt = "$env:programfiles\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
Import-Module $Mdt

## For each of the Task Sequence ID's configured, run the process.
ForEach ($Id in $TsId)
{
    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"
    }
    
    Write-Host "$(Get-Date -format g) ###### Starting Task Sequence ID: $Id ######"
    Write-Host "$(Get-Date -format g) Backing up current MDT CustomSettings.ini"

    ## Backup the exisiting CustomSettings.ini.
    Copy-Item $MdtDeployPath\Control\CustomSettings.ini $MdtDeployPath\Control\CustomSettings-backup.ini
    Start-Sleep -s 5

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Setting up MDT CustomSettings.ini for Task Sequence ID: $Id"
    }

    Write-Host "$(Get-Date -format g) Setting MDT CustomSettings.ini for Task Sequence ID: $Id"

    ## Setup MDT CustomSettings.ini for auto deploy.
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtBuildPath\Control\CustomSettings.ini ""
    Add-Content $MdtDeployPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
    Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
    Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipComputerName=YES"

    ## Set the VM name as the Task Sequence ID.
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

    ## Create the VM with 4GB Dynamic RAM, Gen 1, 127GB VHD, and add the configured vNIC.
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

    ## Configure the VM with 2 vCPUs, static RAM and disable checkpoints. Finally, set the boot CD to the configured ISO.
    Set-VM $VmName -ProcessorCount 2 -StaticMemory -ComputerName $VmHost
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Starting $VmName on $VmHost with $Id"
    }
    
    Write-Host "$(Get-Date -format g) Starting $VmName on $VmHost with $Id"

    ## Start the VM.
    Start-VM $VmName -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Waiting for $VmName to build $Id"
    }

    Write-Host "$(Get-Date -format g) Waiting for $VmName to build $Id"

    ## Wait until the VM is turned off.
    While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -s 5}

    ## Change VM config to remove boot ISO.
    Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $null -ComputerName $VmHost

    If ($LogPath)
    {
        Add-Content -Path $Log -Value "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"
    }
    
    Write-Host "$(Get-Date -format g) Restoring MDT CustomSettings.ini from backup"
    Write-Host "$(Get-Date -format g) ###### End of Task Sequence ID: $Id ######"

    ## Restore CustomSettings.ini from the backup.
    Remove-Item $MdtDeployPath\Control\CustomSettings.ini
    Move-Item $MdtDeployPath\Control\CustomSettings-backup.ini $MdtDeployPath\Control\CustomSettings.ini
    Start-Sleep -s 5
}

## If logging is configured then finish the log file.
If ($LogPath)
{
    Add-Content -Path $Log -Value ""
    Add-Content -Path $Log -Value "$(Get-Date -format g) Log finished"
    Add-Content -Path $Log -Value "****************************************"

    ## This whole block is for e-mail, if it is configured.
    If ($SmtpServer)
    {

        ## Default e-mail subject if none is configured.
        If ($Null -eq $MailSubject)
        {
            $MailSubject = "Image Factory Deploy"
        }

        ## Setting the contents of the log to be the e-mail body. 
        $MailBody = Get-Content -Path $Log | Out-String

        ## If an smtp password is configured, get the username and password together for authentication.
        ## If an smtp password is not provided then send the e-mail without authentication and obviously no SSL.
        If ($SmtpPwd)
        {
            $SmtpCreds = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPwd | ConvertTo-SecureString -AsPlainText -Force)

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

# End