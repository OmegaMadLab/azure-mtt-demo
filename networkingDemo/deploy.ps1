Import-Module Az.Resources 

New-AzDeployment -TemplateFile '.\main.bicep' `
    -Location "westeurope" `
    -adminUsername "omegamadlab" `
    -adminPassword (Read-Host "password" -AsSecureString) `
    -namePrefix "SPOKE"
