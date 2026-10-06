#!/usr/bin/python3
# usb-controller-tray — KDE/Plasma system-tray indicator for usb-controller-toggle.
#
# Green controller = hub enabled (wired controllers present)
# Red controller   = hub disabled
# Amber controller = switching
# Grey controller  = hub could not be found
#
# Left-click toggles. Middle-click (or the right-click menu) quits.
#
# Uses Qt's QSystemTrayIcon, which registers as a native StatusNotifierItem on
# Plasma. The old yad/GtkStatusIcon tray went through xembedsniproxy, which
# never delivered clicks on a Wayland session.
#
# The shebang pins the system python: PySide6 ships with Bazzite
# (python3-pyside6), but not with Homebrew's python.
#
# Usage:
#   usb-controller-tray                    Run the tray indicator (foreground)
#   usb-controller-tray install-autostart  Add a ~/.config/autostart entry
#   usb-controller-tray uninstall-autostart

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

POLL_MS = int(float(os.environ.get("POLL_SECONDS", "0.5")) * 1000)

SELF = Path(sys.argv[0]).resolve()
BIN_DIR = SELF.parent
DESKTOP_FILENAME = "usb-controller-toggle.desktop"
AUTOSTART_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "autostart"

# usb-controller-toggle lives next to this script in the keg's bin/. Use the
# absolute path so the tray works even when PATH lacks Homebrew (Plasma autostart).
TOGGLE_BIN = BIN_DIR / "usb-controller-toggle"
if not os.access(TOGGLE_BIN, os.X_OK):
    TOGGLE_BIN = Path(shutil.which("usb-controller-toggle") or "usb-controller-toggle")


def info(msg):    print(f"\033[0;36m::\033[0m {msg}", file=sys.stderr)
def success(msg): print(f"\033[0;32m✔\033[0m {msg}", file=sys.stderr)
def die(msg):
    print(f"\033[0;31m✘\033[0m {msg}", file=sys.stderr)
    sys.exit(1)


# ── Locate shipped assets ─────────────────────────────────────────────────────
def resolve_share_dir():
    candidate = BIN_DIR.parent / "share" / "usb-controller-toggle"
    if candidate.is_dir():
        return candidate
    brew = shutil.which("brew")
    if brew:
        prefix = subprocess.run([brew, "--prefix"], capture_output=True, text=True).stdout.strip()
        candidate = Path(prefix) / "share" / "usb-controller-toggle"
        if candidate.is_dir():
            return candidate
    die("Could not locate the usb-controller-toggle asset directory.")


def cmd_install_autostart():
    src = resolve_share_dir() / DESKTOP_FILENAME
    if not src.is_file():
        die(f"Missing {src}")
    AUTOSTART_DIR.mkdir(parents=True, exist_ok=True)
    # Rewrite Exec= to an absolute path — Homebrew may not be on PATH when the
    # autostart entry fires. Prefer the version-stable linked bin over SELF
    # (which resolves to a versioned Cellar path).
    exec_path = shutil.which("usb-controller-tray") or str(SELF)
    lines = [f"Exec={exec_path}" if l.startswith("Exec=") else l
             for l in src.read_text().splitlines()]
    dest = AUTOSTART_DIR / DESKTOP_FILENAME
    dest.write_text("\n".join(lines) + "\n")
    success(f"Installed autostart entry: {dest}")


def cmd_uninstall_autostart():
    dest = AUTOSTART_DIR / DESKTOP_FILENAME
    dest.unlink(missing_ok=True)
    success(f"Removed autostart entry: {dest}")


