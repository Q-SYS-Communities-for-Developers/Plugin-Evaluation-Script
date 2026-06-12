# Plugin Evaluation Script

## Setup and Requirements

- Before using install JQ [Install Instructions](https://jqlang.github.io/jq/download/)
  - this is pre-installed on GitHub hosted runners
- Tested using GitBash terminal on windows 11
- Bundled is the lua executable and json.lua that QDS uses at time of writing

## Usage

```./EvaluatePlugin.sh Path_to_file [-maxprops] [prop=value]```

-maxprops will set all booleans to true, and integers/doubles to their max values

Spaces in property name should be replaced with ```%20```

Examples:

- ```./EvaluatePlugin.sh ./test.qplug```
- ```./EvaluatePlugin.sh ./test.qplug -maxprops```
- ```./EvaluatePlugin.sh ./test.qplug Inputs=7 Poll%20Rate=10```
- ```./EvaluatePlugin.sh C:\Users\John.Doe\Documents\Temp\test.qplug```

### Using PluginEvalConfig.json

#### Settings

**VarsToReset**: List of variables to reset to their initial state before each call of a reserved function.

#### Exceptions

**KeyValues**: Used to ignore non-SDK key value pairs in GetControls and GetControlLayout. Defined by setting ```type``` to either *ControlKey* or *LayoutKey*.

Example:

``` json
{
  "Settings": {
    "VarsToReset": []
  },
  "Exceptions": {
    "KeyValues": [
      {
        "type": "ControlKey",
        "value": "IsShared"
      }
    ],
    "PrettyNamelessControls": [],
    "PinlessControls": [],
    "AllowSpacesInControlNames": false
  }
}
```

**PrettyNamelessControls**: List of control names to not warn about missing PrettyName definitions in GetControlLayout

**PinlessControls**: list of control names to not warn about missing control pin definitions.

**AllowSpacesInControlNames**: If ```true``` do not warn about controls with spaces in their names

## Outputs

### /output/PluginJson.json

This is a json representation of all controls, graphics, properties, pins, pages, errors, notices, warnings, and info

### /output/PluginReport.json

This is a json of only the Notices, Warnings, and Errors that are outputted by the script.

## Known Issues and Behaviors

- The script will fail if you have any print statements during design time
- This script does not close and rerun lua like Designer does for each reserved function call. If a global variable is modified in a reserved function you may need to add it to Settings.VarsToReset in PluginEvalConfig.json

## Support

All support issues, bug reports, and feature requests should be entered as ['issues'](https://github.com/Q-SYS-Communities-for-Developers/Plugin-Evaluation-Script/issues) on this repository. Please do not reach directly to QSC Support for issues regarding this utility.
