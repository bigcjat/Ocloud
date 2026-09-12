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
    busyChanged = Signal(bool, str)
    inspectFinished = Signal(str, str)
    dockerContainersUpdated = Signal(str)

    def __init__(self):
        super().__init__()
        self._cached_status = "{}"
        self._cached_ping = "[]"
        self._is_fetching = False
        self._is_busy = False
        self._busy_text = ""

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

    def _set_busy(self, busy, text=""):
        self._is_busy = busy
        self._busy_text = text
        self.busyChanged.emit(busy, text)

    def _run_async_action(self, action_name, busy_msg, args, timeout=60, post_refresh=True):
        self._set_busy(True, busy_msg)
        def _worker():
            try:
                out, ok, err = self._run_cli(args, timeout=timeout)
                self.actionCompleted.emit(action_name, ok, out if ok else err)
                if post_refresh:
                    self.refreshStatusAsync()
            finally:
                self._set_busy(False, "")
        threading.Thread(target=_worker, daemon=True).start()

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

    @Slot()
    def fetchPingAsync(self):
        def _worker():
            out, ok, err = self._run_cli(['ping', '--json'], timeout=20)
            if ok and out:
                self._cached_ping = out
                self.pingUpdated.emit(out)
        threading.Thread(target=_worker, daemon=True).start()

    @Slot(str, str)
    def launchApp(self, server_id, app_cmd):
        cmd = ['foot', '-e', 'node', OCLOUD_BIN, 'vm', 'app', server_id, app_cmd]
        try:
            subprocess.Popen(cmd)
            self.actionCompleted.emit("launchApp", True, f"Launched {app_cmd}")
        except Exception as e:
            self.actionCompleted.emit("launchApp", False, str(e))

    @Slot(str)
    def inspectMachineAsync(self, server_id):
        def _worker():
            out, ok, err = self._run_cli(['vm', 'inspect', server_id, '--json'], timeout=15)
            self.inspectFinished.emit(server_id, out if ok and out else "{}")
        threading.Thread(target=_worker, daemon=True).start()

    @Slot(str, result=str)
    def inspectMachine(self, server_id):
        # Trigger async inspect and return immediate fallback
        self.inspectMachineAsync(server_id)
        return "{}"

    @Slot(str, str)
    def killProcess(self, server_id, pid):
        self._run_async_action("killProcess", f"Terminating PID {pid}...", ['vm', 'kill-proc', server_id, pid])

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
        self._run_async_action(action, f"{action.capitalize()}ing server...", ['vm', action, server_id])

    @Slot()
    def mountStorageBox(self):
        self._run_async_action("mountStorageBox", "Mounting Storage Box to ~/Cloud...", ['storage', 'mount', 'box'])

    @Slot()
    def unmountStorageBox(self):
        self._run_async_action("unmountStorageBox", "Unmounting Storage Box...", ['storage', 'unmount', 'box'])

    @Slot(str)
    def mountEphemeralVm(self, server_id):
        self._run_async_action("mountEphemeralVm", "Mounting VM root filesystem to ~/Companion-VM...", ['vm', 'mount', server_id, '--yes'])

    @Slot()
    def unmountEphemeralVm(self):
        self._run_async_action("unmountEphemeralVm", "Unmounting ~/Companion-VM...", ['vm', 'unmount'])

    @Slot(str, str, str, str)
    def procureServer(self, name, srv_type, location, tailscale_key):
        args = ['vm', 'create', name, srv_type, location]
        self._run_async_action("procureServer", f"Deploying {name} ({srv_type})...", args, timeout=90)

    @Slot(str, str, bool, str, int)
    def addCustomNode(self, name, host, is_home, user, port):
        args = ['node', 'add', name, host, f'--user={user}', f'--port={port}']
        if is_home:
            args.append('--home')
        self._run_async_action("addCustomNode", f"Adding node {name}...", args)

    @Slot(str)
    def removeNode(self, node_id):
        self._run_async_action("removeNode", "Removing node...", ['node', 'remove', node_id])

    @Slot(str)
    def fetchDockerContainers(self, server_id):
        def _worker():
            out, ok, err = self._run_cli(['vm', 'exec', server_id, 'docker ps --format "{{json .}}"'], timeout=12)
            containers = []
            if ok and out:
                for line in out.strip().split('\n'):
                    line = line.strip()
                    if line:
                        try:
                            containers.append(json.loads(line))
                        except Exception:
                            pass
            self.dockerContainersUpdated.emit(json.dumps(containers))
        threading.Thread(target=_worker, daemon=True).start()

    @Slot()
    def runBackup(self):
        self._run_async_action("runBackup", "Running backup snapshot...", ['backup', 'run'], timeout=180)

    @Slot(bool, str)
    def setBackupSchedule(self, enabled, interval):
        arg = '--enable' if enabled else '--disable'
        self._run_async_action("setBackupSchedule", "Updating backup schedule...", ['backup', 'schedule', arg, f'--interval={interval}'])

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
    modal_arg = ""
    for arg in sys.argv[1:]:
        if arg.startswith('--tab='):
            initial_tab = arg.split('=')[1]
        elif arg.startswith('--modal='):
            modal_arg = arg.split('=')[1]

    backend = OcloudBackend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("ocloud", backend)
    engine.rootContext().setContextProperty("initialTab", initial_tab)
    engine.rootContext().setContextProperty("openModalOnStart", modal_arg)

    qml_file = os.path.join(ROOT_DIR, 'app', 'ui', 'MainWindow.qml')
    engine.load(qml_file)

    if not engine.rootObjects():
        print(f"Error: Could not load QML file {qml_file}")
        sys.exit(1)

    sys.exit(app.exec())

if __name__ == '__main__':
    main()
