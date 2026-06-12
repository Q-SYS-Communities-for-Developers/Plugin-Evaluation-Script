#!/bin/bash
start_time=$(date +%s)  # Capture start time

# Usage: ./EvaluatePlugin.sh <path to plugin file> [other args]
# Example: ./EvaluatePlugin.sh "C:\Users\John.Doe\Documents\Temp\test.qplug"  Inputs=4

file="$1"
other_args=("${@:2}")
# print other args
echo "Other args: ${other_args[@]}"

if [ -f "$file" ]; then
  echo "File exists: $file"
  if test -f 'lua53.exe'; then
    PluginJson=$(./lua53.exe evaluateDesignTime.lua $file ${other_args[@]})
  elif test -f './eval/lua53.exe'; then
    PluginJson=$(./eval/lua53.exe ./eval/evaluateDesignTime.lua $file ${other_args[@]})
  else
    echo "lua53.exe not found"
    exit 1
  fi

  if [ -f "PluginEvalConfig.json" ]; then
    echo "Eval Config found, reading..."
    PluginEvalConfig=$(cat PluginEvalConfig.json)
  fi
  # Test for valid json
  if echo "$PluginJson" | jq . >/dev/null 2>&1 && [ ${#PluginJson} -gt 0 ]; then
    if echo "$PluginJson" | jq -e '. == {}' >/dev/null; then
      echo "Error running test.lua, empty JSON"
    else
      # Write to file for debugging, overwrites each time
      # echo $PluginJson > PluginJson.json
      # Ensure PluginJson.Warnings, PluginJson.Notices, and PluginJson.Errors exist
      PluginJson=$(echo $PluginJson | jq 'if .Warnings == null then .Warnings = [] else . end')
      PluginJson=$(echo $PluginJson | jq 'if .Notices == null then .Notices = [] else . end')
      PluginJson=$(echo $PluginJson | jq 'if .Errors == null then .Errors = [] else . end')
      echo ""
      echo "Properties:"
      echo $PluginJson | jq -r '.Properties[] | "Name: \"\(.Name)\" Type: \(.Type) Value: \(.Value)"'
      echo ""
      echo "There are $(echo $PluginJson | jq '[.Controls[].Count] | add') Controls"
      echo ""

      # Test for Controls without PrettyNames
      while IFS= read -r name; do
        # Check if control is in PrettyNamelessControls exception list
        if [ "$PluginEvalConfig" ]; then
          if echo "$PluginEvalConfig" | jq -e --arg name "$name" '.Exceptions.PrettyNamelessControls // [] | any(. == $name)' >/dev/null 2>&1; then
            continue
          fi
        fi
        # echo $name
        PluginJson=$(echo "$PluginJson" | jq --arg name "$name" '.Notices += ["Control without PrettyName: \($name)"]')
      done < <(echo "$PluginJson" | jq -r '.Layout | to_entries | .[] | select(.value.PrettyName == null) | .key' | sort | tr -d '\r')

      # Test for Controls with PinStyle explicitly set to "None"
      while IFS= read -r name; do
        # Check if control is in PinlessControls exception list
        if [ "$PluginEvalConfig" ]; then
          if echo "$PluginEvalConfig" | jq -e --arg name "$name" '.Exceptions.PinlessControls // [] | any(. == $name)' >/dev/null 2>&1; then
            continue
          fi
        fi
        # echo $name
        PluginJson=$(echo "$PluginJson" | jq --arg name "$name" '.Notices += ["Control PinStyle set to None: \($name)"]')
      done < <(echo "$PluginJson" | jq -r '.Controls[] | select(.PinStyle == "None") | .Name' | sort | tr -d '\r')

      # Test for Controls with missing (nil/null) PinStyle
      while IFS= read -r name; do
        # Check if control is in PinlessControls exception list
        if [ "$PluginEvalConfig" ]; then
          if echo "$PluginEvalConfig" | jq -e --arg name "$name" '.Exceptions.PinlessControls // [] | any(. == $name)' >/dev/null 2>&1; then
            continue
          fi
        fi
        # echo $name
        PluginJson=$(echo "$PluginJson" | jq --arg name "$name" '.Errors += ["Control without PinStyle: \($name)"]')
      done < <(echo "$PluginJson" | jq -r '.Controls[] | select(.PinStyle == null) | .Name' | sort | tr -d '\r')

      # Test for Controls with a '.' in the Name
      while IFS= read -r name; do
        PluginJson=$(echo "$PluginJson" | jq --arg name "$name" '.Warnings += ["Control with period in Name: \($name)"]')
      done < <(echo "$PluginJson" | jq -r '.Controls[] | select(.Name | contains(".") == true) | .Name' | sort | tr -d '\r')

      
      # Test for Controls with a ' ' in the Name if the config is not found or Exceptions.AllowSpacesInControlNames is not true
      if [ -z "$PluginEvalConfig" ] || ! echo "$PluginEvalConfig" | jq -e '.Exceptions.AllowSpacesInControlNames == true' >/dev/null; then
        while IFS= read -r name; do
          PluginJson=$(echo "$PluginJson" | jq --arg name "$name" '.Warnings += ["Control with space in Name: \($name)"]')
        done < <(echo "$PluginJson" | jq -r '.Controls[] | select(.Name | contains(" ") == true) | .Name' | sort | tr -d '\r')
      else
        echo "AllowSpacesInControlNames exception found, skipping space check"
        # add notice that space check is skipped
        PluginJson=$(echo "$PluginJson" | jq '.Notices += ["Skipping check for spaces in Control Names."]')
      fi

      # Test for layout items that are null and print the key
      while IFS= read -r key; do
        PluginJson=$(echo "$PluginJson" | jq --arg key "$key" '.Errors += ["Control without layout definition: \($key)"]')
      done < <(echo "$PluginJson" | jq -r '.Layout | to_entries[] | select(.value == null) | .key' | sort | tr -d '\r')

      # replace _ with . in control names
      PluginJson=$(echo "$PluginJson" | jq '(.Controls[] | select(.Name | contains("_") == true) | .Name) |= gsub("_"; ".")')

      # check for exceptions in optional PluginEvalConfig.json
      # exception:
      # type: "ControlKey", "LayoutKey"

      # ControlKey:
      #  value: "String" name of the control key to ignore
      # LayoutKey:
      #  value: "String" name of the layout key to ignore

      if [ "$PluginEvalConfig"  ]; then
        echo "Applying exceptions from PluginEvalConfig.json"
        # for each exception in PluginEvalConfig.json with type == "ControlKey", remove any Warnings or Notices that mention "Control key 'value'"
        # example json: {"Exceptions":[{"type":"ControlKey","value":"Attribute"},{"type":"ControlKey","value":"QsysControlName"},{"type":"ControlKey","value":"NameSuffixForControl"}]}
        # example warning to ignore: "Control key 'Attribute' is missing for Control 'MyControl'"
        while IFS= read -r exception; do
          type=$(echo "$exception" | jq -r '.type')
          value=$(echo "$exception" | jq -r '.value')
          if [ "$type" == "ControlKey" ]; then
            # remove any Warnings that mention "Control key 'value'" (note: lowercase 'key')
            PluginJson=$(echo "$PluginJson" | jq --arg value "$value" '.Warnings |= map(select(contains("Control key '\''" + $value + "'\''") | not))')
            PluginJson=$(echo "$PluginJson" | jq --arg value "$value" '.Notices |= map(select(contains("Control key '\''" + $value + "'\''") | not))')
          elif [ "$type" == "LayoutKey" ]; then
            PluginJson=$(echo "$PluginJson" | jq --arg value "$value" '.Warnings |= map(select(contains("Layout key '\''" + $value + "'\''") | not))')
            PluginJson=$(echo "$PluginJson" | jq --arg value "$value" '.Notices |= map(select(contains("Layout key '\''" + $value + "'\''") | not))')
          fi
        done < <(echo "$PluginEvalConfig" | jq -c '.Exceptions.KeyValues[]')
      fi


      # print Notices stored in $PluginJson.Notices
      if [ $(echo $PluginJson | jq '.Notices | length') -gt 0 ]; then
        echo ""
        echo "Notices:"
        echo $PluginJson | jq -r '.Notices[]'
      fi
      # print Warnings stored in $PluginJson.Warnings
      if [ $(echo $PluginJson | jq '.Warnings | length') -gt 0 ]; then
        echo ""
        echo "Warnings:"
        echo $PluginJson | jq -r '.Warnings[]'
      fi
      # print Errors stored in $PluginJson.Errors
      if [ $(echo $PluginJson | jq '.Errors | length') -gt 0 ]; then
        echo ""
        echo "Errors:"
        echo $PluginJson | jq -r '.Errors[]'
      fi
      if [ ! -d output ]; then
        mkdir output
      fi
      echo $PluginJson | jq > output/PluginJson.json
      # create file PLuginReport.json with only the notices, warnings, and errors
      echo $PluginJson | jq '{Notices: .Notices, Warnings: .Warnings, Errors: .Errors}' > output/PluginReport.json

    fi
  else
    echo "Invalid JSON or error running test.lua"
    echo "$PluginJson"
    exit 1
  fi
else
  echo "File does not exist: $file"
fi

end_time=$(date +%s)  # Capture end time
execution_time=$((end_time - start_time))  # Calculate execution time
echo ""
echo "Execution time: $execution_time seconds"  # Display execution time