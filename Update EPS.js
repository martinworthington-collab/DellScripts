#target illustrator

// Optional incoming source folder when launched via a droplet (arguments[0])
var droppedPath = (typeof arguments !== "undefined" && arguments.length > 0) ? arguments[0] : null;

// Convert legacy text by rewriting contents
function convertLegacyText(doc) {
    var frames = doc.textFrames;
    for (var i = 0; i < frames.length; i++) {
        var tf = frames[i];
        try {
            var original = tf.contents;
            tf.contents = "";
            tf.contents = original;
        } catch (e) {
            // Skip frames that cannot be rewritten
        }
    }
}

// Get all .ai and .eps files (no subfolders)
function getIllustratorFiles(folder) {
    var aiFiles = folder.getFiles("*.ai");
    var epsFiles = folder.getFiles("*.eps");
    var all = [];
    var i;

    for (i = 0; i < aiFiles.length; i++) {
        all.push(aiFiles[i]);
    }
    for (i = 0; i < epsFiles.length; i++) {
        all.push(epsFiles[i]);
    }

    return all;
}

// Count legacy text frames in a document
function countLegacyText(doc) {
    var count = 0;

    // Newer Illustrator exposes legacyTextItems; fall back to probing frames if absent
    try {
        if (doc.legacyTextItems && doc.legacyTextItems.length) {
            count = doc.legacyTextItems.length;
        }
    } catch (e) {
        // Ignore and use frame probing
    }

    if (count === 0) {
        var frames = doc.textFrames;
        for (var i = 0; i < frames.length; i++) {
            try {
                // Access a property that can throw on legacy text
                frames[i].textRange.characterAttributes.textFont;
            } catch (err) {
                count++;
            }
        }
    }

    return count;
}

// Save the document back to disk
function saveDocument(doc, targetFile, isEps, overwrite) {
    if (isEps) {
        var epsOpts = new EPSSaveOptions();
        epsOpts.embedAllFonts = true;
        epsOpts.includeDocumentThumbnails = true;
        epsOpts.compatibility = Compatibility.ILLUSTRATOR17;
        epsOpts.overprint = PDFOverprint.PRESERVEPDFOVERPRINT;
        doc.saveAs(targetFile, epsOpts);
        return;
    }

    // Keep existing options when overwriting, otherwise supply basic AI options
    if (overwrite) {
        doc.save();
    } else {
        var aiOpts = new IllustratorSaveOptions();
        aiOpts.pdfCompatible = true;
        aiOpts.embedICCProfile = true;
        aiOpts.compatibility = Compatibility.ILLUSTRATOR17;
        doc.saveAs(targetFile, aiOpts);
    }
}

// Process a single file
function processFile(file, overwrite, destFolder, convertText) {
    var doc;
    var legacyFound = false;
    var legacyConverted = false;
    try {
        doc = app.open(file);

        var legacyCount = countLegacyText(doc);
        legacyFound = legacyCount > 0;

        if (convertText && legacyFound) {
            convertLegacyText(doc);
            legacyConverted = true;
        }

        var isEps = (/\.eps$/i).test(file.name);
        var target = overwrite ? file : new File(destFolder.fsName + "/" + file.name);

        saveDocument(doc, target, isEps, overwrite);
        return { ok: true, legacyFound: legacyFound, legacyConverted: legacyConverted };
    } catch (err) {
        $.writeln("Failed to process " + file.fsName + ": " + err);
        return { ok: false, legacyFound: legacyFound, legacyConverted: legacyConverted };
    } finally {
        if (doc) {
            // Close without saving because we already saved explicitly
            doc.close(SaveOptions.DONOTSAVECHANGES);
        }
    }
}

