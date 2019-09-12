
$gitRootFolder = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
while (-not (Test-Path (Join-Path $gitRootFolder ".git"))) {
    $gitRootFolder = Split-Path $gitRootFolder -Parent
}
$moduleFolder = Join-Path $gitRootFolder "modules"
Import-Module (Join-Path $moduleFolder "Logging.psm1") -Force
Import-Module (Join-Path $moduleFolder "Common.psm1") -Force
Import-Module (Join-Path $moduleFolder "YamlUtil.psm1") -Force
$k8sFolder = Join-Path $gitRootFolder "k8s"
if (-not (Test-Path $k8sFolder)) {
    New-Item $k8sFolder -ItemType Directory -Force | Out-Null
}

# assumes you are already logged in to azure
$defaultResourceGroupName = "sace-dev-rg"
$dataResourceGroupName = "sace-dev-data-rg"
$aksClusterName = "sacedev"
$location = "westus2"
$vaultName = "sace-dev-kv"
$azAccount = az account show | ConvertFrom-Json
$mcResourceGroupName = "MC_$($defaultResourceGroupName)_$($aksClusterName)_$($location)"
$serviceName = "demo"

$acrName = "sacedevacr"
$acr = az acr show -n $acrName | ConvertFrom-Json
$acrPassword = "$(az acr credential show -n $acrName --query ""passwords[0].value"")"
$acrOwnerEmail = "xiaodoli@microsoft.com"
$acrLoginServer = $acr.loginServer
$serviceImageName = "test/$($serviceName)"
$serviceImageTag = "latest"
$aksSpnAppId = "2e4c24df-5f5c-459d-9c01-beaf48af53e8"
$aksSpn = az ad sp show --id $aksSpnAppId | ConvertFrom-Json

$domainName = "sace.works"
$sslCert = "sslcert-sace-works"
# $appSpnName = "onees-space-dev-xiaodong-wus2-spn"
# $appSpn = az ad sp list --display-name $appSpnName | ConvertFrom-Json

# Write-Host "0. Deploy aad-pod-identity infra.."
# kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml


$identityName = "sace-dev-kv-reader"
Write-Host "1. Creating managed service identity '$identityName'..." -ForegroundColor White
$msisFound = az identity list --resource-group $defaultResourceGroupName --query "[?name=='$identityName']" | ConvertFrom-Json
if (!$msisFound -or ([array]$msisFound).Length -eq 0) {
    Write-Host "Creating service identity '$identityName'..."
    az identity create --name $identityName --resource-group $defaultResourceGroupName | Out-Null
}
else {
    Write-Host "Service identity '$identityName' is already created."
}
$serviceIdentity = az identity show --resource-group $defaultResourceGroupName --name $identityName | ConvertFrom-Json


Write-Host "Granting read access to aks resource group '$($mcResourceGroupName)'..." -ForegroundColor Yellow
$mcRG = az group show --name $mcResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $mcRG.id | Out-Null

Write-Host "Granting read access to aks resource group '$($defaultResourceGroupName)'..." -ForegroundColor Yellow
$rg = az group show --name $defaultResourceGroupName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $rg.id | Out-Null

Write-Host "Granting read access to key vault '$vaultName'..." -ForegroundColor Yellow
$kv = az keyvault show --name $vaultName | ConvertFrom-Json
az role assignment create --role Reader --assignee $serviceIdentity.principalId --scope $kv.id | Out-Null

Write-Host "Granting access policy for key vault '$vaultName'..." -ForegroundColor Yellow
az keyvault set-policy -n $vaultName --secret-permissions get list --spn $serviceIdentity.clientId | Out-Null
az keyvault set-policy -n $vaultName --certificate-permissions get list --spn $serviceIdentity.clientId | Out-Null

Write-Host "Granting aks spn access to managed identity..."
az role assignment create --role "Managed Identity Operator" --assignee $aksSpn.appId --scope $serviceIdentity.id | Out-Null

# Write-Host "2. Setup ACR connection as secret in AKS..."
# kubectl create secret docker-registry acr-auth `
#     --docker-server $acrLoginServer `
#     --docker-username $acrName `
#     --docker-password $acrPassword `
#     --docker-email $acrOwnerEmail


# Write-Host "3. Deploy ca cert"

# $sslCertSecret = az keyvault secret show --name "sslcert-dev-xiaodong-world" --vault-name "xiaodong-kv" | ConvertFrom-Json
# $secretYaml = $sslCertSecret.value | ConvertFrom-Yaml
# $caCrtFile = Join-Path $gitRootFolder "ca.crt"
# [System.IO.File]::WriteAllText($caCrtFile, $secretYaml.data["ca.crt"])
# $tlsCrtFile = Join-Path $gitRootFolder "tls.crt"
# [System.IO.File]::WriteAllText($tlsCrtFile, $secretYaml.data["tls.crt"])
# $tlsKeyFile = Join-Path $gitRootFolder "tls.key"
# [System.IO.File]::WriteAllText($tlsKeyFile, $secretYaml.data["tls.key"])

# kubectl delete configmap ca-pemstore
# kubectl create configmap ca-pemstore --from-file=ca.crt=$caCrtFile --from-file=tls.crt=$tlsCrtFile --from-file=tls.key=$tlsKeyFile


