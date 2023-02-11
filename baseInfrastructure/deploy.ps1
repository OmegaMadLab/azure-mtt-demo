$rgName = 'CORE-RESOURCES-RG'
$location = 'westeurope'

$rg = Get-AzResourceGroup -Name $rgName -Location $location -ErrorAction SilentlyContinue
if (-not $rg) {
    $rg = New-AzResourceGroup -Name $rgName -Location $location
} 

$baseInfradeployment = New-AzResourceGroupDeployment -Name "BaseInfra" `
                            -ResourceGroupName $rg.ResourceGroupName `
                            -TemplateFile .\main.bicep `
                            -adminUsername "omegamadlab" `
                            -domainName "demo.omegamadlab.it"