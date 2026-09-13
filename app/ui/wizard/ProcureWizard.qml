import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../components"

Rectangle {
  id: modal
  visible: false
  anchors.fill: parent
  color: Qt.rgba(0, 0, 0, 0.78)
  z: 1500

  signal serverProcured()

  property var dynamicAuthInputs: ({})
  property var foundKeyFiles: []
  property bool isVerifyingAuth: false
  property string authVerifyError: ""
  property string authEnableUrl: ""

  function setDynamicInput(key, val) {
    var copy = Object.assign({}, dynamicAuthInputs);
    copy[key] = val;
    dynamicAuthInputs = copy;
  }

  function getDynamicInput(key) {
    return dynamicAuthInputs[key] !== undefined ? dynamicAuthInputs[key] : "";
  }

  function onAuthFieldChanged(fieldKey, newVal) {
    setDynamicInput(fieldKey, newVal);
    try {
      var p = JSON.parse(newVal.trim());
      if (selectedProvider && selectedProvider.auth && selectedProvider.auth.fields) {
        var copy = Object.assign({}, dynamicAuthInputs);
        for (var i = 0; i < selectedProvider.auth.fields.length; i++) {
          var f = selectedProvider.auth.fields[i];
          if (f.key !== fieldKey && f.jsonKey && p[f.jsonKey] && (!copy[f.key] || copy[f.key].trim() === "")) {
            copy[f.key] = String(p[f.jsonKey]);
          }
        }
        dynamicAuthInputs = copy;
      }
    } catch(e) {}
  }

  function scanForCredentialFiles() {
    if (!selectedProvider || !selectedProvider.auth || !selectedProvider.auth.fileDrop) {
      modal.foundKeyFiles = [];
      return;
    }
    ocloud.scanDownloadsForKeys(function(files) {
      modal.foundKeyFiles = files || [];
    });
  }

  function loadCredentialFile(filePath) {
    ocloud.readTextFile(filePath, function(content, ok) {
      if (ok && content.trim().length > 0) {
        var trimmed = content.trim();
        var parsed = null;
        try {
          parsed = JSON.parse(trimmed);
        } catch(e) {}

        if (selectedProvider && selectedProvider.auth && selectedProvider.auth.fields) {
          var copy = Object.assign({}, dynamicAuthInputs);
          for (var i = 0; i < selectedProvider.auth.fields.length; i++) {
            var f = selectedProvider.auth.fields[i];
            if (parsed) {
              if (f.jsonKey && parsed[f.jsonKey] !== undefined) {
                copy[f.key] = typeof parsed[f.jsonKey] === "object" ? JSON.stringify(parsed[f.jsonKey], null, 2) : String(parsed[f.jsonKey]);
              } else if (f.type === "textarea") {
                copy[f.key] = trimmed;
              } else if (parsed[f.key] !== undefined) {
                copy[f.key] = String(parsed[f.key]);
              }
            } else if (f.type === "textarea" || f.type === "password") {
              copy[f.key] = trimmed;
            }
          }
          dynamicAuthInputs = copy;
        }
      }
    });
  }

  property int currentStep: 1 // 1: Provider, 2: Specs/Tier, 3: Region, 4: OS & Hostname, 5: Auth & Verification, 6: Review & Deploy
  property var providers: []
  property var selectedProvider: null
  property var selectedTier: null
  property var selectedRegion: null
  property var selectedOs: null
  property var catalogData: null
  property var dynamicTiers: []
  property var dynamicRegions: regions
  property var dynamicImages: []
  property string filterTenancy: "all" // "all", "shared", "dedicated"
  property string filterArch: "all" // "all", "arm", "x86"
  property bool isCatalogLoading: false

  property bool isDeploying: false
  property string deployError: ""
  property bool deploySuccess: false
  property string deploySuccessMsg: ""
  property var authenticatedProviders: ({})

  function markProviderAuthenticated(provId, isAuth) {
    var map = Object.assign({}, authenticatedProviders);
    map[provId] = isAuth;
    authenticatedProviders = map;
  }

  property bool isProviderAuthenticated: {
    if (!selectedProvider) return false;
    if (selectedProvider.id === "baremetal" || selectedProvider.id === "custom") return true;
    if (authenticatedProviders[selectedProvider.id] !== undefined) return Boolean(authenticatedProviders[selectedProvider.id]);
    if (selectedProvider.isConfigured) return true;
    return isConfiguredInSettings(selectedProvider);
  }

  function isConfiguredInSettings(prov) {
    if (!prov) return false;
    var provObj = (typeof prov === "object") ? prov : null;
    if (!provObj) {
      for (var i = 0; i < providers.length; i++) {
        if (providers[i].id === prov) {
          provObj = providers[i];
          break;
        }
      }
    }
    if (!provObj) return false;
    if (provObj.id === "baremetal" || provObj.id === "custom") return true;

    if (provObj.auth && provObj.auth.fields && provObj.auth.fields.length > 0) {
      var hasRequired = false;
      for (var j = 0; j < provObj.auth.fields.length; j++) {
        var f = provObj.auth.fields[j];
        if (f.required !== false) {
          hasRequired = true;
          var val = ocloud.getVaultSecret(f.key);
          if (!val || val.trim().length === 0) {
            if (f.key === "hetzner_api_token" && ocloud.getVaultSecret("api_token")) continue;
            if (f.key === "api_token" && ocloud.getVaultSecret("hetzner_api_token")) continue;
            return false;
          }
        }
      }
      if (hasRequired) return true;
    }
    return Boolean(provObj.isConfigured);
  }

  function loadProviders() {
    try {
      var raw = ocloud.fetchComputePlugins();
      if (raw && raw.length > 2) {
        var list = JSON.parse(raw);
        if (list && list.length > 0) {
          providers = list;
          return;
        }
      }
    } catch (e) {}
    providers = [];
  }

  Component.onCompleted: {
    loadProviders();
  }

  function openModal(step) {
    loadProviders();
    currentStep = (typeof step === "number") ? step : 1;
    selectedProvider = null;
    selectedTier = null;
    selectedRegion = null;
    selectedOs = null;
    hostnameField.text = "runner-" + Math.floor(100 + Math.random() * 900);
    modal.visible = true;
    var testP = Quickshell.env("OCLOUD_TEST_PROVIDER");
    if (testP && providers) {
      for (var pi = 0; pi < providers.length; pi++) {
        if (providers[pi].id === testP) {
          selectedProvider = providers[pi];
          break;
        }
      }
    }
    if (step >= 2 && selectedProvider) {
      loadCatalog();
      if (!selectedTier && dynamicTiers.length > 0) selectedTier = dynamicTiers[0];
      if (!selectedRegion && dynamicRegions.length > 0) selectedRegion = dynamicRegions[0];
      if (!selectedOs && dynamicImages.length > 0) selectedOs = dynamicImages[0];
    }
    if (step >= 5) {
      initAuthForStep5();
    }
    probeRegions();
    scanForCredentialFiles();
  }

  function initAuthForStep5() {
    if (selectedProvider && selectedProvider.auth) {
      var inputs = Object.assign({}, dynamicAuthInputs);
      var fields = selectedProvider.auth.fields || [];
      for (var i = 0; i < fields.length; i++) {
        var f = fields[i];
        if (!inputs[f.key] || inputs[f.key].trim() === "") {
          var secret = ocloud.getVaultSecret(f.key);
          if (!secret && f.key === "api_token") secret = ocloud.getVaultSecret("hetzner_api_token");
          if (secret && secret.trim().length > 0) {
            inputs[f.key] = secret.trim();
          }
        }
      }
      dynamicAuthInputs = inputs;

      if (selectedProvider.auth.fileDrop) {
        scanForCredentialFiles();
      }

      if (isProviderAuthenticated) {
        modal.isVerifyingAuth = true;
        modal.authVerifyError = "";
        modal.authEnableUrl = "";
        ocloud.verifyProvider(selectedProvider.id, function(result, ok) {
          modal.isVerifyingAuth = false;
          if (!ok) {
            modal.markProviderAuthenticated(selectedProvider.id, false);
            if (result && result.needsApiEnable) {
              modal.authVerifyError = result.error || "Compute API is disabled for this provider.";
              modal.authEnableUrl = result.enableUrl || "";
            } else {
              modal.authVerifyError = (result && result.error) || ("Failed to verify credentials for " + (selectedProvider.name || selectedProvider.id) + ".");
            }
          }
        });
      }
    }
  }

  onCurrentStepChanged: {
    if (currentStep === 5) {
      initAuthForStep5();
    }
  }

  onSelectedProviderChanged: {
    if (currentStep === 5) {
      initAuthForStep5();
    }
  }

  function probeRegions() {
    // Latency probing for regions
  }

  function loadCatalog() {
    var provId = (selectedProvider && selectedProvider.id) ? selectedProvider.id : (providers && providers.length > 0 ? providers[0].id : "gcp");
    try {
      var jsonStr = ocloud.fetchCatalog(provId);
      if (jsonStr && jsonStr !== "{}" && jsonStr.length > 5) {
        applyCatalogJson(jsonStr);
      }
    } catch (e) {}
  }

  function refreshCatalog() {
    isCatalogLoading = true;
    var provId = (selectedProvider && selectedProvider.id) ? selectedProvider.id : (providers && providers.length > 0 ? providers[0].id : "gcp");
    try {
      ocloud.refreshCatalogAsync(provId);
    } catch (e) {
      isCatalogLoading = false;
    }
  }

  function applyCatalogJson(jsonStr) {
    try {
      var data = JSON.parse(jsonStr);
      if (data && data.server_types && data.server_types.length > 0) {
        modal.catalogData = data;
        modal.dynamicTiers = data.server_types;
        if (selectedTier && !data.server_types.find(function(t) { return t.id === selectedTier.id; })) {
          selectedTier = null;
        }
        if (data.locations && data.locations.length > 0) {
          modal.dynamicRegions = data.locations;
          if (selectedRegion && !data.locations.find(function(r) { return r.id === selectedRegion.id; })) {
            selectedRegion = null;
          }
        }
        if (data.images && data.images.length > 0) {
          modal.dynamicImages = data.images;
          if (selectedOs && !data.images.find(function(im) { return (im.name || im.id) === (selectedOs.name || selectedOs.id); })) {
            selectedOs = null;
          }
        }
      }
    } catch (e) {}
  }

  function getTierPrice(tier, regionId) {
    var sym = (tier && tier.currencySymbol) || 
              (selectedProvider && selectedProvider.currencySymbol) || 
              (tier && tier.currency === "USD" ? "$" : (selectedProvider && selectedProvider.id === "gcp" ? "$" : "€"));
    if (!tier) return { sym: sym, month: sym + "0.00", hour: sym + "0.000", monthlyNet: 0, hourlyNet: 0 };
    var loc = regionId || (selectedRegion ? selectedRegion.id : "");
    if (tier.prices && loc && tier.prices[loc]) {
      var p = tier.prices[loc];
      var hStr = p.hourly_net < 0.01 ? p.hourly_net.toFixed(4) : p.hourly_net.toFixed(3);
      return {
        sym: sym,
        month: sym + p.monthly_net.toFixed(2),
        hour: sym + hStr,
        monthlyNet: p.monthly_net,
        hourlyNet: p.hourly_net
      };
    }
    if (tier.priceMonthlyNet !== undefined && tier.priceMonthlyNet !== null) {
      var hVal = tier.priceHourlyNet || 0;
      var hStr = hVal < 0.01 ? hVal.toFixed(4) : hVal.toFixed(3);
      return {
        sym: sym,
        month: sym + tier.priceMonthlyNet.toFixed(2),
        hour: sym + hStr,
        monthlyNet: tier.priceMonthlyNet,
        hourlyNet: hVal
      };
    }
    return {
      sym: sym,
      month: tier.priceMonth || (sym + "3.29"),
      hour: tier.priceHour || (sym + "0.005"),
      monthlyNet: parseFloat((tier.priceMonth || "3.29").replace(/[^0-9.]/g, '')),
      hourlyNet: parseFloat((tier.priceHour || "0.005").replace(/[^0-9.]/g, ''))
    };
  }

  function getFilteredTiers() {
    var source = (dynamicTiers && dynamicTiers.length > 0) ? dynamicTiers : tiers;
    return source.filter(function(t) {
      if (filterTenancy !== "all" && t.cpuType !== filterTenancy) return false;
      if (filterArch !== "all" && t.architecture !== filterArch) return false;
      return true;
    });
  }

  function getFilteredOsTemplates() {
    var tierArch = (selectedTier && selectedTier.architecture) ? selectedTier.architecture : "x86";
    var source = (dynamicImages && dynamicImages.length > 0) ? dynamicImages : osTemplates;
    return source.filter(function(img) {
      if (img.architecture && img.architecture !== tierArch) return false;
      return true;
    });
  }

  function getOsIcon(img) {
    if (!img) return Qt.resolvedUrl("../icons/server.svg");
    if (img.iconSvg && img.iconSvg.indexOf("server.svg") === -1) return Qt.resolvedUrl(img.iconSvg);
    var flavor = (img.osFlavor || "").toLowerCase();
    var name = (img.name || "").toLowerCase();
    var desc = (img.description || "").toLowerCase();
    var combined = flavor + " " + name + " " + desc;

    if (combined.indexOf("ubuntu") !== -1) return Qt.resolvedUrl("../icons/ubuntu.svg");
    if (combined.indexOf("debian") !== -1) return Qt.resolvedUrl("../icons/debian.svg");
    if (combined.indexOf("rocky") !== -1) return Qt.resolvedUrl("../icons/rockylinux.svg");
    if (combined.indexOf("alma") !== -1) return Qt.resolvedUrl("../icons/almalinux.svg");
    if (combined.indexOf("fedora") !== -1) return Qt.resolvedUrl("../icons/fedora.svg");
    if (combined.indexOf("alpine") !== -1) return Qt.resolvedUrl("../icons/alpinelinux.svg");
    if (combined.indexOf("arch") !== -1) return Qt.resolvedUrl("../icons/archlinux.svg");
    if (combined.indexOf("suse") !== -1) return Qt.resolvedUrl("../icons/opensuse.svg");
    return Qt.resolvedUrl("../icons/server.svg");
  }

  Connections {
    target: ocloud
    function onCatalogUpdated(provId, jsonStr) {
      if (!modal.selectedProvider || modal.selectedProvider.id === provId) {
        modal.isCatalogLoading = false;
        applyCatalogJson(jsonStr);
      }
    }
    function onHetznerCatalogUpdated(jsonStr) {
      if (!modal.selectedProvider || modal.selectedProvider.id === "hetzner") {
        modal.isCatalogLoading = false;
        applyCatalogJson(jsonStr);
      }
    }
    function onComputePluginsUpdated(pluginsJson) {
      loadProviders();
    }
    function onActionCompleted(action, success, msg) {
      if (action === "procureServer") {
        modal.isDeploying = false;
        if (success) {
          modal.deploySuccess = true;
          modal.deploySuccessMsg = msg || "Instance provisioned successfully!";
        } else {
          modal.deployError = msg || "Procurement failed.";
        }
      }
    }
  }

  // =========================================================
  // DATA MODELS
  // =========================================================

  readonly property var tiers: [
    {
      id: "cax11",
      name: "cax11",
      category: "arm",
      arch: "Ampere ARM64",
      cpu: "2 vCPU",
      ram: "4 GB RAM",
      disk: "40 GB NVMe",
      traffic: "20 TB Traffic",
      priceMonth: "€3.29",
      priceHour: "€0.005",
      badge: "Best Value",
      badgeColor: "#10b981",
      recommendedFor: "General compute, Docker containers, background task runner"
    },
    {
      id: "cx23",
      name: "cx23",
      category: "x86",
      arch: "Intel x86_64",
      cpu: "2 vCPU",
      ram: "4 GB RAM",
      disk: "40 GB NVMe",
      traffic: "20 TB Traffic",
      priceMonth: "€3.79",
      priceHour: "€0.006",
      badge: "Standard x86",
      badgeColor: "#38bdf8",
      recommendedFor: "Standard Linux x86 applications, Wine/Steam streaming"
    },
    {
      id: "cpx21",
      name: "cpx21",
      category: "perf",
      arch: "AMD EPYC High-Freq",
      cpu: "3 vCPU",
      ram: "4 GB RAM",
      disk: "80 GB NVMe",
      traffic: "20 TB Traffic",
      priceMonth: "€6.90",
      priceHour: "€0.011",
      badge: "High Performance",
      badgeColor: "#f59e0b",
      recommendedFor: "Fast code compiling, CI/CD runners, heavier databases"
    },
    {
      id: "cx32",
      name: "cx32",
      category: "x86",
      arch: "Intel x86_64",
      cpu: "4 vCPU",
      ram: "8 GB RAM",
      disk: "80 GB NVMe",
      traffic: "20 TB Traffic",
      priceMonth: "€7.90",
      priceHour: "€0.013",
      badge: "Heavy Workloads",
      badgeColor: "#8b5cf6",
      recommendedFor: "Multi-container Docker fleets, AI inference, app suites"
    }
  ]

  readonly property var regions: [
    {
      id: "nbg1",
      name: "Nuremberg",
      country: "Germany",
      flag: "🇩🇪",
      continent: "EU Central",
      optimalFor: "Ultra-Low Latency & High-FPS Gaming"
    },
    {
      id: "fsn1",
      name: "Falkenstein",
      country: "Germany",
      flag: "🇩🇪",
      continent: "EU Central",
      optimalFor: "General European Compute & Backups"
    },
    {
      id: "hel1",
      name: "Helsinki",
      country: "Finland",
      flag: "🇫🇮",
      continent: "EU North",
      optimalFor: "Nordic & Eastern Europe Route"
    },
    {
      id: "ash",
      name: "Ashburn, VA",
      country: "United States",
      flag: "🇺🇸",
      continent: "US East",
      optimalFor: "North American East Coast"
    },
    {
      id: "hil",
      name: "Hillsboro, OR",
      country: "United States",
      flag: "🇺🇸",
      continent: "US West",
      optimalFor: "North American West Coast"
    },
    {
      id: "sin",
      name: "Singapore",
      country: "Singapore",
      flag: "🇸🇬",
      continent: "Asia-Pacific",
      optimalFor: "Asia-Pacific Direct Route"
    }
  ]

  readonly property var osTemplates: [
    {
      id: "ubuntu",
      name: "Ubuntu 24.04 LTS",
      imageTag: "ubuntu-24.04",
      iconSvg: "../icons/ubuntu.svg",
      badge: "Enterprise Standard",
      badgeColor: "#e95420",
      size: "Maximum Compatibility",
      description: "Industry-standard LTS release with full glibc support, official cloud kernels, and pre-built packages.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["gcp", "hetzner"]
    },
    {
      id: "debian",
      name: "Debian 12 Bookworm",
      imageTag: "debian-12",
      iconSvg: "../icons/debian.svg",
      badge: "Rock Solid",
      badgeColor: "#d70a53",
      size: "Minimal Base",
      description: "Rock-solid Linux foundation known for legendary stability and massive software repository.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["gcp", "hetzner"]
    },
    {
      id: "rocky",
      name: "Rocky Linux 9",
      imageTag: "rocky-linux-9",
      iconSvg: "../icons/rockylinux.svg",
      badge: "RHEL Compatible",
      badgeColor: "#10b981",
      size: "Enterprise Linux",
      description: "Enterprise operating system engineered to be 100% bug-for-bug compatible with Red Hat Enterprise Linux.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["gcp", "hetzner"]
    },
    {
      id: "almalinux",
      name: "AlmaLinux 9",
      imageTag: "almalinux-9",
      iconSvg: "../icons/almalinux.svg",
      badge: "Binary Compatible",
      badgeColor: "#0284c7",
      size: "Enterprise Linux",
      description: "Community-driven open-source enterprise distribution built for cloud workloads and containers.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["gcp", "hetzner"]
    },
    {
      id: "alpine",
      name: "Alpine Linux 3.20",
      imageTag: "alpine-3",
      iconSvg: "../icons/alpinelinux.svg",
      badge: "Fastest Boot (Sub-5s)",
      badgeColor: "#10b981",
      size: "130 MB Footprint",
      description: "Ultra-minimal security-oriented distribution with musl libc and busybox. Perfect for lightweight Docker runners.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["hetzner"]
    },
    {
      id: "arch",
      name: "Arch Linux",
      imageTag: "arch",
      iconSvg: "../icons/archlinux.svg",
      badge: "Rolling Release",
      badgeColor: "#1793d1",
      size: "Latest Kernel",
      description: "Bleeding-edge Linux packages with pacman. Ideal for gaming templates, modern toolchains, and custom environments.",
      supportedArch: ["x86", "arm"],
      supportedProviders: ["hetzner"]
    }
  ]

  MouseArea {
    anchors.fill: parent
    onClicked: {} // Block click-through
  }

  // Wizard Main Window (880 x 620)
  Rectangle {
    id: modalDialog
    width: Math.min(parent.width - 16, 880)
    height: Math.min(parent.height - 16, 700)
    radius: (typeof theme !== "undefined" && theme.cornerRadius) ? theme.cornerRadius : 12
    color: (typeof theme !== "undefined" && theme.cardBg) ? theme.cardBg : "#0a0f1d"
    border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#1e293b"
    border.width: 1
    anchors.centerIn: parent
    clip: true

    RowLayout {
      anchors.fill: parent
      spacing: 0

      // =========================================================
      // LEFT SIDEBAR: STEPPER PROGRESS (Responsive)
      // =========================================================
      Rectangle {
        id: stepperSidebar
        visible: modalDialog.width >= 560
        Layout.fillHeight: true
        Layout.preferredWidth: modalDialog.width < 750 ? 56 : 220
        Layout.minimumWidth: modalDialog.width < 750 ? 56 : 220
        Layout.maximumWidth: modalDialog.width < 750 ? 56 : 220
        color: (typeof theme !== "undefined" && theme.sidebarBg) ? theme.sidebarBg : "#070c16"
        border.color: (typeof theme !== "undefined" && theme.borderSubtle) ? theme.borderSubtle : "#1e293b"
        border.width: 1

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 16

          // Header
          RowLayout {
            spacing: 10
            Rectangle {
              width: 34
              height: 34
              radius: 8
              color: "#0f1f38"
              border.color: "#1d4ed8"
              border.width: 1
              Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("../icons/server.svg")
                fillMode: Image.PreserveAspectFit
                smooth: true
              }
            }
            ColumnLayout {
              spacing: 2
              Text {
                text: "Compute Wizard"
                font.pixelSize: 13
                font.bold: true
                color: "#f8fafc"
              }
              Text {
                text: "Setup Assistant"
                font.pixelSize: 11
                color: "#64748b"
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1e293b"
          }

          // Step Items
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            // Step 1
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 1 ? "#13233f" : "transparent"
              border.color: currentStep === 1 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: currentStep > 1 ? "#10b981" : (currentStep === 1 ? "#2563eb" : "#1e293b")
                  Text {
                    anchors.centerIn: parent
                    text: currentStep > 1 ? "✓" : "1"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "Cloud Provider"; font.pixelSize: 12; font.bold: currentStep === 1; color: currentStep >= 1 ? "#f8fafc" : "#64748b" }
                  Text { text: selectedProvider ? selectedProvider.name : "Select Provider"; font.pixelSize: 10; color: "#64748b" }
                }
              }
              MouseArea {
                anchors.fill: parent
                onClicked: currentStep = 1
              }
            }

            // Step 2
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 2 ? "#13233f" : "transparent"
              border.color: currentStep === 2 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: currentStep > 2 ? "#10b981" : (currentStep === 2 ? "#2563eb" : "#1e293b")
                  Text {
                    anchors.centerIn: parent
                    text: currentStep > 2 ? "✓" : "2"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "Hardware Tier"; font.pixelSize: 12; font.bold: currentStep === 2; color: currentStep >= 2 ? "#f8fafc" : "#64748b" }
                  Text {
                    text: currentStep > 2 && selectedTier ? (selectedTier.name.toUpperCase() + " (" + (selectedTier.cores ? selectedTier.cores + " vCPU" : selectedTier.cpu) + ")") : (currentStep === 2 ? (selectedTier ? selectedTier.name.toUpperCase() : "Select Tier") : "Pending selection")
                    font.pixelSize: 10
                    color: "#64748b"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: currentStep >= 2 || selectedProvider !== null
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: currentStep = 2
              }
            }

            // Step 3
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 3 ? "#13233f" : "transparent"
              border.color: currentStep === 3 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: currentStep > 3 ? "#10b981" : (currentStep === 3 ? "#2563eb" : "#1e293b")
                  Text {
                    anchors.centerIn: parent
                    text: currentStep > 3 ? "✓" : "3"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "Datacenter Region"; font.pixelSize: 12; font.bold: currentStep === 3; color: currentStep >= 3 ? "#f8fafc" : "#64748b" }
                  Text {
                    text: currentStep > 3 && selectedRegion ? ((selectedRegion.flag ? selectedRegion.flag + " " : "") + selectedRegion.name) : (currentStep === 3 ? (selectedRegion ? selectedRegion.name : "Select Region") : "Pending selection")
                    font.pixelSize: 10
                    color: "#64748b"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: currentStep >= 3 || (selectedProvider !== null && selectedTier !== null)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: currentStep = 3
              }
            }

            // Step 4
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 4 ? "#13233f" : "transparent"
              border.color: currentStep === 4 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: currentStep > 4 ? "#10b981" : (currentStep === 4 ? "#2563eb" : "#1e293b")
                  Text {
                    anchors.centerIn: parent
                    text: currentStep > 4 ? "✓" : "4"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "OS & Mesh Network"; font.pixelSize: 12; font.bold: currentStep === 4; color: currentStep >= 4 ? "#f8fafc" : "#64748b" }
                  Text {
                    text: currentStep > 4 && selectedOs ? (selectedOs.name || selectedOs.description) : (currentStep === 4 ? (selectedOs ? selectedOs.name : "Select OS") : "Pending selection")
                    font.pixelSize: 10
                    color: "#64748b"
                    elide: Text.ElideRight
                    Layout.maximumWidth: 150
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: currentStep >= 4 || (selectedProvider !== null && selectedTier !== null && selectedRegion !== null)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: currentStep = 4
              }
            }

            // Step 5: Authentication
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 5 ? "#13233f" : "transparent"
              border.color: currentStep === 5 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: (currentStep > 5 || isProviderAuthenticated) ? "#10b981" : (currentStep === 5 ? "#2563eb" : "#1e293b")
                  Text {
                    anchors.centerIn: parent
                    text: (currentStep > 5 || isProviderAuthenticated) ? "✓" : "5"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "Authentication"; font.pixelSize: 12; font.bold: currentStep === 5; color: currentStep >= 5 ? "#f8fafc" : "#64748b" }
                  Text {
                    text: isProviderAuthenticated ? "Verified" : (currentStep === 5 ? "Connect Account" : "Pending setup")
                    font.pixelSize: 10
                    color: isProviderAuthenticated ? "#34d399" : "#64748b"
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: currentStep >= 5 || (selectedProvider !== null && selectedTier !== null && selectedRegion !== null && selectedOs !== null)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: currentStep = 5
              }
            }

            // Step 6: Review & Deploy
            Rectangle {
              Layout.fillWidth: true
              height: 44
              radius: 8
              color: currentStep === 6 ? "#13233f" : "transparent"
              border.color: currentStep === 6 ? "#1d4ed8" : "transparent"
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10
                Rectangle {
                  width: 22
                  height: 22
                  radius: 11
                  color: currentStep === 6 ? "#2563eb" : "#1e293b"
                  Text {
                    anchors.centerIn: parent
                    text: "6"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                  }
                }
                ColumnLayout {
                  spacing: 1
                  Text { text: "Review & Deploy"; font.pixelSize: 12; font.bold: currentStep === 6; color: currentStep === 6 ? "#f8fafc" : "#64748b" }
                  Text {
                    text: currentStep === 6 && selectedTier ? (getTierPrice(selectedTier, selectedRegion ? selectedRegion.id : "").hour + "/hr") : "Final review"
                    font.pixelSize: 10
                    color: "#64748b"
                  }
                }
              }
              MouseArea {
                anchors.fill: parent
                enabled: selectedProvider !== null && selectedTier !== null && selectedRegion !== null && selectedOs !== null && (selectedProvider.id === "baremetal" || isProviderAuthenticated)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: currentStep = 6
              }
            }
          }

          Item { Layout.fillHeight: true }

          // Price Summary Box
          Rectangle {
            Layout.fillWidth: true
            height: 60
            radius: 8
            color: "#0d1b32"
            border.color: "#1e3a5f"
            border.width: 1

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 10
              spacing: 2
              Text { text: "ESTIMATED PRICING"; font.pixelSize: 9; font.bold: true; color: "#64748b" }
              RowLayout {
                visible: Boolean(selectedTier)
                Text { text: selectedTier ? getTierPrice(selectedTier, selectedRegion ? selectedRegion.id : "").hour : "—"; font.pixelSize: 16; font.bold: true; color: "#38bdf8" }
                Text { text: "/ hr"; font.pixelSize: 11; color: "#94a3b8" }
                Item { Layout.fillWidth: true }
                Text { text: "(" + (selectedTier ? getTierPrice(selectedTier, selectedRegion ? selectedRegion.id : "").month : "—") + "/mo)"; font.pixelSize: 10; color: "#64748b" }
              }
              Text {
                visible: !selectedTier
                text: "Calculated in Step 2"
                font.pixelSize: 11
                color: "#64748b"
              }
            }
          }
        }
      }

      // =========================================================
      // RIGHT PANEL: CONTENT & ACTIONS
      // =========================================================
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "transparent"

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: 24
          spacing: 16

          // =======================================================
          // STEP 1: CHOOSE CLOUD PROVIDER
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 1
            spacing: 8

            ColumnLayout {
              spacing: 2
              Text { text: "Select Cloud Provider"; font.pixelSize: 17; font.bold: true; color: "#f8fafc" }
              Text { text: "Choose your preferred compute provider or bare metal server"; font.pixelSize: 11; color: "#94a3b8" }
            }

            ScrollView {
              id: step1Scroll
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                active: true
              }

              ColumnLayout {
                id: step1Col
                width: step1Scroll.availableWidth
                spacing: 8

                Repeater {
                  model: providers

                  delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 64
                    radius: 10
                    color: (selectedProvider && selectedProvider.id === modelData.id) ? "#13233f" : (provMouse.containsMouse ? "#0f172a" : "#0b1329")
                    border.color: (selectedProvider && selectedProvider.id === modelData.id) ? "#2563eb" : "#1e293b"
                    border.width: (selectedProvider && selectedProvider.id === modelData.id) ? 2 : 1

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: 12
                      spacing: 12

                      Rectangle {
                        width: 40
                        height: 40
                        radius: 8
                        color: "#080e1a"
                        border.color: "#1e293b"
                        Image {
                          anchors.centerIn: parent
                          width: 24
                          height: 24
                          source: (modelData.iconDataUri && modelData.iconDataUri.length > 0) ? modelData.iconDataUri : Qt.resolvedUrl(modelData.iconSvg || "../icons/server.svg")
                          fillMode: Image.PreserveAspectFit
                          smooth: true
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 8
                          Text {
                            text: modelData.name
                            font.pixelSize: 14
                            font.bold: true
                            color: "#f8fafc"
                            elide: Text.ElideRight
                          }
                          AppBadge {
                            variant: (modelData.badgeColor === "#d50c2d" || modelData.isConfigured) ? "success" : "neutral"
                            text: modelData.badge || "Plugin"
                          }
                        }
                        Text {
                          text: modelData.tagline || ""
                          font.pixelSize: 11
                          color: "#94a3b8"
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: implicitWidth
                        Text {
                          text: "Starts at " + (modelData.pricingFrom || "€0.005 / hr")
                          font.pixelSize: 12
                          font.bold: true
                          color: "#38bdf8"
                          Layout.alignment: Qt.AlignRight
                        }
                        Text {
                          text: modelData.status || (modelData.isConfigured ? "Ready" : "Configurable")
                          font.pixelSize: 10
                          color: "#64748b"
                          Layout.alignment: Qt.AlignRight
                        }
                      }
                    }

                    MouseArea {
                      id: provMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        selectedProvider = modelData;
                        selectedTier = null;
                        selectedRegion = null;
                        selectedOs = null;
                        loadCatalog();
                      }
                    }
                  }
                }
              }
            }
          }

          // =======================================================
          // STEP 2: HARDWARE TIER & SPECS
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 2
            spacing: 16

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                spacing: 4
                Text { text: "Select Instance Specification"; font.pixelSize: 18; font.bold: true; color: "#f8fafc" }
                Text { text: "Live " + (selectedProvider ? selectedProvider.name : "Cloud") + " hardware catalog with real-time datacenter rates"; font.pixelSize: 12; color: "#94a3b8" }
              }
              Item { Layout.fillWidth: true }
              AppButton {
                text: isCatalogLoading ? "Refreshing..." : "Refresh Catalog"
                variant: "secondary"
                iconSource: "icons/refresh.svg"
                onClicked: refreshCatalog()
              }
            }

            // Filter Bar
            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              // Tenancy Filter Pills (All / Shared / Dedicated)
              RowLayout {
                spacing: 4
                Text { text: "CPU:"; font.pixelSize: 11; font.bold: true; color: "#64748b"; Layout.alignment: Qt.AlignVCenter }

                Rectangle {
                  height: 26
                  implicitWidth: tAllText.implicitWidth + 16
                  radius: 13
                  color: filterTenancy === "all" ? "#2563eb" : "#0d1b32"
                  border.color: filterTenancy === "all" ? "#3b82f6" : "#1e293b"
                  Text { id: tAllText; anchors.centerIn: parent; text: "All Tenancy"; font.pixelSize: 10; font.bold: filterTenancy === "all"; color: filterTenancy === "all" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterTenancy = "all" }
                }

                Rectangle {
                  height: 26
                  implicitWidth: tSharedText.implicitWidth + 16
                  radius: 13
                  color: filterTenancy === "shared" ? "#2563eb" : "#0d1b32"
                  border.color: filterTenancy === "shared" ? "#3b82f6" : "#1e293b"
                  Text { id: tSharedText; anchors.centerIn: parent; text: "Shared vCPU"; font.pixelSize: 10; font.bold: filterTenancy === "shared"; color: filterTenancy === "shared" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterTenancy = "shared" }
                }

                Rectangle {
                  height: 26
                  implicitWidth: tDedText.implicitWidth + 16
                  radius: 13
                  color: filterTenancy === "dedicated" ? "#2563eb" : "#0d1b32"
                  border.color: filterTenancy === "dedicated" ? "#3b82f6" : "#1e293b"
                  Text { id: tDedText; anchors.centerIn: parent; text: "Dedicated vCPU (CCX)"; font.pixelSize: 10; font.bold: filterTenancy === "dedicated"; color: filterTenancy === "dedicated" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterTenancy = "dedicated" }
                }
              }

              Item { Layout.fillWidth: true }

              // Architecture Filter Pills (All / ARM64 / x86_64)
              RowLayout {
                spacing: 4
                Text { text: "Arch:"; font.pixelSize: 11; font.bold: true; color: "#64748b"; Layout.alignment: Qt.AlignVCenter }

                Rectangle {
                  height: 26
                  implicitWidth: aAllText.implicitWidth + 16
                  radius: 13
                  color: filterArch === "all" ? "#2563eb" : "#0d1b32"
                  border.color: filterArch === "all" ? "#3b82f6" : "#1e293b"
                  Text { id: aAllText; anchors.centerIn: parent; text: "All"; font.pixelSize: 10; font.bold: filterArch === "all"; color: filterArch === "all" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterArch = "all" }
                }

                Rectangle {
                  height: 26
                  implicitWidth: aArmText.implicitWidth + 16
                  radius: 13
                  color: filterArch === "arm" ? "#2563eb" : "#0d1b32"
                  border.color: filterArch === "arm" ? "#3b82f6" : "#1e293b"
                  Text { id: aArmText; anchors.centerIn: parent; text: "ARM64"; font.pixelSize: 10; font.bold: filterArch === "arm"; color: filterArch === "arm" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterArch = "arm" }
                }

                Rectangle {
                  height: 26
                  implicitWidth: aX86Text.implicitWidth + 16
                  radius: 13
                  color: filterArch === "x86" ? "#2563eb" : "#0d1b32"
                  border.color: filterArch === "x86" ? "#3b82f6" : "#1e293b"
                  Text { id: aX86Text; anchors.centerIn: parent; text: "x86_64"; font.pixelSize: 10; font.bold: filterArch === "x86"; color: filterArch === "x86" ? "#ffffff" : "#94a3b8" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: filterArch = "x86" }
                }
              }
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentWidth: availableWidth

              ColumnLayout {
                width: parent.width
                spacing: 8

                Repeater {
                  model: getFilteredTiers()

                  delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 72
                    radius: 10
                    color: (selectedTier && selectedTier.id === modelData.id) ? "#13233f" : (tierMouse.containsMouse ? "#0f172a" : "#0b1329")
                    border.color: (selectedTier && selectedTier.id === modelData.id) ? "#2563eb" : "#1e293b"
                    border.width: (selectedTier && selectedTier.id === modelData.id) ? 2 : 1

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: 12
                      spacing: 12

                      Rectangle {
                        width: 44
                        height: 44
                        radius: 8
                        color: "#080e1a"
                        border.color: "#1e293b"
                        ColumnLayout {
                          anchors.centerIn: parent
                          spacing: 1
                          Text {
                            text: (modelData.cores ? modelData.cores + "C" : (modelData.cpu ? modelData.cpu.split(" ")[0] + "C" : "2C"))
                            font.pixelSize: 12
                            font.bold: true
                            color: "#38bdf8"
                            Layout.alignment: Qt.AlignHCenter
                          }
                          Text {
                            text: (modelData.architecture || "x86").toUpperCase()
                            font.pixelSize: 8
                            font.bold: true
                            color: "#64748b"
                            Layout.alignment: Qt.AlignHCenter
                          }
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 3
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 8
                          Text {
                            text: modelData.name.toUpperCase() + " · " + (modelData.cores ? modelData.cores + " vCPU / " + modelData.memory + " GB RAM" : modelData.cpu + " / " + modelData.ram)
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f8fafc"
                            elide: Text.ElideRight
                          }
                          AppBadge {
                            variant: modelData.cpuType === "dedicated" ? "warning" : (modelData.architecture === "arm" ? "success" : "info")
                            text: modelData.cpuType === "dedicated" ? "Dedicated CPU" : (modelData.architecture === "arm" ? "Ampere ARM64" : "Shared x86")
                          }
                        }
                        Text {
                          text: (modelData.disk ? modelData.disk + " GB NVMe" : modelData.disk) + " · " + (modelData.description || (modelData.cpuType === "dedicated" ? "Guaranteed 100% vCPU hardware threads" : "Burstable cloud instance"))
                          font.pixelSize: 10
                          color: "#94a3b8"
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        Layout.preferredWidth: implicitWidth
                        Text {
                          text: getTierPrice(modelData, selectedRegion ? selectedRegion.id : "").hour + " / hr"
                          font.pixelSize: 14
                          font.bold: true
                          color: "#38bdf8"
                          Layout.alignment: Qt.AlignRight
                        }
                        Text {
                          text: getTierPrice(modelData, selectedRegion ? selectedRegion.id : "").month + " / mo"
                          font.pixelSize: 10
                          color: "#64748b"
                          Layout.alignment: Qt.AlignRight
                        }
                      }
                    }

                    MouseArea {
                      id: tierMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: selectedTier = modelData
                    }
                  }
                }
              }
            }
          }

          // =======================================================
          // STEP 3: REGION & LATENCY BENCHMARK
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 3
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              ColumnLayout {
                spacing: 4
                Text { text: "Choose Datacenter Region"; font.pixelSize: 18; font.bold: true; color: "#f8fafc" }
                Text { text: "Deploy closest to your users or primary workloads"; font.pixelSize: 12; color: "#94a3b8" }
              }
              Item { Layout.fillWidth: true }
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentWidth: availableWidth

              ColumnLayout {
                width: parent.width
                spacing: 10

                Repeater {
                  model: (dynamicRegions && dynamicRegions.length > 0) ? dynamicRegions : regions

                  delegate: Rectangle {
                    Layout.fillWidth: true
                    height: 64
                    radius: 12
                    color: (selectedRegion && selectedRegion.id === modelData.id) ? "#13233f" : (regMouse.containsMouse ? "#0f172a" : "#0b1329")
                    border.color: (selectedRegion && selectedRegion.id === modelData.id) ? "#2563eb" : "#1e293b"
                    border.width: (selectedRegion && selectedRegion.id === modelData.id) ? 2 : 1

                    RowLayout {
                      anchors.fill: parent
                      anchors.margins: 14
                      spacing: 14

                      Rectangle {
                        width: 36
                        height: 36
                        radius: 8
                        color: (selectedRegion && selectedRegion.id === modelData.id) ? "#1d4ed8" : "#1e293b"
                        Image {
                          anchors.centerIn: parent
                          width: 20
                          height: 20
                          source: "../icons/world.svg"
                          sourceSize: Qt.size(20, 20)
                        }
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 2
                        RowLayout {
                          Layout.fillWidth: true
                          spacing: 8
                          Text {
                            text: modelData.name + " (" + modelData.id + ")"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#f8fafc"
                            elide: Text.ElideRight
                          }
                          Text {
                            text: (modelData.networkZone || modelData.continent || "")
                            font.pixelSize: 11
                            color: "#64748b"
                          }
                        }
                        Text {
                          text: (modelData.description || modelData.optimalFor || "Optimal latency route")
                          font.pixelSize: 10
                          color: "#94a3b8"
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      // Region Location Badge
                      AppBadge {
                        text: (modelData.country || "GLOBAL").toUpperCase()
                        variant: (selectedRegion && selectedRegion.id === modelData.id) ? "info" : "neutral"
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                      }
                    }

                    MouseArea {
                      id: regMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: selectedRegion = modelData
                    }
                  }
                }
              }
            }
          }

          // =======================================================
          // STEP 4: OS TEMPLATE & MESH NETWORK
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 4
            spacing: 12

            ColumnLayout {
              spacing: 4
              Text { text: "Distribution & Network Mesh"; font.pixelSize: 18; font.bold: true; color: "#f8fafc" }
              Text { text: "Configure Linux OS template and peer-to-peer Tailscale connectivity"; font.pixelSize: 12; color: "#94a3b8" }
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentWidth: availableWidth

              ColumnLayout {
                width: parent.width
                spacing: 14

                // Hostname Field
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 4
                  Text { text: "INSTANCE HOSTNAME"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
                  Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 8
                    color: "#080e1a"
                    border.color: hostnameField.activeFocus ? "#2563eb" : "#1e293b"
                    TextInput {
                      id: hostnameField
                      anchors.fill: parent
                      anchors.margins: 10
                      color: "#f8fafc"
                      font.pixelSize: 13
                      selectByMouse: true
                    }
                  }
                }

                // OS Templates
                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 8

                  Text { text: "SELECT OS DISTRIBUTION"; font.pixelSize: 10; font.bold: true; color: "#64748b" }

                  Repeater {
                    model: getFilteredOsTemplates()

                    delegate: Rectangle {
                      Layout.fillWidth: true
                      height: 60
                      radius: 10
                      readonly property bool isSelected: Boolean(selectedOs && ((selectedOs.name && selectedOs.name === modelData.name) || (selectedOs.id && selectedOs.id === modelData.id)))
                      color: isSelected ? "#13233f" : (osMouse.containsMouse ? "#0f172a" : "#0b1329")
                      border.color: isSelected ? "#2563eb" : "#1e293b"
                      border.width: isSelected ? 2 : 1

                      RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Image {
                          width: 24
                          height: 24
                          source: getOsIcon(modelData)
                          fillMode: Image.PreserveAspectFit
                          smooth: true
                        }

                        ColumnLayout {
                          Layout.fillWidth: true
                          spacing: 2
                          RowLayout {
                            spacing: 8
                            Text { text: modelData.description || modelData.name; font.pixelSize: 13; font.bold: true; color: "#f8fafc" }
                            AppBadge { variant: "neutral"; text: modelData.badge || (modelData.osFlavor ? modelData.osFlavor.toUpperCase() : "Linux") }
                          }
                          Text { text: (modelData.size ? modelData.size + " · " : "") + (modelData.name || "Cloud image"); Layout.fillWidth: true; font.pixelSize: 10; color: "#94a3b8"; elide: Text.ElideRight }
                        }
                      }

                      MouseArea {
                        id: osMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: selectedOs = modelData
                      }
                    }
                  }
                }

                // Tailscale Switch
                Rectangle {
                  Layout.fillWidth: true
                  height: 50
                  radius: 10
                  color: "#0b1329"
                  border.color: "#1e293b"
                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    CheckBox {
                      id: tsCheck
                      checked: true
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1
                      Text { text: "Auto-join Tailscale Mesh Network on Boot"; font.pixelSize: 12; font.bold: true; color: "#f8fafc" }
                      Text { text: "Connect directly to your local machine via encrypted zero-config WireGuard mesh"; font.pixelSize: 10; color: "#64748b" }
                    }
                  }
                }
              }
            }
          }

          // =======================================================
          // STEP 5: PROVIDER CREDENTIALS & AUTHENTICATION
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 5
            spacing: 16

            ColumnLayout {
              spacing: 4
              Text {
                text: "Authenticate " + (selectedProvider ? selectedProvider.name : "Provider")
                font.pixelSize: 18
                font.bold: true
                color: "#f8fafc"
              }
              Text {
                text: "Connect your cloud credentials and verify account access before review and deployment"
                font.pixelSize: 12
                color: "#94a3b8"
              }
            }

            ScrollView {
              id: step5Scroll
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true

              ColumnLayout {
                width: step5Scroll.availableWidth
                spacing: 16

                // Verified State Banner (When authenticated or bare metal)
                Rectangle {
                  visible: Boolean(selectedProvider && (isProviderAuthenticated || selectedProvider.id === "baremetal"))
                  Layout.fillWidth: true
                  implicitHeight: authSuccessRow.implicitHeight + 28
                  radius: 12
                  color: "#06281b"
                  border.color: "#059669"
                  border.width: 1

                  RowLayout {
                    id: authSuccessRow
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14
                    Rectangle {
                      width: 40
                      height: 40
                      radius: 20
                      color: "#064e3b"
                      Text {
                        anchors.centerIn: parent
                        text: "✔"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#34d399"
                      }
                    }
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      spacing: 2
                      Text {
                        text: (selectedProvider ? selectedProvider.name : "Provider") + " Verified & Ready"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#f8fafc"
                      }
                      Text {
                        text: "Credentials are active in Ocloud Vault. Click Continue below to review and launch."
                        font.pixelSize: 12
                        color: "#a7f3d0"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                      }
                    }
                    AppButton {
                      visible: selectedProvider && selectedProvider.id !== "baremetal"
                      text: "Change Credentials"
                      variant: "secondary"
                      Layout.alignment: Qt.AlignVCenter
                      onClicked: markProviderAuthenticated(selectedProvider ? selectedProvider.id : "", false)
                    }
                  }
                }

                // DYNAMIC PROVIDER AUTHENTICATION PANEL (When unauthenticated)
                Rectangle {
                  visible: Boolean(selectedProvider && selectedProvider.id !== "baremetal" && !isProviderAuthenticated)
                  Layout.fillWidth: true
                  implicitHeight: authPanelCol.implicitHeight + 32
                  radius: 12
                  color: "#080e1a"
                  border.color: "#1e3a5f"
                  border.width: 1

                  ColumnLayout {
                    id: authPanelCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 16

                    // Provider Header
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      Rectangle {
                        width: 40
                        height: 40
                        radius: 8
                        color: "#1e3a8a"
                        Image {
                          anchors.centerIn: parent
                          width: 24
                          height: 24
                          source: (selectedProvider && selectedProvider.iconDataUri && selectedProvider.iconDataUri.length > 0) ? selectedProvider.iconDataUri : ((selectedProvider && selectedProvider.iconSvg) ? Qt.resolvedUrl(selectedProvider.iconSvg) : Qt.resolvedUrl("../icons/server.svg"))
                          fillMode: Image.PreserveAspectFit
                        }
                      }
                      ColumnLayout {
                        spacing: 2
                        Layout.fillWidth: true
                        Text {
                          text: (selectedProvider && selectedProvider.auth && selectedProvider.auth.title) ? selectedProvider.auth.title : ((selectedProvider ? selectedProvider.name : "Provider") + " Credentials")
                          font.pixelSize: 15
                          font.bold: true
                          color: "#f8fafc"
                        }
                        Text {
                          text: (selectedProvider && selectedProvider.auth && selectedProvider.auth.subtitle) ? selectedProvider.auth.subtitle : "Enter your API credentials to connect Ocloud"
                          font.pixelSize: 12
                          color: "#94a3b8"
                        }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#1e293b" }

                    // Dynamic Guide Steps Box (Dictated 100% by plugin.json)
                    Rectangle {
                      visible: Boolean(selectedProvider && selectedProvider.auth && selectedProvider.auth.guideSteps && selectedProvider.auth.guideSteps.length > 0)
                      Layout.fillWidth: true
                      radius: 8
                      color: "#0c1527"
                      border.color: "#1e3a5f"
                      border.width: 1
                      implicitHeight: guideStepsCol.implicitHeight + 24

                      ColumnLayout {
                        id: guideStepsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 10

                        Text {
                          text: "HOW TO GET YOUR CREDENTIALS:"
                          font.pixelSize: 11
                          font.bold: true
                          color: "#38bdf8"
                        }

                        Repeater {
                          model: (selectedProvider && selectedProvider.auth && selectedProvider.auth.guideSteps) ? selectedProvider.auth.guideSteps : []
                          delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                              text: (index + 1) + "."
                              font.pixelSize: 12
                              font.bold: true
                              color: "#38bdf8"
                            }
                            Text {
                              text: modelData
                              font.pixelSize: 12
                              color: index === 0 ? "#e2e8f0" : "#94a3b8"
                              Layout.fillWidth: true
                              wrapMode: Text.WordWrap
                            }
                            AppButton {
                              visible: index === 0 && Boolean(selectedProvider && selectedProvider.auth && selectedProvider.auth.guideUrl)
                              text: "Open Console ↗"
                              variant: "secondary"
                              onClicked: Qt.openUrlExternally(selectedProvider.auth.guideUrl)
                            }
                          }
                        }
                      }
                    }

                    // Auto-detected Key Files Banner (Dictated by plugin.json auth.fileDrop)
                    Rectangle {
                      visible: Boolean(selectedProvider && selectedProvider.auth && selectedProvider.auth.fileDrop && modal.foundKeyFiles.length > 0)
                      Layout.fillWidth: true
                      radius: 8
                      color: "#081d33"
                      border.color: "#0284c7"
                      border.width: 1
                      implicitHeight: autoKeyCol.implicitHeight + 20

                      ColumnLayout {
                        id: autoKeyCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Text {
                          text: "✨ Detected Credential Files in Downloads:"
                          font.pixelSize: 12
                          font.bold: true
                          color: "#38bdf8"
                          Layout.fillWidth: true
                        }

                        Repeater {
                          model: modal.foundKeyFiles
                          delegate: RowLayout {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                              text: "📄 " + modelData.name + (modelData.projectId ? (" (" + modelData.projectId + ")") : "")
                              font.pixelSize: 11
                              font.family: "monospace"
                              color: "#e2e8f0"
                              Layout.fillWidth: true
                              elide: Text.ElideMiddle
                            }
                            AppButton {
                              text: "Load File"
                              variant: "primary"
                              onClicked: modal.loadCredentialFile(modelData.path)
                            }
                          }
                        }
                      }
                    }

                    // API Error / Warning Alert Banner
                    Rectangle {
                      visible: modal.authVerifyError.length > 0
                      Layout.fillWidth: true
                      radius: 8
                      color: "#201305"
                      border.color: "#d97706"
                      border.width: 1
                      implicitHeight: apiWarnCol.implicitHeight + 24

                      ColumnLayout {
                        id: apiWarnCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        RowLayout {
                          spacing: 8
                          Image {
                            width: 18
                            height: 18
                            source: "../icons/alert-triangle.svg"
                            sourceSize: Qt.size(18, 18)
                          }
                          Text {
                            text: modal.authEnableUrl.length > 0 ? "Compute API Disabled" : "Verification Failed"
                            font.pixelSize: 13
                            font.bold: true
                            color: "#fbbf24"
                          }
                        }

                        Text {
                          text: modal.authVerifyError
                          font.pixelSize: 11
                          color: "#fde68a"
                          wrapMode: Text.WordWrap
                          Layout.fillWidth: true
                        }

                        RowLayout {
                          spacing: 10
                          AppButton {
                            visible: modal.authEnableUrl.length > 0
                            text: "Enable API in Console ↗"
                            variant: "primary"
                            onClicked: Qt.openUrlExternally(modal.authEnableUrl)
                          }
                          AppButton {
                            text: "Verify Again"
                            variant: "secondary"
                            onClicked: verifySelectedProvider()
                          }
                        }
                      }
                    }

                    // Dynamic Fields Repeater (Dictated 100% by plugin.json auth.fields)
                    Repeater {
                      model: (selectedProvider && selectedProvider.auth && selectedProvider.auth.fields) ? selectedProvider.auth.fields : []
                      delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                          text: (modelData.label || modelData.key).toUpperCase() + (modelData.required !== false ? " *" : " (Optional)")
                          font.pixelSize: 10
                          font.bold: true
                          color: "#94a3b8"
                        }

                        // Text Area input (e.g. JSON Service Account or PEM Key)
                        Rectangle {
                          visible: modelData.type === "textarea"
                          Layout.fillWidth: true
                          implicitHeight: 110
                          radius: 8
                          color: "#060913"
                          border.color: txtArea.activeFocus ? "#3b82f6" : "#1e293b"
                          border.width: 1

                          TextArea {
                            id: txtArea
                            anchors.fill: parent
                            anchors.margins: 10
                            text: modal.getDynamicInput(modelData.key)
                            placeholderText: modelData.placeholder || ""
                            placeholderTextColor: "#475569"
                            color: "#f8fafc"
                            font.pixelSize: 11
                            font.family: "monospace"
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            activeFocusOnPress: true
                            background: null
                            onTextChanged: {
                              if (text !== modal.getDynamicInput(modelData.key)) {
                                modal.onAuthFieldChanged(modelData.key, text);
                              }
                            }
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: txtArea.forceActiveFocus()
                            z: -1
                          }
                        }

                        // Standard TextInput (Text or Password)
                        Rectangle {
                          visible: modelData.type !== "textarea" && modelData.type !== "boolean"
                          Layout.fillWidth: true
                          height: 38
                          radius: 6
                          color: "#060913"
                          border.color: txtInput.activeFocus ? "#3b82f6" : "#1e293b"
                          border.width: 1

                          TextInput {
                            id: txtInput
                            anchors.fill: parent
                            anchors.margins: 10
                            text: modal.getDynamicInput(modelData.key)
                            color: "#f8fafc"
                            font.pixelSize: 12
                            font.family: "monospace"
                            echoMode: modelData.type === "password" ? TextInput.Password : TextInput.Normal
                            selectByMouse: true
                            activeFocusOnPress: true
                            onTextChanged: {
                              if (text !== modal.getDynamicInput(modelData.key)) {
                                modal.setDynamicInput(modelData.key, text);
                              }
                            }

                            Text {
                              anchors.fill: parent
                              text: modelData.placeholder || ""
                              color: "#475569"
                              font.pixelSize: 12
                              font.family: "monospace"
                              visible: !txtInput.text && !txtInput.activeFocus
                            }
                          }

                          MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            acceptedButtons: Qt.LeftButton
                            onClicked: txtInput.forceActiveFocus()
                            z: -1
                          }
                        }
                      }
                    }

                    // Verify & Connect Account Button
                    RowLayout {
                      Layout.fillWidth: true
                      Item { Layout.fillWidth: true }
                      AppButton {
                        text: modal.isVerifyingAuth ? "Verifying..." : "Verify & Connect Account"
                        variant: "primary"
                        enabled: !modal.isVerifyingAuth
                        onClicked: verifySelectedProvider()
                      }
                    }
                  }
                }
              }
            }
          }

          // =======================================================
          // STEP 6: REVIEW & DEPLOY
          // =======================================================
          ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: currentStep === 6
            spacing: 14

            ColumnLayout {
              spacing: 4
              Text { text: "Review Instance Configuration"; font.pixelSize: 18; font.bold: true; color: "#f8fafc" }
              Text { text: "Confirm deployment settings and provider credentials before allocating resources"; font.pixelSize: 12; color: "#94a3b8" }
            }

            ScrollView {
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentWidth: availableWidth

              ColumnLayout {
                width: parent.width
                spacing: 14

                // Hero Summary Card
                Rectangle {
                  Layout.fillWidth: true
                  radius: 12
                  color: "#080e1a"
                  border.color: "#1e3a5f"
                  border.width: 1
                  implicitHeight: sumCol.implicitHeight + 28

                  ColumnLayout {
                    id: sumCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 14

                    // Top Line: Hostname & Status
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: 12
                      Rectangle {
                        width: 44
                        height: 44
                        radius: 10
                        color: "#0f1f38"
                        border.color: "#1d4ed8"
                        Image {
                          anchors.centerIn: parent
                          width: 24
                          height: 24
                          source: (selectedProvider && selectedProvider.iconDataUri && selectedProvider.iconDataUri.length > 0) ? selectedProvider.iconDataUri : Qt.resolvedUrl(selectedProvider ? (selectedProvider.iconSvg || "../icons/server.svg") : "../icons/server.svg")
                          fillMode: Image.PreserveAspectFit
                          smooth: true
                        }
                      }
                      ColumnLayout {
                        spacing: 2
                        Text { text: hostnameField.text || "runner-node"; font.pixelSize: 16; font.bold: true; color: "#f8fafc" }
                        Text { text: (selectedProvider ? selectedProvider.name : "Cloud") + " · " + (selectedTier ? selectedTier.name.toUpperCase() : "Tier"); font.pixelSize: 12; color: "#38bdf8" }
                      }
                      Item { Layout.fillWidth: true }
                      ColumnLayout {
                        spacing: 2
                        Layout.alignment: Qt.AlignRight
                        Text { text: selectedTier ? (getTierPrice(selectedTier, selectedRegion ? selectedRegion.id : "").hour + " / hr") : "—"; font.pixelSize: 18; font.bold: true; color: "#10b981" }
                        Text { text: selectedTier ? ("Est. " + getTierPrice(selectedTier, selectedRegion ? selectedRegion.id : "").month + " / mo") : ""; font.pixelSize: 10; color: "#64748b"; Layout.alignment: Qt.AlignRight }
                      }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#1e293b" }

                    // Spec Grid
                    GridLayout {
                      columns: 2
                      columnSpacing: 20
                      rowSpacing: 12
                      Layout.fillWidth: true

                      ColumnLayout {
                        spacing: 2
                        Text { text: "HARDWARE RESOURCES"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
                        Text { text: selectedTier ? ((selectedTier.cores ? selectedTier.cores + " vCPU · " + selectedTier.memory + " GB RAM · " + selectedTier.disk + " GB NVMe" : (selectedTier.cpu + " · " + selectedTier.ram + " · " + selectedTier.disk)) + (selectedTier.cpuType === "dedicated" ? " · Dedicated CPU" : " · Shared CPU")) : "—"; font.pixelSize: 12; color: "#f8fafc" }
                      }

                      ColumnLayout {
                        spacing: 2
                        Text { text: "DATACENTER REGION"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
                        Text { text: selectedRegion ? (selectedRegion.name + " (" + selectedRegion.id + ") · High Speed Backbone") : "—"; font.pixelSize: 12; color: "#f8fafc" }
                      }

                      ColumnLayout {
                        spacing: 2
                        Text { text: "OPERATING SYSTEM"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
                        RowLayout {
                          spacing: 6
                          Image {
                            width: 14
                            height: 14
                            source: getOsIcon(selectedOs)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                          }
                          Text { text: selectedOs ? (selectedOs.description || selectedOs.name) : "Ubuntu 24.04"; font.pixelSize: 12; color: "#f8fafc" }
                        }
                      }

                      ColumnLayout {
                        spacing: 2
                        Text { text: "AUTHENTICATION & SECURITY"; font.pixelSize: 10; font.bold: true; color: "#64748b" }
                        Text { text: "OpenSSH Key Auto-Injected (~/.ssh/id_ed25519)"; font.pixelSize: 12; color: "#f8fafc" }
                      }
                    }
                  }
                }

                // Authentication Status / Credential Entry Card
                Rectangle {
                  Layout.fillWidth: true
                  radius: 10
                  color: isProviderAuthenticated ? "#091c14" : "#1c1409"
                  border.color: isProviderAuthenticated ? "#15803d" : "#d97706"
                  border.width: 1
                  implicitHeight: credCol.implicitHeight + 24

                  ColumnLayout {
                    id: credCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                      spacing: 8
                      Image {
                        width: 16
                        height: 16
                        source: isProviderAuthenticated ? "../icons/shield.svg" : "../icons/alert-triangle.svg"
                        sourceSize: Qt.size(16, 16)
                      }
                      Text {
                        text: (selectedProvider ? selectedProvider.name : "Provider") + " Credentials Configured"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#4ade80"
                      }
                      Item { Layout.fillWidth: true }
                      Text {
                        text: "Verified in Ocloud Vault"
                        font.pixelSize: 11
                        color: "#86efac"
                      }
                    }

                    Text {
                      text: "All required API credentials and SSH keys are active and verified in the Ocloud Vault."
                      font.pixelSize: 11
                      color: "#94a3b8"
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                    }
                  }
                }

                // Info banner with WordWrap
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: infoRow.implicitHeight + 16
                  radius: 6
                  color: "#0d1b32"
                  border.color: "#1e3a5f"
                  RowLayout {
                    id: infoRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Image {
                      width: 16
                      height: 16
                      source: "../icons/bolt.svg"
                      sourceSize: Qt.size(16, 16)
                      Layout.alignment: Qt.AlignVCenter
                    }
                    Text { text: "Instant Launch:"; font.pixelSize: 11; font.bold: true; color: "#fbbf24"; Layout.alignment: Qt.AlignVCenter }
                    Text {
                      text: "Server will boot in ~10 seconds. Cloud-init automatically joins Tailscale and preps Docker."
                      font.pixelSize: 11
                      color: "#94a3b8"
                      Layout.fillWidth: true
                      wrapMode: Text.WordWrap
                      Layout.alignment: Qt.AlignVCenter
                    }
                  }
                }
              }
            }
          }
          // =======================================================
          // BOTTOM CONTROLS & NAVIGATION
          // =======================================================
          Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#1e293b"
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            AppButton {
              text: "Cancel"
              variant: "secondary"
              onClicked: modal.visible = false
            }

            Item { Layout.fillWidth: true }

            AppButton {
              visible: currentStep > 1
              text: "← Back"
              variant: "secondary"
              onClicked: currentStep = currentStep - 1
            }

            AppButton {
              visible: currentStep < 6
              text: "Continue →"
              variant: "primary"
              enabled: {
                if (currentStep === 1) return selectedProvider !== null;
                if (currentStep === 2) return selectedTier !== null;
                if (currentStep === 3) return selectedRegion !== null;
                if (currentStep === 4) return selectedOs !== null;
                if (currentStep === 5) return selectedProvider && (selectedProvider.id === "baremetal" || isProviderAuthenticated);
                return true;
              }
              onClicked: currentStep = currentStep + 1
            }

            AppButton {
              visible: currentStep === 6 && !deploySuccess
              text: isDeploying ? "Deploying..." : "Deploy Instance"
              variant: "primary"
              enabled: !isDeploying && (selectedProvider && (selectedProvider.id === "baremetal" || isProviderAuthenticated))
              iconSource: isDeploying ? "" : "icons/server.svg"
              onClicked: deployInstance()
            }
          }
        }
      }
    }

    // Live Deployment & Error Overlay (Prevents premature close)
    Rectangle {
      visible: isDeploying || deployError !== "" || deploySuccess
      anchors.fill: parent
      color: Qt.rgba(0.03, 0.05, 0.10, 0.96)
      radius: modalDialog.radius
      z: 200

      ColumnLayout {
        anchors.centerIn: parent
        spacing: 16
        width: Math.min(parent.width - 48, 500)

        // While deploying:
        BusyIndicator {
          visible: isDeploying
          running: isDeploying
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          visible: isDeploying
          text: "Provisioning Cloud Instance..."
          font.pixelSize: 16
          font.bold: true
          color: "#f8fafc"
          Layout.alignment: Qt.AlignHCenter
        }
        Text {
          visible: isDeploying
          text: (isDeploying && selectedTier && selectedRegion) ? ("Allocating " + selectedTier.name.toUpperCase() + " in " + selectedRegion.name + " (" + selectedRegion.id + ") via " + (selectedProvider ? selectedProvider.name : "Cloud") + " API.") : ""
          font.pixelSize: 12
          color: "#94a3b8"
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
        }

        // Error State:
        Rectangle {
          visible: !isDeploying && deployError !== ""
          Layout.fillWidth: true
          implicitHeight: errCol.implicitHeight + 24
          color: "#220808"
          border.color: "#ef4444"
          radius: 8

          ColumnLayout {
            id: errCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            RowLayout {
              spacing: 8
              Image {
                width: 18
                height: 18
                source: "../icons/alert-triangle.svg"
                sourceSize: Qt.size(18, 18)
              }
              Text { text: "Deployment Failed"; font.pixelSize: 14; font.bold: true; color: "#f87171" }
            }
            Text {
              text: deployError
              font.pixelSize: 11
              color: "#fca5a5"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            Rectangle {
              visible: modal.authEnableUrl.length > 0 || (deployError && (deployError.indexOf("API") !== -1 || deployError.indexOf("disabled") !== -1))
              Layout.fillWidth: true
              radius: 6
              color: "#1c1409"
              border.color: "#d97706"
              implicitHeight: apiErrPromptCol.implicitHeight + 16

              ColumnLayout {
                id: apiErrPromptCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8
                Text {
                  text: "⚠️ API Activation Required:"
                  font.pixelSize: 12
                  font.bold: true
                  color: "#fbbf24"
                }
                Text {
                  text: (selectedProvider ? selectedProvider.name : "Provider") + " requires the compute API service to be enabled in your account console before allocating resources. Click below to open your console, enable the service, and retry."
                  font.pixelSize: 11
                  color: "#fde68a"
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
                AppButton {
                  visible: modal.authEnableUrl.length > 0 || Boolean(selectedProvider && selectedProvider.auth && selectedProvider.auth.guideUrl)
                  text: "Enable API in Console ↗"
                  variant: "primary"
                  onClicked: {
                    var targetUrl = modal.authEnableUrl.length > 0 ? modal.authEnableUrl : (selectedProvider && selectedProvider.auth ? selectedProvider.auth.guideUrl : "");
                    if (targetUrl) Qt.openUrlExternally(targetUrl);
                  }
                }
              }
            }
          }
        }

        RowLayout {
          visible: !isDeploying && deployError !== ""
          Layout.alignment: Qt.AlignHCenter
          spacing: 12
          AppButton {
            text: "Edit Configuration"
            variant: "secondary"
            onClicked: { deployError = ""; }
          }
          AppButton {
            text: "Retry Deployment"
            variant: "primary"
            onClicked: {
              deployError = "";
              deployInstance();
            }
          }
        }

        // Success State:
        Rectangle {
          visible: !isDeploying && deploySuccess
          Layout.fillWidth: true
          implicitHeight: succCol.implicitHeight + 24
          color: "#082012"
          border.color: "#22c55e"
          radius: 8

          ColumnLayout {
            id: succCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            Text { text: "✓ Instance Provisioned Successfully!"; font.pixelSize: 15; font.bold: true; color: "#4ade80"; Layout.alignment: Qt.AlignHCenter }
            Text { text: deploySuccessMsg; font.pixelSize: 12; color: "#bbf7d0"; wrapMode: Text.WordWrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
            Text { text: "The instance is booting and will appear in your Compute Fleet momentarily."; font.pixelSize: 11; color: "#86efac"; wrapMode: Text.WordWrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
          }
        }

        AppButton {
          visible: !isDeploying && deploySuccess
          text: "Done - View in Fleet"
          variant: "primary"
          Layout.alignment: Qt.AlignHCenter
          onClicked: {
            modal.visible = false;
            modal.serverProcured();
            deploySuccess = false;
          }
        }
      }
    }
  }

  function verifySelectedProvider() {
    if (!selectedProvider) return;
    var provId = selectedProvider.id;
    var fields = (selectedProvider.auth && selectedProvider.auth.fields) ? selectedProvider.auth.fields : [];

    modal.isVerifyingAuth = true;
    modal.authVerifyError = "";
    modal.authEnableUrl = "";

    function onStored() {
      ocloud.verifyProvider(provId, function(result, ok) {
        modal.isVerifyingAuth = false;
        if (ok) {
          modal.markProviderAuthenticated(provId, true);
          modal.loadCatalog();
        } else {
          modal.markProviderAuthenticated(provId, false);
          if (result && result.needsApiEnable) {
            modal.authVerifyError = result.error || "Compute API is disabled for this provider.";
            modal.authEnableUrl = result.enableUrl || "";
          } else {
            modal.authVerifyError = (result && result.error) || ("Failed to verify credentials for " + (selectedProvider.name || provId) + ".");
          }
        }
      });
    }

    var asyncImports = 0;
    for (var i = 0; i < fields.length; i++) {
      var f = fields[i];
      var val = (dynamicAuthInputs[f.key] || "").trim();
      if (val.length > 0) {
        if (f.type === "textarea" && (val.startsWith("/") || val.startsWith("~") || (val.indexOf("\n") === -1 && val.endsWith(".json")))) {
          asyncImports++;
          ocloud.importVaultKeyFile(f.key, val, function(out, ok) {
            asyncImports--;
            if (asyncImports <= 0) onStored();
          });
        } else {
          ocloud.setVaultSecret(f.key, val);
          if (provId === "hetzner" && f.key === "api_token") {
            ocloud.setVaultSecret("hetzner_api_token", val);
          }
        }
      }
    }

    if (asyncImports === 0) {
      onStored();
    }
  }

  function deployInstance() {
    isDeploying = true;
    deployError = "";
    deploySuccess = false;
    var chosenName = hostnameField.text.trim() || ("runner-" + Math.floor(Math.random() * 1000));
    var chosenType = selectedTier.id;
    var chosenLoc = selectedRegion.id;
    var chosenOs = (selectedOs && (selectedOs.imageTag || selectedOs.name)) || "ubuntu-24.04";
    var tsOption = tsCheck.checked ? "auto" : "";
    ocloud.procureServer(chosenName, chosenType, chosenLoc, tsOption, chosenOs, selectedProvider ? selectedProvider.id : "hetzner");
  }
}