Write-Host "3. Build docker image and push to acr..." -ForegroundColor White

$srcFolder = Join-Path $gitRootFolder "src"
$serviceProjFolder = Join-Path $srcFolder "demo-api"
& "$srcFolder\setup.ps1" `
    -serviceImageName $serviceImageName `
    -serviceImageTag $serviceImageTag `
    -serviceProjFolder $serviceProjFolder `
    -defaultResourceGroupName $defaultResourceGroupName

Write-Host "4. Deploy service '$serviceName'..." -ForegroundColor White

$settings = @{
    global          = @{
        envName        = "dev"
        subscriptionId = $azAccount.id
    }
    acr             = @{
        name = $acrName
    }
    dns             = @{
        domain  = $domainName
        sslCert = $sslCert
    }
    identity        = @{
        name        = $identityName
        id          = $serviceIdentity.id
        clientId    = $serviceIdentity.clientId
        principalId = $serviceIdentity.principalId
    }
    service         = @{
        name      = $serviceName
        label     = $serviceName
        namespace = "default"
        image     = @{
            name = $serviceImageName
            tag  = $serviceImageTag
        }
    }
    serviceIdentity = @{
        clientId      = $serviceIdentity.clientId
        objectId      = $serviceIdentity.principalId
        resourceGroup = $mcResourceGroupName
        id            = $serviceIdentity.id
    }
    aksSpn          = @{
        appId = $aksSpn.appId
    }
    # appSpn          = @{
    #     appId    = $appSpn.appId
    #     certFile = $appSpnCertFile
    # }
}

$templatesFolder = Join-Path $gitRootFolder "templates"
$deployTemplateFile = Join-Path $templatesFolder "deployment.tpl"
$deploymentContent = Get-Content $deployTemplateFile -Raw
$deploymentContent = Set-YamlValues -ValueTemplate $deploymentContent -Settings $settings
$deploymentYamlFile = Join-Path $k8sFolder "deployment.yaml"
$deploymentContent | Out-File $deploymentYamlFile -Force -Encoding UTF8 | Out-Null

kubectl apply -f $deploymentYamlFile


Write-Host "8. Granting permission to read config map in its own namespace..."
$configReaderTemplateFile = Join-Path $templatesFolder "ConfigReader.tpl"
$configReaderContent = Get-Content $configReaderTemplateFile -Raw
$configReaderContent = Set-YamlValues -ValueTemplate $configReaderContent -Settings $settings
$configReaderYamlFile = Join-Path $k8sFolder "ConfigReaderRole.yaml"
$configReaderContent | Out-File $configReaderYamlFile -Encoding UTF8 -Force | Out-Null
kubectl apply -f $configReaderYamlFile

$roleBindingTemplateFile = Join-Path $templatesFolder "ConfigReaderRoleBinding.tpl"
$roleBindingContent = Get-Content $roleBindingTemplateFile -Raw
$roleBindingContent = Set-YamlValues -ValueTemplate $roleBindingContent -Settings $settings
$roleBindingYamlFile = Join-Path $k8sFolder "ConfigReaderRoleBinding.yaml"
$roleBindingContent | Out-File $roleBindingYamlFile -Encoding UTF8 -Force | Out-Null
kubectl apply -f $roleBindingYamlFile

Write-Host "5. Deploy pod identity..." -ForegroundColor White
$podIdentityTempFile = Join-Path $templatesFolder "AadPodIdentity.tpl"
$podIdentityContent = Get-Content $podIdentityTempFile -Raw
$podIdentityContent = Set-YamlValues -ValueTemplate $podIdentityContent -Settings $settings
$podIdentityYamlFile = Join-Path $k8sFolder "AadPodIdentity.yaml"
$podIdentityContent | Out-File $podIdentityYamlFile -Encoding UTF8 -Force | Out-Null
kubectl apply -f $podIdentityYamlFile

Write-Host "6. Deploy pod identity binding..." -ForegroundColor White
$identityBindingTemplateFile = Join-Path $templatesFolder "AadPodIdentityBinding.tpl"
$identityBindingContent = Get-Content $identityBindingTemplateFile -Raw
$identityBindingContent = Set-YamlValues -ValueTemplate $identityBindingContent -Settings $settings
$identityBindingYamlFile = Join-Path $k8sFolder "AadPodIdentityBinding.yaml"
$identityBindingContent | Out-File $identityBindingYamlFile -Encoding UTF8 -Force | Out-Null
kubectl apply -f $identityBindingYamlFile

# Write-Host "7. Deploy service and expose api endpoint..."
# $serviceTemplateFile = Join-Path $templatesFolder "Service.tpl"
# $serviceContent = Get-Content $serviceTemplateFile -Raw
# $serviceContent = $serviceContent.Replace("{{.Values.service.name}}", $settings.service.name)
# $serviceContent = $serviceContent.Replace("{{.Values.service.label}}", $settings.service.label)
# $serviceYamlFile = Join-Path $k8sFolder "Service.yaml"
# $serviceContent | Out-File $serviceYamlFile -Encoding UTF8 -Force | Out-Null
# kubectl apply -f $serviceYamlFile
