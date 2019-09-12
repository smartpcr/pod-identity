
function LoginAzureAsUser {
    param (
        [string] $SubscriptionName
    )

    $azAccount = az account show | ConvertFrom-Json
    if ($null -eq $azAccount -or $azAccount.name -ine $SubscriptionName) {
        az login | Out-Null
        az account set --subscription $SubscriptionName | Out-Null
    }
    elseif ($azAccount.user.type -eq "servicePrincipal") {
        az login | Out-Null
        az account set --subscription $SubscriptionName | Out-Null
    }

    $currentAccount = az account show | ConvertFrom-Json
    return $currentAccount
}

function LoginAsServicePrincipalUsingCert {
    param (
        [string] $VaultName,
        [string] $CertName,
        [string] $ServicePrincipalName,
        [string] $TenantId,
        [string] $ScriptFolder
    )

    $credentialFolder = Join-Path $ScriptFolder "credential"
    if (-not (Test-Path $credentialFolder)) {
        New-Item $credentialFolder -ItemType Directory -Force | Out-Null
    }
    $privateKeyFilePath = Join-Path $credentialFolder "$certName.key"
    if (-not (Test-Path $privateKeyFilePath)) {
        LoginAzureAsUser -SubscriptionName $bootstrapValues.global.subscriptionName | Out-Null
        DownloadCertFromKeyVault -VaultName $vaultName -CertName $certName -ScriptFolder $ScriptFolder
    }

    LogInfo -Message "Login as service principal '$ServicePrincipalName'"
    $azAccountFromSpn = az login --service-principal `
        -u "http://$ServicePrincipalName" `
        -p $privateKeyFilePath `
        --tenant $TenantId | ConvertFrom-Json
    return $azAccountFromSpn
}

function LoginAsServicePrincipalUsingPwd {
    param (
        [string] $VaultName,
        [string] $SecretName,
        [string] $ServicePrincipalName,
        [string] $TenantId
    )

    $clientSecret = az keyvault secret show --vault-name $VaultName --name $SecretName | ConvertFrom-Json
    $azAccountFromSpn = az login --service-principal `
        --username "http://$ServicePrincipalName" `
        --password $clientSecret.value `
        --tenant $TenantId | ConvertFrom-Json
    return $azAccountFromSpn
}

function TranslateToLinuxFilePath() {
    param(
        [string]$FilePath = "C:/work/github/container/bedrock-lab/scripts/temp/aamva/flux-deploy-key"
    )

    $isWindowsOs = ($PSVersionTable.PSVersion.Major -lt 6) -or ($PSVersionTable.Platform -eq "Win32NT")
    if ($isWindowsOs) {
        # this is for running inside WSL
        $FilePath = $FilePath.Replace("\", "/")
        $driveLetter = Split-Path $FilePath -Qualifier
        $driveLetter = $driveLetter.TrimEnd(':')
        return $FilePath.Replace("$($driveLetter):", "/mnt/$($driveLetter.ToLower())")
    }

    return $FilePath
}

function StipSpaces() {
    param(
        [ValidateSet("key", "pub")]
        [string]$FileType,
        [string]$FilePath
    )

    $fileContent = Get-Content $FilePath -Raw
    $fileContent = $fileContent.Replace("`r", "")
    if ($FileType -eq "key") {
        # 3 parts
        $parts = $fileContent.Split("`n")
        if ($parts.Count -gt 3) {
            $builder = New-Object System.Text.StringBuilder
            $lineNumber = 0
            $parts | ForEach-Object {
                if ($lineNumber -eq 0) {
                    $builder.AppendLine($_) | Out-Null
                }
                elseif ($lineNumber -eq $parts.Count - 1) {
                    $builder.Append("`n$_") | Out-Null
                }
                else {
                    $builder.Append($_) | Out-Null
                }
                $lineNumber++
            }
            $fileContent = $builder.ToString()
        }
    }

    $fileContent | Out-File $FilePath -Encoding ascii -Force
}

function New-CrcTable {
    [uint32]$c = $null
    $crcTable = New-Object 'System.Uint32[]' 256

    for ($n = 0; $n -lt 256; $n++) {
        $c = [uint32]$n
        for ($k = 0; $k -lt 8; $k++) {
            if ($c -band 1) {
                $c = (0xEDB88320 -bxor ($c -shr 1))
            }
            else {
                $c = ($c -shr 1)
            }
        }
        $crcTable[$n] = $c
    }

    Write-Output $crcTable
}

function Update-Crc ([uint32]$crc, [byte[]]$buffer, [int]$length, $crcTable) {
    [uint32]$c = $crc

    for ($n = 0; $n -lt $length; $n++) {
        $c = ($crcTable[($c -bxor $buffer[$n]) -band 0xFF]) -bxor ($c -shr 8)
    }

    Write-output $c
}

function Get-CRC32 {
    <#
        .SYNOPSIS
            Calculate CRC.
        .DESCRIPTION
            This function calculates the CRC of the input data using the CRC32 algorithm.
        .EXAMPLE
            Get-CRC32 $data
        .EXAMPLE
            $data | Get-CRC32
        .NOTES
            C to PowerShell conversion based on code in https://www.w3.org/TR/PNG/#D-CRCAppendix

            Author: Øyvind Kallstad
            Date: 06.02.2017
            Version: 1.0
        .INPUTS
            byte[]
        .OUTPUTS
            uint32
        .LINK
            https://communary.net/
        .LINK
            https://www.w3.org/TR/PNG/#D-CRCAppendix

    #>
    [CmdletBinding()]
    param (
        # Array of Bytes to use for CRC calculation
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [byte[]]$InputObject
    )

    $dataArray = @()
    $crcTable = New-CrcTable
    foreach ($item  in $InputObject) {
        $dataArray += $item
    }
    $inputLength = $dataArray.Length
    Write-Output ((Update-Crc -crc 0xffffffffL -buffer $dataArray -length $inputLength -crcTable $crcTable) -bxor 0xffffffffL)
}

function GetHash() {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$InputString
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hasCode = Get-CRC32 $bytes
    $hex = "{0:x}" -f $hasCode
    return $hex
}

function TryGetServicePrincipal() {
    param([string]$Name)

    [array]$spns = az ad sp list --display-name $Name | ConvertFrom-Json
    if ($null -eq $spns -or $spns.Count -eq 0) {
        return $null
    }
    elseif ($spns.Count -gt 1) {
        throw "Duplicated spn found with same name: $Name"
    }

    return $spns[0]
}

function TryGetAadApp() {
    param([string]$Name)

    [array]$apps = az ad app list --display-name $Name | ConvertFrom-Json
    if ($null -eq $apps -or $apps.Count -eq 0) {
        return $null
    }
    elseif ($apps.Count -gt 1) {
        throw "Duplicated app found with same name: $Name"
    }

    return $apps[0]
}