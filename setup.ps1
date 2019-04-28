# assumes you are already logged in to azure 
$defaultResourceGroupName = "azds-dev-rg"
$aksClusterName = "rrdu-azds-k8s-dev"
$location = "westus2"
$azAccount = az account show | ConvertFrom-Json

$mcResourceGroupName = "MC_$($defaultResourceGroupName)_$($aksClusterName)_$($location)"
$serviceName = "demo"
az identity create --name $serviceName --resource-group $mcResourceGroupName | Out-Null
$serviceIdentity = az identity show --resource-group $mcResourceGroupName --name $serviceName | ConvertFrom-Json
$mcRG = az group show --name $mcResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $mcRG.id | Out-Null 
