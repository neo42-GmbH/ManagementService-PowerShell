# Neo42 MMS API PowerShell Module
# UTF-8 with BOM for PowerShell 5.1 compatibility

# Load required assemblies for PowerShell 5.1
Add-Type -AssemblyName System.Web

# Module variables
$script:DefaultHeaders = @{
    'X-Neo42-Auth' = 'Admin'
    'Content-Type' = 'application/json'
}

$script:ServerName = $null

# Enum for cleanup actions
# Guard against re-loading when the module is re-imported in the same session:
# Add-Type registers the type AppDomain-wide and cannot be unloaded.
if (-not ([System.Management.Automation.PSTypeName]'CleanupAction').Type) {
    Add-Type -TypeDefinition @"
        public enum CleanupAction
        {
            NoAssignmentInstallApproved = 1,
            NoAssignmentNoInstallApproved = 2,
            AllPackages = 3
        }
"@
}

#region Helper Functions

function Set-Neo42ServerName {
    <#
    .SYNOPSIS
    Sets the server name for all API calls

    .PARAMETER ServerName
    The server name (e.g. "https://myserver.com")
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerName
    )

    $script:ServerName = $ServerName.TrimEnd('/')
    Write-Verbose "Server set to: $script:ServerName"
}

function Get-Neo42ServerName {
    <#
    .SYNOPSIS
    Returns the currently configured server name
    #>
    return $script:ServerName
}

function Invoke-Neo42ApiRequest {
    <#
    .SYNOPSIS
    Internal helper function for API calls - PowerShell 5.1 compatible
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $false)]
        [string]$Method = 'GET',

        [Parameter(Mandatory = $false)]
        [hashtable]$Body = $null,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers = $script:DefaultHeaders
    )

    if (-not $script:ServerName) {
        throw "ERROR: No server configured. Use Set-Neo42ServerName first."
    }

    $uri = "$script:ServerName$Endpoint"

    try {
        # PowerShell 5.1 compatible parameters
        $params = @{
            Uri = $uri
            Method = $Method
            Headers = $Headers
            UseDefaultCredentials = $true
            UseBasicParsing = $true  # Important for PowerShell 5.1 server environments
        }

        # Body handling for PowerShell 5.1
        if ($Body) {
            if ($Method -eq 'GET') {
                Write-Warning "Body is ignored for GET requests"
            } else {
                $jsonBody = $Body | ConvertTo-Json -Depth 10 -Compress
                $params.Body = $jsonBody
                # Set Content-Type explicitly when a body is present
                if (-not $params.Headers.ContainsKey('Content-Type')) {
                    $params.Headers = $params.Headers.Clone()
                    $params.Headers['Content-Type'] = 'application/json; charset=utf-8'
                }
            }
        }

        # Timeout for long requests
        $params.TimeoutSec = 300

        Write-Verbose "API call: $Method $uri"
        if ($Body) {
            Write-Verbose "Body: $($jsonBody.Length) characters"
        }

        # PowerShell 5.1 Invoke-RestMethod with error handling
        $response = Invoke-RestMethod @params -ErrorAction Stop

        Write-Verbose "API response received successfully"
        return $response
    }
    catch [System.Net.WebException] {
        $errorDetails = ""
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode
            $statusDescription = $_.Exception.Response.StatusDescription
            $errorDetails = "HTTP $([int]$statusCode) - $statusDescription"

            # Read response stream if available
            try {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $responseText = $reader.ReadToEnd()
                $reader.Close()
                if ($responseText) {
                    $errorDetails += " | Response: $responseText"
                }
            } catch {
                # Stream could not be read
            }
        }

        Write-Error "Web error at $uri : $errorDetails"
        Write-Error "Original exception: $($_.Exception.Message)"
        throw
    }
    catch [System.Management.Automation.ParameterBindingException] {
        Write-Error "Parameter error at $uri : $($_.Exception.Message)"
        Write-Error "Tip: Verify the parameters for PowerShell 5.1 compatibility"
        throw
    }
    catch {
        Write-Error "Unexpected API error at $uri : $($_.Exception.Message)"
        Write-Error "Exception type: $($_.Exception.GetType().Name)"
        if ($_.Exception.InnerException) {
            Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
        }
        throw
    }
}

