$Email  = 'Your Cloudflare account email address'
$Token = 'Your Cloudflare API Token'
$Domain = 'Your Cloudflare DNS Zone (eg. contoso.com)'
$Record = 'Your Cloudflare DNS Record (eg. dmeo.contoso.com)'

.\Update-CloudflareDDNS.ps1 -Email $Email -Token $Token -Domain $Domain -Record $Record
