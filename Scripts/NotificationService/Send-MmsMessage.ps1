#requires -version 4
<#
.SYNOPSIS
    Sends a MMS Message to a Client
.DESCRIPTION
    This Script enables you to automate messages to clients utilizting the neo42 Management Service
.INPUTS
    Header, BodyLineOne, BodyLineTwo
.OUTPUTS
    Message Details
.NOTES
    Version:             1.0
    Author:              neo42 GmbH
    Creation Date:       30.11.2021
    Purpose/Change:      Initial version
    Required MMS Server: 2.8.5.0
.COMPONENT
    neo42 Management Service 
.EXAMPLE
    .\Send-MmsMessage.ps1 -Header "Überschrift" -BodyLineOne "Hello there" -BodyLineTwo "Please contact your IT-Service Team 123456789"
#>
[CmdletBinding()]
param (
    [Parameter()]
    [String]
    $Header,
    [Parameter()]
    [String]
    $BodyLineOne,
    [Parameter()]
    [String]
    $BodyLineTwo
    
)
# URL of MMS server
$servername = 'https://server.domain:443'

# Target Client
$ClientName = "ClientName"
$NetBiosDomain = "Domain"

# Setup header
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")

# Search client
$clientsearchurl = "$servername/api/clientbyname/$([System.Guid]::Empty)?domainName=$NetBiosDomain&computerName=$ClientName"
$client = Invoke-RestMethod -Method Get -Uri $clientsearchurl -Headers $headers -UseDefaultCredentials

$msgId = (New-Guid).Guid

$msg = @"
{
    "Id": "{MSGID}",
    "ClientId": "{CLIENTID}",
    "ExpirationDate": "",
    "Notification": {
        "Id": "{MSGID}",
        "Actions": [
            {
                "<ActionType>k__BackingField": 0,
                "<Arguments>k__BackingField": null,
                "<ProcessPath>k__BackingField": null
            }
        ],
        "ApplicationId": "",
        "Lines": [
            "{MSGHEADER}",
            "{MSGLINE1}",
            "{MSGLINE2}"
        ],
        "Icon": null,
        "IconData": null,
        "Type": 7,
        "Sound": 0
    },
    "IsSent": false,
    "SentTime": "$(Get-Date -Format yyyy-MM-ddTHH:mm:ss)",
    "SentTimeOffset": "02:00:00",
    "ClientRecievedTime": "0001-01-01T00:00:00",
    "ClientRecievedTimeOffset": "00:00:00"
}
"@


$msgBody = $msg.Replace(
    "{MSGID}","$msgId"
    ).Replace("{CLIENTID}","$($client.Id)"
    ).Replace("{MSGHEADER}","$header"
    ).Replace("{MSGLINE1}","$BodyLineOne"
    ).Replace("{MSGLINE2}","$BodyLineTwo"
    )


# Push notification to client
$notificationPushUri = "$servername/api/StoreableNotification/"
Invoke-RestMethod -Method Post -Uri $notificationPushUri -Headers $headers -UseDefaultCredentials -Body $msgBody -ContentType "application/json; charset=utf-8"