# PS-Cloudflare-DDNS

Update a DNS record in Cloudflare with PowerShell.

## Prerequisites
* Modules `Microsoft.PowerShell.SecretManagement` and `Microsoft.PowerShell.SecretStore` (`Install-Module -Name Microsoft.PowerShell.SecretManagement,Microsoft.PowerShell.SecretStore`)
* \>= PowerShell 7.1


## Setup
1. Create a Cloudflare API token ([howto](https://adamtheautomator.com/cloudflare-dynamic-dns/#Getting_a_the_Cloudflare_API_Token)).


2. Set up a secret vault (From a pwsh prompt):

```
Register-SecretVault -Name "your_vault_name" -ModuleName Microsoft.PowerShell.SecretStore
```

If you weren't prompted to set a password for the vault, you will be prompted when creating the first secret in the next step. 

3. Note down the following secrets in preparation for the next step:


mail: #The e-mail address used to log in to your CloudFlare account  
token: #The token from step 1  
domain #Your domain, i.e. `example.com`  
record: #Your FQDN (\<dns record\> to be updated when your device's public IP changes. For example: `myserver.example.com`.



4. Create the required secrets:  

```
Set-Secret -Name "mail" -Vault your_vault_name

cmdlet Set-Secret at command pipeline position 1
Supply values for the following parameters:
SecureStringSecret: <mail value from step 3>
Creating a new ddns vault. A password is required by the current store configuration.
Enter password:
<your vault password>
Enter password again for verification:
<your vault password>

Set-Secret -Name "token" -Vault your_vault_name
Set-Secret -Name "domain" -Vault your_vault_name
Set-Secret -Name "record" -Vault your_vault_name
```


5. Verify that the secrets are set correctly:

```
Unlock-SecretVault -Name your_vault_name
foreach($secretname in ("mail","token","domain","record")){Write-Host "$secretname`: $(Get-Secret -Vault your_vault_name -Name $secretname -AsPlainText)"}
```


6. Download the script

```
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/chippey5/PS-Cloudflare-DDNS/main/Update-CloudflareDDNS.ps1" -OutFile "Update-CloudflareDDNS.ps1"
```


7. Test the script:

```
pwsh Update-CloudflareDDNS.ps1 -LogPath "path_to_your_logs" `
                               -VaultName "your_vault_name" `
                               -VaultPass "your_vault_password" `
                               -Record_Type "your_dns_records_type_to_update"  
```

8. [Optional - Linux] Set up an hourly cron job

```
crontab -e
5 * * * * /path/to/pwsh /path/to/Update-CloudflareDDNS.ps1 -LogPath "/path/to/your/log.log" -VaultName "your_vault_name" -VaultPass "your_vault_pass" -Record_Type "your_record_type"
```

## Further notes
This script has been tested on a Windows 10 (amd64) and Linux (arm64) machine.
