###################################################################################################################################################################
#Title: Cross-vCenter-Migration.ps1
#Description: Script takes a list of VMs and migrates them between vCenters. Creates log file showing sucessfull and failed migrations.
#Requirements: vCenter version 6 or higher; VMs with up to 4 Network adapters; same VDS version or change advance settings to ignore VDS chek on destination vCenter
#Author: Piotr Pitera
#Date: 10-06-2020
#Version: 1.0
###################################################################################################################################################################

#Import VMware modules
Import-Module VMware.VimAutomation.Vds

# Set basic variables for source and destination
$sourceVC = "sourcevcentermae.com"
$destVC = "destinationvcentername.com"
$destCluster = "Destination_Cluster_Name"
$datastoreCluster = "Destination_DatastoreCluster_Name"

$Credentials = Get-Credential -Credential $null
$vcUser = $Credentials.UserName
$vcPassword = $Credentials.GetNetworkCredential().password

#Make sure you are not connected to any other vCenters before connecting
    if ($global:DefaultVIServers.Count -gt 0) {
	    Disconnect-VIServer -Server * -Force -confirm: $false
		Write-Host "Previous connections have been disconnected" -foregroundcolor DarkCyan
        }

#Connection to both vCenters
$sourceVCConn = Connect-VIServer -Server $sourceVC -User $vcUser -Password $vcPassword 
$destVCConn = Connect-VIServer -Server $destVC -User $vcUser -Password $vcPassword 

#Configure source file for VM names anad log file destination
$filedir = Get-Location
$VMs_File = "$filedir\VM1.txt"
$Logfile = "$filedir\Log1_($destCluster)_$(get-date -f yyyy-MM-dd_HH-mm).log"

Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}

#Provide source portgroup names on the left and destination portgroup names on the right
$port_groups =@{ 
		'source_vLan_name_001' = 'destination_vLan_name_001'
		'source_vLan_name_002' = 'destination_vLan_name_002'
		'source_vLan_name_003' = 'destination_vLan_name_003'
		'source_vLan_name_004' = 'destination_vLan_name_004'
		'source_vLan_name_005' = 'destination_vLan_name_005'
	}

## get the VM server names from the txt file
Get-Content $VMs_File | 
        
        foreach {
            $vmname = $_; Write-Verbose -Verbose "Working on Virtual Machine: $vmname"
            
			# Confirmation that the VM name is present on the source vCenter
$vm = Get-VM $vmname -Server $sourceVCConn 
If ($vm.count -eq 1)
	{ 
	
	Write-host "VM: $vm found on the source vCenter $sourceVC script will continue" -foregroundcolor green
	
	}
Else { 
		Write-host "VM: $vm not Found, Script will terminate..." -foregroundcolor magenta
	    exit 1
	}
	
# Get Network Adapter and Port Group Name
$networkAdapter = Get-NetworkAdapter -VM $vm -Server $sourceVCConn
If ($networkAdapter.count -eq 1)
	{
		$portgroupName1 = $networkAdapter.NetworkName | Select-Object -first 1
		$destinationPortGroup = Get-VDPortgroup -Name $port_groups.$portgroupName1 
		$destinationPortGroup | Format-Table -AutoSize 
		Write-host 'One network adapter found on the VM '$vm' script will continue' -foregroundcolor 'green'
	}
ElseIf ($networkAdapter.count -eq 2)
	{
		$portgroupName1 = $networkAdapter.NetworkName[0] 
		$portgroupName2 = $networkAdapter.NetworkName[1] 
		$destinationPortGroup = @()
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName1 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName2 
		$destinationPortGroup | Format-Table -AutoSize 
		Write-host 'Two network adapters found on the VM '$vm' script will continue' -foregroundcolor 'green'
	}
ElseIf ($networkAdapter.count -eq 3)
	{
		$portgroupName1 = $networkAdapter.NetworkName[0] 
		$portgroupName2 = $networkAdapter.NetworkName[1] 
		$portgroupName3 = $networkAdapter.NetworkName[2]
		$destinationPortGroup = @()
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName1 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName2 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName3 
		$destinationPortGroup | Format-Table -AutoSize 
		Write-host 'Three network adapters found on the VM '$vm' script will continue' -foregroundcolor 'green'
	}
ElseIf ($networkAdapter.count -eq 4)
	{
		$portgroupName1 = $networkAdapter.NetworkName[0] 
		$portgroupName2 = $networkAdapter.NetworkName[1] 
		$portgroupName3 = $networkAdapter.NetworkName[2]
		$portgroupName4 = $networkAdapter.NetworkName[3]
		$destinationPortGroup = @()
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName1 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName2 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName3 
		$destinationPortGroup += Get-VDPortgroup -Name $port_groups.$portgroupName4 
		$destinationPortGroup | Format-Table -AutoSize 
		Write-host 'Four network adapters found on the VM '$vm' script will continue' -foregroundcolor 'green'
	}
Else 
	{
		Write-host 'Check number of network adapters' -foregroundcolor 'magenta'
		exit 1
	}

#Selects 2nd host with lowest memory usage in the destination cluster
$destination = Get-Cluster -Name $destCluster -Server $destVCConn | Get-VMHost -State Connected | Sort-Object MemoryUsageGB | Select-Object -Skip 1 | Select-Object -First 1
$destination | Format-Table -AutoSize

#Selects 2nd datastore with most space available in selected destination datastore cluster
$destinationDatastore = Get-DatastoreCluster –Name $datastoreCluster –Server $destVCConn | Get-Datastore | Sort-Object -Property FreeSpaceGB -Descending | Select-Object -Skip 1 | Select-Object -First 1
$destinationDatastore | Format-Table -AutoSize 

#Displays destination portgroups for VM
$destinationPortGroup | Format-Table -AutoSize 

#Starts VM migration
Move-VM -VM $vm -Destination $destination -NetworkAdapter $networkAdapter -PortGroup $destinationPortGroup -Datastore $destinationDatastore
if($?) {
	# migration was sucesfull
	LogWrite "VM: $vm, migration was sucesfull to cluster: $destCluster, host: $destination, datastore: $destinationDatastore"
}

if (!$?) {
	# migration failed
	LogWrite "VM: $vm, migration has failed"
}

            } 

Disconnect-VIServer * -Confirm:$false 
