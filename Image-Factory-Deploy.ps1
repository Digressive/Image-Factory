<#PSScriptInfo

.VERSION 22.06.07

.GUID 849ea0c5-1c44-49c1-817e-fd7702b83752

.AUTHOR Mike Galvin Contact: mike@gal.vin / twitter.com/mikegalvin_ / discord.gg/5ZsnJ5k

.COMPANYNAME Mike Galvin

.COPYRIGHT (C) Mike Galvin. All rights reserved.

.TAGS Microsoft Deployment Toolkit MDT Hyper-V Windows OSD Testing

.LICENSEURI

.PROJECTURI https://gal.vin/utils/image-factory-utility/

.ICONURI

.EXTERNALMODULEDEPENDENCIES Microsoft Deployment Toolkit PowerShell Modules, Hyper-V Management PowerShell Modules

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES

#>

<#
    .SYNOPSIS
    Image Factory Utility (Deploy) - Automate testing of WIM files and task sequences.

    .DESCRIPTION
    This script will create Hyper-V virtual machines to test WIM files and Microsoft Deployment
    Toolkit task sequences.
    Run with -help or no arguments for usage.
#>

## Set up command line switches.
[CmdletBinding()]
Param(
    [alias("Deploy")]
    $MdtDeployPathUsr,
    [alias("TS")]
    $TsId,
    [alias("VH")]
    $VmHost,
    [alias("VHD")]
    $VhdPathUsr,
    [alias("Boot")]
    $BootMedia,
    [alias("VNic")]
    $VmNic,
    [alias("L")]
    $LogPathUsr,
    [alias("LogRotate")]
    $LogHistory,
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
    [switch]$Remote,
    [switch]$VBox,
    [switch]$Help,
    [switch]$NoBanner)

If ($NoBanner -eq $False)
{
    Write-Host -ForegroundColor Yellow -BackgroundColor Black -Object "
  .___                  ___________              __                         ____ ___   __  .__.__  .__  __            
  |   | _____    ____   \_   _____/____    _____/  |_  ___________ ___.__. |    |   \_/  |_|__|  | |__|/  |_ ___.__.  
  |   |/     \  / ___\   |    __) \__  \ _/ ___\   __\/  _ \_  __ <   |  | |    |   /\   __\  |  | |  \   __<   |  |  
  |   |  Y Y  \/ /_/  >  |     \   / __ \\  \___|  | (  <_> )  | \/\___  | |    |  /  |  | |  |  |_|  ||  |  \___  |  
  |___|__|_|  /\___  /   \___  /  (____  /\___  >__|  \____/|__|   / ____| |______/   |__| |__|____/__||__|  / ____|  
            \//_____/        \/        \/     \/                   \/                                        \/       
                                          Mike Galvin               Version 22.06.07                                  
                                        https://gal.vin            See -help for usage          -Deploy-              
                                           Donate: https://www.paypal.me/digressive                                   
"
}

If ($PSBoundParameters.Values.Count -eq 0 -or $Help)
{
    Write-Host -Object "Usage:

    From a terminal run: [path\]Image-Factory-Deploy.ps1 -Deploy [path\] -Boot [path\]LiteTouchPE_x64-Deploy.iso
    -Vnic [virtual NIC name] -Ts W11-21H2,W10-21H2

    This will use Hyper-V VMs on the local machine to build wim files from the task sequences W11-21H2 and W10-21H2.

    Use -VH [hostname] to specify a remote Hyper-V server.
    Please note that -Boot and -VHD paths will be local to the remote server.

    Use -VHD [path\] to configure where to store the VM's VHD, if not the default.

    Use -Remote when the Hyper-V server is a remote computer.
    Use -VBox if using Virtual Box instead of Hyper-V as the VM platform.

    To output a log: -L [path\].
    To remove logs produced by the utility older than X days: -LogRotate [number].
    Run with no ASCII banner: -NoBanner

    To use the 'email log' function:
    Specify the subject line with -Subject ""'[subject line]'"" If you leave this blank a default subject will be used
    Make sure to encapsulate it with double & single quotes as per the example for Powershell to read it correctly.

    Specify the 'to' address with -SendTo [example@contoso.com]
    For multiple address, separate with a comma.

    Specify the 'from' address with -From [example@contoso.com]
    Specify the SMTP server with -Smtp [smtp server name]

    Specify the port to use with the SMTP server with -Port [port number].
    If none is specified then the default of 25 will be used.

    Specify the user to access SMTP with -User [example@contoso.com]
    Specify the password file to use with -Pwd [path\]ps-script-pwd.txt.
    Use SSL for SMTP server connection with -UseSsl.

    To generate an encrypted password file run the following commands
    on the computer and the user that will run the script:
"
    Write-Host -Object '    $creds = Get-Credential
    $creds.Password | ConvertFrom-SecureString | Set-Content [path\]ps-script-pwd.txt'
}

