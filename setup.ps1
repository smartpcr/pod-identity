# assumes you are already logged in to azure 
$defaultResourceGroupName = "azds-dev-rg"
$aksClusterName = "rrdu-azds-k8s-dev"
$location = "westus2"
$vaultName = "rrdu-kv"
$azAccount = az account show | ConvertFrom-Json
$mcResourceGroupName = "MC_$($defaultResourceGroupName)_$($aksClusterName)_$($location)"
$serviceName = "demo"

$msisFound = az identity list --resource-group $defaultResourceGroupName --query "[?name=='$serviceName']" | ConvertFrom-Json
if (!$msisFound -or ([array]$msisFound).Length -eq 0) {
    az identity create --name $serviceName --resource-group $mcResourceGroupName | Out-Null
}
$serviceIdentity = az identity show --resource-group $defaultResourceGroupName --name $serviceName | ConvertFrom-Json

Write-Host "Grating read access to aks resource group '$($mcResourceGroupName)'..." -ForegroundColor Yellow
$mcRG = az group show --name $mcResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $mcRG.id | Out-Null 

Write-Host "Granting read access to key vault '$vaultName'..." -ForegroundColor Yellow
$kv = az keyvault show --resource-group $defaultResourceGroupName --name $vaultName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $kv.id | Out-Null

