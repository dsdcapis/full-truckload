#!/bin/bash
set -e

currentFolder="$(pwd)"
publicFolder="$currentFolder/public"

findAllFiles() {
    local -n resultRef=$1
    local excludeArgs=(-not -path "$currentFolder/api-prds/*" -not -path "$currentFolder/api-scopes/*")

    while IFS= read -r -d '' dir; do
        rel_dir="${dir#$currentFolder/}"
        resultRef["$rel_dir"]="openapi"
    done < <(find "$currentFolder" -type f -name "openapi.yaml" "${excludeArgs[@]}" -print0 | xargs -0 -n1 dirname -z | sort -zu)

    while IFS= read -r -d '' file; do
        rel_file="${file#$currentFolder/}"
        resultRef["$rel_file"]="pdf"
    done < <(find "$currentFolder" -type f -name "*.pdf" "${excludeArgs[@]}" -print0 | sort -z)

    while IFS= read -r -d '' file; do
        rel_file="${file#$currentFolder/}"
        resultRef["$rel_file"]="xlsx"
    done < <(find "$currentFolder" -type f -name "*.xlsx" "${excludeArgs[@]}" -print0 | sort -z)
}

loadStaticHtmlToFolder() {
    local folder="$1"

    echo "Creating folder \"$publicFolder/$folder\""
    mkdir -p "$publicFolder/$folder"

    echo "Bundling OpenAPI spec: \"$currentFolder/$folder/openapi.yaml\""
    npx @redocly/cli@latest bundle "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/openapi-combined.yaml" --ext yaml

    echo "Building docs: \"$currentFolder/$folder/openapi.yaml\""
    npx @redocly/cli@latest build-docs "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/index.html" --theme.openapi.downloadDefinitionUrl="openapi-combined.yaml" --theme.openapi.hideDownloadButtons=true

    echo "Adding back-to-downloads button: \"$publicFolder/$folder/index.html\""
    IFS='/' read -ra folderParts <<< "$folder"
    local backPath=""
    for ((i=0; i<${#folderParts[@]}; i++)); do backPath="../$backPath"; done
    local backHref="${backPath}index.html"
    local targetHtml="$publicFolder/$folder/index.html"
    local backScriptFile=$(mktemp)

    cat > "$backScriptFile" << EOF
<script>
(function() {
    var backHref = "$backHref";
    var tries = 0;
    var iv = setInterval(function() {
        tries++;
        var redocEl = document.getElementById('redoc');
        var h1 = redocEl ? redocEl.querySelector('h1') : null;
        var titleBlock = h1 ? h1.parentElement : null;
        if (titleBlock && titleBlock.parentElement) {
            var wrap = document.createElement('div');
            wrap.style.padding = '16px 40px';
            var link = document.createElement('a');
            link.href = backHref;
            link.textContent = String.fromCharCode(8592) + ' Back to Downloads';
            link.style.display = 'inline-block';
            link.style.backgroundColor = '#592E82';
            link.style.color = '#ffffff';
            link.style.padding = '14px 28px';
            link.style.fontFamily = 'Arial, Helvetica, sans-serif';
            link.style.fontWeight = 'bold';
            link.style.fontSize = '16px';
            link.style.textDecoration = 'none';
            link.style.boxShadow = '0px 2px 8px rgba(0,0,0,0.3)';
            wrap.appendChild(link);
            titleBlock.parentElement.insertBefore(wrap, titleBlock.nextSibling);
            clearInterval(iv);
            return;
        }
        if (tries > 50) { clearInterval(iv); }
    }, 100);
})();
</script>
EOF

    local bodyCloseLine=$(grep -n "</body>" "$targetHtml" | head -1 | cut -d: -f1)
    {
        head -n "$((bodyCloseLine - 1))" "$targetHtml"
        cat "$backScriptFile"
        tail -n "+$bodyCloseLine" "$targetHtml"
    } > "${targetHtml}.tmp"
    mv "${targetHtml}.tmp" "$targetHtml"
    rm -f "$backScriptFile"
}

generateHighLevelIndex() {
    local indexFile="$publicFolder/index.html"

    cat > "$indexFile" << 'ENDHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FTL API Documentation</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Jost:wght@400;500;600;700;800&family=Nunito+Sans:opsz,wght@6..12,400;6..12,600;6..12,700;6..12,800&display=swap" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js" integrity="sha512-XMVd28F1oH/O71fzwBnV7HucLxVwtxf26XV8P4wPk26EDxuGZ91N8bsOttmnomcCD3CS5ZMRL50H0GgOHvegtg==" crossorigin="anonymous"></script>
    <script charset="utf-8" type="text/javascript" src="https://js.hsforms.net/forms/embed/v2.js"></script>
    <style>
        *, *::before, *::after { box-sizing: border-box; }

        body {
            font-family: 'Nunito Sans', Arial, sans-serif;
            background-color: #151515;
            color: #ffffff;
            margin: 0;
            padding: 0;
            padding-bottom: 100px;
            font-size: 16px;
            line-height: 26px;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }

        .container {
            max-width: 1140px;
            margin: 0 auto;
            padding: 0 24px;
        }

        /* Header */
        header {
            background-color: #151515;
            border-bottom: 3px solid #592E82;
            padding: 16px 0;
            margin-bottom: 48px;
        }
        img.logo {
            max-height: 80px;
            display: block;
        }

        /* Typography */
        .section-label {
            font-family: 'Jost', Arial, sans-serif;
            font-weight: 600;
            color: #C4A0E0;
            font-size: 12px;
            letter-spacing: 3px;
            text-transform: uppercase;
            margin: 0 0 10px 0;
        }
        h1 {
            font-family: 'Jost', Arial, sans-serif;
            font-weight: 700;
            color: #ffffff;
            font-size: 38px;
            margin: 0 0 16px 0;
            line-height: 1.2;
        }
        .intro {
            max-width: 720px;
            line-height: 1.7;
            color: #B4B4B4;
            font-size: 16px;
            margin-bottom: 40px;
        }
        .files-heading {
            font-family: 'Jost', Arial, sans-serif;
            font-weight: 600;
            color: #ffffff;
            font-size: 18px;
            margin: 0 0 4px 0;
        }
        .files-caption {
            font-family: 'Nunito Sans', Arial, sans-serif;
            color: #ffffff;
            font-weight: 600;
            font-size: 18px;
            line-height: 1.5;
            margin: 0 0 20px 0;
            padding-bottom: 14px;
            border-bottom: 1px solid rgba(255,255,255,0.1);
        }

        /* Tree */
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
            margin: 6px 0;
            position: relative;
        }
        .folder {
            font-family: 'Jost', Arial, sans-serif;
            font-weight: 600;
            color: #ffffff;
            cursor: pointer;
            user-select: none;
            font-size: 15px;
        }
        .folder::before {
            content: '📁 ';
            margin-right: 4px;
        }
        .folder.collapsed::before {
            content: '📂 ';
        }
        .file-link {
            text-decoration: none;
            padding: 2px 6px;
            font-size: 14px;
            font-family: 'Nunito Sans', Arial, sans-serif;
            transition: background-color 0.2s;
        }
        .file-link:hover {
            background-color: rgba(89, 46, 130, 0.25);
        }
        .pdf-link { color: #ff6b6b; }
        .pdf-link::before { content: '📄 '; margin-right: 4px; }
        .xlsx-link { color: #5cb85c; }
        .xlsx-link::before { content: '📊 '; margin-right: 4px; }
        .openapi-link { color: #5bc0de; }
        .openapi-link::before { content: '👁 '; margin-right: 4px; }
        .quick-download-link {
            display: inline-block;
            margin-left: 10px;
            padding: 2px 10px;
            font-size: 12px;
            font-family: 'Nunito Sans', Arial, sans-serif;
            font-weight: 700;
            color: #ffffff;
            background-color: #592E82;
            text-decoration: none;
            transition: background-color 0.2s;
        }
        .quick-download-link:hover { background-color: #3A1D57; }

        .toggle {
            display: inline-block;
            width: 16px;
            text-align: center;
            cursor: pointer;
            user-select: none;
            margin-right: 3px;
            color: #B4B4B4;
            font-size: 12px;
        }
        .hidden { display: none; }

        /* Checkbox */
        .download-checkbox {
            margin-right: 6px;
            cursor: pointer;
            width: 14px;
            height: 14px;
            vertical-align: middle;
            accent-color: #592E82;
        }

        /* Download button */
        #download-btn {
            display: none;
            position: fixed;
            bottom: 28px;
            right: 28px;
            background-color: #592E82;
            color: #ffffff;
            border: none;
            padding: 13px 28px;
            border-radius: 0;
            font-family: 'Nunito Sans', Arial, sans-serif;
            font-size: 15px;
            font-weight: 700;
            cursor: pointer;
            box-shadow: 0px 3px 16px 0px rgba(0,0,0,0.4);
            z-index: 100;
            transition: background-color 0.3s ease;
            letter-spacing: 0.5px;
        }
        #download-btn:hover { background-color: #3A1D57; }

        /* Modal */
        #download-modal {
            display: none;
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            background: rgba(0,0,0,0.8);
            z-index: 200;
            align-items: center;
            justify-content: center;
        }
        .modal-box {
            background: #1e1e1e;
            border-top: 4px solid #592E82;
            padding: 20px 24px 24px;
            max-width: 560px;
            width: 90%;
            position: relative;
            max-height: 96vh;
            overflow-y: auto;
            box-shadow: 0px 0px 40px 0px rgba(0,0,0,0.6);
        }
        .modal-box h2 {
            font-family: 'Jost', Arial, sans-serif;
            font-weight: 700;
            color: #ffffff;
            margin: 0 0 12px 0;
            font-size: 17px;
        }
        .modal-close {
            position: absolute;
            top: 14px;
            right: 18px;
            background: none;
            border: none;
            font-size: 20px;
            cursor: pointer;
            color: #B4B4B4;
            transition: color 0.2s;
            line-height: 1;
        }
        .modal-close:hover { color: #ffffff; }

        /* HubSpot form — light background, compact layout */
        #hubspot-form-container {
            background: #ffffff;
            padding: 16px;
            margin-top: 4px;
        }
        #hubspot-form-container .hs-form-field {
            margin-bottom: 10px !important;
        }
        #hubspot-form-container .hs-form-field label {
            font-size: 13px !important;
            margin-bottom: 3px !important;
            display: block !important;
        }
        #hubspot-form-container .hs-form-field input[type="text"],
        #hubspot-form-container .hs-form-field input[type="email"] {
            padding: 6px 8px !important;
            font-size: 13px !important;
            height: auto !important;
            width: 100% !important;
        }
        #hubspot-form-container .hs-error-msgs {
            font-size: 12px !important;
            margin: 2px 0 0 0 !important;
        }
        #hubspot-form-container .hs-form-private .hs-button,
        #hubspot-form-container .hs-form .hs-button {
            background-color: #592E82 !important;
            color: #ffffff !important;
            border: none !important;
            border-radius: 0 !important;
            font-family: 'Nunito Sans', Arial, sans-serif !important;
            font-weight: 700 !important;
            font-size: 14px !important;
            padding: 10px 24px !important;
            margin-top: 6px !important;
            cursor: pointer !important;
            transition: background-color 0.3s ease !important;
            letter-spacing: 0.5px !important;
        }
        #hubspot-form-container .hs-form-private .hs-button:hover,
        #hubspot-form-container .hs-form .hs-button:hover {
            background-color: #3A1D57 !important;
        }

        /* Toast */
        #download-toast {
            display: none;
            position: fixed;
            bottom: 28px;
            left: 50%;
            transform: translateX(-50%);
            background: #592E82;
            color: #ffffff;
            padding: 13px 28px;
            font-family: 'Nunito Sans', Arial, sans-serif;
            font-weight: 700;
            font-size: 14px;
            z-index: 300;
            box-shadow: 0px 3px 16px 0px rgba(0,0,0,0.4);
            letter-spacing: 0.5px;
            white-space: nowrap;
        }

        /* Footer */
        footer {
            background-color: #151515;
            border-top: 1px solid rgba(255,255,255,0.1);
            padding: 32px 0;
            margin-top: 60px;
        }
        footer p {
            color: #B4B4B4;
            font-size: 13px;
            margin: 4px 0;
            line-height: 1.6;
        }
        footer a {
            color: #C4A0E0;
            text-decoration: none;
            transition: color 0.2s;
        }
        footer a:hover { color: #ffffff; }
    </style>
</head>
<body>
    <header>
        <div class="container">
            <img class="logo" src="images/DSDC-TruckloadHigh-Res-R.png" alt="DSDC Truckload">
        </div>
    </header>
    <div class="container">
        <p class="section-label">DSDC Digital FTL Council</p>
        <h1>FTL API Documentation</h1>
        <p class="intro">Supported by the Digital Standards Development Council<sup>&reg;</sup> (DSDC)<sup>&reg;</sup>'s Digital FTL Council, these API standards help organizations modernize FTL workflows through standardized, open, and scalable integration.</p>
        <p class="files-heading">Available Files</p>
        <p class="files-caption">Click a spec name to preview it in your browser, or use its Download button to save the file directly. Check box(es) and use "Download Selected" to grab multiple files at once.</p>
        <ul class="tree" id="root">
ENDHEAD

    # Sort all paths for processing
    local sortedPaths=()
    for path in "${!allFiles[@]}"; do
        sortedPaths+=("$path")
    done
    IFS=$'\n' sortedPaths=($(sort <<< "${sortedPaths[*]}"))
    unset IFS

    # Copy PDF and XLSX files
    for path in "${sortedPaths[@]}"; do
        local fileType="${allFiles[$path]}"
        if [[ "$fileType" == "pdf" || "$fileType" == "xlsx" ]]; then
            local fileDir=$(dirname "$path")
            mkdir -p "$publicFolder/$fileDir"
            cp "$currentFolder/$path" "$publicFolder/$path"
        fi
    done

    # Build complete tree structure
    declare -A treeNodes
    declare -a topLevel

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

                if [[ $i -eq 0 ]]; then
                    topLevel+=("$currentPath")
                fi
            fi
        done

        treeNodes["$path"]="${allFiles[$path]}"
    done

    IFS=$'\n' topLevel=($(sort -u <<< "${topLevel[*]}"))
    unset IFS

    printTree() {
        local prefix="$1"
        local indent="$2"

        local items=()
        for path in "${sortedPaths[@]}"; do
            if [[ -z "$prefix" ]]; then
                IFS='/' read -ra parts <<< "$path"
                local firstPart="${parts[0]}"
                items+=("$firstPart")
            elif [[ "$path" == "$prefix"* ]]; then
                local remainder="${path#$prefix/}"
                if [[ "$remainder" != */* ]]; then
                    items+=("$path")
                else
                    IFS='/' read -ra parts <<< "$remainder"
                    local nextPart="$prefix/${parts[0]}"
                    items+=("$nextPart")
                fi
            fi
        done

        IFS=$'\n' items=($(sort -u <<< "${items[*]}"))
        unset IFS

        for item in "${items[@]}"; do
            local nodeType="${treeNodes[$item]}"

            if [[ "$nodeType" == "folder" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local folderName="${parts[-1]}"

                echo "${indent}<li>" >> "$indexFile"
                echo "${indent}    <span class=\"toggle\" onclick=\"toggleFolder(this)\">▼</span>" >> "$indexFile"
                echo "${indent}    <span class=\"folder\">$folderName</span>" >> "$indexFile"
                echo "${indent}    <ul>" >> "$indexFile"

                printTree "$item" "$indent    "

                echo "${indent}    </ul>" >> "$indexFile"
                echo "${indent}</li>" >> "$indexFile"

            elif [[ "$nodeType" == "openapi" ]]; then
                if [[ -f "$publicFolder/$item/index.html" ]]; then
                    IFS='/' read -ra parts <<< "$item"
                    local fileName="${parts[-1]}"
                    echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" aria-label=\"Select $fileName (OpenAPI) for download\" data-file=\"${item}/openapi-combined.yaml\" data-name=\"${item}/openapi-combined.yaml\" onchange=\"updateSelection()\"><a class=\"file-link openapi-link\" href=\"$item/index.html\">$fileName (OpenAPI) &ndash; Preview</a><a class=\"quick-download-link\" href=\"${item}/openapi-combined.yaml\" aria-label=\"Download $fileName\" onclick=\"handleDownloadClick(event); return false;\">&#8595; Download</a></li>" >> "$indexFile"
                fi

            elif [[ "$nodeType" == "pdf" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local fileName="${parts[-1]}"
                echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" aria-label=\"Select $fileName for download\" data-file=\"$item\" data-name=\"$item\" onchange=\"updateSelection()\"><a class=\"file-link pdf-link\" href=\"$item\" onclick=\"handleDownloadClick(event); return false;\">$fileName</a></li>" >> "$indexFile"

            elif [[ "$nodeType" == "xlsx" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local fileName="${parts[-1]}"
                echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" aria-label=\"Select $fileName for download\" data-file=\"$item\" data-name=\"$item\" onchange=\"updateSelection()\"><a class=\"file-link xlsx-link\" href=\"$item\" onclick=\"handleDownloadClick(event); return false;\">$fileName</a></li>" >> "$indexFile"
            fi
        done
    }

    printTree "" "        "

    cat >> "$indexFile" << 'ENDSCRIPT'
        </ul>
    </div>

    <footer>
        <div class="container">
            <p>Copyright <sup>&copy;</sup> National Motor Freight Traffic Association, Inc.<sup>&reg;</sup> (NMFTA)<sup>&reg;</sup> 2024. All Rights Reserved</p>
            <p><a href="mailto:dsdc@nmfta.org">dsdc@nmfta.org</a> &nbsp;|&nbsp; (866) 411-6632</p>
        </div>
    </footer>

    <button id="download-btn" onclick="openDownloadModal()">
        Download Selected (<span id="download-count">0</span>)
    </button>

    <div id="download-modal">
        <div class="modal-box" role="dialog" aria-modal="true" aria-labelledby="modal-title">
            <button class="modal-close" onclick="closeDownloadModal()">&#x2715;</button>
            <h2 id="modal-title">Please fill out the form to download</h2>
            <div id="hubspot-form-container"></div>
        </div>
    </div>

    <div id="download-toast">&#x2713; Download complete</div>

    <script>
        var selectedFiles = [];
        var _modalTrigger = null;

        function updateSelection() {
            selectedFiles = [];
            document.querySelectorAll('.download-checkbox:checked').forEach(function(cb) {
                selectedFiles.push({ path: cb.dataset.file, name: cb.dataset.name });
            });
            var btn = document.getElementById('download-btn');
            document.getElementById('download-count').textContent = selectedFiles.length;
            btn.style.display = selectedFiles.length > 0 ? 'block' : 'none';
        }

        function handleDownloadClick(event) {
            event.preventDefault();
            var cb = event.currentTarget.closest('li').querySelector('.download-checkbox');
            if (cb && !cb.checked) {
                cb.checked = true;
                updateSelection();
            }
            openDownloadModal();
        }

        function openDownloadModal() {
            if (selectedFiles.length === 0) return;
            var filesToDownload = selectedFiles.slice();

            if (localStorage.getItem('dsdc_signed_up') === '1') {
                downloadAsZip(filesToDownload).catch(function(err) {
                    showToast('Download failed: ' + err.message);
                });
                document.querySelectorAll('.download-checkbox:checked').forEach(function(cb) {
                    cb.checked = false;
                });
                updateSelection();
                return;
            }

            if (typeof hbspt === 'undefined') {
                showToast('Form is loading, please try again in a moment.');
                return;
            }

            var fileList = filesToDownload.map(function(f) {
                return f.name.split('/').pop();
            }).join(', ');

            var pageUrl = new URL(window.location.href);
            pageUrl.searchParams.set('dsdc_apis_downloaded', fileList);
            window.history.replaceState({}, '', pageUrl);

            var container = document.getElementById('hubspot-form-container');
            container.innerHTML = '';

            hbspt.forms.create({
                portalId: '22203423',
                formId: '3171c162-f7a0-4402-ac25-d1b769031b6e',
                region: 'na1',
                target: '#hubspot-form-container',
                onFormReady: function($form) {
                    $form.find('input[name="dsdc_apis_downloaded"]')
                        .val(fileList)
                        .change();
                },
                onFormSubmitted: function() {
                    localStorage.setItem('dsdc_signed_up', '1');
                    closeDownloadModal();
                    downloadAsZip(filesToDownload).catch(function(err) {
                        showToast('Download failed: ' + err.message);
                    });
                    document.querySelectorAll('.download-checkbox:checked').forEach(function(cb) {
                        cb.checked = false;
                    });
                    updateSelection();
                }
            });

            var _modal = document.getElementById('download-modal');
            _modal.style.display = 'flex';
            _modalTrigger = document.activeElement;
            var firstFocusable = _modal.querySelector('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
            if (firstFocusable) firstFocusable.focus();
        }

        function closeDownloadModal() {
            document.getElementById('download-modal').style.display = 'none';
            if (_modalTrigger) { _modalTrigger.focus(); _modalTrigger = null; }
        }

        async function downloadAsZip(files) {
            var zip = new JSZip();
            var fetchPromises = files.map(function(file) {
                return fetch(file.path)
                    .then(function(r) {
                        if (!r.ok) throw new Error('Failed to fetch ' + file.name + ' (' + r.status + ')');
                        return r.blob();
                    })
                    .then(function(blob) { zip.file(file.name, blob); });
            });
            await Promise.all(fetchPromises);
            var content = await zip.generateAsync({ type: 'blob' });
            var url = URL.createObjectURL(content);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'dsdc-ftl-specs.zip';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            var cleanUrl = new URL(window.location.href);
            cleanUrl.searchParams.delete('dsdc_apis_downloaded');
            window.history.replaceState({}, '', cleanUrl);
            showToast();
        }

        function showToast(message) {
            var toast = document.getElementById('download-toast');
            toast.textContent = message || '✓ Download complete';
            toast.style.display = 'block';
            setTimeout(function() { toast.style.display = 'none'; }, 3000);
        }

        function toggleFolder(toggle) {
            var li = toggle.parentElement;
            var ul = li.querySelector('ul');
            if (ul) {
                ul.classList.toggle('hidden');
                toggle.textContent = ul.classList.contains('hidden') ? '▶' : '▼';
            }
        }

        document.addEventListener('keydown', function(e) {
            var modal = document.getElementById('download-modal');
            if (modal.style.display === 'flex') {
                if (e.key === 'Escape') { closeDownloadModal(); return; }
                if (e.key === 'Tab') {
                    var focusable = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
                    var first = focusable[0], last = focusable[focusable.length - 1];
                    if (e.shiftKey ? document.activeElement === first : document.activeElement === last) {
                        e.preventDefault();
                        (e.shiftKey ? last : first).focus();
                    }
                }
            }
        });

        document.addEventListener('DOMContentLoaded', function() {
            document.querySelectorAll('.folder').forEach(function(folder) {
                folder.addEventListener('dblclick', function() {
                    var toggle = this.previousElementSibling;
                    if (toggle && toggle.classList.contains('toggle')) {
                        toggleFolder(toggle);
                    }
                });
            });
        });
    </script>
</body>
</html>
ENDSCRIPT
    echo "Created high level index at \"$indexFile\""
}

copyImages() {
    echo "Copying images..."
    mkdir -p "$publicFolder/images"
    cp "$currentFolder/images/DSDC-TruckloadHigh-Res-R.png" "$publicFolder/images/"
}

mainProcess() {
    echo "Removing existing public folder..."
    rm -rf "$publicFolder"

    declare -A allFiles
    findAllFiles allFiles

    for path in "${!allFiles[@]}"; do
        if [[ "${allFiles[$path]}" == "openapi" ]]; then
            echo "Processing OpenAPI directory: \"$path\""
            loadStaticHtmlToFolder "$path"
        fi
    done

    generateHighLevelIndex
    copyImages
}

mainProcess
