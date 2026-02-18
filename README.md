# DellScripts

Tools and small apps for Dell workflows.

## Contents

- `organize_pdfs.py` - Organize PDFs and optionally combine them.
- `build_crossword_quarter_plan.py` - Generate month-by-month quarter planning text from weekday rules.
- `PDF Batch Update.applescript` - Illustrator-driven batch PDF font remapper only (no color/cleanup steps).
- `EPS Batch Update.applescript` - Primary EPS batch updater (font mapping, legacy text refresh, stray point cleanup, CMYK/grayscale conversion).
- `EPS Batch Update.app` - Clickable app bundle built from `EPS Batch Update.applescript`.
- `Scan EPS RGB.jsx` - Illustrator script to scan EPS files and report which are RGB.
- `Rename and Number Files (2-digit).app` - Drag-and-drop folder renamer with 2-digit numbering.
- `Rename and Number Files (3-digit).app` - Drag-and-drop folder renamer with 3-digit numbering.
- `Log jigsum ANS files Modern.app` - Modernized app bundle for logging jigsum ANS files.
- `Log Sudoku Puzzles Modern.app` - Modernized app bundle for logging Sudoku puzzles.

## organize_pdfs.py

Organizes PDFs into `<PREFIX> PDFs/` folders based on filename prefix, and can combine PDFs inside folders into a single PDF.

### Usage

Organize PDFs in a folder (uses prefix like `CSCS318-003.pdf` -> `CSCS318 PDFs/`):

```bash
python3 organize_pdfs.py /path/to/folder
```

Combine PDFs inside one or more folders into `<folder>.pdf`:

```bash
python3 organize_pdfs.py --combine /path/to/folder /path/to/another
```

Launch the GUI (organize or combine):

```bash
python3 organize_pdfs.py --gui
```

If no arguments are provided and Tkinter is available, the GUI opens automatically.

### Combine behavior

- If a selected folder contains PDFs directly, it is combined into `<folder>.pdf`.
- If it does not contain PDFs directly, immediate subfolders that contain PDFs are combined instead.
- Existing outputs are not overwritten.
- Files named like the output or containing “combined”/“merged” in the filename are skipped.

### Dependencies

- `PyPDF2` is required for `--combine`.
- Tkinter is optional and used for the GUI when available.

## build_crossword_quarter_plan.py

Generates legacy quarter text in this pattern for each month:

- `Easy` (Mon/Tue)
- `Medium` (Wed/Thu/Fri)
- `Hard` (Sat/Sun)

Each section includes kept ranges, `(count/double-count)`, `Skip`, and `Start`.

### Usage

Open the GUI:

```bash
python3 build_crossword_quarter_plan.py
```

In the GUI:

- Click `Generate` to preview the quarter text.
- Optionally save the preview to a text file.
- Choose the source folder containing `YYYYMMDD_ans_dxwd.pdf` and `YYYYMMDD_puz_dxwd.pdf`.
- Click `Apply Rename + Move` to rename the date portion and move files into `Q<quarter>_<year>`.

Difficulty mapping for rename/move uses Finder color tags:

- Green -> Easy
- Yellow/Orange -> Medium
- Red -> Hard
- Output files are tagged automatically as Green (Easy), Orange (Medium), Red (Hard)

If tags are missing (common after some cloud copy workflows), enable:

- `Use weekday fallback for untagged files`

This classifies untagged files by the source filename date weekday using the same rules:
Mon/Tue = Easy, Wed/Thu/Fri = Medium, Sat/Sun = Hard.

## EPS Batch Update.applescript

Batch-processes `.eps` files through Illustrator with these steps:

- Optional save mode: overwrite originals or save to a selected output folder.
- Raw text font replacements for files under 50KB.
- Illustrator font remapping across story characters.
- Legacy text refresh pass.
- Stray point selection/removal via Illustrator menus.
- Document color mode update to CMYK and convert artwork to grayscale.
- End-of-run RGB report listing files still in RGB.

### Usage

Run from Script Editor or the app bundle:

- Script: `EPS Batch Update.applescript`
- App: `EPS Batch Update.app`

The script prompts for:

- Source folder of EPS files.
- Save behavior (overwrite vs output folder).

### Permissions

Because this script uses UI scripting (menu clicks), macOS permissions are required:

- Accessibility permission for the script/app.
- Automation permission to control Adobe Illustrator.

If permissions are reset after recompiling the app, remove/re-add the app entry in Accessibility.

## Scan EPS RGB.jsx

Scans a folder of `.eps` files in Illustrator and reports RGB files.

### Usage

In Illustrator:

1. `File > Scripts > Other Script...`
2. Select `Scan EPS RGB.jsx`
3. Choose the source folder when prompted

## Notes

- The `.app` bundles are macOS apps; drag a folder onto them or open directly.
- If macOS blocks an app, right-click the app, choose Open, then confirm.
