#Requires -Version 4
<#
.SYNOPSIS
    Export Bitlocker Recovery Keys from neo42 Management Service and Active Directory if available
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to receive Bitlocker RecoveryKeys
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  26.05.2021
    Purpose/Change: Initial version
  
.EXAMPLE
    ./Export-BitlockerRecoveryKeys.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\BitlockerRecoveryKeys.csv"

#prepare request headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$headersv3=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv3.Add("X-Neo42-Auth", "Admin")
$headersv3.Add("X-Neo42-ControllerVersion", "3")

# Get Clientlist from MMS Server
$url = "$servername/api/client"

$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials
Remove-Item -Path $filename -ea 0
foreach ($client in $clients){
    $AdRecoveryKeys = Invoke-RestMethod -Method Get -Uri "https://mms.neo.dom/api/BitlockerAdRecoveryKey/?clientId=$($client.id)"  -Headers $headers -UseDefaultCredentials
    $AdRecoveryKeys|Select-Object -ExcludeProperty key *,@{
        Label = "StoredIn"
        Expression = {"AD"}
    },@{
        Label = "key"
        Expression = {$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key)))}
    }|Export-Csv -NoTypeInformation -Append -Path $filename -Encoding UTF8
    $MMSRecoveryKeys = Invoke-RestMethod -Method Get -Uri "https://mms.neo.dom/api/BitlockerInbuiltRecoveryKey/?clientId=$($client.id)" -Headers $headers -UseDefaultCredentials
    $MMSRecoveryKeys|Select-Object -ExcludeProperty key *,@{
        Label = "StoredIn"
        Expression = {"MMS"}
    },@{
        Label = "key"
        Expression = {$([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_.key)))}
    }|Export-Csv -NoTypeInformation -Append -Path $filename -Encoding UTF8
}
