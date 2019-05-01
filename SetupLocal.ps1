
$secretFolder = Join-Path $env:HOME ".secrets"
if (-not (Test-Path $secretFolder)) {
    New-Item -Path $secretFolder -ItemType Directory -Force | Out-Null
}
$pfxCertFile = Join-Path $secretFolder "$appSpnCertName.pfx"
$pemCertFile = Join-Path $secretFolder "$appSpnCertName.pem"
$keyCertFile = Join-Path $secretFolder "$appSpnCertName.key"

Write-Host "Downloading cert '$appSpnCertName' from keyvault '$vaultName' and convert it to private key" 
az keyvault secret download --vault-name $vaultName -n $appSpnCertName -e base64 -f $pfxCertFile
openssl pkcs12 -in $pfxCertFile -clcerts -nodes -out $keyCertFile -passin pass:
openssl rsa -in $keyCertFile -out $pemCertFile

$aksSpn = az ad sp list --display-name $aksSpnName | ConvertFrom-Json
$appSpnName = "rrdu-azds-dev-xd-wus2-spn"
$appSpn = az ad sp list --display-name $appSpnName | ConvertFrom-Json
$appSpnCertName = "rrdu-azds-dev-xd-wus2-spn"


