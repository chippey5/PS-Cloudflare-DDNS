# PS-Cloudflare-DDNS

Update a DNS record in Cloudflare with PowerShell.

## Prerequisites
* Modules `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore`
* \>= PowerShell 7.1


## Setup
1. Create a Cloudflare API token ([howto](https://adamtheautomator.com/cloudflare-dynamic-dns/#Getting_a_the_Cloudflare_API_Token)).


2. Set up a secret vault:

```
Register-SecretVault -Name "your_vault_name" -ModuleName Microsoft.PowerShell.SecretStore
```

If you weren't prompted to set a password for a vault, you will be prompted when creating the first secret in the next step. 


3. Create the required secrets:  

```
Set-Secret -Name "mail" -Vault your_vault_name
Set-Secret -Name "token" -Vault your_vault_name
Set-Secret -Name "domain" -Vault your_vault_name
Set-Secret -Name "record" -Vault your_vault_name
```


4. Verify that the secrets are set correctly:

```
Unlock-SecretVault -Name your_vault_name
foreach($secretname in ("mail","token","domain","record")){Write-Host "$secretname`: $(Get-Secret -Vault your_vault_name -Name $secretname -AsPlainText)"}
```


5. Download the script

```
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chippey5/PS-Cloudflare-DDNS/main/Update-CloudflareDDNS.ps1" -OutFile "Update-CloudflareDDNS.ps1"
```


6. Test the script:

```
pwsh Update-CloudflareDDNS.ps1 -LogPath "path_to_your_logs" -VaultName "your_vault_name" -VaultPass "your_vault_password" -Record_Type "your_dns_records_type_to_update"
```

## Further notes
This script has been tested on a Windows 10 (amd64) and Linux (arm64) machine.
