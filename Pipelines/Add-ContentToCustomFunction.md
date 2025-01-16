# Add-ContentToCustomFunction
The `Add-ContentToCustomFunction` script was developed to allow automated injections of user scripts into the designated hook functions inside the PSADT-based packages.
It's main use case is the integration into the neo42 Application Package Center (APC) pipelines.



## Usage example within the APC
*It is recommended to have a central directory on the filesystem of the MMS/APC that contains all staticly served files such as scripts, images and other assets. We assume you have this directory set up and the path to it is defined in a global variable.*
1. Download the script to a filesystem accessable my the MMS Server
2. Add a `Script execution` task.
   
   *Make sure the package is already extracted when this task is called*
3. Use the parameters as *reference*:
   - **Type**: PowerShell
   - **ExecutionPolicy**: Bypass
   - **Scriptfile**: `<GLOBAL.MYSCRIPTSTORAGE>\ADD-CONTENTTOCUSTOMFUNCTION.PS1`
   - **ScriptArguments**: 
```
-DeployApplicationFile "<Phase.PackagePath>\<Run.Version>\Deploy-Application.ps1" 
-FunctionName "CustomInstallAndReinstallAndSoftMigrationEnd"
-ContentFile "<GLOBAL.MYSCRIPTSTORAGE>\CustomCode.ps1"
```
4. Save the updated pipeline.
  
With this above example the content of `CustomCode.ps1` will be injected to the start of the function `CustomInstallAndReinstallAndSoftMigrationEnd` on every run of this pipeline. You can optionally specify `-InsertAtEnd` to write to the end of the function. 


## References
For a full reference to the available parameters, please consult the [scriptfile](Pipelines/Add-ContentToCustomFunction.ps1) itself.

For all hook functions, consult the content of the any recent [`Deploy-Application.ps1`](https://github.com/neo42-GmbH/PSAppDeployToolKitExtensions/blob/production/Deploy-Application.ps1) file. 