# ── Tray ──────────────────────────────────────────────────────────────────────
def cmd_tray():
    try:
        from PySide6.QtCore import QProcess, QTimer
        from PySide6.QtGui import QAction, QIcon
        from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon
    except ImportError:
        die("PySide6 is not available to /usr/bin/python3. On Bazzite: rpm-ostree install python3-pyside6")

    app = QApplication(sys.argv)
    app.setApplicationName("usb-controller-tray")
    app.setDesktopFileName("usb-controller-toggle")
    app.setQuitOnLastWindowClosed(False)

    if not QSystemTrayIcon.isSystemTrayAvailable():
        die("No system tray available. A graphical Plasma session is required.")

    share = resolve_share_dir()
    icons = {name: QIcon(str(share / f"icon-{name}.svg"))
             for name in ("enabled", "disabled", "busy", "unknown")}
    tips = {
        "enabled":  "Wired controllers: enabled",
        "disabled": "Wired controllers: disabled",
        "busy":     "Switching…",
        "unknown":  "Wired controllers: hub not found",
    }

    tray = QSystemTrayIcon(icons["unknown"])
    tray.setToolTip("USB controllers")

    state = {"current": None}
    toggle_proc = QProcess()
    status_proc = QProcess()

    def paint(name):
        if state["current"] != name:
            state["current"] = name
            tray.setIcon(icons[name])
            tray.setToolTip(tips[name])

    def poll():
        if toggle_proc.state() != QProcess.NotRunning or status_proc.state() != QProcess.NotRunning:
            return
        status_proc.start(str(TOGGLE_BIN), ["status"])

    def on_status_finished(code, _status):
        out = bytes(status_proc.readAllStandardOutput()).decode().strip()
        paint(out if code == 0 and out in ("enabled", "disabled") else "unknown")

    def toggle():
        if toggle_proc.state() != QProcess.NotRunning:
            return
        paint("busy")
        toggle_proc.start(str(TOGGLE_BIN), ["toggle"])

    def on_toggle_finished(code, _status):
        if code != 0:
            err = bytes(toggle_proc.readAllStandardError()).decode()
            # Strip ANSI colour codes from the toggle script's error output.
            err = re.sub(r"\x1b\[[0-9;]*m", "", err).strip() or f"exit code {code}"
            tray.showMessage("USB controller toggle failed", err,
                             QSystemTrayIcon.Warning, 8000)
        poll()

    status_proc.finished.connect(on_status_finished)
    toggle_proc.finished.connect(on_toggle_finished)

    def on_activated(reason):
        if reason == QSystemTrayIcon.Trigger:
            toggle()
        elif reason == QSystemTrayIcon.MiddleClick:
            app.quit()

    tray.activated.connect(on_activated)

    menu = QMenu()
    act_toggle = QAction("Toggle wired controllers", menu)
    act_toggle.triggered.connect(toggle)
    act_quit = QAction("Quit", menu)
    act_quit.triggered.connect(app.quit)
    menu.addAction(act_toggle)
    menu.addSeparator()
    menu.addAction(act_quit)
    tray.setContextMenu(menu)

    timer = QTimer()
    timer.timeout.connect(poll)
    timer.start(POLL_MS)

    tray.show()
    poll()
    sys.exit(app.exec())


def usage():
    b = os.path.basename(sys.argv[0])
    print(f"""
usb-controller-tray — Plasma tray indicator for usb-controller-toggle

Usage:
  {b}                       Run the tray indicator (foreground)
  {b} install-autostart     Add a ~/.config/autostart entry
  {b} uninstall-autostart   Remove that entry

Options:
  -h, --help    Show this help message

Needs PySide6 (python3-pyside6, ships with Bazzite). Controller icon:
green = enabled, red = disabled, amber = switching, grey = hub not found.
Left-click toggles; middle-click or right-click → Quit exits.""")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd in ("", "tray", "run"):
        cmd_tray()
    elif cmd == "install-autostart":
        cmd_install_autostart()
    elif cmd == "uninstall-autostart":
        cmd_uninstall_autostart()
    elif cmd in ("help", "--help", "-h"):
        usage()
    else:
        usage()
        sys.exit(1)


if __name__ == "__main__":
    main()
