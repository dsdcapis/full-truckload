#!/bin/bash
set -e

currentFolder="$(pwd)"
apiSpecFolder="$currentFolder/api-specs"
publicFolder="$currentFolder/public"
allFolders=()

# Finds all directories containing openapi.yaml files and all PDF files in currentFolder and returns their paths and types
# Returns an associative array where keys are relative paths and values are types ("openapi" or "pdf")
findAllFiles() {
    local -n resultRef=$1

    # Find all openapi.yaml directories
    while IFS= read -r -d '' dir; do
        # Remove the $currentFolder prefix and leading slash if present
        rel_dir="${dir#$currentFolder/}"
        resultRef["$rel_dir"]="openapi"
    done < <(find "$currentFolder" -type f -name "openapi.yaml" -print0 | xargs -0 -n1 dirname -z | sort -zu)

    # Find all PDF files
    while IFS= read -r -d '' file; do
        # Remove the $currentFolder prefix and leading slash if present
        rel_file="${file#$currentFolder/}"
        resultRef["$rel_file"]="pdf"
    done < <(find "$currentFolder" -type f -name "*.pdf" -print0 | sort -z)
}

# Creates static html files for openapi.yaml file in the current directory
loadStaticHtmlToFolder() {
    local folder="$1"

    echo "Creating folder \"$publicFolder/$folder\""
    mkdir -p "$publicFolder/$folder"

    echo "Running redocly/cli build-docs command on \"$currentFolder/$folder/openapi.yaml\" and saving it to \"$publicFolder/$folder/index.html\""
    npx @redocly/cli@latest build-docs "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/index.html"
}

# Generates a high-level index for the Redoc static HTML documentation and PDF files.
# This function displays all files found from currentFolder in a hierarchical tree structure.
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
        margin: 20px;
    }
    p {
        max-width: 720px;
        line-height: 1.6;
    }
    img.logo {
        max-height: 100px;
        margin-top: 10px;
        margin-bottom: 10px;
    }
    .tree {
        list-style-type: none;
        padding-left: 0;
    }
    .tree ul {
        list-style-type: none;
        padding-left: 20px;
        margin: 0;
    }
    .tree li {
        margin: 3px 0;
        position: relative;
    }
    .folder {
        font-weight: bold;
        color: #333;
        cursor: pointer;
        user-select: none;
    }
    .folder::before {
        content: '📁 ';
        margin-right: 5px;
    }
    .folder.collapsed::before {
        content: '📂 ';
    }
    .file-link {
        text-decoration: none;
        padding: 2px 4px;
        border-radius: 3px;
        transition: background-color 0.2s;
    }
    .file-link:hover {
        background-color: #f0f0f0;
    }
    .pdf-link {
        color: #d9534f;
    }
    .pdf-link::before {
        content: '📄 ';
        margin-right: 5px;
    }
    .openapi-link {
        color: #5bc0de;
    }
    .openapi-link::before {
        content: '📋 ';
        margin-right: 5px;
    }
    .toggle {
        display: inline-block;
        width: 16px;
        text-align: center;
        cursor: pointer;
        user-select: none;
        margin-right: 3px;
    }
    .hidden {
        display: none;
    }
