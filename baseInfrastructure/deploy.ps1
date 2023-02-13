$rgName = 'CORE-RESOURCES-RG'
$location = 'westeurope'

$rg = Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction SilentlyContinue
if (-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
} 

# Deploy base infrastracture
$baseInfraDeployment = New-AzResourceGroupDeployment -Name "BaseInfra" `
                            -ResourceGroupName $rg.ResourceGroupName `
                            -TemplateFile .\main.bicep `
                            -adminUsername "omegamadlab" `
                            -domainName "demo.omegamadlab.it"

# Resize the DC and its OS disk
$dcVm = Get-AzVm -ResourceId $baseInfraDeployment.Outputs.vmDcId
$dcVm.HardwareProfile.VmSize = "Standard_B2s"
$dcVm.StorageProfile.OsDisk.ManagedDisk.StorageAccountType = "StandardSSD_LRS"
$dcVm | Update-AzVM

# Deploy Bastion to complete the deployment
$pip = New-AzPublicIpAddress -Name "CORE-BASTION-PIP" `
            -ResourceGroupName $rg.ResourceGroupName `
            -Location $location `
            -Sku Standard `
            -AllocationMethod Static

New-AzBastion -ResourceGroupName $rg.ResourceGroupName `
    -Name "CORE-BASTION" `
    -PublicIpAddressId $pip.Id `
    -VirtualNetworkResourceId $baseInfraDeployment.Outputs.vnetId.Value `
    -Sku "Basic"

# Deploy an ACR and create a demo image
$acrName = "omegamadlabacrdemo"
az acr create --resource-group $rg.ResourceGroupName --name $acrName --sku Basic

az acr build --registry $acrName --image helloacrtasks:v1 .\dockerFiles\helloWorld
az acr repository list --name $acrName --output table