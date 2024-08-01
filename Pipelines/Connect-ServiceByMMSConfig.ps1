#requires -Version 5.1
<#
    .SYNOPSIS
        Wrapper to make use of bridge and network share functionality inside your scripts.
    .DESCRIPTION
        This script is a wrapper to make use of the bridge and network share functionality inside your scripts.
        It will authenticate to the MMS API and retrieve the necessary information to connect to the different services.
    .PARAMETER MmsApiUri
        The URI of the MMS API. By default is the local machine name with port 4242 will be used.
    .PARAMETER CertificateThumbprint
        The thumbprint of the certificate to use for authentication to the MMS API. 
        If not provided, the script will try to find the certificate in the store based on the MMS Root Certificate.
    .PARAMETER Credentials
        The credentials to use for authentication to the MMS API. 
        Alternative to the certificate thumbprint.
    .PARAMETER Mount
        The network share names to mount. 
        These shares will be mounted as temporary PSDrives with the share name as drive name.
    .PARAMETER TenantName
        The name of the tenant of which to obtain the bridge and network share information.
    .PARAMETER ConnectConfigMgr
        Switch to connect to ConfigMgr.
        Will provide a PSDrive to the ConfigMgr site server and set the location to the root of the site.
    .PARAMETER ConnectEmpirum
        Switch to connect to Empirum.
        Will provide an authenticated SqlServer module with the Empirum database data as default parameter values.
    .PARAMETER ConnectM42Cloud
        Switch to connect to M42Cloud.
        Will provide a session to the Empirum SDK cmdlets from the Matrix42.SDK.Empirum.Powershell module.
    .PARAMETER ConnectIntune
        Switch to connect to Intune.
        Will provide a authenticated Microsoft.Graph session.
    .PARAMETER ConnectWSO
        Switch to connect to WorkspaceONE.
        Currently only available with the GetDataOnly switch.
    .PARAMETER GetDataOnly
        Switch to only get the data and store it in variables. No connections will be established.
        Useful if you want to use the data in your own way and not use the default modules.
#>
[CmdletBinding(DefaultParameterSetName="Certificate")]
Param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({ Invoke-RestMethod -Uri ($_.AbsoluteUri + "api/TimeService/1") -Headers @{"X-Neo42-Auth" = "Anonymous"} -ErrorAction Stop })]
    [uri]
    $MmsApiUri = ("https://" + [System.Net.Dns]::GetHostByName($env:computerName).HostName + ":4242"),

    [Parameter(Mandatory=$false, ParameterSetName="Certificate")]
    [ValidateScript({[System.Text.Encoding]::UTF8.GetByteCount($_) -eq 40})]
    [string]
    $CertificateThumbprint,
    [Parameter(Mandatory=$true, ParameterSetName="Credentials")]
    [PSCredential]
    $Credentials,
    [Parameter(Mandatory=$false)]
    [string]
    $TenantName = "Default",

    [Parameter(Mandatory=$false)]
    [string[]]
    $Mount,

    [Parameter(Mandatory=$false)]
    [switch]
    $ConnectConfigMgr,
    [Parameter(Mandatory=$false)]
    [switch]
    $ConnectEmpirum,
    [Parameter(Mandatory=$false)]
    [switch]
    $ConnectM42Cloud,
    [Parameter(Mandatory=$false)]
    [switch]
    $ConnectIntune,
    [Parameter(Mandatory=$false)]
    [switch]
    $ConnectWSO,

    [Parameter(Mandatory=$false)]
    [switch]
    $GetDataOnly
)