#endregion

#region Tenant Functions

function Get-MmsApcEmpCleanupTenant {
    <#
    .SYNOPSIS
    Retrieves tenant information from the APC API

    .DESCRIPTION
    This function can retrieve tenant information based on different criteria:
    - All tenants
    - Filter by tenant name
    - Retrieve a specific tenant by GUID

    .PARAMETER TenantName
    Optional: Filters by a specific tenant name

    .PARAMETER TenantGuid
    Optional: Retrieves a specific tenant by GUID

    .PARAMETER All
    Optional: Retrieves all available tenants

    .EXAMPLE
    Get-ApcTenant -All
    Retrieves all tenants

    .EXAMPLE
    Get-ApcTenant -TenantName "MyTenantName"
    Retrieves the tenant with the name "MyTenantName"

    .EXAMPLE
    Get-ApcTenant -TenantGuid "12345678-1234-1234-1234-123456789012"
    Retrieves the tenant with the specified GUID
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [string]$TenantName,

        [Parameter(ParameterSetName = 'ByGuid', Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantGuid,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )



    try {
        switch ($PSCmdlet.ParameterSetName) {
            'ByName' {

                $endpoint = "/api/apc/tenant?tenantName=$([System.Web.HttpUtility]::UrlEncode($TenantName))"
            }
            'ByGuid' {

                $endpoint = "/api/apc/tenant/$TenantGuid"
            }
            'All' {

                $endpoint = "/api/apc/tenant/all"
            }
        }

        $result = Invoke-Neo42ApiRequest -Endpoint $endpoint

        if ($result.Success) {

            # Remove the Id field, TenantId is sufficient
            $cleanedResult = $result.Item | Select-Object -Property * -ExcludeProperty Id
            return $cleanedResult
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error retrieving tenant data: $($_.Exception.Message)"
        throw
    }
}

function Get-MmsApcEmpCleanupPackageList {
    <#
    .SYNOPSIS
    Retrieves Empirum package cleanup items

    .DESCRIPTION
    This function retrieves Empirum package items based on the cleanup action.
    Uses a real PowerShell enum for type-safe parameters.

    .PARAMETER Action
    The type of cleanup action as an enum value:
    - [CleanupAction]::NoAssignmentInstallApproved (1)
    - [CleanupAction]::NoAssignmentNoInstallApproved (2)
    - [CleanupAction]::AllPackages (3)

    .PARAMETER TenantId
    The tenant ID for the query

    .EXAMPLE
    Get-MmsApcEmpCleanUpPackagelist -Action ([CleanupAction]::NoAssignmentInstallApproved) -TenantId "0082d481-1084-4494-bc1d-222b6df976f7"
    Retrieves packages with "No assignment / Install approved" (enum)

    .EXAMPLE
    Get-MmsApcEmpCleanUpPackagelist -Action AllPackages -TenantId "0082d481-1084-4494-bc1d-222b6df976f7"
    Retrieves all packages (enum name without brackets)

    .EXAMPLE
    Get-MmsApcEmpCleanUpPackagelist -Action 3 -TenantId "0082d481-1084-4494-bc1d-222b6df976f7"
    Retrieves all packages (enum value as number)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [CleanupAction]$Action,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId
    )

    $actionDescriptions = @{
        1 = "No assignment / Install approved"
        2 = "No assignment / No install approved"
        3 = "All packages"
    }

    $actionNumber = [int]$Action
    $actionName = $Action.ToString()





    try {
        $endpoint = "/api/apc/EmpirumCleanup/CleanupItems?cleanupAction=$actionNumber&tenantId=$([System.Web.HttpUtility]::UrlEncode($TenantId))"

        $result = Invoke-Neo42ApiRequest -Endpoint $endpoint

        if ($result.Success) {
            $itemCount = if ($result.Item) { $result.Item.Count } else { 0 }

            return $result.Item
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error retrieving package list: $($_.Exception.Message)"
        throw
    }
}

function New-MmsApcEmpCleanupJob {
    <#
    .SYNOPSIS
    Creates a new Empirum package cleanup job

    .DESCRIPTION
    This function creates a new cleanup job with the specified CleanupAction and TenantId.

    .PARAMETER TenantId
    The tenant ID for which the job should be created

    .PARAMETER CleanupAction
    The type of cleanup action as an enum value

    .EXAMPLE
    New-MmsApcEmpCleanupJob -TenantId "0082d481-1084-4494-bc1d-222b6df976f7" -CleanupAction AllPackages
    Creates a new cleanup job for all packages
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [CleanupAction]$CleanupAction
    )

    $actionNumber = [int]$CleanupAction
    $actionName = $CleanupAction.ToString()





    try {
        $requestBody = @{
            TenantId = $TenantId
            CleanupAction = $actionNumber
        }

        $result = Invoke-Neo42ApiRequest -Endpoint "/api/apc/EmpirumCleanupJob" -Method "POST" -Body $requestBody

        if ($result.Success) {
            $jobId = $result.Item

            return $jobId
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error creating cleanup job: $($_.Exception.Message)"
        throw
    }
}

function Start-MmsApcEmpCleanupJob {
    <#
    .SYNOPSIS
    Starts an Empirum package cleanup job

    .DESCRIPTION
    This function starts a previously created cleanup job with the selected packages.

    .PARAMETER JobId
    The ID of the job to start

    .PARAMETER EmpirumCleanupItems
    Array of EmpirumCleanupItem objects to be cleaned up

    .PARAMETER DuplicatesFound
    Indicates whether duplicates were found (optional, default: false)

    .EXAMPLE
    $packages = Get-MmsApcEmpCleanupPackageList -Action AllPackages -TenantId "..."
    Start-MmsApcEmpCleanupJob -JobId "job-id" -EmpirumCleanupItems $packages
    Starts the cleanup job with the selected packages
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$JobId,

        [Parameter(Mandatory = $true)]
        [array]$EmpirumCleanupItems,

        [Parameter(Mandatory = $false)]
        [bool]$DuplicatesFound = $false
    )

    $itemCount = if ($EmpirumCleanupItems) { $EmpirumCleanupItems.Count } else { 0 }






    try {
        $requestBody = @{
            JobId = $JobId
            EmpirumCleanupItems = $EmpirumCleanupItems
            DuplicatesFound = $DuplicatesFound
        }

        $result = Invoke-Neo42ApiRequest -Endpoint "/api/apc/EmpirumCleanup/StartEmpirumCleanupJob" -Method "POST" -Body $requestBody

        if ($result.Success) {

            return $result
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error starting cleanup job: $($_.Exception.Message)"
        throw
    }
}

function Get-MmsApcEmpCleanupJob {
    <#
    .SYNOPSIS
    Retrieves cleanup job information

    .DESCRIPTION
    This function can retrieve cleanup job information:
    - A specific job by ID
    - All jobs for a tenant

    .PARAMETER JobId
    Optional: The ID of a specific job

    .PARAMETER TenantId
    The tenant ID for which jobs should be retrieved

    .PARAMETER All
    Switch: Retrieves all jobs for the tenant

    .EXAMPLE
    Get-MmsApcEmpCleanupJob -JobId "job-guid" -TenantId "tenant-guid"
    Retrieves a specific job

    .EXAMPLE
    Get-MmsApcEmpCleanupJob -TenantId "tenant-guid" -All
    Retrieves all jobs for the tenant
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$JobId,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )



    try {
        switch ($PSCmdlet.ParameterSetName) {
            'ById' {

                $endpoint = "/api/apc/EmpirumCleanupJob/$JobId"
            }
            'All' {

                $endpoint = "/api/apc/EmpirumCleanupJob/all?tenantId=$([System.Web.HttpUtility]::UrlEncode($TenantId))"
            }
        }

        $result = Invoke-Neo42ApiRequest -Endpoint $endpoint

        if ($result.Success) {
            if ($PSCmdlet.ParameterSetName -eq 'ById') {

            } else {
                $jobCount = if ($result.Item) { $result.Item.Count } else { 0 }

            }
            return $result.Item
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error retrieving job information: $($_.Exception.Message)"
        throw
    }
}

function Get-MmsApcEmpCleanupProtocols {
    <#
    .SYNOPSIS
    Retrieves protocol entries for a specific Empirum package cleanup job

    .DESCRIPTION
    This function retrieves protocol entries for a given cleanup job.
    Entries are returned localized based on the specified culture code.

    .PARAMETER JobId
    The unique ID of the package cleanup job

    .PARAMETER CultureCode
    The culture code for protocol entry localization (optional, default: "en")
    Available values: "en" or "de"

    .PARAMETER FromDate
    The start date from which protocol entries should be retrieved (optional, default: 180 days ago)

    .EXAMPLE
    Get-MmsApcEmpCleanupProtocols -JobId "12345678-1234-1234-1234-123456789012"
    Retrieves protocol entries from the last 180 days with English localization

    .EXAMPLE
    Get-MmsApcEmpCleanupProtocols -JobId $jobId -CultureCode "de"
    Retrieves protocol entries with German localization

    .EXAMPLE
    $fromDate = (Get-Date).AddDays(-30)
    Get-MmsApcEmpCleanupProtocols -JobId $jobId -CultureCode "en" -FromDate $fromDate
    Retrieves English protocol entries from the last 30 days
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$JobId,

        [Parameter(Mandatory = $false)]
        [ValidateSet("en", "de")]
        [string]$CultureCode = "en",

        [Parameter(Mandatory = $false)]
        [DateTime]$FromDate = (Get-Date).AddDays(-180)
    )

    # Convert DateTime to UTC ticks
    $fromDateTicks = $FromDate.ToUniversalTime().Ticks






    try {
        $endpoint = "/api/apc/EmpirumCleanup/Protocols?jobId=$([System.Web.HttpUtility]::UrlEncode($JobId))&cultureCode=$([System.Web.HttpUtility]::UrlEncode($CultureCode))&fromDateTicks=$fromDateTicks"

        $result = Invoke-Neo42ApiRequest -Endpoint $endpoint

        if ($result.Success) {
            $protocolCount = if ($result.Item) { $result.Item.Count } else { 0 }

            return $result.Item
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error retrieving protocol entries: $($_.Exception.Message)"
        throw
    }
}

function Test-MmsApcEmpCleanupDuplicates {
    <#
    .SYNOPSIS
    Checks Empirum package items for duplicates

    .DESCRIPTION
    This function checks a list of Empirum package items for duplicates
    based on the specified criteria and returns any duplicates found.

    .PARAMETER TenantId
    The unique ID of the tenant

    .PARAMETER EmpirumCleanupItems
    Array of EmpirumCleanupItem objects to be checked for duplicates

    .PARAMETER JobId
    The unique ID of an existing cleanup job (required)

    .EXAMPLE
    $jobId = New-MmsApcEmpCleanupJob -TenantId $tenantId -CleanupAction AllPackages
    $packages = Get-MmsApcEmpCleanupPackageList -Action AllPackages -TenantId $tenantId
    Test-MmsApcEmpCleanupDuplicates -TenantId $tenantId -EmpirumCleanupItems $packages -JobId $jobId
    Checks the package list for duplicates using an existing job ID
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [array]$EmpirumCleanupItems,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$JobId
    )

    $itemCount = if ($EmpirumCleanupItems) { $EmpirumCleanupItems.Count } else { 0 }






    try {
        $requestBody = @{
            TenantId = $TenantId
            EmpirumCleanupItems = $EmpirumCleanupItems
            JobId = $JobId
        }

        $result = Invoke-Neo42ApiRequest -Endpoint "/api/apc/EmpirumCleanup/CheckForDuplicates" -Method "POST" -Body $requestBody

        if ($result.Success) {
            $duplicateCount = if ($result.Item) { $result.Item.Count } else { 0 }
            if ($duplicateCount -gt 0) {

            } else {

            }
            return $result.Item
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error checking for duplicates: $($_.Exception.Message)"
        throw
    }
}

function Remove-MmsApcEmpCleanupJob {
    <#
    .SYNOPSIS
    Deletes an Empirum package cleanup job

    .DESCRIPTION
    This function deletes an existing cleanup job by its unique ID.

    .PARAMETER JobId
    The unique ID of the cleanup job to delete

    .EXAMPLE
    Remove-MmsApcEmpCleanupJob -JobId "12345678-1234-1234-1234-123456789012"
    Deletes the cleanup job with the specified ID

    .EXAMPLE
    $jobs = Get-MmsApcEmpCleanupJob -TenantId $tenantId -All
    $jobs | ForEach-Object { Remove-MmsApcEmpCleanupJob -JobId $_.Id }
    Deletes all jobs for a tenant
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$JobId
    )




    if ($PSCmdlet.ShouldProcess("Job $JobId", "Delete")) {
        try {
            $endpoint = "/api/apc/EmpirumCleanupJob/$JobId"

            $result = Invoke-Neo42ApiRequest -Endpoint $endpoint -Method "DELETE"

            if ($result.Success) {

                return $result
            } else {
                Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
                return $null
            }
        }
        catch {
            Write-Error " Error deleting cleanup job: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-MmsApcEmpCleanupDirectorySize {
    <#
    .SYNOPSIS
    Calculates the size of a directory for Empirum package items

    .DESCRIPTION
    This function calculates the size of a specific directory
    in the context of Empirum package items for a given tenant.

    .PARAMETER Directory
    The directory path for which the size should be calculated

    .PARAMETER TenantId
    The unique ID of the tenant

    .EXAMPLE
    Get-MmsApcEmpCleanupDirectorySize -Directory "C:\Program Files\MyApp" -TenantId "12345678-1234-1234-1234-123456789012"
    Calculates the size of the specified directory

    .EXAMPLE
    $packages = Get-MmsApcEmpCleanupPackageList -Action AllPackages -TenantId $tenantId
    $packages | ForEach-Object { Get-MmsApcEmpCleanupDirectorySize -Directory $_.Directory -TenantId $tenantId }
    Calculates the size of all package directories
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$TenantId
    )





    try {
        $endpoint = "/api/apc/EmpirumCleanup/CalculateSize?directory=$([System.Web.HttpUtility]::UrlEncode($Directory))&tenantId=$([System.Web.HttpUtility]::UrlEncode($TenantId))"

        $result = Invoke-Neo42ApiRequest -Endpoint $endpoint

        if ($result.Success) {
            $sizeInBytes = $result.Item
            $sizeInMB = [Math]::Round($sizeInBytes / 1MB, 2)

            return $result.Item
        } else {
            Write-Warning " API response was unsuccessful: $($result.Error.Reason)"
            return $null
        }
    }
    catch {
        Write-Error " Error calculating directory size: $($_.Exception.Message)"
        throw
    }
}

#endregion

# Export functions
Export-ModuleMember -Function Set-Neo42ServerName, Get-Neo42ServerName, Get-MmsApcEmpCleanupTenant, Get-MmsApcEmpCleanupPackageList, New-MmsApcEmpCleanupJob, Start-MmsApcEmpCleanupJob, Get-MmsApcEmpCleanupJob, Get-MmsApcEmpCleanupProtocols, Test-MmsApcEmpCleanupDuplicates, Remove-MmsApcEmpCleanupJob, Get-MmsApcEmpCleanupDirectorySize
