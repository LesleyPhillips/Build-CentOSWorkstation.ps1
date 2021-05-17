# Here's how I did it

## Define the VM ################################
##
$DTTag = Get-Date -Format "yyyyMMddHHmmss"
$VMPath = 'F:\VM\' + $VMName
$VMName = "CentOSWorkstation" + $DTTag
$VMRam = 4GB
$VMSwitch = "External" ## Get-VMSwitch
$VMSwitchName = $VMSwitch + $DTTag
$VHDpath = $VMPath + "$VMName.vhdx"
$VHDsize = 50GB
$OSiso = "E:\Downloads\CentOS-8.3.2011-x86_64-dvd1.iso"


## Create the VM ################################
##
$VMParams = @{
    Name = $VMName
    MemoryStartupBytes = $VMRam
    Generation = 2
    Path = $VMPath
}

$VM = New-VM @VMParams 
# Undo:  Remove-VM $VMName; Remove-Item -Path $VMPath -Recurse -Force
<# inspect #> Get-VM


## Fix the Switche ##############################
##
# Remove the default created switch
Remove-VMNetworkAdapter -VMName $VMName -Name 'Network Adapter'
# Add the wanted switch for this VM
Add-VMNetworkAdapter -VMName $VMName -SwitchName $VMSwitch -name $VMSwitchName
# Undo: Remove-VMNetworkAdapter -VMName $VMName -VMNetworkAdapterName $VMSwitchName
<# inspect #> Get-VMNetworkAdapter -VMName $VMName


## Add a hard drive #############################
##
$VHD = New-VHD -Path $VHDpath -Dynamic -SizeBytes $vhdsize 
Add-VMHardDiskDrive -VMName $VMName -Path $VHDpath
# Undo: Remove-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -ControllerNumber 0 -ControllerLocation 0
<# inspect #> Get-VMHardDiskDrive -VMName $VMName


## Mount OS install iso #########################
##
# Create the DVD Drive
Add-VMDvdDrive -VMName $VMName -Path $OSiso
# Undo: See the Unmount OS install iso
<# inspect #> get-VMDvdDrive -VMName $VMName


## Disable SecureBoot ###########################
##
<# inspect #> Get-VMFirmware -VMName $VMName | select SecureBoot
# As this is a Centos build we have to disable secureboot
Set-VMFirmware $VMName -EnableSecureBoot Off
# Undo: Set-VMFirmware $VMName -EnableSecureBoot On
<# inspect #> Get-VMFirmware -VMName $VMName | select SecureBoot

## Boot Order ###################################
##
# https://vmlabblog.com/2018/08/how-to-change-vm-bootorder-with-powershell/
# On initial load this is not so much an issue as there is no OS anywhere. But, 
# if this is after your initial load, you'll want to force gogin to the iso first.
# I only want the Hard Drive and DVD, in that order.
# Assumptions: there is only one hard drive and one DVD at this point. Inspect to make sure.
$VMFirmware = Get-VMFirmware -VMName $VMName; $VMFirmware.BootOrder
$HardDrive = $null; $DVD = $null; $BootDevices = $VMFirmware.BootOrder
foreach ($BootDevice in $VMFirmware.BootOrder){
    Try {
        $BootDevice.Device.Name.ToString()
        if($BootDevice.Device.Name.ToString().Contains('Hard Drive')){$HardDrive=$BootDevice}
        if($BootDevice.Device.Name.ToString().Contains('DVD Drive')){$DVD=$BootDevice}
    } catch { $null }
}
Set-VMFirmware -VMName $VMName -BootOrder $HardDrive,$DVD
<# inspect #> $VMFirmware = Get-VMFirmware -VMName $VMName; $VMFirmware.BootOrder


## Start VM
#
Start-VM -Name $VMName
##
## Do in-OS stuff
# .\vmconnect.exe $VMName
# Setup
#    Pick one
#    Language
#    Partition
#    Root
#    Initial User
#       Begin Installation    
#    Licensing
#    Power off
##
<# if needed #> Stop-VM -Name $VMName -force

## Unmount OS install iso
##
# removes ISO from DVD drive
Get-VMDvdDrive -VMName $VMName | ? Path -eq $OSiso | Remove-VMDvdDrive 
# remove unneeded media emulation
Remove-VMDvdDrive -VMName $VMName -ControllerNumber 0 -ControllerLocation 1
<# inspect #> Get-VMDvdDrive -VMName $VMName

## Re-do Boot Order #############################
##
Set-VMFirmware -VMName $VMName -BootOrder $HardDrive
<# inspect #> $VMFirmware = Get-VMFirmware -VMName $VMName; $VMFirmware.BootOrder


## Create a checkpoint
$VMInitialSnapShot = $VMName + '-' + (Get-Date -Format "yyyyMMddHHmmss")
Checkpoint-VM -VMName $VMName -SnapshotName $VMInitialSnapShot
# Undo: Remove-VMSnapshot -VMName $VMName -Name $VMInitialSnapShot
<# inspect #> Get-VMCheckpoint -VMName $VMName


## Go have fun!   : )


<# eof #>