# Merge-FilesToPackageV4
The `Merge-FilesToPackageV4` script copies user defined files, folders and logos into a neo42 package. It supports PSADT v3 (PackageFramework 3.0) and PSADT v4 (PackageFramework 4.0) based packages and replaces the obsolete [`Merge-FilesToPackage.ps1`](Merge-FilesToPackage.pdf), which only supports PSADT v3 based packages.
Its main use case is the integration into the neo42 Application Package Center (APC) pipelines.

The accent color of the deployment dialogs is not part of this script, use [`Set-AccentColor.ps1`](Set-AccentColor.md) for it.



## Prerequisites
1. Create a directory on the filesystem of the MMS/APC server that holds all package assets, e.g. `C:\neo42\General`.
2. In the APC menu `Configuration / Pipeline variables` add a global pipeline variable with the key `GeneralDirectory` and the path of this directory as value. It is referenced as `<Global.GeneralDirectory>` in the pipelines.

   *The path has to be absolute, either with a drive letter or as UNC path.*
3. Download the script to this directory.



## Usage example within the APC
1. Add a `Run script` task to your product automation pipeline.

   *Make sure the package is already extracted when this task is called*
2. Use the parameters as *reference*:
   - **Type**: PowerShell
   - **ExecutionPolicy**: Bypass
   - **Scriptfile**: `<Global.GeneralDirectory>\Merge-FilesToPackageV4.ps1`
   - **ScriptArguments**:
```
-PackagePath "<Phase.PackagePath>\<Run.Version>"
-GlobalGeneralDirectory "<Global.GeneralDirectory>"
-PackageFramework "<Run.PackageFramework>"
```
3. Save the updated pipeline.

On the next run the script creates the folder structure described below in `<Global.GeneralDirectory>`. Put your files into the folders of the product and they are copied into every package of the product the pipeline builds.

For packages without toolkit such as neo42 tools (PackageFramework 0.1) the script does nothing and the task succeeds.



## Folder structure
The product folders are named `<AppVendor> <AppName>` as found in the `neo42PackageConfig.json` of the package, e.g. `Notepad++ Team Notepad++ x64`.
```
<Global.GeneralDirectory>
├── Logos
│   ├── CustomAppDeployToolkitBanner.png
│   ├── CustomAppDeployToolkitBanner_dark.png
│   └── CustomAppDeployToolkitLogo.png
└── CustomFiles
    ├── <AppVendor> <AppName>                   PSADT v3 (PackageFramework 3.0)
    │   ├── AppDeployToolkit
    │   ├── Files
    │   └── SupportFiles
    │       └── User
    └── 4.0
        └── <AppVendor> <AppName>               PSADT v4 (PackageFramework 4.0)
            ├── Files
            ├── SupportFiles
            │   └── User
            └── Overrides.Branding
                └── Assets
```

### PSADT v3 (PackageFramework 3.0)
The script behaves like the obsolete `Merge-FilesToPackage.ps1`:
- The logos in `Logos` are copied into the `AppDeployToolkit` folder of the product.
- The folders `AppDeployToolkit`, `Files` and `SupportFiles` of the product are copied into the package.

### PSADT v4 (PackageFramework 4.0)
- The product folders are located below `CustomFiles\4.0`, because files for PSADT v3 based packages do not necessarily work in PSADT v4 based packages.
- As long as the `Files` or `SupportFiles` folder of a 4.0 product folder does not exist, it is created as a complete copy of the same folder of the PSADT v3 product folder. Afterwards both product folders are maintained independently, files you delete from the 4.0 product folder stay deleted.
- The content of the folders `Files` and `SupportFiles` of the product is copied into the `Files` and `SupportFiles` folders of the package.
- The logos in `Logos` are copied into `Overrides.Branding\Assets` of the product with the file names PSADT v4 expects:

  | Logos                                   | Overrides.Branding\Assets |
  |-----------------------------------------|---------------------------|
  | `CustomAppDeployToolkitLogo.png`        | `Logo.png`                |
  | `CustomAppDeployToolkitBanner.png`      | `Banner.Classic.png`      |
  | `CustomAppDeployToolkitBanner_dark.png` | `Banner.Classic.Dark.png` |

  A logo found in `Logos` overwrites the one of the product on every run. If a logo is missing in `Logos`, the logo of the product is used if present.
- The logos are written into the package directory `Overrides.Branding` together with a `Config\config.psd1` that references them. An existing `Overrides.Branding` directory of the package is replaced. If no logos are found at all, the package keeps its own logos.



## Migration from Merge-FilesToPackage.ps1
The neo42 Management Service 5.0 detects pipeline tasks that still use the obsolete `Merge-FilesToPackage.ps1` and offers to migrate them in the `PSADT v4 migration` dialog. The migration writes `Merge-FilesToPackageV4.ps1` next to the existing script and adds the `-PackageFramework` argument to the task.

To migrate a task manually, change the **Scriptfile** to `Merge-FilesToPackageV4.ps1` and add `-PackageFramework "<Run.PackageFramework>"` to the **ScriptArguments**. Your existing PSADT v3 product folders are used as they are, the 4.0 product folders are created from them on the first run for a PSADT v4 based package.



## References
For a full reference to the available parameters, please consult the [scriptfile](Merge-FilesToPackageV4.ps1) itself.
