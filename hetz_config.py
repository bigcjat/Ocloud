#!/usr/bin/env python3
"""Configuration management for Hetzner Companion."""

import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

CONFIG_PATHS = [
    Path.cwd() / "config.json",
    Path.home() / ".config" / "omarchy" / "hetzner.json",
    Path.home() / ".config" / "hetz" / "config.json",
]


def get_config_path() -> Path:
    for p in CONFIG_PATHS:
        if p.is_file():
            return p
    default_path = Path.home() / ".config" / "omarchy" / "hetzner.json"
    default_path.parent.mkdir(parents=True, exist_ok=True)
    return default_path


def load_config() -> Dict[str, Any]:
    config_path = get_config_path()
    config: Dict[str, Any] = {
        "api_token": os.environ.get("HETZNER_API_TOKEN", ""),
        "tailscale_auth_key": os.environ.get("TAILSCALE_AUTH_KEY", ""),
        "storage_box": {
            "username": "",
            "host": "",
            "port": 23,
            "mount_point": str(Path.home() / "Cloud"),
            "backup_source": str(Path.home()),
        },
        "default_vm_type": "cx23",
        "default_location": "nbg1",
    }

    if config_path.is_file():
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                loaded = json.load(f)
                if isinstance(loaded, dict):
                    config.update(loaded)
                    if "storage_box" in loaded and isinstance(loaded["storage_box"], dict):
                        sb = config["storage_box"].copy()
                        sb.update(loaded["storage_box"])
                        config["storage_box"] = sb
        except Exception:
            pass

    env_token = os.environ.get("HETZNER_API_TOKEN")
    if env_token:
        config["api_token"] = env_token

    return config


def save_config(config: Dict[str, Any], path: Optional[Path] = None) -> Path:
    target = path or get_config_path()
    target.parent.mkdir(parents=True, exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)
    os.chmod(target, 0o600)
    return target
