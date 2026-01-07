#!/usr/bin/env python3
"""
Organize PDFs in a directory into subfolders based on their filename prefix.

Example: a file named CSCS318-003.pdf will be moved into "CSCS318 PDFs/".
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from shutil import move
from typing import Iterable, Optional, TYPE_CHECKING

try:
    from PyPDF2 import PdfReader, PdfWriter, PdfMerger
except ImportError:  # pragma: no cover - dependency may be missing
    PdfReader = None
    PdfWriter = None
    PdfMerger = None

try:
    import tkinter as tk
    from tkinter import filedialog, messagebox
except Exception:  # pragma: no cover - GUI may not be available
    tk = None
    filedialog = None
    messagebox = None

if TYPE_CHECKING:
    import tkinter as tk_types

    Widget = tk_types.Widget
    Event = tk_types.Event
else:  # Use simple placeholders at runtime to avoid optional imports in annotations.
    Widget = object
    Event = object

PREFIX_REGEX = re.compile(r"^(?P<prefix>[A-Za-z]+\d+)-")


def organize(directory: Path) -> None:
    if not directory.is_dir():
        raise SystemExit(f"Directory not found: {directory}")

    for file_path in directory.iterdir():
        if not file_path.is_file() or file_path.suffix.lower() != ".pdf":
            continue

        match = PREFIX_REGEX.match(file_path.name)
        if not match:
            print(f"Skipping (no prefix match): {file_path.name}")
            continue

        prefix = match.group("prefix")
        target_dir = directory / f"{prefix} PDFs"
        target_dir.mkdir(exist_ok=True)

        target_path = target_dir / file_path.name
        if target_path.exists():
            print(f"Already exists, skipping: {target_path}")
            continue

        print(f"Moving {file_path.name} -> {target_dir.name}/")
        move(str(file_path), target_path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Organize prefixed PDFs into folders, or combine all PDFs in each folder into a single PDF."
        )
    )
    parser.add_argument(
        "--combine",
        action="store_true",
        help="Combine PDFs inside each provided folder into a single PDF named after that folder.",
    )
    parser.add_argument(
        "--gui",
        action="store_true",
        help="Open a simple GUI menu for organizing or combining PDFs.",
    )
    parser.add_argument(
        "directories",
        nargs="*",
        type=Path,
        help="Folders to operate on. Required with --combine; optional for organizing.",
    )
    args = parser.parse_args()

    if args.gui or (not args.directories and not args.combine and tk is not None):
        launch_gui()
        return

    if args.combine:
        dirs: list[Path] = list(args.directories)
        if not dirs and tk is not None:
            dirs = select_multiple_directories("Select folder(s) to combine (Cancel to finish)")
        if not dirs:
            raise SystemExit("Please provide one or more folders to combine with --combine.")
        combine_multiple_folders(dirs)
        return

    if args.directories:
        directory = args.directories[0]
    else:
        default_str = "CS 05:26 PDFs"
        directory = pick_directory(default_str)
        if not directory:
            user_input = input(f"Folder to organize [default: {default_str}]: ").strip()
            directory = Path(user_input or default_str)

    organize(directory)


def pick_directory(default: str) -> Optional[Path]:
    """Open a folder chooser; return None if cancelled/unavailable."""
    if tk is None or filedialog is None:
        return None
    root = tk.Tk()
    root.withdraw()  # Hide the main window
    selected = filedialog.askdirectory(title="Select folder to organize", initialdir=default)
    root.destroy()
    if not selected:
        return None
    return Path(selected)


def combine_pdfs_in_folder(folder: Path) -> Path:
    """Combine all PDFs inside a folder into one PDF named after the folder."""
    if PdfMerger is None:
        raise SystemExit("PyPDF2 is required for combining PDFs. Install with `pip install PyPDF2`.")
    if not folder.is_dir():
        raise SystemExit(f"Directory not found: {folder}")

    output_path = folder / f"{folder.name}.pdf"
    pdf_paths = natural_sort(p for p in folder.iterdir() if is_merge_candidate(p, output_path))
    if not pdf_paths:
        raise SystemExit(f"No PDFs found in {folder}")

    if output_path.exists():
        raise SystemExit(f"Output already exists, refusing to overwrite: {output_path}")

    merger = PdfMerger(strict=False)
    for pdf_path in pdf_paths:
        merger.append(str(pdf_path))

    with output_path.open("wb") as f:
        merger.write(f)
    merger.close()

    print(f"Combined {len(pdf_paths)} PDFs into {output_path.name}")
    return output_path


def combine_multiple_folders(folders: Iterable[Path]) -> None:
    targets = resolve_combine_targets(folders)
    for folder in targets:
        combine_pdfs_in_folder(folder)


def select_multiple_directories(title: str) -> list[Path]:
    """Prompt repeatedly for directories until the user cancels."""
    if tk is None or filedialog is None:
        return []
    selections: list[Path] = []
    while True:
        chosen = filedialog.askdirectory(title=title)
        if not chosen:
            break
        path = Path(chosen)
        if path not in selections:
            selections.append(path)
    return selections


def launch_gui() -> None:
    if tk is None or filedialog is None:
        raise SystemExit("Tkinter GUI not available on this system.")

    root = tk.Tk()
    root.title("PDF Organizer & Combiner")
    root.geometry("320x180")

    status_var = tk.StringVar(value="Select an action.")

    def handle_error(msg: str) -> None:
        status_var.set(msg)
        if messagebox:
            messagebox.showerror("Error", msg)

    def handle_info(msg: str) -> None:
        status_var.set(msg)
        if messagebox:
            messagebox.showinfo("Done", msg)

    def do_organize() -> None:
        directory = filedialog.askdirectory(title="Select folder to organize")
        if not directory:
            status_var.set("Organize cancelled.")
            return
        try:
            organize(Path(directory))
        except SystemExit as exc:  # reuse existing error handling
            handle_error(str(exc))
            return
        handle_info("Finished organizing.")

    def do_combine() -> None:
        directories = select_multiple_directories("Select folder(s) to combine (Cancel to finish)")
        if not directories:
            status_var.set("Combine cancelled.")
            return
        try:
            combine_multiple_folders(directories)
        except SystemExit as exc:
            handle_error(str(exc))
            return
        handle_info("Finished combining.")

    button_frame = tk.Frame(root, padx=20, pady=20)
    button_frame.pack(fill="both", expand=True)

    organize_btn = tk.Button(button_frame, text="Organize", width=16, command=do_organize)
    organize_btn.pack(pady=5)
    add_tooltip(organize_btn, "Move PDFs into folders based on filename prefix (e.g., CS101-001.pdf).")

    combine_btn = tk.Button(button_frame, text="Combine", width=16, command=do_combine)
    combine_btn.pack(pady=5)
    add_tooltip(
        combine_btn,
        "Merge all PDFs inside each selected folder into <folder>.pdf. If a selected folder "
        "has subfolders with PDFs, each subfolder will be combined separately.",
    )

    status_label = tk.Label(root, textvariable=status_var, anchor="w", padx=10)
    status_label.pack(fill="x", pady=(0, 10))

    root.mainloop()


def add_tooltip(widget: Widget, text: str) -> None:
    """Attach a simple hover tooltip to a Tk widget."""
    tooltip = tk.Toplevel(widget)
    tooltip.withdraw()
    tooltip.overrideredirect(True)
    label = tk.Label(
        tooltip,
        text=text,
        justify="left",
        background="#ffffe0",
        relief="solid",
        borderwidth=1,
        padx=6,
        pady=4,
        wraplength=260,
    )
    label.pack()

    def show_tooltip(event: Event) -> None:
        x = event.x_root + 12
        y = event.y_root + 6
        tooltip.geometry(f"+{x}+{y}")
        tooltip.deiconify()

    def hide_tooltip(_: Event) -> None:
        tooltip.withdraw()

    widget.bind("<Enter>", show_tooltip)
    widget.bind("<Leave>", hide_tooltip)


def natural_sort(paths: Iterable[Path]) -> list[Path]:
    """Sort paths using a human-friendly (natural) order."""
    def key(p: Path) -> tuple:
        parts = []
        for chunk in re.split(r"(\d+)", p.name):
            if chunk.isdigit():
                parts.append(int(chunk))
            else:
                parts.append(chunk.lower())
        return tuple(parts)

    return sorted(paths, key=key)


def is_merge_candidate(path: Path, output_path: Path) -> bool:
    """Return True if the file should be merged (skips likely prior outputs)."""
    if not path.is_file() or path.suffix.lower() != ".pdf":
        return False

    stem_lower = path.stem.lower()
    output_stem = output_path.stem.lower()
    # Skip the expected output name and common "combined/merged" outputs to avoid re-ingesting them.
    if stem_lower == output_stem:
        return False
    if "combined" in stem_lower or "merged" in stem_lower:
        return False

    return True


def resolve_combine_targets(folders: Iterable[Path]) -> list[Path]:
    """
    Expand user-provided folders into actual combine targets.

    - If the folder has PDFs directly inside it, combine that folder.
    - Otherwise, look for immediate subfolders that contain PDFs and combine those.
    """
    targets: list[Path] = []
    for folder in folders:
        if not folder.is_dir():
            raise SystemExit(f"Directory not found: {folder}")

        output_path = folder / f"{folder.name}.pdf"
        pdf_here = any(is_merge_candidate(p, output_path) for p in folder.iterdir())
        if pdf_here:
            targets.append(folder)
            continue

        subfolders = [p for p in folder.iterdir() if p.is_dir()]
        pdf_subfolders = [
            sub
            for sub in subfolders
            if any(is_merge_candidate(f, sub / f"{sub.name}.pdf") for f in sub.iterdir())
        ]
        if pdf_subfolders:
            targets.extend(pdf_subfolders)
            continue

        raise SystemExit(f"No PDFs found in {folder} or its immediate subfolders.")

    # Remove duplicates while preserving order
    seen: set[Path] = set()
    deduped: list[Path] = []
    for t in targets:
        if t in seen:
            continue
        seen.add(t)
        deduped.append(t)
    return deduped


if __name__ == "__main__":
    main()