#region FUNCTIONS
function Test-CertificateChain {
    <#
    .SYNOPSIS
        Tests if a certificate chain is valid.
    .PARAMETER IssuerCertificate
        The issuer certificate.
    .PARAMETER Certificate
        The certificate to test.
    .EXAMPLE
        Test-CertificateChain -IssuerCertificate $issuerCert -Certificate $cert
    #>
    Param (
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $IssuerCertificate,
        [Parameter(Mandatory=$true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]
        $Certificate
    )

    [System.Security.Cryptography.X509Certificates.X509Chain]$chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new($true)
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $chain.ChainPolicy.ExtraStore.Add($IssuerCertificate)

    if ($false -eq $chain.Build($Certificate)) {
        return $false
    }

    return ($chain.ChainElements.Certificate.Thumbprint -contains $IssuerCertificate.Thumbprint)
}

function Get-MMSBridgeSettings {
    Param (
        [Parameter(Mandatory=$false)]
        [uri]
        $MmsApiUri = $script:MmsApiUri,
        [Parameter(Mandatory=$false)]
        [PSCustomObject]
        $Tenant = $script:MMSTenant,
        [Parameter(Mandatory=$false)]
        [hashtable]
        $MmsHeaders = $script:MmsHeaders,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Sccm", "Empirum", "EmpirumSDK", "Intune", "Wso")]
        [string]
        $ServiceName
    )

    try {
        [PSCustomObject]$serviceConfigRequest = Invoke-RestMethod -Uri ($MmsApiUri.AbsoluteUri + "api/apc/${ServiceName}Settings?tenantId=$($MMSTenant.TenantId)") -Method Get -Headers $MmsHeaders -ErrorAction Stop
        if ($true -ne $serviceConfigRequest.Success) {
            throw "Failed to get WorkspaceONE connection information. Reply was not successful."
        }
        return $serviceConfigRequest.Item
    }
    catch {
        Write-Error "Could not get [$ServiceName] connection information from [$MmsApiUri]`n$($_.Exception.Message)"
        exit 1
    }
}
#endregion

#region PREREQUISITES
if ($false -eq ($MyInvocation.InvocationName -eq '.' -or $MyInvocation.Line -eq '')) {
    Write-Error "This script must be dot-sourced. Please use the following syntax: [. <PATH_TO_SCRIPT>]"
    exit 1
}
if ($true -eq $ConnectConfigMgr) {
    $env:PSModulePath = $env:PSModulePath + ";${env:ProgramFiles(x86)}\Microsoft Configuration Manager\AdminConsole\bin"
    if ($null -eq (Get-Module -Name "ConfigurationManager" -ListAvailable)) {
        Write-Error "The [ConfigurationManager] module is required for ConfigMgr connection. Please install the Configuration Manager Console Application and try again."
        exit 1
    }
}
if ($true -eq $ConnectM42Cloud) {
    if ($null -eq (Get-Module -Name "Matrix42.SDK.Empirum.Powershell" -ListAvailable)) {
        Write-Error "The [Matrix42.SDK.Empirum.Powershell] module is required for M42Cloud connection. Please install the module and try again."
        exit 1
    }
}
if ($true -eq $ConnectEmpirum){
    if ($null -eq (Get-Module -Name "SqlServer" -ListAvailable)) {
        Write-Error "The [SqlServer] module is required for Empirum connection. Please install the module and try again."
        exit 1
    }
}
if ($true -eq $ConnectIntune) {
    if ($null -eq (Get-Module -Name "Microsoft.Graph" -ListAvailable)) {
        Write-Error "The [Microsoft.Graph] module is required for Intune connection. Please install the module and try again."
        exit 1
    }
}
#endregion

#region AUTHENTICATION MMS
[hashtable]$script:MmsHeaders = @{
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}
if ($PSCmdlet.ParameterSetName -eq "Credentials") {
    Write-Host "Using credentials for authentication to the MMS API..."
    [hashtable]$body = @{
        User     = $Credentials.UserName
        Password = [System.Net.NetworkCredential]::new("", $Credentials.Password).Password
    }

    try {
        [PSCustomObject]$jwtResponse = Invoke-RestMethod -Method Post -Uri ($MmsApiUri.AbsoluteUri + "api/identity/jwt") -Headers $MmsHeaders -Body ($body | ConvertTo-Json) -ErrorAction Stop
        if ($true -eq [string]::IsNullOrEmpty($response.Token)) {
            throw "Failed to get bearer token. Reply did not contain a token."
        }
        $script:MmsHeaders.Add("Authorization", "Bearer $($jwtResponse.Token)")
    }
    catch {
        Write-Error "Could not get JWT token from [$MmsApiUri]`n$($_.Exception.Message)"
        exit 1
    }
}
elseif ($PSCmdlet.ParameterSetName -eq "Certificate") {
    Write-Host "Using certificate for authentication to the MMS API..."

    # Obtain the MMS Root Certificate from the MMS API
    try {
        [string]$MMSRootCertificatePEM = Invoke-RestMethod -Uri ($MmsApiUri.AbsoluteUri + "api/certificateservices/servercert") -Method GET -Headers @{"X-Neo42-Auth" = "Anonymous"; "Accept" = "application/json"} -ErrorAction Stop | Select-Object -ExpandProperty PemEncodedObject
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$MMSRootCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($MMSRootCertificatePEM.Trim("`r").Split("`n")[1..17] -join [string]::Empty))
    }
    catch {
        Write-Error "Could not get MMS Root Certificate from [$MmsApiUri]`n$($_.Exception.Message)"
        exit 1
    }

    # If no thumbprint is provided, try to find the certificate in the store based on the root certificate
    if ($true -eq [string]::IsNullOrEmpty($CertificateThumbprint)) {
        [System.Security.Cryptography.X509Certificates.X509Certificate2[]]$MMSAccessCertificateCandidates = Get-ChildItem -Path "Cert:\LocalMachine\My\" | Where-Object {
            $_.Issuer -eq $MMSRootCertificate.Subject -and 
            $_.NotAfter -gt (Get-Date) -and
            $_.NotBefore -lt (Get-Date) -and
            $_.HasPrivateKey -eq $true -and
            (Test-CertificateChain -IssuerCertificate $MMSRootCertificate -Certificate $_) -eq $true
        }
        if ($MMSAccessCertificateCandidates.Count -ne 1) {
            Write-Error "Could not reliably determine the MMS Access Certificate. Found [$($MMSAccessCertificateCandidates.Count)] matching certificates in store. Either fix the certificate situation or provide the thumbprint as parameter."
            exit 1
        }
        $CertificateThumbprint = $MMSAccessCertificateCandidates[0].Thumbprint
    }

    # Get the certificate for MMS API access from the store
    try {
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$mmsCertificate = Get-Item -Path "Cert:\LocalMachine\My\$CertificateThumbprint" -ErrorAction Stop
        if ($false -eq $mmsCertificate.HasPrivateKey -or $false -eq (Test-CertificateChain -IssuerCertificate $MMSRootCertificate -Certificate $mmsCertificate)) {
            throw "The selected certificate is not valid for MMS API access."
        }
    }
    catch {
        Write-Error "Could not access the certificate with thumbprint [$CertificateThumbprint]`n$($_.Exception.Message)"
        exit 1
    }

    # Get the JWT token from the MMS API using the certificate and build the headers
    $script:MmsHeaders.Add("X-Neo42-Auth", "BlazorUI")
    try {
        [PSCustomObject]$jwtResponse = Invoke-RestMethod -Uri ($MmsApiUri.AbsoluteUri + "api/jwtcert") -Method GET -Headers $script:MmsHeaders -Certificate $mmsCertificate -ErrorAction Stop
        if ($true -eq [string]::IsNullOrEmpty($jwtResponse.Value)) {
            throw "Response did not contain a JWT token"
        }
        $script:MmsHeaders.Add("Authorization", "Bearer $($jwtResponse.Value)")
    }
    catch {
        Write-Error "Could not get JWT token from [$MmsApiUri]`n$($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Error "Invalid parameter set [$($PSCmdlet.ParameterSetName)]"
    exit 1
}
Write-Host "Successfully authenticated to the MMS API"
#endregion

