param (
    [Parameter(Mandatory)]
    [String]
    $EnvTagValue,

    [Parameter(Mandatory)]
    [ValidateSet('start', 'stop')]
    $Action = 'stop'
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

$vmList = Get-AzResource -Tag @{'environment' = $EnvTagValue} -ResourceType Microsoft.Compute/virtualMachines | Get-AzVM

if ($Action -eq 'stop') {
    $vmList | ForEach-Object -Parallel { $_ | Stop-AzVm -Force }
} else {
    $vmList | ForEach-Object -Parallel { $_ | Start-AzVm  }
}