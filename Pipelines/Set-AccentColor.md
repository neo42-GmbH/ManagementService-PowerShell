# Set-AccentColor
The `Set-AccentColor` script sets the accent color of the deployment dialogs of a neo42 package the same way the `Prepare Corporate Identity` pipeline task does. It supports PSADT v3 (PackageFramework 3.0) and PSADT v4 (PackageFramework 4.0) based packages.
It replaces `Replace text in file` tasks that patch the `MainColor` resource in `AppDeployToolkit\CustomAppDeployToolkitUi.ps1`, which only work for PSADT v3 based packages.

The logos of the deployment dialogs are not part of this script, use [`Merge-FilesToPackageV4.ps1`](Merge-FilesToPackageV4.md) for them.



## Behavior per package framework
- **PSADT v3 (PackageFramework 3.0)**: Replaces the `MainColor` resource in `AppDeployToolkit\CustomAppDeployToolkitUi.ps1` of the package. If the file carries no `MainColor` resource, a warning is written and the file is left unchanged.
- **PSADT v4 (PackageFramework 4.0)**: Writes `UI.FluentAccentColor` into `Overrides.AccentColor\Config\config.psd1` of the package. Both the Fluent dialogs and the neo42 legacy dialog read the accent color from this value. An existing `Overrides.AccentColor` directory is replaced.

  The directory only carries the accent color, so it never overwrites the logos `Merge-FilesToPackageV4.ps1` writes to `Overrides.Branding`. If the `Prepare Corporate Identity` pipeline task brands the same package, its accent color wins.

For packages without toolkit such as neo42 tools (PackageFramework 0.1) the script does nothing and the task succeeds.



## Accent color
The `-AccentColor` parameter accepts the following notations:

| Notation                                       | Example                                  |
|------------------------------------------------|------------------------------------------|
| Three RGB values from 0 to 255, separated by comma, semicolon or space | `227,0,15`, `227;0;15`, `227 0 15` |
| Six hex digits with an optional `#` or `0x` prefix | `#E3000F`, `0xE3000F`, `E3000F`      |
| Eight hex digits with the opaque alpha channel `FF`, as written in a `config.psd1` | `0xFFE3000F` |

Always quote the value, an unquoted `#` starts a PowerShell comment.



## Usage example within the APC
*It is recommended to store the accent color in a global pipeline variable, so all pipelines use the same color. We assume you have added a global pipeline variable with the key `AccentColor` in the APC menu `Configuration / Pipeline variables`.*
1. Download the script to a filesystem accessible by the MMS Server, e.g. `<Global.GeneralDirectory>`.
2. Add a `Run script` task to your product automation pipeline.

   *Make sure the package is already extracted when this task is called*
3. Use the parameters as *reference*:
   - **Type**: PowerShell
   - **ExecutionPolicy**: Bypass
   - **Scriptfile**: `<Global.GeneralDirectory>\Set-AccentColor.ps1`
   - **ScriptArguments**:
```
-PackagePath "<Phase.PackagePath>\<Run.Version>"
-PackageFramework "<Run.PackageFramework>"
-AccentColor "<Global.AccentColor>"
```
4. Save the updated pipeline.

Instead of a `Run script` task you can use a `Run inline script` task with the content of the script and the same arguments. In this case do not change the code of the script: an unchanged script is run as is, while pipeline variables are expanded in a changed one, which breaks its regular expressions.



## Migration from Replace text in file
The neo42 Management Service 5.0 detects `Replace text in file` tasks that only set the `MainColor` in `CustomAppDeployToolkitUi.ps1` and offers to migrate them in the `PSADT v4 migration` dialog. The migration converts the task into a `Run inline script` task running `Set-AccentColor.ps1`. If the task took the color from a global pipeline variable, the color is passed through the global pipeline variable `AccentColor`, otherwise as literal value.



## References
For a full reference to the available parameters, please consult the [scriptfile](Set-AccentColor.ps1) itself.
