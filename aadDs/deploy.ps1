Import-Module Az.Resources 

New-AzDeployment -TemplateFile '.\main.bicep' `
    -Location "westeurope" `
    -domainName "aadds.omegamadlab.it"
