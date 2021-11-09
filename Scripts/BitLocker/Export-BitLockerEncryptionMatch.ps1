#requires -version 4
<#
.SYNOPSIS
    Matches the actual client encryption method vs target policy encryption method
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service API
    to export an encryption method matching table to csv. 
    For more information about the MMS Server API check the API-Browser guide 
    in the help files.
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Script Version:      1.0
    Author:              neo42 GmbH
    Creation Date:       09.11.2021
    Purpose/Change:      Initial version
    Required MMS Server: 2.8.4.0

.EXAMPLE
    .\Export-BitLockerEncryptionMatch.ps1
#>

# Fill with current servername
$servername = 'https://server.domain:443'
# Filename with the collected data
$filename = "$($PSScriptRoot)\BitlockerEncryptionMatchReports.csv"

# prepare request headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth", "Admin")
$headersv3 = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
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
$BitlockerReportCollection = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
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

$compliant = $out | Where-Object ComplianceState -eq $Compliancestates[2] | Where-Object EncryptionPercentage -eq 100

$encryptionMatch = New-Object "System.Collections.Generic.Dictionary[[System.Int32],[System.Int32]]"


enum BitlockerWin10Algorithm 
{
    AES_128 = 0
    AES_256 = 1
    XTS_AES_128 = 2
    XTS_AES_256 = 3
}

enum EncryptionMethod
{
    NONE = 0
    AES_128_WITH_DIFFUSER = 1
    AES_256_WITH_DIFFUSER = 2
    AES_128 = 3
    AES_256 = 4
    HARDWARE_ENCRYPTION = 5
    XTS_AES_128 = 6
    XTS_AES_256 = 7
}

# AES 128
$encryptionMatch.Add(3,0)
# AES 256 
$encryptionMatch.Add(4,1)
# XTS AES 128
$encryptionMatch.Add(6,2)
# XTS AES 256
$encryptionMatch.Add(7,3)

$output = New-Object Collections.Generic.List[System.Object]
foreach($client in $compliant)
{
    $currentEncryptionMethod = $BitlockerReportCollection[$client.Id].Disks[0].SupportsBitlockerVolumes.EncryptionMethod
    $bitlockerPolicy = Invoke-RestMethod -Method Get -Uri "$servername/api/BitlockerPolicy/$($BitlockerReportCollection[$client.Id].CurrentPolicyInfo.Id)" -Headers $headers -UseDefaultCredentials
    $targetEncryptionMethod = $bitlockerPolicy.AlgorithmSettings.Win10
    
    if($encryptionMatch[$currentEncryptionMethod] -ne $targetEncryptionMethod)
    {
        Write-Output "Client '$($client.Name)' does not have the expected encryption method. Current: $([EncryptionMethod].GetEnumName($currentEncryptionMethod)) | Target: $([BitlockerWin10Algorithm].GetEnumName($targetEncryptionMethod))"

        $obj = New-Object System.Object
        $obj | Add-Member -type NoteProperty -name Client -value $($client.Name)
        $obj | Add-Member -type NoteProperty -name CurrentEncryption -value $([EncryptionMethod].GetEnumName($currentEncryptionMethod))
        $obj | Add-Member -type NoteProperty -name TargetEncryption -value $([BitlockerWin10Algorithm].GetEnumName($targetEncryptionMethod))
        $output.Add($obj)
    }
}

$output | Export-Csv  -Path $filename -NoClobber -NoTypeInformation -Encoding Default