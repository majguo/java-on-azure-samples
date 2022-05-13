param (
    [parameter(Mandatory = $false)]
    [Object] $RecoveryPlanContext
)

$trafficMgrRG = "<your prefix>-demo-traffic-manager"
$profileName = "<your prefix>-demo"
$secondaryEndpointName = "gw-westus"

# Connect to Azure with system-assigned managed identity (automation account)
Connect-AzAccount -Identity

$startTime = $(get-date)
Write-Output("${startTime}: Starting to execute the post action after failing over managed servers......")

# Wait until the secondary endpoint of the Azure Traffic Manager is online
while ($true)
{
	$endpointState = (Get-AzTrafficManagerEndpoint -Name $secondaryEndpointName -ProfileName $profileName -ResourceGroupName $trafficMgrRG -Type AzureEndpoints).EndpointMonitorStatus
	Write-Output("$(get-date): ${secondaryEndpointName} is in '${endpointState}' state.")
	if ($endpointState -eq "Online") {
		break
	} else {
		Start-Sleep -s 5
	}
}

$endTime = $(get-date)
Write-Output("${endTime}: Completed the post action after failing over managed servers.")
$elapsedTime = $endTime - $StartTime
$totalTime = "{0:HH:mm:ss}" -f ([datetime]$elapsedTime.Ticks)
Write-Output("The time for completing the post action after failing over managed servers is about ${totalTime}")
