import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // ==========================================
  // SIGNALS (Matching MainWindow & Child Tabs)
  // ==========================================
  signal statusUpdated(string statusJson)
  signal cloudAccountsUpdated(string accountsJson)
  signal actionCompleted(string action, bool success, string message)
  signal busyChanged(bool busy, string message)
  signal inspectFinished(string serverId, string detailsJson)
  signal dockerContainersUpdated(string containersJson)
  signal workloadPluginsUpdated(string pluginsJson)
  signal nodeDockerStatusUpdated(string serverId, bool installed, bool running, string version)
  signal networkSharesUpdated(string sharesJson)
  signal networkSharesScanned(string sharesJson)
  signal catalogUpdated(string providerId, string catalogJson)
  signal hetznerCatalogUpdated(string catalogJson)
  signal computePluginsUpdated(string pluginsJson)
  signal storagePluginsUpdated(string pluginsJson)
  signal storageMounted(string name, string path)
  signal settingsUpdated(string settingsJson)
  signal desktopNodesUpdated(string nodesJson)
  signal desktopActionCompleted(string action, bool success, string msg)

  // ==========================================
  // CACHED STATE & PATHS
  // ==========================================
  readonly property string homeDir: Quickshell.env("HOME") || "/home/bigcjat"
  readonly property string ocloudBin: homeDir + "/.local/bin/ocloud"

  property string cachedStatus: "{}"
  property string cachedCloudAccounts: "[]"
  property string cachedStoragePlugins: "[]"
  property string cachedComputePlugins: "[]"
  property string cachedWorkloadPlugins: "[]"
  property string cachedDriveCapacities: "{}"
  property string cachedNetworkShares: "[]"
  property string cachedCatalog: "{}"
  property var cachedCatalogsMap: ({})
  property string cachedSettings: "{}"

  // ==========================================
  // PERSISTENT NODE BRIDGE (ZERO-FORK IPC)
  // ==========================================
  property bool bridgeReady: false
  property var pendingCallbacks: ({})
  property int nextReqId: 1

  Process {
    id: bridgeProc
    command: [root.ocloudBin, "bridge"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: data => {
        try {
          var msg = JSON.parse(data);
          if (msg.type === "ready") {
            root.bridgeReady = true;
            return;
          }
          if (msg.id && root.pendingCallbacks[msg.id]) {
            var cb = root.pendingCallbacks[msg.id];
            delete root.pendingCallbacks[msg.id];
            cb(msg.output || "", msg.ok);
          }
        } catch(e) {}
      }
    }
    onExited: (code, status) => {
      root.bridgeReady = false;
      var cbs = root.pendingCallbacks;
      root.pendingCallbacks = ({});
      for (var k in cbs) {
        if (typeof cbs[k] === "function") {
          try { cbs[k]("Bridge process exited unexpectedly (code " + code + ")", false); } catch(e) {}
        }
      }
      bridgeRestartTimer.start();
    }
  }

  Timer {
    id: bridgeRestartTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (!bridgeProc.running) bridgeProc.running = true;
    }
  }

  Component {
    id: bridgeTimeoutTimerComp
    Timer {
      property string reqId: ""
      property int timeoutMs: 15000
      interval: timeoutMs
      running: true
      repeat: false
      onTriggered: {
        if (root.pendingCallbacks && root.pendingCallbacks[reqId]) {
          var cb = root.pendingCallbacks[reqId];
          delete root.pendingCallbacks[reqId];
          console.warn("[OcloudBackend] Bridge request timed out after " + timeoutMs + "ms: " + reqId);
          cb("Operation timed out after " + Math.round(timeoutMs/1000) + "s", false);
        }
        destroy();
      }
    }
  }

  // Helper to run a command and collect output (uses warm Bridge first, fallback to CLI fork)
  function runCli(args, onDone, timeoutMs) {
    var tMs = timeoutMs || 15000;
    if (root.bridgeReady && bridgeProc.running) {
      var reqId = "req_" + (root.nextReqId++);
      var timer = bridgeTimeoutTimerComp.createObject(root, { "reqId": reqId, "timeoutMs": tMs });
      root.pendingCallbacks[reqId] = function(out, ok) {
        if (timer) timer.destroy();
        onDone(out, ok);
      };
      bridgeProc.write(JSON.stringify({ id: reqId, args: args }) + "\n");
      return;
    }

    var proc = dynamicProcComp.createObject(root, {
      "command": [root.ocloudBin].concat(args),
      "timeoutMs": tMs
    });
    proc.finishedCallback = onDone;
    proc.running = true;
  }

  // Helper to run a command directly via dedicated CLI process (for streaming viewers and long installers)
  function runCliDirect(args, onDone, timeoutMs) {
    var proc = dynamicProcComp.createObject(root, {
      "command": [root.ocloudBin].concat(args),
      "timeoutMs": timeoutMs || 30000
    });
    proc.finishedCallback = onDone;
    proc.running = true;
  }

  Component {
    id: dynamicProcComp
    Item {
      id: wrapper
      property alias command: p.command
      property alias running: p.running
      property var finishedCallback: null
      property int timeoutMs: 15000
      property string capturedStdout: ""
      property string capturedStderr: ""

      Timer {
        id: procTimeoutTimer
        interval: wrapper.timeoutMs
        running: p.running
        repeat: false
        onTriggered: {
          if (p.running) {
            console.warn("[OcloudBackend] Command timed out after " + wrapper.timeoutMs + "ms: " + p.command.join(" "));
            p.running = false;
            if (wrapper.finishedCallback) {
              var cb = wrapper.finishedCallback;
              wrapper.finishedCallback = null;
              cb("Operation timed out", false);
            }
            wrapper.destroy();
          }
        }
      }

      Process {
        id: p
        running: false
        stdout: StdioCollector {
          waitForEnd: true
          onStreamFinished: wrapper.capturedStdout = text || ""
        }
        stderr: StdioCollector {
          waitForEnd: true
          onStreamFinished: wrapper.capturedStderr = text || ""
        }
        onExited: (code, status) => {
          procTimeoutTimer.stop();
          if (wrapper.finishedCallback) {
            var cb = wrapper.finishedCallback;
            wrapper.finishedCallback = null;
            var isOk = (code === 0);
            var stdOut = wrapper.capturedStdout.trim();
            var stdErr = wrapper.capturedStderr.trim();
            var finalMsg = isOk ? (stdOut.length > 0 ? stdOut : "Success") : (stdErr.length > 0 ? stdErr : (stdOut.length > 0 ? stdOut : "Command failed with code " + code));
            cb(finalMsg, isOk);
          }
          wrapper.destroy();
        }
      }
    }
  }

  // Streaming runner for live line-by-line terminal output
  function runCliStreaming(args, onLine, onDone, timeoutMs) {
    var proc = streamingProcComp.createObject(root, {
      "command": [root.ocloudBin].concat(args),
      "timeoutMs": timeoutMs || 300000
    });
    proc.lineCallback = onLine;
    proc.finishedCallback = onDone;
    proc.running = true;
  }

  Component {
    id: streamingProcComp
    Item {
      id: streamWrapper
      property alias command: sp.command
      property alias running: sp.running
      property var lineCallback: null
      property var finishedCallback: null
      property int timeoutMs: 300000
      property string capturedStdout: ""
      property string capturedStderr: ""

      Timer {
        id: streamTimeoutTimer
        interval: streamWrapper.timeoutMs
        running: sp.running
        repeat: false
        onTriggered: {
          if (sp.running) {
            sp.running = false;
            if (streamWrapper.finishedCallback) {
              var cb = streamWrapper.finishedCallback;
              streamWrapper.finishedCallback = null;
              cb("Operation timed out after " + Math.round(streamWrapper.timeoutMs / 1000) + "s", false);
            }
            streamWrapper.destroy();
          }
        }
      }

      Process {
        id: sp
        running: false
        stdout: SplitParser {
          onRead: data => {
            var line = String(data || "");
            streamWrapper.capturedStdout += line + "\n";
            if (streamWrapper.lineCallback) {
              streamWrapper.lineCallback(line);
            }
          }
        }
        stderr: SplitParser {
          onRead: data => {
            var line = String(data || "");
            streamWrapper.capturedStderr += line + "\n";
            if (streamWrapper.lineCallback) {
              streamWrapper.lineCallback("[stderr] " + line);
            }
          }
        }
        onExited: (code, status) => {
          streamTimeoutTimer.stop();
          if (streamWrapper.finishedCallback) {
            var cb = streamWrapper.finishedCallback;
            streamWrapper.finishedCallback = null;
            var isOk = (code === 0);
            var stdOut = streamWrapper.capturedStdout.trim();
            var stdErr = streamWrapper.capturedStderr.trim();
            var finalMsg = isOk ? (stdOut.length > 0 ? stdOut : "Success") : (stdErr.length > 0 ? stdErr : (stdOut.length > 0 ? stdOut : "Process exited with code " + code));
            cb(finalMsg, isOk);
          }
          streamWrapper.destroy();
        }
      }
    }
  }

  function verifyProvider(providerId, callback) {
    runCli(["providers", "verify", providerId || "gcp", "--json"], function(out, ok) {
      try {
        var parsed = JSON.parse(out);
        if (callback) callback(parsed, Boolean(parsed && parsed.ok));
      } catch(e) {
        if (callback) callback({ ok: false, error: out }, false);
      }
    });
  }

  function scanDownloadsForKeys(callback) {
    runCli(["vault", "scan-keys"], function(out, ok) {
      var files = [];
      if (ok && out) {
        try { files = JSON.parse(out); } catch(e) {}
      }
      if (callback) callback(files);
    });
  }

  // ==========================================
  // STATUS & MONITORING
  // ==========================================
  Timer {
    id: statusWatchdog
    interval: 10000
    running: statusProc.running
    repeat: false
    onTriggered: {
      if (statusProc.running) {
        console.warn("[OcloudBackend] statusProc watchdog timeout, aborting.");
        statusProc.running = false;
        root.busyChanged(false, "");
      }
    }
  }

  Process {
    id: statusProc
    command: [root.ocloudBin, "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        statusProc.running = false;
        statusWatchdog.stop();
        root.busyChanged(false, "");
        if (text && text.trim().length > 0) {
          root.cachedStatus = text;
          root.statusUpdated(text);
          try {
            var s = JSON.parse(text);
            if (s.storage && s.storage.cloud_accounts) {
              root.cachedCloudAccounts = JSON.stringify(s.storage.cloud_accounts);
              root.cloudAccountsUpdated(root.cachedCloudAccounts);
            }
            var hasTrans = false;
            if (s.servers && Array.isArray(s.servers)) {
              for (var i = 0; i < s.servers.length; i++) {
                var srv = s.servers[i];
                if (srv.status === "starting" || srv.status === "stopping" || srv.status === "provisioning" || srv.ipv4 === "no IP" || !srv.ipv4) {
                  hasTrans = true;
                  break;
                }
              }
            }
            fleetPollTimer.interval = hasTrans ? 4000 : 30000;
          } catch(e) {}
        }
      }
    }
  }

  Timer {
    id: fleetPollTimer
    interval: 30000
    running: true
    repeat: true
    onTriggered: {
      refreshStatusAsync();
    }
  }

  function fetchStatus() {
    refreshStatusAsync();
    return root.cachedStatus;
  }

  function refreshStatusAsync() {
    if (!statusProc.running) {
      statusProc.running = true;
    }
  }

  // ==========================================
  // CLOUD STORAGE & ACCOUNTS
  // ==========================================
  Timer {
    id: accountsWatchdog
    interval: 10000
    running: accountsProc.running
    repeat: false
    onTriggered: {
      if (accountsProc.running) {
        console.warn("[OcloudBackend] accountsProc watchdog timeout, aborting.");
        accountsProc.running = false;
      }
    }
  }

  Process {
    id: accountsProc
    command: [root.ocloudBin, "storage", "list", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        accountsProc.running = false;
        accountsWatchdog.stop();
        if (text && text.trim().length > 0) {
          root.cachedCloudAccounts = text;
          root.cloudAccountsUpdated(text);
        }
      }
    }
  }

  function fetchCloudAccounts() {
    fetchCloudAccountsAsync();
    return root.cachedCloudAccounts;
  }

  function fetchCloudAccountsAsync() {
    if (!accountsProc.running) {
      accountsProc.running = true;
    }
  }

  function mountCloudAccount(name, path, callback) {
    root.busyChanged(true, "Mounting " + name + "...");
    runCli(["storage", "mount", name, path || ""], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name) : (out || ("Failed to mount " + name));
      root.actionCompleted("mountCloudAccount", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 35000);
  }

  function unmountCloudAccount(path, callback) {
    root.busyChanged(true, "Unmounting " + path + "...");
    runCli(["storage", "unmount", path], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Unmounted " + path) : (out || ("Failed to unmount " + path));
      root.actionCompleted("unmountCloudAccount", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 20000);
  }

  function openCloudFolder(path) {
    runCli(["storage", "open", path], function() {});
  }

  function toggleAutoMount(name) {
    runCli(["storage", "toggle-auto-mount", name], function(out, ok) {
      root.actionCompleted("toggleAutoMount", ok, ok ? ("Updated auto-mount for " + name) : ("Failed to update auto-mount: " + out));
      root.fetchCloudAccountsAsync();
    });
  }

  function disconnectCloudAccount(name) {
    root.busyChanged(true, "Removing " + name + "...");
    runCli(["storage", "remove", name], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("disconnectCloudAccount", ok, "Removed " + name);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
    });
  }

  function mountStorageBox() {
    mountCloudAccount("storagebox", "~/Cloud");
  }

  function unmountStorageBox() {
    unmountCloudAccount("storagebox");
  }

  // ==========================================
  // STORAGE PLUGINS, CAPACITIES & SHARES
  // ==========================================
  Process {
    id: pluginsProc
    command: [root.ocloudBin, "storage", "plugins"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          root.cachedStoragePlugins = text;
          root.storagePluginsUpdated(root.cachedStoragePlugins);
        }
      }
    }
  }

  Process {
    id: computePluginsProc
    command: [root.ocloudBin, "providers", "list", "compute", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (text && text.trim().length > 0) {
          try {
            var parsed = JSON.parse(text.trim());
            var list = Array.isArray(parsed) ? parsed : (parsed.compute || []);
            if (list.length > 0) {
              root.cachedComputePlugins = JSON.stringify(list);
              root.computePluginsUpdated(root.cachedComputePlugins);
            }
          } catch(e) {}
        }
      }
    }
  }

  function fetchStoragePlugins(force) {
    if (force || (!pluginsProc.running && root.cachedStoragePlugins === "[]")) {
      pluginsProc.running = true;
    }
    return root.cachedStoragePlugins;
  }

  Timer {
    id: capacitiesWatchdog
    interval: 8000
    running: capacitiesProc.running
    repeat: false
    onTriggered: {
      if (capacitiesProc.running) {
        console.warn("[OcloudBackend] capacitiesProc watchdog timeout, aborting.");
        capacitiesProc.running = false;
      }
    }
  }

  Process {
    id: capacitiesProc
    command: [root.ocloudBin, "storage", "capacities"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        capacitiesProc.running = false;
        capacitiesWatchdog.stop();
        if (text && text.trim().length > 0) {
          root.cachedDriveCapacities = text;
        }
      }
    }
  }

  function getDriveCapacities() {
    if (!capacitiesProc.running) {
      capacitiesProc.running = true;
    }
    return root.cachedDriveCapacities;
  }

  Timer {
    id: sharesWatchdog
    interval: 8000
    running: sharesProc.running
    repeat: false
    onTriggered: {
      if (sharesProc.running) {
        console.warn("[OcloudBackend] sharesProc watchdog timeout, aborting.");
        sharesProc.running = false;
      }
    }
  }

  Process {
    id: sharesProc
    command: [root.ocloudBin, "storage", "shares"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        sharesProc.running = false;
        sharesWatchdog.stop();
        if (text && text.trim().length > 0) {
          root.cachedNetworkShares = text;
          root.networkSharesUpdated(text);
          root.networkSharesScanned(text);
        }
      }
    }
  }

  function getNetworkShares() {
    if (!sharesProc.running && root.cachedNetworkShares === "[]") {
      sharesProc.running = true;
    }
    return root.cachedNetworkShares;
  }

  function scanNetworkSharesAsync() {
    sharesProc.running = true;
  }

  function mountSmbShare(host, share, user, pass, mountPath) {
    root.busyChanged(true, "Mounting SMB share //" + host + "/" + share + "...");
    runCli(["storage", "mount-smb", host, share, user || "guest", pass || "", mountPath || ""], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("mountSmbShare", ok, ok ? ("Mounted //" + host + "/" + share) : ("Failed to mount share: " + out));
      root.refreshStatusAsync();
      root.scanNetworkSharesAsync();
    });
  }

  // ==========================================
  // PROVIDER REGISTRATION (Proton, S3, WebDAV, SFTP, OAuth)
  // ==========================================
  function addProtonDriveStorage(name, username, password, twofa, mailboxPass, mountPath, callback) {
    root.busyChanged(true, "Configuring Proton Drive in Vault & mounting...");
    var args = ["storage", "add-proton", name, username, password];
    args.push(twofa ? twofa : "");
    args.push(mailboxPass ? mailboxPass : "");
    args.push(mountPath ? mountPath : "");
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name + " to " + (mountPath || "~/ProtonDrive")) : (out || "Failed to add Proton Drive");
      root.actionCompleted("addProtonDriveStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addMegaStorage(name, username, password, mountPath, callback) {
    root.busyChanged(true, "Configuring MEGA in Vault & mounting...");
    var args = ["storage", "add-mega", name, username, password];
    args.push(mountPath ? mountPath : "");
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name + " to " + (mountPath || "~/Mega")) : (out || "Failed to add MEGA storage");
      root.actionCompleted("addMegaStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addKoofrStorage(name, username, password, mountPath, callback) {
    root.busyChanged(true, "Configuring Koofr in Vault & mounting...");
    var args = ["storage", "add-koofr", name, username, password];
    args.push(mountPath ? mountPath : "");
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name + " to " + (mountPath || "~/Koofr")) : (out || "Failed to add Koofr storage");
      root.actionCompleted("addKoofrStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addFilenStorage(name, email, password, twofa, mountPath, callback) {
    root.busyChanged(true, "Configuring Filen in Vault & mounting...");
    var args = ["storage", "add-filen", name, email, password];
    args.push(twofa ? twofa : "");
    args.push(mountPath ? mountPath : "");
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name + " to " + (mountPath || "~/Filen")) : (out || "Failed to add Filen storage");
      root.actionCompleted("addFilenStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addS3Storage(name, endpoint, bucket, key, secret, mountPath, callback) {
    root.busyChanged(true, "Configuring S3 in Vault & mounting...");
    runCli(["storage", "add-s3", name, endpoint, bucket || "", key, secret, mountPath || ""], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name) : (out || "Failed to add S3 storage");
      root.actionCompleted("addS3Storage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addWebdavStorage(name, endpoint, user, pass, vendor, mountPath, callback) {
    root.busyChanged(true, "Configuring WebDAV in Vault & mounting...");
    runCli(["storage", "add-webdav", name, endpoint, user, pass, vendor || "other", mountPath || ""], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name) : (out || "Failed to add WebDAV storage");
      root.actionCompleted("addWebdavStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function addSftpStorage(name, host, user, pass, mountPath, callback) {
    root.busyChanged(true, "Configuring SFTP in Vault & mounting...");
    runCli(["storage", "add-sftp", name, host, user, pass, mountPath || ""], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? ("Mounted " + name) : (out || "Failed to add SFTP storage");
      root.actionCompleted("addSftpStorage", ok, msg);
      root.refreshStatusAsync();
      root.fetchCloudAccountsAsync();
      if (callback) callback(ok, msg);
    }, 45000);
  }

  function connectCloudAccount(type, name, extraArgs) {
    var rName = name || type;
    var cmd = ["foot", "-T", ("Connect " + rName), root.homeDir + "/.local/bin/rclone", "config", "create", rName, type];
    if (extraArgs) {
      var parts = String(extraArgs).split(" ");
      for (var i = 0; i < parts.length; i++) {
        if (parts[i]) cmd.push(parts[i]);
      }
    }
    var proc = dynamicProcComp.createObject(root, { "command": cmd });
    proc.running = true;
  }

  // ==========================================
  // COMPUTE FLEET & VM MANAGEMENT
  // ==========================================
  function serverAction(act, id) {
    root.busyChanged(true, "Performing " + act + " on VM " + id + "...");
    runCli(["vm", act, id], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("serverAction", ok, out);
      root.refreshStatusAsync();
    });
  }

  function inspectMachineAsync(id) {
    runCli(["vm", "inspect", id, "--json"], function(out, ok) {
      root.inspectFinished(id, out);
    });
  }

  function killProcess(id, pid) {
    runCli(["vm", "kill-proc", id, pid], function(out, ok) {
      root.actionCompleted("killProcess", ok, out);
      inspectMachineAsync(id);
    });
  }

  function fetchAppShortcuts(callback) {
    runCli(["app", "list"], function(out, ok) {
      var list = [];
      if (ok && out) {
        try { list = JSON.parse(out); } catch(e) {}
      }
      if (callback) callback(list);
    });
  }

  function probeAllApps(serverId, callback) {
    runCli(["app", "probe-all", serverId], function(out, ok) {
      var res = { success: false, apps: {} };
      try {
        res = JSON.parse(out.trim());
      } catch (e) {
        res = { success: false, error: out, apps: {} };
      }
      if (callback) callback(res, ok);
    }, 20000);
  }

  function probeApp(serverId, app, callback) {
    runCli(["app", "probe", serverId, app], function(out, ok) {
      var res = null;
      try { res = JSON.parse(out.trim()); } catch (e) {
        res = { installed: false, error: out };
      }
      if (callback) callback(res, ok);
    });
  }

  function installApp(serverId, app, callback) {
    runCliDirect(["app", "install", serverId, app], function(out, ok) {
      if (callback) callback(ok, out);
    }, 300000);
  }

  function installAppStreaming(serverId, app, onLine, callback) {
    runCliStreaming(["app", "install", serverId, app], onLine, function(out, ok) {
      if (callback) callback(ok, out);
    }, 300000);
  }

  function launchApp(serverId, app, engine, audio) {
    var args = ["app", "launch", serverId, app];
    if (engine) args.push("--engine=" + engine);
    if (audio === true) args.push("--audio");
    else if (audio === false) args.push("--no-audio");
    runCliDirect(args, function(out, ok) {
      root.actionCompleted("launchApp", ok, out);
    }, 300000);
  }

  function attachAppSession(serverId, display, audio) {
    var args = ["app", "attach", serverId];
    if (display) args.push(display);
    if (audio === true) args.push("--audio");
    else if (audio === false) args.push("--no-audio");
    runCliDirect(args, function(out, ok) {
      root.actionCompleted("attachAppSession", ok, out);
    }, 30000);
  }

  function detachAppSession(callback) {
    runCli(["app", "detach"], function(out, ok) {
      root.actionCompleted("detachAppSession", ok, out);
      if (callback) callback(ok);
    });
  }

  function stopAppSession(serverId, display, callback) {
    runCli(["app", "stop", serverId, display || ":100"], function(out, ok) {
      root.actionCompleted("stopAppSession", ok, out);
      if (callback) callback(ok);
    });
  }

  function checkAppAttached(callback) {
    runCli(["app", "is-attached"], function(out, ok) {
      var attached = false;
      try {
        var parsed = JSON.parse(out.trim());
        if (parsed) attached = Boolean(parsed.attached);
      } catch (e) {}
      if (callback) callback(attached);
    });
  }

  function fetchAppSessions(serverId, callback) {
    runCli(["app", "sessions", serverId], function(out, ok) {
      if (callback) callback(out, ok);
    });
  }

  function setStreamingEngine(engine, callback) {
    runCli(["app", "engine", engine], function(out, ok) {
      if (callback) callback(ok);
    });
  }

  function getStreamingEngine(callback) {
    runCli(["app", "engine", "get"], function(out, ok) {
      var res = "xpra";
      try {
        var parsed = JSON.parse(out.trim());
        if (parsed && parsed.engine) res = parsed.engine;
      } catch (e) {}
      if (callback) callback(res);
    });
  }

  function setStreamingAudio(audio, callback) {
    runCli(["app", "audio", audio ? "on" : "off"], function(out, ok) {
      if (callback) callback(ok);
    });
  }

  function getStreamingAudio(callback) {
    runCli(["app", "audio", "get"], function(out, ok) {
      var res = true;
      try {
        var parsed = JSON.parse(out.trim());
        if (parsed && parsed.audio !== undefined) res = Boolean(parsed.audio);
      } catch (e) {}
      if (callback) callback(res);
    });
  }

  function mountEphemeralVm(serverId) {
    root.busyChanged(true, "Mounting ephemeral companion drive...");
    runCli(["vm", "mount", serverId || "", "--yes"], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("mountEphemeralVm", ok, out);
      root.refreshStatusAsync();
    });
  }

  function unmountEphemeralVm() {
    root.busyChanged(true, "Unmounting ephemeral drive...");
    runCli(["vm", "unmount"], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("unmountEphemeralVm", ok, out);
      root.refreshStatusAsync();
    });
  }

  function openTerminal(name, ip, user, execCmd) {
    var u = user || "root";
    var targetIp = ip || "";
    if (!targetIp) return;
    var sshKey = root.homeDir + "/.ssh/id_ed25519";
    var title = "SSH: " + name + " (" + targetIp + ")";
    var remote = execCmd ? ("-t \"" + u + "@" + targetIp + "\" \"" + execCmd + "\"") : ("\"" + u + "@" + targetIp + "\"");
    var termCmd = [
      "foot",
      "-T", title,
      "bash", "-c",
      "ssh -i \"" + sshKey + "\" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 " + remote + " || (echo ''; echo '❌ SSH connection closed or failed. Press Enter to close...'; read _)"
    ];
    Quickshell.execDetached(termCmd);
  }

  function launchRcloneConfig() {
    var proc = dynamicProcComp.createObject(root, {
      "command": ["foot", "-T", "Rclone Storage Configurator", root.homeDir + "/.local/bin/rclone", "config"]
    });
    proc.running = true;
  }

  function addCustomNode(name, host, user, port, keyPath) {
    runCli(["node", "add", name, host, user, port || "22", keyPath || ""], function(out, ok) {
      root.actionCompleted("addCustomNode", ok, out);
      root.refreshStatusAsync();
    });
  }

  function removeNode(id) {
    runCli(["node", "remove", id], function(out, ok) {
      root.actionCompleted("removeNode", ok, out);
      root.refreshStatusAsync();
    });
  }

  function listComputeServers() {
    refreshStatusAsync();
  }

  // ==========================================
  // CATALOG & PROCUREMENT
  // ==========================================
  function fetchComputePlugins() {
    if (root.cachedComputePlugins && root.cachedComputePlugins.length > 5) {
      return root.cachedComputePlugins;
    }
    refreshComputePluginsAsync();
    return JSON.stringify([
      {
        "id": "custom",
        "name": "Bare-Metal / Home Rig",
        "badge": "SSH Direct",
        "badgeColor": "#38bdf8",
        "tagline": "Connect any existing Linux box, home lab, or unmanaged VPS via SSH.",
        "pricingFrom": "€0.000 / hr",
        "isConfigured": true,
        "securityStatus": "PASSED",
        "auth": {
          "type": "ssh",
          "fields": [
            { "key": "host", "label": "Hostname / IP Address", "type": "text", "required": true },
            { "key": "port", "label": "SSH Port", "type": "number", "default": 22 },
            { "key": "user", "label": "SSH Username", "type": "text", "default": "root" },
            { "key": "key_path", "label": "Private Key Path", "type": "text", "default": "~/.ssh/id_ed25519" }
          ]
        }
      },
      {
        "id": "gcp",
        "name": "Google Cloud",
        "badge": "Enterprise API",
        "badgeColor": "#4285F4",
        "tagline": "Global cloud infrastructure with per-second billing.",
        "pricingFrom": "$0.0084 / hr",
        "currency": "USD",
        "currencySymbol": "$",
        "isConfigured": false,
        "securityStatus": "PASSED",
        "auth": {
          "type": "service_account",
          "title": "Google Cloud Service Account",
          "subtitle": "Connect Ocloud directly using a Google Cloud Service Account JSON Key",
          "guideUrl": "https://console.cloud.google.com/iam-admin/serviceaccounts",
          "guideButtonText": "Open Console ↗",
          "guideSteps": [
            "Open Google Cloud Console > IAM & Admin > Service Accounts",
            "Create a Service Account and grant the 'Compute Admin' role (roles/compute.admin)",
            "Click your Service Account > Keys tab > Add Key > Create new key > JSON, and download the file",
            "Load your downloaded key using the button below or paste the JSON key content directly"
          ],
          "fileDrop": { "pattern": "json", "label": "Detected Service Account Key in Downloads:" },
          "fields": [
            { "key": "gcp_service_account_json", "label": "Service Account JSON / Credentials", "placeholder": "{\n  \"type\": \"service_account\",\n  \"project_id\": \"your-project-id\",\n  \"private_key\": \"-----BEGIN RSA PRIVATE KEY-----...\"\n}", "type": "textarea", "required": true },
            { "key": "gcp_project_id", "label": "GCP Project ID", "placeholder": "e.g. my-project-id", "type": "text", "required": false },
            { "key": "gcp_default_zone", "label": "Default Zone", "placeholder": "us-central1-a", "type": "text", "default": "us-central1-a" }
          ]
        }
      },
      {
        "id": "hetzner",
        "name": "Hetzner Cloud",
        "badge": "Integrated API",
        "badgeColor": "#d50c2d",
        "tagline": "Ultra-fast European, US & Singapore cloud infrastructure with hourly billing.",
        "pricingFrom": "€0.005 / hr",
        "currency": "EUR",
        "currencySymbol": "€",
        "isConfigured": true,
        "securityStatus": "PASSED",
        "auth": {
          "type": "token",
          "title": "Hetzner Cloud API Token",
          "subtitle": "Connect your Hetzner Cloud project using a personal API token",
          "guideUrl": "https://console.hetzner.cloud/projects",
          "guideButtonText": "Open Console ↗",
          "guideSteps": [
            "Open Hetzner Cloud Console > Choose your Project",
            "Navigate to Security > API Tokens > Generate API Token with Read & Write permissions",
            "Paste the token into the field below and click 'Verify & Connect Account'"
          ],
          "fields": [
            { "key": "api_token", "label": "Hetzner Cloud API Token", "placeholder": "Enter your Hetzner Cloud API token", "type": "password", "required": true }
          ]
        }
      }
    ]);
  }

  function refreshComputePluginsAsync() {
    if (!computePluginsProc.running) {
      computePluginsProc.running = true;
    }
  }

  function fetchCatalog(providerId) {
    var p = providerId || "gcp";
    refreshCatalogAsync(p);
    if (root.cachedCatalogsMap && root.cachedCatalogsMap[p]) {
      return root.cachedCatalogsMap[p];
    }
    return root.cachedCatalog || "{}";
  }

  function refreshCatalogAsync(providerId) {
    var p = providerId || "gcp";
    runCli(["catalog", p, "--json", "--refresh"], function(out, ok) {
      if (ok && out) {
        root.cachedCatalog = out;
        if (!root.cachedCatalogsMap) root.cachedCatalogsMap = {};
        root.cachedCatalogsMap[p] = out;
        root.catalogUpdated(p, out);
        if (p === "hetzner") {
          root.hetznerCatalogUpdated(out);
        }
      }
    });
  }

  function fetchHetznerCatalogAsync() {
    refreshCatalogAsync("hetzner");
  }

  function procureServer(name, type, location, tsKey, os, provider) {
    root.busyChanged(true, "Procuring cloud server " + name + "...");
    var args = ["vm", "create", name, type || "cx23", location || "nbg1"];
    if (os) args.push("--os=" + os);
    if (provider) args.push("--provider=" + provider);
    if (tsKey) args.push("--ts=" + tsKey);

    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("procureServer", ok, ok ? ("Server " + name + " provisioned successfully!") : ("Procurement failed: " + out));
      root.refreshStatusAsync();
    });
  }

  // ==========================================
  // WORKLOADS & CONTAINERS
  // ==========================================
  function fetchWorkloadPlugins() {
    runCli(["workload", "templates", "--json"], function(out, ok) {
      if (ok && out) {
        cachedWorkloadPlugins = out.trim();
        root.workloadPluginsUpdated(cachedWorkloadPlugins);
      }
    });
  }

  function checkNodeDocker(serverId) {
    if (!serverId) return;
    runCli(["workload", "status", serverId, "--json"], function(out, ok) {
      try {
        var data = JSON.parse(out);
        root.nodeDockerStatusUpdated(serverId, data.installed || false, data.running || false, data.version || "");
      } catch (e) {
        root.nodeDockerStatusUpdated(serverId, false, false, "");
      }
    }, 40000);
  }

  function bootstrapNodeDocker(serverId) {
    if (!serverId) return;
    root.busyChanged(true, "Bootstrapping Docker engine on " + serverId + " (this may take 1-2 minutes)...");
    runCli(["workload", "bootstrap", serverId, "--json"], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("bootstrapDocker", ok, ok ? "Docker engine installed successfully!" : ("Bootstrap failed: " + out));
      checkNodeDocker(serverId);
      fetchDockerContainers(serverId);
    }, 180000);
  }

  function fetchDockerContainers(serverId) {
    if (!serverId) return;
    console.log("[OcloudBackend] fetchDockerContainers triggered for", serverId);
    runCli(["workload", "list", serverId, "--json"], function(out, ok) {
      console.log("[OcloudBackend] fetchDockerContainers received out len:", (out || "").length, "ok:", ok);
      var list = [];
      if (ok && out) {
        try { list = JSON.parse(out); } catch(e) {}
      }
      root.dockerContainersUpdated(JSON.stringify(list));
    }, 40000);
  }

  function deployDockerContainer(serverId, config, callback) {
    if (!serverId || !config) return;
    root.busyChanged(true, "Deploying container " + (config.name || config.image || "") + "...");
    var args = ["workload", "deploy", serverId, config.image || config.templateId || ""];
    if (config.name) args.push("--name=" + config.name);
    if (config.ports) args.push("--ports=" + config.ports);
    if (config.tailscale === false) args.push("--public");
    else args.push("--tailscale");
    if (config.volumes) args.push("--volumes=" + config.volumes);
    if (config.env) {
      for (var k in config.env) {
        args.push("--env=" + k + "=" + config.env[k]);
      }
    }
    args.push("--json");
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("deployContainer", ok, ok ? "Container deployed successfully!" : ("Deploy failed: " + out));
      fetchDockerContainers(serverId);
      if (typeof callback === "function") callback(ok, out);
    }, 120000);
  }

  function containerAction(serverId, containerId, action) {
    if (!serverId || !containerId) return;
    var act = action || "restart";
    root.busyChanged(true, "Performing " + act + " on " + containerId + "...");
    runCli(["workload", "action", serverId, containerId, act, "--json"], function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("containerAction", ok, out);
      fetchDockerContainers(serverId);
    }, 45000);
  }

  function saveCustomWorkload(manifest, callback) {
    runCli(["workload", "save-template", JSON.stringify(manifest), "--json"], function(out, ok) {
      fetchWorkloadPlugins();
      if (typeof callback === "function") callback(ok, out);
    });
  }

  function deleteCustomWorkload(id, callback) {
    runCli(["workload", "delete-template", id, "--json"], function(out, ok) {
      fetchWorkloadPlugins();
      if (typeof callback === "function") callback(ok, out);
    });
  }

  function openContainerShell(serverName, ip, containerName) {
    openTerminal(containerName, ip, "root", "docker exec -it " + containerName + " /bin/sh || docker exec -it " + containerName + " /bin/bash");
  }

  // ==========================================
  // SOVEREIGN REMOTE DESKTOP
  // ==========================================
  function fetchDesktopNodes(callback) {
    runCli(["desktop", "list", "--json"], function(out, ok) {
      if (ok && out) {
        root.desktopNodesUpdated(out.trim());
      }
      if (typeof callback === "function") callback(ok, out);
    }, 25000);
  }

  function probeDesktopNode(nodeId, callback) {
    if (!nodeId) return;
    runCli(["desktop", "probe", nodeId, "--json"], function(out, ok) {
      if (typeof callback === "function") callback(ok, out);
    }, 15000);
  }

  function launchDesktopBreakout(nodeId, user, pass, callback) {
    if (!nodeId) return;
    root.busyChanged(true, "Launching standalone remote desktop for " + nodeId + "...");
    var args = ["desktop", "launch", nodeId, "--json"];
    if (user) args.push("--user=" + user);
    if (pass) args.push("--password=" + pass);

    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? "Remote desktop breakout launched!" : ("Launch failed: " + out);
      root.actionCompleted("launchDesktop", ok, msg);
      if (typeof callback === "function") callback(ok, out);
    }, 30000);
  }

  function launchDesktopTerminal(nodeId, user, callback) {
    if (!nodeId) return;
    var args = ["desktop", "terminal", nodeId, "--json"];
    if (user) args.push("--user=" + user);

    runCli(args, function(out, ok) {
      var msg = ok ? "Terminal launched in Hyprland!" : ("Terminal launch failed: " + out);
      root.actionCompleted("launchTerminal", ok, msg);
      if (typeof callback === "function") callback(ok, out);
    }, 15000);
  }

  function saveDesktopCredentials(nodeId, user, pass, callback) {
    if (!nodeId) return;
    runCli(["desktop", "save-creds", nodeId, user || "", pass || "", "--json"], function(out, ok) {
      if (typeof callback === "function") callback(ok, out);
    }, 10000);
  }

  function installLocalViewers(callback) {
    runCli(["desktop", "install-viewers", "--json"], function(out, ok) {
      if (typeof callback === "function") callback(ok, out);
    }, 15000);
  }

  function bootstrapRemoteDesktop(nodeId, callback) {
    if (!nodeId) return;
    root.busyChanged(true, "Configuring Remote Desktop on " + nodeId + " over SSH...");
    runCli(["desktop", "bootstrap", nodeId, "--json"], function(out, ok) {
      root.busyChanged(false, "");
      var msg = ok ? "Remote Desktop service configured and running!" : ("Setup failed: " + out);
      root.actionCompleted("bootstrapDesktop", ok, msg);
      if (typeof callback === "function") callback(ok, out);
    }, 180000);
  }

  // ==========================================
  // BACKUPS
  // ==========================================
  function runBackup(source, dest) {
    root.busyChanged(true, "Running backup snapshot...");
    var args = ["backup", "run"];
    if (source) args.push("--source=" + source);
    if (dest) args.push("--dest=" + dest);
    runCli(args, function(out, ok) {
      root.busyChanged(false, "");
      root.actionCompleted("runBackup", ok, out);
      root.refreshStatusAsync();
    });
  }

  function setBackupSchedule(enabled, interval, source, dest) {
    var args = ["backup", "schedule", enabled ? "--enable" : "--disable", "--interval=" + (interval || "daily")];
    if (source) args.push("--source=" + source);
    if (dest) args.push("--dest=" + dest);
    runCli(args, function(out, ok) {
      root.actionCompleted("setBackupSchedule", ok, out);
      root.refreshStatusAsync();
    });
  }

  // ==========================================
  // SETTINGS & FILE MANAGERS
  // ==========================================
  function getAvailableFileManagers() {
    return JSON.stringify([
      { "id": "default", "name": "System Default (xdg-open)", "badge": "Standard", "desc": "Uses desktop default file manager association", "available": true },
      { "id": "flea", "name": "Flea", "badge": "Recommended", "desc": "Blazing fast Rust terminal file manager", "available": true },
      { "id": "nautilus", "name": "GNOME Files (Nautilus)", "badge": "GUI", "desc": "Full-featured GTK desktop file manager", "available": true },
      { "id": "thunar", "name": "Thunar", "badge": "XFCE", "desc": "Lightweight GTK file manager", "available": false },
      { "id": "dolphin", "name": "Dolphin", "badge": "KDE", "desc": "Advanced desktop file manager", "available": false },
      { "id": "custom", "name": "Custom Command", "badge": "Advanced", "desc": "Execute user-defined file manager command", "available": true }
    ]);
  }

  function fetchFileManagers() {
    return getAvailableFileManagers();
  }

  function testLaunchFileManager(mgr, customCommand) {
    runCli(["storage", "open", "~/Cloud"], function() {});
  }

  // Reactive settings watcher from ~/.config/ocloud/settings.json
  FileView {
    id: settingsFile
    path: root.homeDir + "/.config/ocloud/settings.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var txt = text();
        if (txt && txt.trim().length > 0) {
          root.cachedSettings = txt;
          root.settingsUpdated(txt);
        }
      } catch(e) {}
    }
    onFileChanged: reload()
  }

  function fetchSettings() {
    try {
      if (settingsFile.text() && settingsFile.text().trim().length > 0) {
        root.cachedSettings = settingsFile.text();
      }
    } catch(e) {}
    return root.cachedSettings || "{}";
  }

  function saveSettings(settingsJson) {
    root.cachedSettings = settingsJson;
    root.settingsUpdated(settingsJson);
    runCli(["settings", "save", settingsJson], function(out, ok) {
      root.actionCompleted("saveSettings", ok, "Settings saved.");
      try { settingsFile.reload(); } catch(e) {}
    });
  }

  function getVaultSecret(key) {
    return "";
  }

  function getVaultKeyInfo(key, callback) {
    runCli(["vault", "key-info", key || "tailscale_auth_key"], function(out, ok) {
      if (callback) {
        try {
          callback(JSON.parse(out), ok);
        } catch(e) {
          callback({ hasKey: false, masked: "", daysSince: null }, false);
        }
      }
    });
  }

  function setVaultSecret(key, val) {
    runCli(["vault", "set", key, val], function(out, ok) {
      root.actionCompleted("setVaultSecret", ok, "Saved secret " + key);
    });
  }

  function importVaultKeyFile(key, filePath, callback) {
    runCli(["vault", "set-file", key, filePath], function(out, ok) {
      root.actionCompleted("importVaultKeyFile", ok, "Imported key " + key);
      if (callback) callback(out, ok);
    });
  }

  function readTextFile(filePath, callback) {
    var proc = dynamicProcComp.createObject(root, {
      "command": ["cat", filePath],
      "timeoutMs": 5000
    });
    proc.finishedCallback = callback;
    proc.running = true;
  }

  Component.onCompleted: {
    pluginsProc.running = true;
    statusProc.running = true;
    accountsProc.running = true;
    capacitiesProc.running = true;
  }
}
