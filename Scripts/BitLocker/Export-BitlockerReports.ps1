#Requires -Version 4
<#
.SYNOPSIS
    Export neo42 Management Service BitlockerReports
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export values from Bitlocker Reports to csv.
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
    ./Export-BitlockerReports.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\BitlockerReports.csv"

# prepare request headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$headersv3=New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headersv3.Add("X-Neo42-Auth", "Admin")
$headersv3.Add("X-Neo42-ControllerVersion", "3")

# Get Clientlist from MMS Server
$url = "$servername/api/client"

$clients = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials
$clientcollection=New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($client in $clients){
    $clientcollection.Add($client.Id, $client)
}

#  Append this URL with /[ClientID] to get only the specified report
$BitlockerReports = Invoke-WebRequest -Method Get -Uri "$servername/api/BitlockerReport/" -Headers $headersv3 -UseDefaultCredentials| Select-Object -ExpandProperty content| convertfrom-json
$BitlockerReportCollection=New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($BitlockerReport in $BitlockerReports){
    $BitlockerReportCollection.Add($BitlockerReport.ClientID, $BitlockerReport)
}


$Compliancestates = New-Object "System.Collections.Generic.Dictionary[[Int],[String]]"
$Compliancestates[0]="No Report"
$Compliancestates[1]="Not Compliant"
$Compliancestates[2]="Compliant"

$out=$clients|Select-Object Id,name,@{
    Label="ComplianceState"
    Expression = {$Compliancestates[$BitlockerReportCollection[$_.id].ComplianceState]}
},@{
    Label="CurrentConfiguration"
    Expression = {$BitlockerReportCollection[$_.id].CurrentConfigurationInfo.name}
},@{
    Label="TargetConfiguration"
    Expression = {$BitlockerReportCollection[$_.id].TargetConfigurationInfo.name}
},@{
    Label="EncryptionPercentage"
    Expression = {$BitlockerReportCollection[$_.id].EncryptionPercentage}
}

$out|Export-Csv -Encoding UTF8 -Path $filename -NoTypeInformation