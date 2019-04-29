
# assumes you are already logged in to azure 
$defaultResourceGroupName = "azds-dev-rg"
$aksClusterName = "rrdu-azds-k8s-dev"
$location = "westus2"
$vaultName = "rrdu-kv"
$azAccount = az account show | ConvertFrom-Json
$mcResourceGroupName = "MC_$($defaultResourceGroupName)_$($aksClusterName)_$($location)"
$serviceName = "demo"

$acrName = "rrdudevacr"
$acr = az acr show -g $defaultResourceGroupName -n $acrName | ConvertFrom-Json
$acrPassword = "$(az acr credential show -n $acrName --query ""passwords[0].value"")"
$acrOwnerEmail = "lingxd@gmail.com"
$acrLoginServer = $acr.loginServer
$serviceImageName = "test/$($serviceName)"
$serviceImageTag = "latest"
$fullImageName = "$($acrLoginServer)/$($serviceImageName)"
$aksSpnName = "rrdu-azds-dev-xd-k8s-spn"
$aksSpn = az ad sp list --display-name $aksSpnName | ConvertFrom-Json

Write-Host "1. Creating managed service identity '$serviceName'..." -ForegroundColor White 
$msisFound = az identity list --resource-group $mcResourceGroupName --query "[?name=='$serviceName']" | ConvertFrom-Json
if (!$msisFound -or ([array]$msisFound).Length -eq 0) {
    Write-Host "Creating service identity '$serviceName'..."
    az identity create --name $serviceName --resource-group $mcResourceGroupName | Out-Null
}
else {
    Write-Host "Service identity '$serviceName' is already created."
}
$serviceIdentity = az identity show --resource-group $mcResourceGroupName --name $serviceName | ConvertFrom-Json

$settings = @{
    subscriptionId  = $azAccount.id
    service         = @{
        name      = $serviceName
        label     = $serviceName
        namespace = "default"
        image     = @{
            name = $fullImageName
            tag  = $serviceImageTag
        }
    }
    serviceIdentity = @{
        clientId      = $serviceIdentity.clientId
        resourceGroup = $mcResourceGroupName
        id            = $serviceIdentity.id 
    }
    aksSpn = @{
        appId = $aksSpn.appId
    }
}

Write-Host "Granting read access to aks resource group '$($mcResourceGroupName)'..." -ForegroundColor Yellow
$mcRG = az group show --name $mcResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $mcRG.id | Out-Null 

Write-Host "Grating read access to aks resource group '$($defaultResourceGroupName)'..." -ForegroundColor Yellow
$rg = az group show --name $defaultResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $rg.id | Out-Null 

Write-Host "Granting read access to key vault '$vaultName'..." -ForegroundColor Yellow
$kv = az keyvault show --resource-group $defaultResourceGroupName --name $vaultName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $kv.id | Out-Null
az keyvault set-policy -n $vaultName --secret-permissions get list --spn $serviceIdentity.clientId | Out-Null

Write-Host "Granting aks spn access to managed identity..."
az role assignment create --role "Managed Identity Operator" --assignee $aksSpn.appId --scope $serviceIdentity.id | Out-Null

Write-Host "2. Setup ACR connection as secret in AKS..."
kubectl create secret docker-registry acr-auth `
    --docker-server $acrLoginServer `
    --docker-username $acrName `
    --docker-password $acrPassword `
    --docker-email $acrOwnerEmail

Write-Host "3. Build docker image and push to acr..." -ForegroundColor White
$gitRootFolder = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
while (-not (Test-Path (Join-Path $gitRootFolder ".git"))) {
    $gitRootFolder = Split-Path $gitRootFolder -Parent 
}
$srcFolder = Join-Path $gitRootFolder "src"
$serviceProjFolder = Join-Path $srcFolder "demo-api"
& "$srcFolder\setup.ps1" -serviceImageName $serviceImageName -serviceImageTag $serviceImageTag -serviceProjFolder $serviceProjFolder

Write-Host "4. Deploy service '$serviceName'..." -ForegroundColor White
$templatesFolder = Join-Path $gitRootFolder "templates"
$deployTemplateFile = Join-Path $templatesFolder "deployment.tpl"
$deploymentContent = Get-Content $deployTemplateFile -Raw 
$deploymentContent = $deploymentContent.Replace("{{.Values.subscriptionId}}", $settings.subscriptionId)
$deploymentContent = $deploymentContent.Replace("{{.Values.service.namespace}}", $settings.service.namespace)
$deploymentContent = $deploymentContent.Replace("{{.Values.service.name}}", $settings.service.name)
$deploymentContent = $deploymentContent.Replace("{{.Values.service.label}}", $settings.service.label)
$deploymentContent = $deploymentContent.Replace("{{.Values.service.image.name}}", $settings.service.image.name)
$deploymentContent = $deploymentContent.Replace("{{.Values.service.image.tag}}", $settings.service.image.tag)
$deploymentContent = $deploymentContent.Replace("{{.Values.serviceIdentity.clientId}}", $settings.serviceIdentity.clientId)
$deploymentContent = $deploymentContent.Replace("{{.Values.serviceIdentity.resourceGroup}}", $settings.serviceIdentity.resourceGroup)
$deploymentYamlFile = Join-Path $gitRootFolder "deployment.yaml"
$deploymentContent | Out-File $deploymentYamlFile -Force | Out-Null
kubectl apply -f $deploymentYamlFile

Write-Host "5. Deploy pod identity..." -ForegroundColor White 
$podIdentityTempFile = Join-Path $templatesFolder "AadPodIdentity.tpl"
$podIdentityContent = Get-Content $podIdentityTempFile -Raw 
$podIdentityContent = $podIdentityContent.Replace("{{.Values.service.name}}", $settings.service.name)
$podIdentityContent = $podIdentityContent.Replace("{{.Values.serviceIdentity.id}}", $settings.serviceIdentity.id)
$podIdentityContent = $podIdentityContent.Replace("{{.Values.serviceIdentity.clientId}}", $settings.serviceIdentity.clientId)
$podIdentityYamlFile = Join-Path $gitRootFolder "AadPodIdentity.yaml"
$podIdentityContent | Out-File $podIdentityYamlFile -Force 
kubectl apply -f $podIdentityYamlFile 

Write-Host "6. Deploy pod identity binding..." -ForegroundColor White 
$identityBindingTemplateFile = Join-Path $templatesFolder "AadPodIdentityBinding.tpl"
$identityBindingContent = Get-Content $identityBindingTemplateFile -Raw 
$identityBindingContent = $identityBindingContent.Replace("{{.Values.service.name}}", $settings.service.name)
$identityBindingContent = $identityBindingContent.Replace("{{.Values.service.label}}", $settings.service.label)
$identityBindingYamlFile = Join-Path $gitRootFolder "AadPodIdentityBinding.yaml"
$identityBindingContent | Out-File $identityBindingYamlFile -Force 
kubectl apply -f $identityBindingYamlFile 

Write-Host "7. Deploy service and expose api endpoint..."
$serviceTemplateFile = Join-Path $templatesFolder "Service.tpl"
$serviceContent = Get-Content $serviceTemplateFile -Raw 
$serviceContent = $serviceContent.Replace("{{.Values.service.name}}", $settings.service.name)
$serviceContent = $serviceContent.Replace("{{.Values.service.label}}", $settings.service.label)
$serviceYamlFile = Join-Path $gitRootFolder "Service.yaml"
$serviceContent | Out-File $serviceYamlFile -Force 
kubectl apply -f $serviceYamlFile 