// Main UI
function showBatchUpdateUI() {
    var win = new Window("dialog", "Batch Update AI/EPS Files");
    win.orientation = "column";
    win.alignChildren = "fill";

    // Source folder
    var srcGroup = win.add("group");
    srcGroup.add("statictext", undefined, "Source folder:");
    var srcField = srcGroup.add("edittext", undefined, "");
    srcField.characters = 30;
    var srcBtn = srcGroup.add("button", undefined, "Browse...");

    // If launched with a folder argument, prefill the field
    if (droppedPath) {
        srcField.text = droppedPath;
    }

    // Save options panel
    var modePanel = win.add("panel", undefined, "Save Options");
    modePanel.orientation = "column";
    modePanel.alignChildren = "left";
    modePanel.margins = 10;

    var overwriteRadio = modePanel.add("radiobutton", undefined, "Overwrite original files");
    var copyRadio = modePanel.add("radiobutton", undefined, "Save updated copies to another folder");
    overwriteRadio.value = true;

    var destGroup = modePanel.add("group");
    destGroup.enabled = false;
    destGroup.add("statictext", undefined, "Output folder:");
    var destField = destGroup.add("edittext", undefined, "");
    destField.characters = 25;
    var destBtn = destGroup.add("button", undefined, "Browse...");

    overwriteRadio.onClick = function () {
        destGroup.enabled = false;
    };
    copyRadio.onClick = function () {
        destGroup.enabled = true;
    };

    // Options
    var optPanel = win.add("panel", undefined, "Options");
    optPanel.orientation = "column";
    optPanel.alignChildren = "left";
    optPanel.margins = 10;

    var cbLegacy = optPanel.add("checkbox", undefined, "Convert legacy text objects");
    cbLegacy.value = false;

    // Status
    var statusText = win.add("statictext", undefined, "Select a source folder to begin.");
    statusText.characters = 50;

    // Manual legacy scan trigger
    var scanBtn = win.add("button", undefined, "Scan for legacy text");
    scanBtn.alignment = "left";

    var lastScan = null;

    function runLegacyScan(srcFolder) {
        var files = getIllustratorFiles(srcFolder);
        lastScan = {
            folder: srcFolder.fsName,
            files: files,
            legacyFiles: [],
            totalLegacyFrames: 0
        };

        if (!files || files.length === 0) {
            statusText.text = "No .ai or .eps files found for scanning.";
            return lastScan;
        }

        win.enabled = false;
        for (var i = 0; i < files.length; i++) {
            statusText.text = "Scanning for legacy text (" + (i + 1) + "/" + files.length + "): " + files[i].name;
            var doc = null;
            try {
                doc = app.open(files[i]);
                var count = countLegacyText(doc);
                if (count > 0) {
                    lastScan.legacyFiles.push(files[i].name);
                    lastScan.totalLegacyFrames += count;
                }
            } catch (e) {
                $.writeln("Legacy scan failed on " + files[i].fsName + ": " + e);
            } finally {
                if (doc) {
                    doc.close(SaveOptions.DONOTSAVECHANGES);
                }
            }
        }
        win.enabled = true;

        var legacySummary;
        if (lastScan.legacyFiles.length === 0) {
            legacySummary = "No legacy text detected in " + files.length + " file(s).";
        } else {
            legacySummary = "Legacy text detected in " + lastScan.legacyFiles.length + " of " + files.length + " file(s).";
        }
        statusText.text = legacySummary;
        alert(legacySummary + "\n" + (lastScan.legacyFiles.length ? "Enable \"Convert legacy text objects\" to update them." : "Conversion not needed."));

        return lastScan;
    }

    // Buttons
    var btnGroup = win.add("group");
    btnGroup.alignment = "right";
    var runBtn = btnGroup.add("button", undefined, "Run", { name: "ok" });
    var cancelBtn = btnGroup.add("button", undefined, "Cancel", { name: "cancel" });

    // Handlers
    srcBtn.onClick = function () {
        var f = Folder.selectDialog("Choose folder of .ai / .eps files");
        if (f) {
            srcField.text = f.fsName;
        }
    };

    scanBtn.onClick = function () {
        var srcPath = srcField.text;
        if (!srcPath) {
            alert("Please choose a source folder first, then scan.");
            return;
        }
        var srcFolder = new Folder(srcPath);
        if (!srcFolder.exists) {
            alert("Source folder does not exist.");
            return;
        }
        runLegacyScan(srcFolder);
    };

    destBtn.onClick = function () {
        var f = Folder.selectDialog("Choose folder for updated copies");
        if (f) {
            destField.text = f.fsName;
        }
    };

    runBtn.onClick = function () {
        var srcPath = srcField.text;
        if (!srcPath) {
            alert("Please choose a source folder.");
            return;
        }

        var srcFolder = new Folder(srcPath);
        if (!srcFolder.exists) {
            alert("Source folder does not exist.");
            return;
        }

        var overwrite = overwriteRadio.value;
        var destFolder = null;

        if (!overwrite) {
            var destPath = destField.text;
            if (!destPath) {
                alert("Please choose an output folder.");
                return;
            }
            destFolder = new Folder(destPath);
            if (!destFolder.exists) {
                alert("Output folder does not exist.");
                return;
            }
        }

        var files = getIllustratorFiles(srcFolder);

        win.enabled = false;
        statusText.text = "Scanning for files...";
        if (!files || files.length === 0) {
            alert("No .ai or .eps files found in the selected folder.");
            win.enabled = true;
            statusText.text = "No files found.";
            return;
        }

        var failed = [];
        var legacyDetected = 0;
        var legacyConverted = 0;
        var legacySkippedFiles = [];

        for (var i = 0; i < files.length; i++) {
            statusText.text = "Processing (" + (i + 1) + "/" + files.length + "): " + files[i].name;
            var result = processFile(files[i], overwrite, destFolder, cbLegacy.value);

            if (result.legacyFound) {
                legacyDetected++;
                if (result.legacyConverted) {
                    legacyConverted++;
                } else {
                    legacySkippedFiles.push(files[i].name);
                }
            }

            if (!result.ok) {
                failed.push(files[i].name);
            }
        }

        var successCount = files.length - failed.length;
        statusText.text = "Done. Updated " + successCount + " of " + files.length + " files.";
        win.enabled = true;

        if (failed.length) {
            alert("Completed with errors. Failed files:\n" + failed.join("\n"));
        } else {
            var legacyMsg = "";
            if (legacyDetected > 0) {
                legacyMsg = "\nLegacy text detected in " + legacyDetected + " file(s).";
                if (cbLegacy.value) {
                    legacyMsg += " Converted in " + legacyConverted + ".";
                } else {
                    legacyMsg += " Conversion skipped (checkbox off).";
                }
                if (legacySkippedFiles.length) {
                    legacyMsg += "\nSkipped files:\n" + legacySkippedFiles.join("\n");
                }
            } else {
                legacyMsg = "\nNo legacy text detected.";
            }

            alert("Completed successfully. " + successCount + " files updated." + legacyMsg);
        }

        win.close();
    };

    cancelBtn.onClick = function () {
        win.close();
    };

    win.show();
}

showBatchUpdateUI();