</style>
<body>
    <p>Supported by the Digital Standard Development Council's (DSDC) Digital LTL Council, these API standards help organizations modernize LTL workflows through standardized, open, and scalable integration.</p>
    <h1>API Documentation Index</h1>
    <ul class=\"tree\" id=\"root\">" > "$indexFile"

    # Sort all paths for processing
    local sortedPaths=()
    for path in "${!allFiles[@]}"; do
        sortedPaths+=("$path")
    done
    IFS=$'\n' sortedPaths=($(sort <<< "${sortedPaths[*]}"))
    unset IFS

    # Copy PDF files first
    for path in "${sortedPaths[@]}"; do
        local fileType="${allFiles[$path]}"
        if [[ "$fileType" == "pdf" ]]; then
            local pdfDir=$(dirname "$path")
            mkdir -p "$publicFolder/$pdfDir"
            cp "$currentFolder/$path" "$publicFolder/$path"
        fi
    done

    # Build complete tree structure
    declare -A treeNodes
    declare -a topLevel
    
    # First pass: identify all unique directories
    for path in "${sortedPaths[@]}"; do
        IFS='/' read -ra parts <<< "$path"
        local currentPath=""
        
        for ((i=0; i<${#parts[@]}-1; i++)); do
            local part="${parts[$i]}"
            if [[ -n "$currentPath" ]]; then
                currentPath="$currentPath/$part"
            else
                currentPath="$part"
            fi
            
            if [[ -z "${treeNodes[$currentPath]}" ]]; then
                treeNodes["$currentPath"]="folder"
                
                # Track top-level directories
                if [[ $i -eq 0 ]]; then
                    topLevel+=("$currentPath")
                fi
            fi
        done
        
        # Add the file to the tree
        treeNodes["$path"]="${allFiles[$path]}"
    done

    # Sort top-level directories
    IFS=$'\n' topLevel=($(sort -u <<< "${topLevel[*]}"))
    unset IFS

    # Recursive function to print tree
    printTree() {
        local prefix="$1"
        local indent="$2"
        
        # Get all items under this prefix
        local items=()
        for path in "${sortedPaths[@]}"; do
            # Check if this path starts with prefix
            if [[ -z "$prefix" ]]; then
                # Top level - get first segment
                IFS='/' read -ra parts <<< "$path"
                local firstPart="${parts[0]}"
                items+=("$firstPart")
            elif [[ "$path" == "$prefix"* ]]; then
                # Remove prefix and get next segment
                local remainder="${path#$prefix/}"
                if [[ "$remainder" != */* ]]; then
                    # Direct child (file)
                    items+=("$path")
                else
                    # Has more path segments (subfolder)
                    IFS='/' read -ra parts <<< "$remainder"
                    local nextPart="$prefix/${parts[0]}"
                    items+=("$nextPart")
                fi
            fi
        done
        
        # Sort and deduplicate
        IFS=$'\n' items=($(sort -u <<< "${items[*]}"))
        unset IFS
        
        for item in "${items[@]}"; do
            local nodeType="${treeNodes[$item]}"
            
            if [[ "$nodeType" == "folder" ]]; then
                # It's a folder
                IFS='/' read -ra parts <<< "$item"
                local folderName="${parts[-1]}"
                
                echo "${indent}<li>" >> "$indexFile"
                echo "${indent}    <span class=\"toggle\" onclick=\"toggleFolder(this)\">▼</span>" >> "$indexFile"
                echo "${indent}    <span class=\"folder\">$folderName</span>" >> "$indexFile"
                echo "${indent}    <ul>" >> "$indexFile"
                
                # Recursively print children
                printTree "$item" "$indent    "
                
                echo "${indent}    </ul>" >> "$indexFile"
                echo "${indent}</li>" >> "$indexFile"
                
            elif [[ "$nodeType" == "openapi" ]]; then
                # It's an OpenAPI file
                if [[ -f "$publicFolder/$item/index.html" ]]; then
                    IFS='/' read -ra parts <<< "$item"
                    local fileName="${parts[-1]}"
                    echo "${indent}<li><a class=\"file-link openapi-link\" href=\"$item/index.html\">$fileName (OpenAPI)</a></li>" >> "$indexFile"
                fi
                
            elif [[ "$nodeType" == "pdf" ]]; then
                # It's a PDF file
                IFS='/' read -ra parts <<< "$item"
                local fileName="${parts[-1]}"
                echo "${indent}<li><a class=\"file-link pdf-link\" href=\"$item\" target=\"_blank\">$fileName</a></li>" >> "$indexFile"
            fi
        done
    }

    # Start printing from root
    printTree "" "        "

    echo "    </ul>
    <script>
        function toggleFolder(toggle) {
            const li = toggle.parentElement;
            const ul = li.querySelector('ul');
            if (ul) {
                ul.classList.toggle('hidden');
                toggle.textContent = ul.classList.contains('hidden') ? '▶' : '▼';
            }
        }
        
        // Optional: Add expand/collapse all functionality
        document.addEventListener('DOMContentLoaded', function() {
            const folders = document.querySelectorAll('.folder');
            folders.forEach(folder => {
                folder.addEventListener('dblclick', function(e) {
                    const toggle = this.previousElementSibling;
                    if (toggle && toggle.classList.contains('toggle')) {
                        toggleFolder(toggle);
                    }
                });
            });
        });
    </script>
</body>
</html>" >> "$indexFile"
    echo "Created high level index at \"$indexFile\""
}

# mainProcess is the primary function that orchestrates the creation of a static HTML file
# for ReDoc documentation. It handles the main workflow, including any necessary setup,
# execution of commands, and error handling required to generate the documentation output.
mainProcess() {
    echo "Removing existing public folder..."
    rm -rf "$publicFolder"
    
    declare -A allFiles
    findAllFiles allFiles

    # Process OpenAPI files
    for path in "${!allFiles[@]}"; do
        if [[ "${allFiles[$path]}" == "openapi" ]]; then
            echo "Processing OpenAPI directory: \"$path\""
            loadStaticHtmlToFolder "$path"
        fi
    done

    # Process PDF files in generateHighLevelIndex
    generateHighLevelIndex
}

mainProcess
