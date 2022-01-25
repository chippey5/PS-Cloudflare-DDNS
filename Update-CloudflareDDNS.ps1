#Requires -Version 7.1
#Requires -Modules Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore

[cmdletbinding()]
param (
    [parameter(Mandatory)]
    [String]$LogPath,
    [parameter(Mandatory)]
    [String]$VaultName,
    [parameter(Mandatory)]
    [String]$VaultPass
    
)
function logThis($Text) {
    $timestamp = Get-Date -Format "[yyyy-MM-dd HH:mm] "
    if(-not (Test-Path $LogPath)){
        New-Item -ItemType File $LogPath -Force
    }
    Add-Content -Path $LogPath -Value ($timestamp+$Text) -PassThru
}

try{
    Unlock-SecretVault -Name $VaultName -Password ($VaultPass | ConvertTo-SecureString -AsPlainText)
}
catch{
    logThis -Text "Failed unlocking the vault. Is the provided password correct?"
    exit
}

$auth = @{}
$auth.mail = Get-Secret -Vault $VaultName -Name mail -AsPlainText 
$auth.token = Get-Secret -Vault $VaultName -Name token -AsPlainText
$auth.domain = Get-Secret -Vault $VaultName -Name domain -AsPlainText 
$auth.record = Get-Secret -Vault $VaultName -Name record -AsPlainText

#Precondition check for authentication details
if(($auth.Values) -contains $null){
    logThis -Text "The following secret(s) are missing: $(($auth.keys | Where-Object {$auth.$_ -eq $null}) -join ", ")"
    exit
}

# Build the request headers once. These headers will be used throughout the script.
$headers = @{
    "X-Auth-Email"  = $($auth.mail)
    "Authorization" = "Bearer $($auth.token)"
    "Content-Type"  = "application/json"
}

#Region Token Test
## This block verifies that your API key is valid.
## If not, the script will terminate.

$uri = "https://api.cloudflare.com/client/v4/user/tokens/verify"

$auth_result = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($auth_result.result)) {
    logThis -Text "API token validation failed. Error: $($auth_result.errors.message). Terminating script."
    # Exit script
    return
}
logThis -Text "API token validation success. $($auth_result.messages.message)."
#EndRegion

#Region Get Zone ID
## Retrieves the domain's zone identifier based on the zone name. If the identifier is not found, the script will terminate.
$uri = "https://api.cloudflare.com/client/v4/zones?name=$($auth.domain)"
$DnsZone = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($DnsZone.result)) {
    logThis -Text "Search for the DNS domain [$($auth.domain)] return zero results. Terminating script."
    # Exit script
    return
}
## Store the DNS zone ID
$zone_id = $DnsZone.result.id
logThis -Text "Domain zone [$($auth.domain)]: ID=$($zone_id)"
#End Region

#Region Get DNS Record
## Retrieve the existing DNS record details from Cloudflare.
$uri = "https://api.cloudflare.com/client/v4/zones/$($zone_id)/dns_records?name=$($auth.record)"
$DnsRecord = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($DnsRecord.result)) {
    logThis -Text "Search for the DNS record [$($auth.record)] return zero results. Terminating script."
    # Exit script
    return
}
## Store the existing IP address in the DNS record
$old_ip = $DnsRecord.result.content
## Store the DNS record type value
$record_type = $DnsRecord.result.type
## Store the DNS record id value
$record_id = $DnsRecord.result.id
## Store the DNS record ttl value
$record_ttl = $DnsRecord.result.ttl
## Store the DNS record proxied value
$record_proxied = $DnsRecord.result.proxied
logThis -Text "DNS record [$($auth.record)]: Type=$($record_type), IP=$($old_ip)"
#EndRegion

#Region Get Current Public IP Address
$new_ip = (Invoke-RestMethod -Uri 'https://cloudflare.com/cdn-cgi/trace' | ConvertFrom-StringData -Delimiter '=').ip
logThis -Text "Public IP Address: OLD=$($old_ip), NEW=$($new_ip)"
#EndRegion

#Region update Dynamic DNS Record
## Compare current IP address with the DNS record
## If the current IP address does not match the DNS record IP address, update the DNS record.
if (($new_ip -ne $old_ip) -and ($new_ip)) {
    logThis -Text "The current IP address does not match the DNS record IP address. Attempt to update."
    ## Update the DNS record with the new IP address
    $uri = "https://api.cloudflare.com/client/v4/zones/$($zone_id)/dns_records/$($record_id)"
    $body = @{
        type    = $record_type
        name    = $auth.record
        content = $new_ip
        ttl     = $record_ttl
        proxied = $record_proxied
    } | ConvertTo-Json

    $Update = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -SkipHttpErrorCheck -Body $body
    if (($Update.errors)) {
        logThis -Text "DNS record update failed. Error: $($Update[0].errors.message)"
        ## Exit script
        return
    }

    logThis -Text "DNS record update successful."
    return ($Update.result)
}
elseif (-not ($new_ip)) {
    logThis -Text "Something went wrong fetching the public IP. Skipping"
}
else {
    logThis -Text "The current IP address and DNS record IP address are the same. There's no need to update."
}
#EndRegion