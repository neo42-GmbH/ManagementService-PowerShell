param(
    $AppName,
    $CI_UniqueID,
    $SiteServer,
    $SiteCode
)
#Arguments to add to the Inline-Script PipelineTask: -AppName "Prefix_<Run.Developer> <Run.Product> <Run.Version>" -CI_UniqueID '<Run.ConfigMgrApplicationUniqueId>' -SiteServer "CM1.corp.contoso.com" -SiteCode "CHQ"
#use your own SiteCode and SiteServer
$ModelName = "$(($CI_UniqueID -split ":")[0])/$(($CI_UniqueID -split ":")[1])"
Start-Process -PassThru -FilePath "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-executionpolicy","bypass","-File","C:\neo42\ConfigMgrScripts\RenameCMApplication.ps1","-AppName","""$AppName""","-ModelName","$ModelName","-SiteServer","$SiteServer","-SiteCode","$SiteCode"
