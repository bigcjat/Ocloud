// HetznerApi.js - Pure JavaScript REST client for Hetzner Cloud API in Quickshell/QML

var API_BASE = "https://api.hetzner.cloud/v1";

function apiRequest(token, method, endpoint, body, onSuccess, onError) {
  if (!token || token.trim() === "") {
    if (onError) onError("No API token provided");
    return;
  }

  var xhr = new XMLHttpRequest();
  xhr.open(method, API_BASE + endpoint);
  xhr.setRequestHeader("Authorization", "Bearer " + token.trim());
  xhr.setRequestHeader("Content-Type", "application/json");
  xhr.setRequestHeader("User-Agent", "Ocloud-Omarchy/1.0");

  xhr.onreadystatechange = function() {
    if (xhr.readyState === XMLHttpRequest.DONE) {
      if (xhr.status >= 200 && xhr.status < 300) {
        try {
          var res = xhr.responseText ? JSON.parse(xhr.responseText) : {};
          if (onSuccess) onSuccess(res);
        } catch (e) {
          if (onError) onError("JSON parse error: " + e);
        }
      } else {
        var errMsg = "HTTP " + xhr.status;
        try {
          var errObj = JSON.parse(xhr.responseText);
          if (errObj.error && errObj.error.message) {
            errMsg = errObj.error.message;
          }
        } catch (e) {}
        if (onError) onError(errMsg);
      }
    }
  };

  xhr.send(body ? JSON.stringify(body) : null);
}

function fetchServers(token, onSuccess, onError) {
  apiRequest(token, "GET", "/servers", null, function(data) {
    if (onSuccess) onSuccess(data.servers || []);
  }, onError);
}

function powerOn(token, serverId, onSuccess, onError) {
  apiRequest(token, "POST", "/servers/" + serverId + "/actions/poweron", null, onSuccess, onError);
}

function powerOff(token, serverId, onSuccess, onError) {
  apiRequest(token, "POST", "/servers/" + serverId + "/actions/poweroff", null, onSuccess, onError);
}

function reboot(token, serverId, onSuccess, onError) {
  apiRequest(token, "POST", "/servers/" + serverId + "/actions/reboot", null, onSuccess, onError);
}

function createServer(token, name, serverType, location, image, sshKeys, userData, onSuccess, onError) {
  var payload = {
    name: name,
    server_type: serverType || "cx23",
    location: location || "nbg1",
    image: image || "ubuntu-24.04",
    start_after_create: true
  };
  if (sshKeys && sshKeys.length > 0) payload.ssh_keys = sshKeys;
  if (userData) payload.user_data = userData;

  apiRequest(token, "POST", "/servers", payload, function(data) {
    if (onSuccess) onSuccess(data.server || {});
  }, onError);
}

function deleteServer(token, serverId, onSuccess, onError) {
  apiRequest(token, "DELETE", "/servers/" + serverId, null, onSuccess, onError);
}
