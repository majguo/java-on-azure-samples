param (
	[parameter(Mandatory = $false)]
	[Object] $RecoveryPlanContext
)

$secondaryPostgreSQLServerRG = "<your prefix>-demo-postgres"
$secondaryPostgreSQLServerName = "<your prefix>-demo-westus"
$secondaryWLSClusterRG = "<your prefix>-demo-wls-cluster-westus"
$secondaryVNetName = "wlsd_VNET"
$secondaryVNetSubnetName = "Subnet"
$secondaryAdminVMNicName = "adminVM_NIC"
$secondaryAdminVMPublicIPName = "adminVM_PublicIP"
$secondaryAdminVMNicIPConfigName = "ipconfig1"
$secondaryAdminConsoleURI = "<secondary-admin-console-uir>"

# Connect to Azure with system-assigned managed identity (automation account)
Connect-AzAccount -Identity

$startTime = $(get-date)
Write-Output("${startTime}: Starting to executing the post action after failing over the admin server...")

# Assign pubic ip address to the secondary admin server
Write-Output("$(get-date): Starting to assign the public IP address to the NIC of secondary VM...")
$vnet = Get-AzVirtualNetwork -Name $secondaryVNetName -ResourceGroupName $secondaryWLSClusterRG
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $secondaryVNetSubnetName -VirtualNetwork $vnet
$nic = Get-AzNetworkInterface -Name $secondaryAdminVMNicName -ResourceGroupName $secondaryWLSClusterRG
$pip = Get-AzPublicIpAddress -Name $secondaryAdminVMPublicIPName -ResourceGroupName $secondaryWLSClusterRG
$privateIp = (Get-AzNetworkInterfaceIpConfig -Name $secondaryAdminVMNicIPConfigName -NetworkInterface $nic).PrivateIpAddress
$nic | Set-AzNetworkInterfaceIpConfig -Name $secondaryAdminVMNicIPConfigName -PublicIPAddress $pip -PrivateIpAddress $privateIp -Subnet $subnet
$nic | Set-AzNetworkInterface
Write-Output("$(get-date): Completed to assign the public IP address to the NIC of secondary VM.")

# Promote the replica to a standalone PostgreSQL server
Write-Output("$(get-date): Starting to promote the replica ${secondaryPostgreSQLServerName} to a standalone PostgreSQL server...")
Update-AzPostgreSqlServer -ResourceGroupName $secondaryPostgreSQLServerRG -Name $secondaryPostgreSQLServerName -ReplicationRole None
Write-Output("$(get-date): Completed to promote the replica ${secondaryPostgreSQLServerName} to a standalone PostgreSQL server.")

# Wait until admin console is accessible
while ($true)
{
	try {
		$statusCode = (Invoke-WebRequest -URI $secondaryAdminConsoleURI -UseBasicParsing).StatusCode
		if ($statusCode -eq 200) {
			Write-Output("$(get-date): Successfully connect to ${secondaryAdminConsoleURI}.")
			break
		} else {
			Write-Output("$(get-date): Unexpected response status code ${statusCode} received from ${secondaryAdminConsoleURI}.")
			Start-Sleep -s 5
		}
	} catch {
		Write-Output("$(get-date): Unable to connect to ${secondaryAdminConsoleURI}.")
		Start-Sleep -s 5
	}
}

$endTime = $(get-date)
Write-Output("${endTime}: Completed the post action after failing over the admin server.")
$elapsedTime = $endTime - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
Write-Output("The time for completing the post action after failing over the admin server is about ${totalTime}")
