#requires -version 4
<#
.SYNOPSIS
    Exports all certificate information from the Device Information plug-in
.DESCRIPTION
    An Example to show how to interact with the neo42 Management Service Api
    to export certificate values for all known clients from the Device Information plug-in to csv.
    Since clients often have a large amount of certificates the process can be very time and cpu
    consuming and creates large output files!
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  08.02.2023
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Export-DeviceInformationCertificates.ps1
#>

# Fill with current servername
$servername='https://server.name:443'

# Filename with the collected data. Creates a new file every 2000 clients
$filename = "$($PSScriptRoot)\DeviceInformation_Certificates_{COUNTER}.csv"

$clientUrl = "$servername/api/client"
$deviceInformationCertReportUrl = "$servername/api/deviceinformationv2?type=cert"

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("X-Neo42-Auth","Admin")

$clientsRaw = Invoke-RestMethod -Method Get -Uri $clientUrl -Headers $headers -UseDefaultCredentials
$clientsDict = New-Object "System.Collections.Generic.Dictionary[[System.Guid],[System.Object]]"
foreach($client in $clientsRaw)
{
    $clientsDict.Add($client.Id, $client.NetBiosName)
}

$offset = 0
$limit = 500

$fileNameCounter = 0
$loopCounter = 0

do {
    $loopCounter++
    if($loopCounter -gt 4)
    {
        $loopCounter = 0
        $fileNameCounter++
    }
    $output = New-Object Collections.Generic.List[System.Object]
    $url = "$deviceInformationCertReportUrl&offset=$offset&limit=$limit"
    $page = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -UseDefaultCredentials
    $page | ForEach-Object {
        if ($clientsDict.ContainsKey($_.Id)) {
            foreach($store in $_.OperatingSystem.CertificateStores)
            {
                foreach($certificate in $store.Certificates)
                {
                    $obj = New-Object System.Object
                    $obj | Add-Member -type NoteProperty -name Client -value $clientsDict[$_.Id]
                    $obj | Add-Member -type NoteProperty -name Store -value $store.FriendlyName
                    $obj | Add-Member -type NoteProperty -name CertName -value $certificate.Name
                    $obj | Add-Member -type NoteProperty -name Issuer -value $certificate.Issuer
                    $obj | Add-Member -type NoteProperty -name Subject -value $certificate.Subject
                    $obj | Add-Member -type NoteProperty -name NotBefore -value $certificate.NotBefore
                    $obj | Add-Member -type NoteProperty -name NotAfter -value $certificate.NotAfter
                    $obj | Add-Member -type NoteProperty -name Serial -value $certificate.Serial
                    $obj | Add-Member -type NoteProperty -name Thumbprint -value $certificate.Thumbprint
                    $obj | Add-Member -type NoteProperty -name HasPrivateKey -value $certificate.PrivateKey
                    $output.Add($obj)
                }
            }    
        }
    }
    $output | Export-Csv  -Path $($filename).Replace("{COUNTER}", $fileNameCounter) -NoClobber -NoTypeInformation -Encoding Default -Append
    $offset += $limit
    Write-Output "Clients written to csv files: $offset"
} while ($page.Count -eq $limit)