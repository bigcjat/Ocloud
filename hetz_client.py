#!/usr/bin/env python3
"""Hetzner Cloud API client using standard library only."""

import json
import urllib.error
import urllib.request
from typing import Any, Dict, List, Optional

API_BASE = "https://api.hetzner.cloud/v1"


class HetznerCloudError(Exception):
    def __init__(self, message: str, status_code: Optional[int] = None, details: Optional[Dict] = None):
        super().__init__(message)
        self.status_code = status_code
        self.details = details or {}


class HetznerClient:
    def __init__(self, token: str, mock: bool = False):
        self.token = token.strip()
        self.mock = mock

    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict[str, Any]:
        if self.mock:
            return self._mock_response(method, endpoint, data)

        if not self.token:
            raise HetznerCloudError("No Hetzner API token provided. Set it in config or HETZNER_API_TOKEN.")

        url = f"{API_BASE}{endpoint}"
        headers = {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "User-Agent": "Omarchy-Hetzner-Companion/1.0",
        }

        body = json.dumps(data).encode("utf-8") if data is not None else None
        req = urllib.request.Request(url, data=body, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                status = resp.status
                payload = resp.read().decode("utf-8")
                if payload:
                    return json.loads(payload)
                return {"status": status}
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            try:
                err_json = json.loads(err_body)
                msg = err_json.get("error", {}).get("message", e.reason)
            except Exception:
                msg = f"HTTP {e.code}: {e.reason}"
            raise HetznerCloudError(msg, status_code=e.code)
        except urllib.error.URLError as e:
            raise HetznerCloudError(f"Network error: {e.reason}")

    def list_servers(self) -> List[Dict[str, Any]]:
        resp = self._request("GET", "/servers")
        return resp.get("servers", [])

    def get_server(self, server_id_or_name: str) -> Optional[Dict[str, Any]]:
        servers = self.list_servers()
        for s in servers:
            if str(s.get("id")) == str(server_id_or_name) or s.get("name") == server_id_or_name:
                return s
        return None

    def create_server(
        self,
        name: str,
        server_type: str = "cx23",
        image: str = "ubuntu-24.04",
        location: str = "nbg1",
        ssh_keys: Optional[List[str]] = None,
        user_data: Optional[str] = None,
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "name": name,
            "server_type": server_type,
            "image": image,
            "location": location,
            "start_after_create": True,
        }
        if ssh_keys:
            payload["ssh_keys"] = ssh_keys
        if user_data:
            payload["user_data"] = user_data

        resp = self._request("POST", "/servers", payload)
        return resp.get("server", {})

    def delete_server(self, server_id: int) -> bool:
        self._request("DELETE", f"/servers/{server_id}")
        return True

    def power_on(self, server_id: int) -> Dict[str, Any]:
        return self._request("POST", f"/servers/{server_id}/actions/poweron")

    def power_off(self, server_id: int) -> Dict[str, Any]:
        return self._request("POST", f"/servers/{server_id}/actions/poweroff")

    def shutdown(self, server_id: int) -> Dict[str, Any]:
        return self._request("POST", f"/servers/{server_id}/actions/shutdown")

    def reboot(self, server_id: int) -> Dict[str, Any]:
        return self._request("POST", f"/servers/{server_id}/actions/reboot")

    def list_server_types(self) -> List[Dict[str, Any]]:
        resp = self._request("GET", "/server_types")
        return resp.get("server_types", [])

    def list_locations(self) -> List[Dict[str, Any]]:
        resp = self._request("GET", "/locations")
        return resp.get("locations", [])

    def list_ssh_keys(self) -> List[Dict[str, Any]]:
        resp = self._request("GET", "/ssh_keys")
        return resp.get("ssh_keys", [])

    def add_ssh_key(self, name: str, public_key: str) -> Dict[str, Any]:
        payload = {"name": name, "public_key": public_key.strip()}
        resp = self._request("POST", "/ssh_keys", payload)
        return resp.get("ssh_key", {})

    def _mock_response(self, method: str, endpoint: str, data: Optional[Dict] = None) -> Dict[str, Any]:
        if endpoint == "/servers":
            if method == "GET":
                return {
                    "servers": [
                        {
                            "id": 1048576,
                            "name": "omarchy-companion",
                            "status": "running",
                            "server_type": {
                                "name": "cx22",
                                "description": "2 vCPU Intel, 4 GB RAM, 40 GB NVMe",
                                "cores": 2,
                                "memory": 4,
                                "disk": 40,
                            },
                            "datacenter": {
                                "name": "nbg1-dc3",
                                "location": {"name": "nbg1", "city": "Nuremberg", "country": "DE"},
                            },
                            "public_net": {
                                "ipv4": {"ip": "116.203.42.18"},
                                "ipv6": {"ip": "2a01:4f8:c012:3456::1"},
                            },
                            "image": {"description": "Ubuntu 24.04 LTS"},
                        }
                    ]
                }
            elif method == "POST":
                return {
                    "server": {
                        "id": 1048577,
                        "name": data.get("name", "mock-server") if data else "mock-server",
                        "status": "initializing",
                    }
                }
        if "/actions/" in endpoint:
            return {"action": {"status": "running"}}
        return {}
