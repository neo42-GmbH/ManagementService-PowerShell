#requires -version 4
<#
.SYNOPSIS
    Tests the connection to the Management Service Server
.DESCRIPTION
    If this scripts returns the current server time, then the following criterias are fulfilled:
        - The servername and the port are correct
        - The webserver port is not blocked by any firewall
        - The servername is a valid DNS name
        - The client trusts the webserver certificate 
        - The webserver is started
.INPUTS
    none
.OUTPUTS
    none
.NOTES
    Version:        1.0
    Author:         neo42 GmbH
    Creation Date:  27.01.2020
    Purpose/Change: Initial version
  
.EXAMPLE
    .\Test-MMSServerConnection.ps1
#>

# Fill with current servername
$servername='https://server.domain:443'

try
{
    $url = "$servername/api/TimeService/1"
    $web = New-Object System.Net.WebClient
    $web.UseDefaultCredentials = $true
    $web.Headers.Add('X-Neo42-Auth','Anonymous')

    $web.DownloadString($url)
}
catch
{
    $error[0] 
}