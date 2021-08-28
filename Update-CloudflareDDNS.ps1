#requires -Version 7.1

[cmdletbinding()]
param (
    [parameter(Mandatory)]
    $Email,
    [parameter(Mandatory)]
    $Token,
    [parameter(Mandatory)]
    $Domain,
    [parameter(Mandatory)]
    $Record
)

#Region Token Test
## This block verifies that your API key is valid.
## If not, the script will terminate.

$uri = "https://api.cloudflare.com/client/v4/user/tokens/verify"
$headers = @{
    "X-Auth-Email" = $($Email)
    "Authorization" = "Bearer $($Token)"
    "Content-Type" = "application/json"
}
$auth_result = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($auth_result.result)) {
    Write-Output "API token validation failed. Error: $($auth_result.errors.message). Terminating script."
    # Exit script
    return
}
Write-Output "API token validation [$($Token)] success. $($auth_result.messages.message)."
#EndRegion

#Region Get Zone ID
## Retrieves the domain's zone identifier. If the the identifier is not found, the script will terminate.
$uri = "https://api.cloudflare.com/client/v4/zones?name=$($Domain)"
$DnsZone = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($DnsZone.result)) {
    Write-Output "Search for the DNS domain [$($Domain)] return zero results. Terminating script."
    # Exit script
    return
}
## The DNS zone ID
$zone_id = $DnsZone.result.id
Write-Output "Domain zone [$($Domain)]: ID=$($zone_id)"
#End Region

#Region Get DNS Record
## Retrieve the existing DNS record details from Cloudflare.
$uri = "https://api.cloudflare.com/client/v4/zones/$($zone_id)/dns_records?name=$($Record)"
$DnsRecord = Invoke-RestMethod -Method GET -Uri $uri -Headers $headers -SkipHttpErrorCheck
if (-not($DnsRecord.result)) {
    Write-Output "Search for the DNS record [$($Record)] return zero results. Terminating script."
    # Exit script
    return
}
## The existing IP address in the DNS record
$old_ip = $DnsRecord.result.content
## The DNS record type value
$record_type = $DnsRecord.result.type
## The DNS record id value
$record_id = $DnsRecord.result.id
## The DNS record ttl value
$record_ttl = $DnsRecord.result.ttl
## The DNS record proxied value
$record_proxied = $DnsRecord.result.proxied
Write-Output "DNS record [$($Record)]: Type=$($record_type), IP=$($old_ip)"
#EndRegion

#Region Get Current Public IP Address
$new_ip = (curl.exe -s 'http://icanhazip.com')
Write-Output "Public IP Address: OLD=$($old_ip), NEW=$($new_ip)"
#EndRegion

# Compare current IP address with the DNS record
# If the current IP address does not match the DNS record IP address, update the DNS record.
if ($new_ip -ne $old_ip) {
    Write-Output "The current IP address does not match the DNS record IP address. Attempt to update."
    ## Update the DNS record with the new IP address
    $uri = "https://api.cloudflare.com/client/v4/zones/$($zone_id)/dns_records/$($record_id)"
    $body = @{
        type    = $record_type
        name    = $Record
        content = $new_ip
        ttl     = $record_ttl
        proxied = $record_proxied
    } | ConvertTo-Json
    $Update = Invoke-RestMethod -Method PUT -Uri $uri -Headers $headers -SkipHttpErrorCheck -Body $body
    if (($Update.errors)) {
        Write-Output "DNS record update failed. Error: $($Update[0].errors.message)"
        # Exit script
        return
    }

    Write-Output "DNS record update successful."
    return ($Update.result)
}
else {
    Write-Output "The current IP address and DNS record IP address are the same. There's no need to update."
}