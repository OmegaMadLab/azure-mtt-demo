param (
    [Parameter(Mandatory)]
    [String]
    $EnvTagValue,

    [Parameter()]
    [ValidateSet("0","1","2","3","4","5")]
    $CourseDay = "0"
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# Set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

$vmList = Get-AzResource -Tag @{'environment' = $EnvTagValue} -ResourceType Microsoft.Compute/virtualMachines | Get-AzVM

Write-Output "VMs with $EnvTagValue tag:"
Write-Output ($vmList | Select-Object Name)

$vmList | ForEach-Object -Parallel { $_ | Start-AzVm  }

switch ($courseDay.toString()) {
    "1" { Write-Output "Day1"  }
    "2" { Write-Output "Day2"  }
    "3" { Write-Output "Day3"  }
    "4" { Write-Output "Day4"  }
    "5" { Write-Output "Day5"  }
    Default { Write-Output "Day not specified"}
}
