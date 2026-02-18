#target illustrator

function asFolder(path) {
    if (!path) return null;
    var f = new Folder(path);
    return f.exists ? f : null;
}

function listEpsFiles(folder) {
    var items = folder.getFiles();
    var eps = [];
    for (var i = 0; i < items.length; i++) {
        if (items[i] instanceof File && /\.eps$/i.test(items[i].name)) {
            eps.push(items[i]);
        }
    }
    return eps;
}

function scanFolder(folder) {
    var files = listEpsFiles(folder);
    if (!files.length) return { rgb: [], total: 0 };

    var rgbFiles = [];
    var prevInteraction = app.userInteractionLevel;
    app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;

    for (var i = 0; i < files.length; i++) {
        var doc = null;
        try {
            doc = app.open(files[i]);
            var cs = null;
            try { cs = doc.documentColorSpace; } catch (e1) { cs = null; }
            if (cs === DocumentColorSpace.RGB) {
                rgbFiles.push(files[i].name);
            }
        } catch (e2) {
            rgbFiles.push(files[i].name + " (failed to open)");
        } finally {
            if (doc) {
                doc.close(SaveOptions.DONOTSAVECHANGES);
            }
        }
    }

    app.userInteractionLevel = prevInteraction;

    return { rgb: rgbFiles, total: files.length };
}

function buildUI() {
    var win = new Window("dialog", "Scan EPS for RGB Color Space");
    win.orientation = "column";
    win.alignChildren = "fill";

    var srcGroup = win.add("group");
    srcGroup.add("statictext", undefined, "Source folder:");
    var srcField = srcGroup.add("edittext", undefined, "");
    srcField.characters = 30;
    var srcBrowse = srcGroup.add("button", undefined, "Browse...");

    var statusText = win.add("statictext", undefined, "Choose a folder to scan.");
    statusText.characters = 50;

    var btnGroup = win.add("group");
    btnGroup.alignment = "right";
    var runBtn = btnGroup.add("button", undefined, "Scan", { name: "ok" });
    var cancelBtn = btnGroup.add("button", undefined, "Cancel", { name: "cancel" });

    srcBrowse.onClick = function () {
        var f = Folder.selectDialog("Choose folder of EPS files");
        if (f) { srcField.text = f.fsName; }
    };

    runBtn.onClick = function () {
        var folder = asFolder(srcField.text);
        if (!folder) { alert("Please choose a valid folder."); return; }

        win.enabled = false;
        statusText.text = "Scanning...";

        var result = scanFolder(folder);

        win.enabled = true;

        if (result.total === 0) {
            alert("No .eps files found in the selected folder.");
            return;
        }

        var msg = "Scan complete. " + result.total + " EPS file(s) checked.";
        msg += "\nRGB files found: " + result.rgb.length + ".";

        if (result.rgb.length) {
            msg += "\n\nRGB files:\n" + result.rgb.join("\n");
        }

        alert(msg);
        win.close();
    };

    cancelBtn.onClick = function () { win.close(); };

    win.show();
}

buildUI();
