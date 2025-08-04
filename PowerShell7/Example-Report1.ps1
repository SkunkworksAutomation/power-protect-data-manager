# IMPORT THE POWERSHELL 7 MODULE
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# DEFINE YOUR POWERPROTECT SERVERS
$Servers = @(
    "10.239.100.131"
)

# DEFINE YOUR REPORT VARIABLE
$Report = @()

# ITERATE OVER THE POWERPROTECT SERVERS
$Servers | foreach-object {
    # LOGIN INTO THE REST API
    connect-dmapi `
    -Server $_

    # DEFINE ANY FILTERS
    $Filters = @(
        "assetType eq `"HYPERV_VIRTUAL_MACHINE`")"
    )
    
    <#
        SOURCE: https://developer.dell.com/apis/4378/versions/19.20.0/reference/ppdm-public-v3.yaml/paths/~1api~1v3~1protection-policy-summaries/get
        The policyFilter supports filter based on the policy fields, which are invisible from policy summary. 
        For example, /api/v3/protection-policy-summaries?filter=numberOfAssets eq 2&policyFilter=objectives.config.backupMechanism eq "OIM"
    #>
    $policyFilter = @(
        "not purpose eq `"EXCLUSION`""
    )
    $Query1 = get-dm `
    -Version 3 `
    -Endpoint "protection-policy-summaries?filter=$($Filters)&policyFilter=$($policyFilter)&orderby=protectionPolicyName ASC"

    # DISPALY IN CONSOLE
    $Query1 | select-Object `
    protectionPolicyName,`
    assetType,`
    disabled,`
    purpose,`
    numberOfAssets |`
    Format-Table -autosize

    # DEFINE ANY FILTERS
    $Filters = @(
        "type eq `"$($Query1.assetType)`"",
        "and protectionStatus eq `"PROTECTED`""
    )
    $Query2 = get-dm `
    -Version 2 `
    -Endpoint "assets?filter=$($Filters)&orderby=name ASC"

    # DISPALY IN CONSOLE
    $Query2 | select-Object `
    name,`
    type,`
    protectionStatus |`
    Format-Table -autosize

    # LOG OFF OF THE REST API
    disconnect-dmapi
}