#region TENANT SELECTION
try {
    Write-Host "Getting tenant information for [$TenantName]..."
    [PSCustomObject]$mmsTenants = Invoke-RestMethod -Uri ($MmsApiUri.AbsoluteUri + "api/apc/tenant/all") -Method Get -Headers $script:MmsHeaders -ErrorAction Stop
    if ($true -ne $mmsTenants.Success) {
        throw "Failed to get tenant information. Reply was not successful."
    }
    $mmsTenants = $mmsTenants.Item | Where-Object { $_.TenantName -eq $TenantName }
    if ($mmsTenants -is [System.Collections.IEnumerable] -or $null -eq $mmsTenants) {
        throw "Failed to get accurate tenant information. Found [$($mmsTenants.Count)] matching tenants with name [$TenantName]."
    }
    [PSCustomObject]$script:MMSTenant = $mmsTenants | Select-Object -First 1
    Write-Host "Tenant information for [$($script:MMSTenant.TenantName)] with description [$($script:MMSTenant.Description)] aquired."
}
catch {
    Write-Error "Could not get tenant information from [$MmsApiUri]`n$($_.Exception.Message)"
    exit 1
}
#endregion

#region MOUNT NETWORK SHARES
if ($Mount.Count -gt 0) {
    Write-Host "Mounting network shares..."
    try {
        [PSCustomObject]$networkShares = Invoke-RestMethod -Uri ($MmsApiUri.AbsoluteUri + "api/apc/NetworkDrive/all") -Method Get -Headers $script:MmsHeaders -ErrorAction Stop
        if ($true -ne $networkShares.Success) {
            throw "Failed to get network share information. Reply was not successful."
        }
        $networkShares = $networkShares.Item
    }
    catch {
        Write-Error "Could not get network share information from [$MmsApiUri]`n$($_.Exception.Message)"
        exit 1
    }
    foreach ($share in $Mount) {
        [PSCustomObject]$networkShare = $networkShares | Where-Object { $_.Name -eq $share }
        if ($true -eq $GetDataOnly) {
            Set-Variable -Name "NetworkShare_$($networkShare.Name)" -Value $networkShare -Scope Script
            Write-Host "Credentials for network share [$($networkShare.Name)] have been stored in variable [NetworkShare_$($networkShare.Name)]"
            continue
        }
        if ($null -eq $networkShare) {
            Write-Error "Could not find network share with name [$share]. Skipping..."
            continue
        }
        try {
            New-PSDrive -Name $networkShare.Name -PSProvider FileSystem -Root $networkShare.UNCPath -Credential ([PSCredential]::new(($networkShare.Domain + '\' + $networkShare.User), (ConvertTo-SecureString -AsPlainText -Force $networkShare.Password))) -ErrorAction Stop | Out-Null
            Write-Host "Successfully mounted network share [$($networkShare.Name)] with path [$($networkShare.UNCPath)]"
        }
        catch {
            Write-Error "Could not mount network share [$($networkShare.Name)] with path [$($networkShare.UNCPath)]`n$($_.Exception.Message)"
        }
    }
}
#endregion

#region CONNECT CONFIGMGR
if ($true -eq $ConnectConfigMgr) {
    Write-Host "Connecting to ConfigMgr..."
    try {
        Import-Module -Name "ConfigurationManager" -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Could not import the [ConfigurationManager] module`n$($_.Exception.Message)"
        exit 1
    }
    [PSCustomObject]$configMgrConnection = Get-MMSBridgeSettings -ServiceName "Sccm"
    try {
        [PSCredential]$configMgrCredential = [PSCredential]::new(($configMgrConnection.Domain + '\' + $configMgrConnection.User), (ConvertTo-SecureString -AsPlainText -Force $configMgrConnection.Password))
        [CimSession]$session = New-CimSession -ComputerName $configMgrConnection.Server -Credential $configMgrCredential -ErrorAction Stop
        [string]$configMgrSiteCode = (Get-CimInstance -CimSession $session -Namespace "root\sms" -Class "__Namespace").Name.Substring(5,3)
        Remove-CimSession -CimSession $session | Out-Null
        if ($true -eq $GetDataOnly) {
            Add-Member -InputObject $configMgrConnection -MemberType NoteProperty -Name 'SiteCode' -Value $configMgrSiteCode -Force -PassThru -ErrorAction Stop | Out-Null
            Set-Variable -Name "ConfigMgr" -Value $configMgrConnection -Scope Script
            Write-Host "ConfigMgr connection data has been stored in variable [ConfigMgr]"
        }
        else {
            [System.Management.Automation.PSDriveInfo]$configMgrDrive = New-PSDrive -Name $configMgrSiteCode -PSProvider "CMSite" -Root $configMgrConnection.Server -Credential $configMgrCredential -ErrorAction Stop
            Set-Location -Path "$($configMgrDrive.Name):\" -ErrorAction Stop
            Write-Host "Successfully connected to ConfigMgr with server [$($configMgrConnection.Server)]. Drive is mapped to SiteCode [$configMgrSiteCode] and location has been updated."
        }
    }
    catch {
        Write-Error "Could not connect to ConfigMgr to get its SiteCode`n$($_.Exception.Message)"
        exit 1
    }

}
#endregion

#region CONNECT M42CLOUD
if ($true -eq $ConnectM42Cloud) {
    Write-Host "Connecting to Matrix42 Cloud..."
    $m42CloudConnection = Get-MMSBridgeSettings -ServiceName "EmpirumSDK"
    if ($true -eq $GetDataOnly) {
        Set-Variable -Name "M42Cloud" -Value $m42CloudConnection -Scope Script
        Write-Host "Matrix42 Cloud connection data has been stored in variable [M42Cloud]"
    }
    else {
        try {
            [PSCustomObject]$m42CloudSession = Open-Matrix42ServiceConnection -ServerName $m42CloudConnection.Server -Port $m42CloudConnection.Port -UserName $m42CloudConnection.Username -Password $m42CloudConnection.Password -Protocol $m42CloudConnection.Protocol -IsSecured $m42CloudConnection.Secured
            foreach ($empSDKCmndletName in (Get-Command -Module "Matrix42.SDK.Empirum.Powershell" -ParameterName Session).Name) {
                $PSDefaultParameterValues["${empSDKCmndletName}:Session"] = $m42CloudSession
            }
            Write-Host "Successfully connected to Matrix42 Cloud with server [$($m42CloudConnection.Server)]. Session is available for all Empirum SDK cmdlets."
        }
        catch {
            Write-Error "Could not connect to Matrix42 Cloud`n$($_.Exception.Message)"
            exit 1
        }
    }
}
#endregion

#region CONNECT EMPIRUM
if ($true -eq $ConnectEmpirum) {
    Write-Host "Connecting to Empirum database..."
    [PSCustomObject]$empConnection = Get-MMSBridgeSettings -ServiceName "Empirum"
    if ($true -eq $GetDataOnly) {
        Set-Variable -Name "Empirum" -Value $empConnection -Scope Script
        Write-Host "Empirum connection data has been stored in variable [Empirum]"
    }
    else {
        try {
            if ($false -eq [string]::IsNullOrEmpty($empConnection.Domain)){
                $empConnection.User = $empConnection.Domain + '\' + $empConnection.User
            }
            [PSCredential]$empCredential = [PSCredential]::new($empConnection.User, (ConvertTo-SecureString -AsPlainText -Force $empConnection.Password))
            foreach ($sqlSrvCmndletName in (Get-Command -Module SQLServer -ParameterName Credential, ServerInstance).Name) {
                $PSDefaultParameterValues["${empSDKCmndletName}:Credential"] = $empCredential
                $PSDefaultParameterValues["${empSDKCmndletName}:ServerInstance"] = $empConnection.Server
                $PSDefaultParameterValues["${empSDKCmndletName}:TrustServerCertificate"] = $true
                $PSDefaultParameterValues["${empSDKCmndletName}:Database"] = $empConnection.Database
            }
        } 
        catch {
            Write-Error "Could not connect to Empirum database`n$($_.Exception.Message)"
            exit 1
        }
    }
}
#endregion

#region CONNECT INTUNE
if ($true -eq $ConnectIntune) {
    Write-Host "Connecting to Intune..."
    [PSCustomObject]$intuneConnection = Get-MMSBridgeSettings -ServiceName Intune
    if ($true -eq $GetDataOnly) {
        Set-Variable -Name "Intune" -Value $intuneConnection -Scope Script
        Write-Host "Intune connection data has been stored in variable [Intune]"
    }
    else {
        [hashtable]$mgConnectionSplat = @{
            TenantId     = $intuneConnection.IntuneTenantId
            NoWelcome    = $true
            ContextScope = "Process"
        }
        if ($false -eq [string]::IsNullOrEmpty($intuneConnection.AppSecret)) {
            $mgConnectionSplat.Add("ClientSecretCredential", [PSCredential]::new($intuneConnection.AppId, (ConvertTo-SecureString -AsPlainText -Force $intuneConnection.AppSecret)))
        }
        elseif ($false -eq [string]::IsNullOrEmpty($intuneConnection.CertificateData)) {
            $mgConnectionSplat.Add("ClientId", $intuneConnection.AppId)
            try {
                [System.Security.Cryptography.X509Certificates.X509Certificate2]$intuneCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($intuneConnection.CertificateData), $intuneConnection.CertificatePassword)
            }
            catch {
                Write-Error "Could not create certificate object from data`n$($_.Exception.Message)"
                exit 1
            }
            $mgConnectionSplat.Add("Certificate", $intuneCertificate)
        }
        else {
            Write-Error "Could not determine the authentication method for Intune connection. Bridge is missing configuration."
            exit 1
        }

        try {
            Connect-MgGraph @mgConnectionSplat
            Write-Host "Successfully connected to Intune via the Microsoft.Graph module.`nThe following scopes are available:`n$(Get-MgContext | Select-Object -ExpandProperty Scopes)"
        }
        catch {
            Write-Error "Could not connect to Intune`n$($_.Exception.Message)"
            exit 1
        }
    }
}
#endregion

#region CONNECT WSO
if ($true -eq $ConnectWSO) {
    if ($true -ne $GetDataOnly) {
        Write-Error "The WorkspaceONE connection is currently only available with the GetDataOnly switch. Please use the switch and try again."
        exit 1
    }
    Write-Host "Connecting to WorkspaceONE..."
    [PSCustomObject]$wsoConnection = Get-MMSBridgeSettings -ServiceName "Wso"
    Set-Variable -Name "WSO" -Value $wsoConnection -Scope Script
}
#endregion