else {
    ## If logging is configured, start logging.
    ## If the log file already exists, clear it.
    If ($LogPathUsr)
    {
        ## Clean User entered string
        $LogPath = $LogPathUsr.trimend('\')

        ## Make sure the log directory exists.
        If ((Test-Path -Path $LogPath) -eq $False)
        {
            New-Item $LogPath -ItemType Directory -Force | Out-Null
        }

        $LogFile = ("Image-Factory-Deploy_{0:yyyy-MM-dd_HH-mm-ss}.log" -f (Get-Date))
        $Log = "$LogPath\$LogFile"

        If (Test-Path -Path $Log)
        {
            Clear-Content -Path $Log
        }
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
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [INFO] $Evt"
            }
            
            Write-Host -Object "$(Get-DateFormat) [INFO] $Evt"
        }

        If ($Type -eq "Succ")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [SUCCESS] $Evt"
            }

            Write-Host -ForegroundColor Green -Object "$(Get-DateFormat) [SUCCESS] $Evt"
        }

        If ($Type -eq "Err")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$(Get-DateFormat) [ERROR] $Evt"
            }

            Write-Host -ForegroundColor Red -BackgroundColor Black -Object "$(Get-DateFormat) [ERROR] $Evt"
        }

        If ($Type -eq "Conf")
        {
            If ($LogPathUsr)
            {
                Add-Content -Path $Log -Encoding ASCII -Value "$Evt"
            }

            Write-Host -ForegroundColor Cyan -Object "$Evt"
        }
    }

    ## Config checks for conflicting options, needless options.
    If ($Null -eq $MdtDeployPathUsr)
    {
        Write-Log -Type Err -Evt "The Deployment share is not specified."
        Exit
    }

    If ($Null -eq $TsId)
    {
        Write-Log -Type Err -Evt "No Task Sequence IDs are specified."
        Exit
    }

    If ($Null -eq $BootMedia)
    {
        Write-Log -Type Err -Evt "The boot media is not specified."
        Exit
    }

    If ($Null -eq $VmNic)
    {
        If ($Vbox -eq $false)
        {
            Write-Log -Type Err -Evt "The virtual NIC is not specified."
            Exit
        }
    }

    else {
        If ($Vbox -eq $true)
        {
            Write-Log -Type Info -Evt "This setting is ignored with Virtual Box."
            Exit
        }
    }

    If ($Null -ne $Vmhost -AND $Vbox -eq $True)
    {
        Write-Log -Type Err -Evt "The VM host does not need to be configured with the -VBox switch."
        Exit
    }

    ## If not configured set VmHost to local
    If ($Null -eq $VmHost)
    {
        If ($Remote)
        {
            If ($Vbox)
            {
                Write-Log -Type Err -Evt "The -Remote switch has no effect with Virtual Box, Virtual Box must be installed locally."
                Exit
            }

            Write-Log -Type Err -Evt "You must specify the remote VM host when the -Remote switch is set."
            Exit
        }

        $VmHost = $Env:ComputerName

        If ($Vbox)
        {
            $VBoxLoc = "C:\Program Files\Oracle\VirtualBox"

            If ((Test-Path -Path $VBoxLoc) -eq $False)
            {
                Write-Log -Type Err -Evt "Virtual Box is not installed on this local machine."
                Exit
            }
        }

        else {
            ## Test for Hyper-V feature installed on local machine.
            try {
                Get-Service vmcompute -ErrorAction Stop
            }

            catch {
                Write-Log -Type Err -Evt "Hyper-V is not installed on this local machine."
                Exit
            }
        }
    }

    else {
        If ($Remote -eq $False)
        {
            Write-Log -Type Err -Evt "You must use the -Remote switch when specifying a remote VM host."
            Exit
        }
    }

    ## If not configured set VhdPath to the default
    If ($Null -eq $VhdPathUsr)
    {
        If ($Vbox -eq $false)
        {
            $VhdPathUsr = Get-VMHost -Computer $VmHost | Select-Object VirtualHardDiskPath -ExpandProperty VirtualHardDiskPath
        }

        else {
            Write-Log -Type Err -Evt "You must configure a VHD storage path when using Virtual Box."
            Exit
        }
    }

    If ($Null -eq $LogPathUsr -And $SmtpServer)
    {
        Write-Log -Type Err -Evt "You must specify -L [path\] to use the email log function."
        Exit
    }

    ## getting Windows Version info
    $OSVMaj = [environment]::OSVersion.Version | Select-Object -expand major
    $OSVMin = [environment]::OSVersion.Version | Select-Object -expand minor
    $OSVBui = [environment]::OSVersion.Version | Select-Object -expand build
    $OSV = "$OSVMaj" + "." + "$OSVMin" + "." + "$OSVBui"

    ##
    ## Display the current config and log if configured.
    ##
    Write-Log -Type Conf -Evt "************ Running with the following config *************."
    Write-Log -Type Conf -Evt "Utility Version:.......22.06.07"
    Write-Log -Type Conf -Evt "Hostname:..............$Env:ComputerName."
    Write-Log -Type Conf -Evt "Windows Version:.......$OSV."

    If ($MdtDeployPathUsr)
    {
        Write-Log -Type Conf -Evt "Deploy share:..........$MdtDeployPathUsr."
    }

    If ($TsId)
    {
        Write-Log -Type Conf -Evt "No. of TS ID's:........$($TsId.count)."
        Write-Log -Type Conf -Evt "TS ID's:..............."
        ForEach ($Id in $TsId)
        {
            Write-Log -Type Conf -Evt ".......................$Id"
        }
    }

    If ($VmHost)
    {
        Write-Log -Type Conf -Evt "VM Host:...............$VmHost."
    }

    If ($VhdPathUsr)
    {
        Write-Log -Type Conf -Evt "VHD path:..............$VhdPathUsr."
    }

    If ($BootMedia)
    {
        Write-Log -Type Conf -Evt "Boot media path:.......$BootMedia."
    }

    If ($VmNic)
    {
        Write-Log -Type Conf -Evt "Virtual NIC name:......$VmNic."
    }

    If ($LogPathUsr)
    {
        Write-Log -Type Conf -Evt "Logs directory:........$LogPath."
    }

    If ($Null -ne $LogHistory)
    {
        Write-Log -Type Conf -Evt "Logs to keep:..........$LogHistory days."
    }

    If ($MailTo)
    {
        Write-Log -Type Conf -Evt "E-mail log to:.........$MailTo."
    }

    If ($MailFrom)
    {
        Write-Log -Type Conf -Evt "E-mail log from:.......$MailFrom."
    }

    If ($MailSubject)
    {
        Write-Log -Type Conf -Evt "E-mail subject:........$MailSubject."
    }

    If ($SmtpServer)
    {
        Write-Log -Type Conf -Evt "SMTP server:...........$SmtpServer."
    }

    If ($SmtpPort)
    {
        Write-Log -Type Conf -Evt "SMTP Port:.............$SmtpPort."
    }

    If ($SmtpUser)
    {
        Write-Log -Type Conf -Evt "SMTP user:.............$SmtpUser."
    }

    If ($SmtpPwd)
    {
        Write-Log -Type Conf -Evt "SMTP pwd file:.........$SmtpPwd."
    }

    If ($SmtpServer)
    {
        Write-Log -Type Conf -Evt "-UseSSL switch:........$UseSsl."
    }

    If ($VBox)
    {
        Write-Log -Type Conf -Evt "-VBox switch:..........$VBox."
    }

    If ($Remote)
    {
        Write-Log -Type Conf -Evt "-Remote switch:........$Remote."
    }
    Write-Log -Type Conf -Evt "************************************************************"
    Write-Log -Type Info -Evt "Process started"
    ##
    ## Display current config ends here.
    ##

    ##Clean the user paths
    $VhdPath = $VhdPathUsr.trimend('\')
    $MdtDeployPath = $MdtDeployPathUsr.trimend('\')

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
        If (Test-Path -Path $MdtDeployPath\Control\CustomSettings-backup.ini)
        {
            Write-Log -Type Err -Evt "CustomSettings-backup.ini already exists."
            Write-Log -Type Err -Evt "The build environment is dirty."
            Write-Log -Type Err -Evt "Did the script finish successfully last time it was run?"
            Exit
        }

        Write-Log -Type Info -Evt "Start of Task Sequence ID: $Id"
        Write-Log -Type Info -Evt "(TSID:$Id) Backing up current MDT CustomSettings.ini"

        ## Backup the existing CustomSettings.ini.
        Copy-Item $MdtDeployPath\Control\CustomSettings.ini $MdtDeployPath\Control\CustomSettings-backup.ini
        Start-Sleep -Seconds 5

        Write-Log -Type Info -Evt "(TSID:$Id) Setting MDT CustomSettings.ini for Task Sequence"

        ## Setup MDT CustomSettings.ini for auto deploy.
        Add-Content $MdtDeployPath\Control\CustomSettings.ini ""
        Add-Content $MdtDeployPath\Control\CustomSettings.ini ""
        Add-Content $MdtDeployPath\Control\CustomSettings.ini "TaskSequenceID=$Id"
        Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipTaskSequence=YES"
        Add-Content $MdtDeployPath\Control\CustomSettings.ini "SkipComputerName=YES"

        ## Set the VM name as build + the date and time.
        $VmName = ("$Id`_{0:yyyy-MM-dd_HH-mm-ss}" -f (Get-Date))

        Write-Log -Type Info -Evt "(TSID:$Id) Creating VM: $VmName on $VmHost"
        Write-Log -Type Info -Evt "(TSID:$Id) Adding VHD: $VhdPath\$VmName.vhdx"

        If ($VmNic)
        {
            Write-Log -Type Info -Evt "(TSID:$Id) Adding Virtual NIC: $VmNic"
        }

        If ($Vbox -eq $false)
        {
            ## Create the VM with 4GB Dynamic RAM, Gen 1, 127GB VHD, and add the configured vNIC.
            try {
                New-VM -name $VmName -MemoryStartupBytes 4096MB -BootDevice CD -Generation 1 -NewVHDPath $VhdPath\$VmName.vhdx -NewVHDSizeBytes 130048MB -SwitchName $VmNic -ComputerName $VmHost -ErrorAction Stop | Out-Null
            }

            catch {
                Write-Log -Type Err -Evt "(TSID:$Id) $_"

                ## Restore CustomSettings.ini from the backup.
                Write-Log -Type Info -Evt "(TSID:$Id) Restoring MDT CustomSettings.ini from backup"
                Remove-Item $MdtDeployPath\Control\CustomSettings.ini
                Move-Item $MdtDeployPath\Control\CustomSettings-backup.ini $MdtDeployPath\Control\CustomSettings.ini
                Exit
            }
        }

        else {
            & $VBoxLoc\VBoxManage createvm --name $VmName --ostype "Windows10_64" --register
        }

        Write-Log -Type Info -Evt "(TSID:$Id) Configuring VM Processor Count"
        Write-Log -Type Info -Evt "(TSID:$Id) Configuring VM Static Memory"
        Write-Log -Type Info -Evt "(TSID:$Id) Configuring VM to boot from $BootMedia"

        If ($Vbox -eq $false)
        {
            ## Configure the VM with 2 vCPUs, static RAM and disable checkpoints.
            ## Set the boot CD to the configured ISO.
            ## Start the VM
            Set-VM $VmName -ProcessorCount 2 -StaticMemory -AutomaticCheckpointsEnabled $false -ComputerName $VmHost

            try {
                Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $BootMedia -ComputerName $VmHost -ErrorAction Stop
            }

            catch {
                Write-Log -Type Err -Evt "(TSID:$Id) $_"

                ## If -Remote switch is set, remove the VMs VHD's from the remote server.
                ## If switch is not set, the VM's VHDs are removed from the local computer.
                If ($Remote)
                {
                    $VmBye = Get-VM -Name $VmName -ComputerName $VmHost
                    $Disks = Get-VHD -VMId $VmBye.Id -ComputerName $VmHost
                    Write-Log -Type Info -Evt "(TSID:$Id) Deleting $VmName on $VmHost"
                    Invoke-Command {Remove-Item $using:disks.path -Force} -ComputerName $VmBye.ComputerName
                    Start-Sleep -Seconds 5
                }

                else {
                    $VmLocal = Get-VM -Name $VmName -ComputerName $VmHost
                    Write-Log -Type Info -Evt "(TSID:$Id) Deleting $VmName on $VmHost"
                    Remove-Item $VmLocal.HardDrives.Path -Force
                }

                ## Remove Hyper-V VM from remote or local
                Remove-VM $VmName -ComputerName $VmHost -Force

                ## Restore CustomSettings.ini from the backup.
                Write-Log -Type Info -Evt "(TSID:$Id) Restoring MDT CustomSettings.ini from backup"
                Remove-Item $MdtDeployPath\Control\CustomSettings.ini
                Move-Item $MdtDeployPath\Control\CustomSettings-backup.ini $MdtDeployPath\Control\CustomSettings.ini
                Exit
            }

            Write-Log -Type Info -Evt "(TSID:$Id) Starting $VmName on $VmHost"
            Start-VM $VmName -ComputerName $VmHost
        }

        else {
            & $VBoxLoc\VBoxManage modifyvm $VmName --cpus 2
            & $VBoxLoc\VBoxManage modifyvm $VmName --memory 2048 --vram 128
            & $VBoxLoc\VBoxManage modifyvm $VmName --nic1 nat
            & $VBoxLoc\VBoxManage createhd --filename $VhdPath\$VmName.vdi --size 130048 --format VDI
            & $VBoxLoc\VBoxManage storagectl $VmName --name "SATA Controller" --add sata --controller IntelAhci
            & $VBoxLoc\VBoxManage storageattach $VmName --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium $VhdPath\$VmName.vdi
            & $VBoxLoc\VBoxManage storagectl $VmName --name "IDE Controller" --add ide --controller PIIX4
            & $VBoxLoc\VBoxManage storageattach $VmName --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium $BootMedia
            & $VBoxLoc\VBoxManage modifyvm $VmName --boot1 dvd --boot2 disk --boot3 none --boot4 none
            Write-Log -Type Info -Evt "(TSID:$Id) Waiting for $VmName to shutdown"
            & $VBoxLoc\VBoxHeadless --startvm $VmName
        }

        If ($Vbox -eq $false)
        {
            ## Wait until the VM is turned off.
            Write-Log -Type Info -Evt "(TSID:$Id) Waiting for $VmName to shutdown"
            While ((Get-VM -Name $VmName -ComputerName $VmHost).state -ne 'Off') {Start-Sleep -Seconds 5}

            ## Change VM config to remove boot ISO.
            Set-VMDvdDrive -VMName $VmName -ControllerNumber 1 -ControllerLocation 0 -Path $null -ComputerName $VmHost
        }

        ## Restore CustomSettings.ini from the backup.
        Write-Log -Type Info -Evt "(TSID:$Id) Restoring MDT CustomSettings.ini from backup"
        Remove-Item $MdtDeployPath\Control\CustomSettings.ini
        Move-Item $MdtDeployPath\Control\CustomSettings-backup.ini $MdtDeployPath\Control\CustomSettings.ini
        Write-Log -Type Info -Evt "End of Task Sequence ID: $Id"

        ## Increase count for progress bar
        $i = $i+1
    }
    ##
    ## End of the deploy process for TS's
    ##

    Write-Log -Type Info -Evt "Process finished"

    If ($Null -ne $LogHistory)
    {
        ## Cleanup logs.
        Write-Log -Type Info -Evt "Deleting logs older than: $LogHistory days"
        Get-ChildItem -Path "$LogPath\Image-Factory-Deploy_*" -File | Where-Object CreationTime -lt (Get-Date).AddDays(-$LogHistory) | Remove-Item -Recurse
    }

    ## This whole block is for e-mail, if it is configured.
    If ($SmtpServer)
    {
        If (Test-Path -Path $Log)
        {
            ## Default e-mail subject if none is configured.
            If ($Null -eq $MailSubject)
            {
                $MailSubject = "Image Factory Utility Deploy Log"
            }

                ## Default Smtp Port if none is configured.
                If ($Null -eq $SmtpPort)
                {
                    $SmtpPort = "25"
                }

                ## Setting the contents of the log to be the e-mail body. 
                $MailBody = Get-Content -Path $Log | Out-String

                ForEach ($MailAddress in $MailTo)
                {
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
                            Send-MailMessage -To $MailAddress -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort -UseSsl -Credential $SmtpCreds
                        }

                        else {
                            Send-MailMessage -To $MailAddress -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort -Credential $SmtpCreds
                        }
                    }

                else {
                    Send-MailMessage -To $MailAddress -From $MailFrom -Subject $MailSubject -Body $MailBody -SmtpServer $SmtpServer -Port $SmtpPort
                }
            }
        }

        else {
            Write-Host -ForegroundColor Red -BackgroundColor Black -Object "There's no log file to email."
        }
    }
    ## End of Email block
}
## End