#!/bin/bash
set -e

currentFolder="$(pwd)"
publicFolder="$currentFolder/public"
allFolders=()

# Finds all directories containing openapi.yaml files in currentFolder and returns their paths as an array
findAllOpenApiYamlDirs() {
    local -n resultRef=$1

    resultRef=()
    while IFS= read -r -d '' dir; do
        # Remove the $currentFolder prefix and leading slash if present
        rel_dir="${dir#$currentFolder/}"
        resultRef+=("$rel_dir")
    done < <(find "$currentFolder" -type f -name "openapi.yaml" -print0 | xargs -0 -n1 dirname -z | sort -zu)
}

# Creates static html files for openapi.yaml file in the current directory
loadStaticHtmlToFolder() {
    local folder="$1"

    echo "Creating folder \"$publicFolder/$folder\""
    mkdir -p "$publicFolder/$folder"

    echo "Running redocly/cli build-docs command on \"$currentFolder/$folder/openapi.yaml\" and saving it to \"$publicFolder/$folder/index.html\""
    npx @redocly/cli@latest build-docs "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/index.html"
}

# Generates a high-level index for the Redoc static HTML documentation.
# This function is intended to be used within the create-redoc-static-htm.sh script
# to automate the creation of an overview or entry point for the generated API docs.
# Usage: generateHighLevelIndex
generateHighLevelIndex() {
    local indexFile="$publicFolder/index.html"
    echo "<!DOCTYPE html>
<html>
<head>
    <meta charset=\"UTF-8\">
    <title>API Documentation Index</title>
</head>
<style>
   body {
        font-family: Arial, sans-serif;
        margin-left: 20px;
    }
    p {
        max-width: 520px;
    }
    img.logo {
        max-height: 100px;
        margin-top: 10px;
        margin-bottom: 10px;
    }
</style>
<body>
    <img class="logo" src="assets/DSDC-LTL.svg" alt="Company Logo">
    <p>Supported by the Digital Standard Development Council's (DSDC) Digital LTL Council, these API standards help organizations modernize LTL workflows through standardized, open, and scalable integration.</p>
    <h1>API Documentation Index</h1>
    <ul>" > "$indexFile"

    # Build a tree structure from allFolders
    declare -A tree
    for dir in "${allFolders[@]}"; do
        IFS='/' read -ra parts <<< "$dir"
        if [[ ${#parts[@]} -eq 2 ]]; then
            parent="${parts[0]}"
            child="${parts[1]}"
            tree["$parent"]+="$child "
        elif [[ ${#parts[@]} -eq 1 ]]; then
            tree["${parts[0]}"]=""
        fi
    done

    # Output the tree as nested lists
    for parent in "${!tree[@]}"; do
        echo "        <li>$parent" >> "$indexFile"
        if [[ -n "${tree[$parent]}" ]]; then
            echo "            <ul>" >> "$indexFile"
            for child in ${tree[$parent]}; do
                if [[ -f "$publicFolder/$parent/$child/index.html" ]]; then
                    echo "                <li><a href=\"$parent/$child/index.html\">$child</a></li>" >> "$indexFile"
                fi
            done
            echo "            </ul>" >> "$indexFile"
        else
            if [[ -f "$publicFolder/$parent/index.html" ]]; then
                echo "            <ul><li><a href=\"$parent/index.html\">$parent</a></li></ul>" >> "$indexFile"
            fi
        fi
        echo "        </li>" >> "$indexFile"
    done

    echo "    </ul>
</body>
</html>" >> "$indexFile"
    echo "Created high level index at \"$indexFile\""
}

copyAssets() {
    echo "Copying assets..."
    mkdir -p "$publicFolder/assets"
    cp "$currentFolder/assets/DSDC-LTL.svg" "$publicFolder/assets/"
}

# mainProcess is the primary function that orchestrates the creation of a static HTML file
# for ReDoc documentation. It handles the main workflow, including any necessary setup,
# execution of commands, and error handling required to generate the documentation output.
mainProcess() {
    findAllOpenApiYamlDirs allFolders

    for directory in "${allFolders[@]}"; do
        echo "Processing directory: \"$directory\""
        loadStaticHtmlToFolder "$directory"
    done

    generateHighLevelIndex
    copyAssets
}

mainProcess