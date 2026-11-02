# Add-ContentToCustomFunctionV4
The `Add-ContentToCustomFunctionV4` script was developed to allow automated injections of user scripts into the designated hook functions inside the `Deploy-Application.ps1` of PSADT-based neo42 packages. It supports PSADT v3 (PackageFramework 3.0) and PSADT v4 (PackageFramework 4.0) based packages and replaces the obsolete [`Add-ContentToCustomFunction.ps1`](Add-ContentToCustomFunction.md), which only supports PSADT v3 based packages.
Its main use case is the integration into the neo42 Application Package Center (APC) pipelines.



## Content per package framework
Code written for PSADT v3 does not run in a PSADT v4 based package and vice versa. Therefore a content file is resolved per package framework:
- **PSADT v3 (PackageFramework 3.0)**: the file passed as `-ContentFile` itself
- **PSADT v4 (PackageFramework 4.0)**: the file with the same name in a `4.0` subfolder next to the file passed as `-ContentFile`

```
<GLOBAL.MYSCRIPTSTORAGE>
└── Google Chrome
    ├── CustomCode.ps1          PSADT v3 (PackageFramework 3.0)
    └── 4.0
        └── CustomCode.ps1      PSADT v4 (PackageFramework 4.0)
```
There is no fallback from one package framework to the other. If the file of the package framework does not exist, the task fails. If nothing should be added to PSADT v4 based packages, place an empty file in the `4.0` subfolder.

Content passed as string with `-Content` is inserted as is for every package framework.

For packages without toolkit such as neo42 tools (PackageFramework 0.1) the script does nothing and the task succeeds.



## Usage example within the APC
*It is recommended to have a central directory on the filesystem of the MMS/APC that contains all statically served files such as scripts, images and other assets. We assume you have this directory set up and the path to it is defined in a global variable.*
1. Download the script to a filesystem accessible by the MMS Server
2. Add a `Run script` task.

   *Make sure the package is already extracted when this task is called*
3. Use the parameters as *reference*:
   - **Type**: PowerShell
   - **ExecutionPolicy**: Bypass
   - **Scriptfile**: `<GLOBAL.MYSCRIPTSTORAGE>\Add-ContentToCustomFunctionV4.ps1`
   - **ScriptArguments**:
```
-DeployApplicationFile "<Phase.PackagePath>\<Run.Version>\Deploy-Application.ps1"
-FunctionName "CustomInstallAndReinstallAndSoftMigrationEnd"
-ContentFile "<GLOBAL.MYSCRIPTSTORAGE>\Google Chrome\CustomCode.ps1"
-PackageFramework "<Run.PackageFramework>"
```
4. Save the updated pipeline.

With this above example the content of `Google Chrome\CustomCode.ps1` (PSADT v3) or `Google Chrome\4.0\CustomCode.ps1` (PSADT v4) will be injected to the start of the function `CustomInstallAndReinstallAndSoftMigrationEnd` on every run of this pipeline. You can optionally specify `-InsertAtEnd` to write to the end of the function.



## Insert position
- **Start of the function** (default): after the `#region <FunctionName> content` marker of the function. Without the marker, after the `$script:installPhase` assignment (PSADT v3 only), the `param` block or at the very beginning of the function body.
- **End of the function** (`-InsertAtEnd`): before the `#endregion <FunctionName> content` marker of the function. Without the marker, at the very end of the function body.



## Validation
The `Deploy-Application.ps1` is only changed if all checks pass, otherwise the task fails:
- The `Deploy-Application.ps1` and the content must be valid PowerShell code.
- The content must not contain a `#Requires` statement, because it would apply to the whole `Deploy-Application.ps1`.
- The custom function must exist in the `Deploy-Application.ps1`.
- The `Deploy-Application.ps1` must still be valid PowerShell code after the content was inserted.

The content is only checked for syntax errors. It is not checked whether the commands it uses exist in the toolkit of the package.

A byte order mark decides the encoding of a content file. Without one, the file is read as UTF-8 if it is valid UTF-8, otherwise as ANSI.



## Migration from Add-ContentToCustomFunction.ps1
The neo42 Management Service 5.0 detects pipeline tasks that still use the obsolete `Add-ContentToCustomFunction.ps1` and offers to migrate them in the `PSADT v4 migration` dialog. The migration writes `Add-ContentToCustomFunctionV4.ps1` next to the existing script and adds the `-PackageFramework` argument to the task.

To migrate a task manually, change the **Scriptfile** to `Add-ContentToCustomFunctionV4.ps1` and add `-PackageFramework "<Run.PackageFramework>"` to the **ScriptArguments**.

In both cases, the existing content file is used for PSADT v3 based packages. Create the PSADT v4 version of it in the `4.0` subfolder before the first PSADT v4 based package is built.



## References
For a full reference to the available parameters, please consult the [scriptfile](Add-ContentToCustomFunctionV4.ps1) itself.

For all hook functions, consult the `Deploy-Application.ps1` of a recent package of the respective package framework. For PSADT v3 based packages see [`Deploy-Application.ps1`](https://github.com/neo42-GmbH/PSAppDeployToolKitExtensions/blob/production/Deploy-Application.ps1).
