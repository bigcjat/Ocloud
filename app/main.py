#!/usr/bin/env python3
"""
Ocloud Desktop Application - PySide6 / QML Native Manager.
Spacious, multi-tab control center for Sovereign Cloud & Home Fleet.
"""

import sys
import os
import json
import subprocess
from PySide6.QtCore import QObject, Slot, Signal, Property
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OCLOUD_BIN = os.path.join(ROOT_DIR, 'ocloud')

import threading

class OcloudBackend(QObject):
    statusUpdated = Signal(str)
    pingUpdated = Signal(str)
    actionCompleted = Signal(str, bool, str)

    def __init__(self):
        super().__init__()
        self._cached_status = "{}"
        self._cached_ping = "[]"
        self._is_fetching = False

        # Load instant cache if available
        cache_path = os.path.expanduser('~/.config/omarchy/status_cache.json')
        if os.path.exists(cache_path):
            try:
                with open(cache_path, 'r') as f:
                    content = f.read().strip()
                    if content:
                        self._cached_status = content
            except Exception:
                pass

    def _run_cli(self, args, timeout=30):
        node_candidates = [
            os.path.expanduser('~/.local/share/mise/shims/node'),
            '/usr/local/bin/node',
            '/usr/bin/node',
            'node'
        ]
        node_bin = next((p for p in node_candidates if os.path.exists(p)), 'node')
        cmd = [node_bin, OCLOUD_BIN] + args
        env = dict(os.environ)
        env['PATH'] = f"{os.path.expanduser('~/.local/share/mise/shims')}:{os.path.expanduser('~/.local/bin')}:{env.get('PATH', '')}"
        try:
            res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout, env=env)
            return res.stdout.strip(), res.returncode == 0, res.stderr.strip()
        except Exception as e:
            return "", False, str(e)

    @Slot(result=str)
    def fetchStatus(self):
        # Trigger background refresh asynchronously, return cached instantly
        self.refreshStatusAsync()
        return self._cached_status

    @Slot()
    def refreshStatusAsync(self):
        if self._is_fetching:
            return
        self._is_fetching = True

        def _worker():
            try:
                out, ok, err = self._run_cli(['status', '--json'])
                if ok and out:
                    self._cached_status = out
                    self.statusUpdated.emit(out)
                    try:
                        cache_dir = os.path.expanduser('~/.config/omarchy')
                        os.makedirs(cache_dir, exist_ok=True)
                        with open(os.path.join(cache_dir, 'status_cache.json'), 'w') as f:
                            f.write(out)
                    except Exception:
                        pass
            finally:
                self._is_fetching = False

        threading.Thread(target=_worker, daemon=True).start()

    @Slot(result=str)
    def fetchPing(self):
        out, ok, err = self._run_cli(['ping', '--json'], timeout=20)
        if ok and out:
            self._cached_ping = out
            self.pingUpdated.emit(out)
            return out
        return self._cached_ping

    @Slot(str, str)
    def launchApp(self, server_id, app_cmd):
        cmd = ['foot', '-e', 'node', OCLOUD_BIN, 'vm', 'app', server_id, app_cmd]
        try:
            subprocess.Popen(cmd)
            self.actionCompleted.emit("launchApp", True, f"Launched {app_cmd}")
        except Exception as e:
            self.actionCompleted.emit("launchApp", False, str(e))

    @Slot(str, result=str)
    def inspectMachine(self, server_id):
        out, ok, err = self._run_cli(['vm', 'inspect', server_id, '--json'])
        return out if ok else "{}"

    @Slot(str, str)
    def killProcess(self, server_id, pid):
        out, ok, err = self._run_cli(['vm', 'kill-proc', server_id, pid])
        self.actionCompleted.emit("killProcess", ok, out if ok else err)

    @Slot(str, str)
    def openTerminal(self, server_name, server_ip):
        key_path = os.path.expanduser("~/.ssh/id_ed25519")
        cmd = [
            "foot",
            "-T", f"☁ Ocloud Fleet [{server_name} · {server_ip}]",
            "-o", "colors-dark.background=0a0f1d",
            "-o", "colors-dark.foreground=e2e8f0",
            "-o", "colors-dark.regular4=38bdf8",
            "-e", "ssh", "-i", key_path, "-o", "StrictHostKeyChecking=no", f"root@{server_ip}"
        ]
        try:
            subprocess.Popen(cmd)
            self.actionCompleted.emit("terminal", True, "Terminal opened")
        except Exception as e:
            self.actionCompleted.emit("terminal", False, str(e))

    @Slot(str, str)
    def serverAction(self, action, server_id):
        out, ok, err = self._run_cli(['vm', action, server_id])
        self.actionCompleted.emit(action, ok, out if ok else err)
        self.fetchStatus()

    @Slot()
    def mountStorageBox(self):
        out, ok, err = self._run_cli(['storage', 'mount', 'box'])
        self.actionCompleted.emit("mountStorageBox", ok, out if ok else err)
        self.fetchStatus()

    @Slot()
    def unmountStorageBox(self):
        out, ok, err = self._run_cli(['storage', 'unmount', 'box'])
        self.actionCompleted.emit("unmountStorageBox", ok, out if ok else err)
        self.fetchStatus()

    @Slot(str)
    def mountEphemeralVm(self, server_id):
        out, ok, err = self._run_cli(['vm', 'mount', server_id, '--yes'])
        self.actionCompleted.emit("mountEphemeralVm", ok, out if ok else err)
        self.fetchStatus()

    @Slot()
    def unmountEphemeralVm(self):
        out, ok, err = self._run_cli(['vm', 'unmount'])
        self.actionCompleted.emit("unmountEphemeralVm", ok, out if ok else err)
        self.fetchStatus()

    @Slot(str, str, str, str)
    def procureServer(self, name, srv_type, location, tailscale_key):
        args = ['vm', 'create', name, srv_type, location]
        out, ok, err = self._run_cli(args, timeout=60)
        self.actionCompleted.emit("procureServer", ok, out if ok else err)
        self.fetchStatus()

    @Slot(str, str, bool, str, int)
    def addCustomNode(self, name, host, is_home, user, port):
        args = ['node', 'add', name, host, f'--user={user}', f'--port={port}']
        if is_home:
            args.append('--home')
        out, ok, err = self._run_cli(args)
        self.actionCompleted.emit("addCustomNode", ok, out if ok else err)
        self.fetchStatus()

    @Slot(str)
    def removeNode(self, node_id):
        out, ok, err = self._run_cli(['node', 'remove', node_id])
        self.actionCompleted.emit("removeNode", ok, out if ok else err)
        self.fetchStatus()

    @Slot()
    def runBackup(self):
        out, ok, err = self._run_cli(['backup', 'run'], timeout=180)
        self.actionCompleted.emit("runBackup", ok, out if ok else err)
        self.fetchStatus()

    @Slot(bool, str)
    def setBackupSchedule(self, enabled, interval):
        arg = '--enable' if enabled else '--disable'
        out, ok, err = self._run_cli(['backup', 'schedule', arg, f'--interval={interval}'])
        self.actionCompleted.emit("setBackupSchedule", ok, out if ok else err)
        self.fetchStatus()

    @Slot(str, str)
    def setVaultSecret(self, key, value):
        out, ok, err = self._run_cli(['vault', 'set', key, value])
        self.actionCompleted.emit("setVaultSecret", ok, f"Saved secret {key}")

    @Slot(str, result=str)
    def getVaultSecret(self, key):
        out, ok, err = self._run_cli(['vault', 'get', key])
        return out if ok else ""


def main():
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Ocloud Companion")
    app.setOrganizationName("Omarchy")

    initial_tab = "fleet"
    for arg in sys.argv[1:]:
        if arg.startswith('--tab='):
            initial_tab = arg.split('=')[1]

    backend = OcloudBackend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("ocloud", backend)
    engine.rootContext().setContextProperty("initialTab", initial_tab)

    qml_file = os.path.join(ROOT_DIR, 'app', 'ui', 'MainWindow.qml')
    engine.load(qml_file)

    if not engine.rootObjects():
        print(f"Error: Could not load QML file {qml_file}")
        sys.exit(1)

    sys.exit(app.exec())

if __name__ == '__main__':
    main()
