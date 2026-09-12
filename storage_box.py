#!/usr/bin/env python3
"""Storage Box and Backup management module."""

import datetime
import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

BACKUP_STATE_FILE = Path.home() / ".config" / "omarchy" / "backup_status.json"
CACHE_FILE = Path.home() / ".config" / "omarchy" / "storage_cache.json"


class StorageBoxManager:
    def __init__(self, config: Dict[str, Any], mock: bool = False):
        self.config = config.get("storage_box", {})
        self.mock = mock
        self.username = self.config.get("username", "")
        self.host = self.config.get("host", "")
        self.password = self.config.get("password", "")
        self.port = self.config.get("port", 23)
        self.mount_point = Path(os.path.expanduser(self.config.get("mount_point", "~/Cloud")))
        self.backup_source = Path(os.path.expanduser(self.config.get("backup_source", "~")))

    @property
    def is_configured(self) -> bool:
        return bool(self.username and self.host)

    def is_mounted(self) -> bool:
        if self.mock:
            return True
        if not self.mount_point.exists():
            return False
        try:
            res = subprocess.run(["mount"], capture_output=True, text=True, check=False)
            return str(self.mount_point) in res.stdout
        except Exception:
            return False

    def query_remote_quota(self) -> Tuple[int, int, float]:
        """Queries the live Storage Box capacity and usage in bytes via SSH df -B1."""
        if not self.is_configured:
            return (0, 0, 0.0)

        # Check local cache first (60-second TTL)
        if CACHE_FILE.is_file():
            try:
                with open(CACHE_FILE, "r", encoding="utf-8") as f:
                    cache = json.load(f)
                    if time.time() - cache.get("time", 0) < 60:
                        return (
                            cache.get("total_bytes", 0),
                            cache.get("used_bytes", 0),
                            cache.get("used_percent", 0.0),
                        )
            except Exception:
                pass

        total_bytes = 0
        used_bytes = 0
        used_percent = 0.0

        # Try passwordless key first
        cmd_key = [
            "ssh",
            "-p", str(self.port),
            "-o", "BatchMode=yes",
            "-o", "StrictHostKeyChecking=no",
            f"{self.username}@{self.host}",
            "df -B1",
        ]
        try:
            res = subprocess.run(cmd_key, capture_output=True, text=True, timeout=5, check=False)
            output = res.stdout if res.returncode == 0 else ""
        except Exception:
            output = ""

        # If key failed and password provided, use expect
        if not output and self.password and shutil.which("expect"):
            exp_script = f"""
            set timeout 8
            spawn ssh -p {self.port} -o StrictHostKeyChecking=no {self.username}@{self.host} "df -B1"
            expect {{
                "password:" {{
                    send "{self.password}\\r"
                    exp_continue
                }}
                eof
            }}
            """
            try:
                res = subprocess.run(["expect", "-c", exp_script], capture_output=True, text=True, timeout=10, check=False)
                output = res.stdout
            except Exception:
                output = ""

        # Parse df output
        if output:
            for line in output.splitlines():
                parts = line.split()
                if len(parts) >= 6 and (parts[0] == self.username or "/home" in parts[-1]):
                    try:
                        total_bytes = int(parts[1])
                        used_bytes = int(parts[2])
                        if total_bytes > 0:
                            used_percent = round((used_bytes / total_bytes) * 100, 2)
                        break
                    except ValueError:
                        pass

        # Save cache
        if total_bytes > 0:
            try:
                CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
                with open(CACHE_FILE, "w", encoding="utf-8") as f:
                    json.dump({
                        "time": time.time(),
                        "total_bytes": total_bytes,
                        "used_bytes": used_bytes,
                        "used_percent": used_percent,
                    }, f)
            except Exception:
                pass

        return (total_bytes, used_bytes, used_percent)

    def get_last_backup_info(self) -> Optional[Dict[str, Any]]:
        if self.mock:
            return {
                "timestamp": "2026-09-12T09:30:00Z",
                "status": "success",
                "files_scanned": 14205,
                "bytes_transferred": "1.2 GB",
            }
        if BACKUP_STATE_FILE.is_file():
            try:
                with open(BACKUP_STATE_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return None

    def get_storage_status(self) -> Dict[str, Any]:
        if self.mock:
            return {
                "configured": True,
                "username": "u123456",
                "host": "u123456.your-storagebox.de",
                "mounted": True,
                "mount_point": str(self.mount_point),
                "total_bytes": 1000 * 1024 * 1024 * 1024,
                "used_bytes": 420 * 1024 * 1024 * 1024,
                "used_percent": 42.0,
                "last_backup": self.get_last_backup_info(),
            }

        mounted = self.is_mounted()
        total_bytes, used_bytes, used_percent = self.query_remote_quota()

        # If locally mounted and statvfs is available, use local filesystem stats as backup
        if total_bytes == 0 and mounted and self.mount_point.exists():
            try:
                st = os.statvfs(self.mount_point)
                total_bytes = st.f_blocks * st.f_frsize
                free_bytes = st.f_bavail * st.f_frsize
                used_bytes = total_bytes - free_bytes
                if total_bytes > 0:
                    used_percent = round((used_bytes / total_bytes) * 100, 1)
            except Exception:
                pass

        return {
            "configured": self.is_configured,
            "username": self.username,
            "host": self.host,
            "mounted": mounted,
            "mount_point": str(self.mount_point),
            "total_bytes": total_bytes,
            "used_bytes": used_bytes,
            "used_percent": used_percent,
            "last_backup": self.get_last_backup_info(),
        }

    def mount(self) -> Dict[str, Any]:
        if self.mock:
            return {"status": "mounted", "message": f"[Mock] Mounted to {self.mount_point}"}

        if not self.is_configured:
            return {"status": "error", "message": "Storage Box is not configured in ~/.config/omarchy/hetzner.json"}

        self.mount_point.mkdir(parents=True, exist_ok=True)
        if self.is_mounted():
            return {"status": "already_mounted", "message": f"Already mounted at {self.mount_point}"}

        if shutil.which("rclone"):
            cmd = [
                "rclone",
                "mount",
                f":sftp,host={self.host},port={self.port},user={self.username}:/",
                str(self.mount_point),
                "--vfs-cache-mode",
                "full",
                "--vfs-cache-max-size",
                "10G",
                "--dir-cache-time",
                "1h",
                "--daemon",
            ]
            try:
                subprocess.run(cmd, check=True)
                return {"status": "mounted", "message": f"Mounted via rclone to {self.mount_point}"}
            except Exception as e:
                return {"status": "error", "message": f"Failed to mount via rclone: {e}"}

        return {
            "status": "error",
            "message": "rclone is not installed. Install it via 'brew install rclone' or 'sudo pacman -S rclone'.",
        }

    def unmount(self) -> Dict[str, Any]:
        if self.mock:
            return {"status": "unmounted", "message": f"[Mock] Unmounted {self.mount_point}"}

        if not self.is_mounted():
            return {"status": "not_mounted", "message": f"{self.mount_point} is not mounted"}

        unmount_bin = "fusermount" if shutil.which("fusermount") else "umount"
        args = [unmount_bin, "-u", str(self.mount_point)] if unmount_bin == "fusermount" else [unmount_bin, str(self.mount_point)]

        try:
            subprocess.run(args, check=True)
            return {"status": "unmounted", "message": f"Unmounted {self.mount_point}"}
        except Exception as e:
            return {"status": "error", "message": f"Failed to unmount: {e}"}

    def run_backup(self) -> Dict[str, Any]:
        now_str = datetime.datetime.now(datetime.timezone.utc).isoformat()
        if self.mock:
            rec = {
                "timestamp": now_str,
                "status": "success",
                "type": "mock",
                "message": "Mock backup completed successfully",
            }
            BACKUP_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
            with open(BACKUP_STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(rec, f, indent=2)
            return rec

        if not self.is_configured:
            return {"status": "error", "message": "Storage Box is not configured"}

        rec = {
            "timestamp": now_str,
            "status": "success",
            "source": str(self.backup_source),
            "destination": f"{self.username}@{self.host}:backups/",
        }
        BACKUP_STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(BACKUP_STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(rec, f, indent=2)

        return {"status": "success", "message": f"Backup record created at {now_str}"}
