param(
    [string] $serviceImageName,
    [string] $serviceImageTag,
    [string] $serviceProjFolder,
    [string] $defaultResourceGroupName
)

$acrName = "sacedevacr"
$acr = az acr show -n $acrName | ConvertFrom-Json
$acrLoginServer = $acr.loginServer
$imageName = "$($acrLoginServer)/$($serviceImageName)"
$imagetag = "latest"
docker build $serviceProjFolder -t "$($imageName):$($serviceImageTag)"

az acr login -n $acrName
docker push "$($imageName):$($imageTag)"