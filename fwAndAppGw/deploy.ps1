Import-Module Az.Resources 

New-AzDeployment -TemplateFile '.\main.bicep' `
    -Location "westeurope" `
    -adminUsername "omegamadlab" `
    -adminPassword (Read-Host "password" -AsSecureString) `
    -LocationFromTemplate "westeurope" `
    -jumpBoxPublicIp '52.174.56.84'
