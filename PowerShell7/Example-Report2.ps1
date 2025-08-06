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


    # QUERY FOR ALL ASSETS
    $Query1 = get-dm `
    -Version 2 `
    -Endpoint "assets"

    # ITERATE OVER THE ASSETS
    for($i=0;$i -lt $Query1.length;$i++) {
        Write-Progress `
            -Activity "Collecting asset information: $($i) of $($Query1.length)" `
            -Status "$([math]::Round(($i/$Query1.length)*100,2))%" `
            -PercentComplete $([math]::Round(($i/$Query1.length)*100,2))

        if(!$null -eq $Query1[$i].lastAvailableCopyTime) {   
            # QUERY FOR THE LAST COPY
            $Query2 = get-dm `
            -Version 2 `
            -Endpoint "latest-copies?filter=assetId eq `"$($Query1[$i].id)`""
            # THROTTLE API REQUESTS
            Start-Sleep -Seconds 1
        }

        $assetHost = $null
        switch($Query1[$i].type) {
            'FILE_SYSTEM' {
                $assetHost = $Query1[$i].details.fileSystem.clusterName
                break;
            }
            'KUBERNETES' {
                $assetHost = $Query1[$i].details.k8s.inventorySourceName
                break;
            }
            'NAS_SHARE' {
                $assetHost = $Query1[$i].details.nasShare.nasServer.name
                break;
            }
            'VMAX_STORAGE_GROUP' {
                $assetHost = $Query1[$i].details.vmaxStorageGroup.coordinatingHostname
                break;
            }
            'VMWARE_VIRTUAL_MACHINE'{
                $assetHost = $Query1[$i].details.vm.hostName
                break;
            }
            default {
                $assetHost = $Query1[$i].details.database.clusterName
                break;
            }
        }

        # CREATE A CUSTOM OBJECT
        $object = [ordered]@{
            assetHost = $assetHost
            assetId = $Query1[$i].id
            assetName = $Query1[$i].name
            assetType = $Query1[$i].type
            policyId = $Query1[$i].protectionPolicy.id
            policyName = $Query1[$i].protectionPolicy.name
            copyId = $Query2.id
            copyTimeUTC = $Query1[$i].lastAvailableCopyTime
            copySizeBytes = $Query2.copySize
            copyType = $Query2.copyType
            copyCreateTimeUTC = $Query2.createTime
            copyRetentionTimeUTC = $Query2.retentionTime
        }
        # ADD OBJECT TO THE REPROT
        $Report += (New-Object -TypeName psobject -Property $object)
    }

    # DISPLAY IN THE CONSOLE
    $Report | Export-Csv .\Example-Report2.csv

    # LOG OFF OF THE REST API
    disconnect-dmapi
}