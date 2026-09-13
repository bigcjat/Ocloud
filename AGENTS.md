# 🤖 Ocloud Agent & LLM Guidelines

This document defines core architectural constraints, coding standards, and asset sourcing rules for any AI agent or LLM working in this repository.

---

## 1. Core Architecture & Stack Rules
* **Frontend:** Pure QML (Qt 6.8+). No QML deprecation regressions. Responsive, fluid layouts with desktop-first design.
* **Backend:** Pure Node.js.
* **Zero Python:** Never introduce Python runtime dependencies, wrappers, or scripts into the core application or plugin drivers.
* **Zero External npm Dependencies in Plugins:** Drivers must rely strictly on Node.js built-ins (`crypto`, `https`, `child_process`, `fs`, `path`). For example, RS256 JWT signing for service accounts is done via native `crypto.createSign('RSA-SHA256')`.
* **Zero-Trust Security Sandbox:** Every plugin must pass `./ocloud providers audit <id>`. Never use piped shell execution (`curl | sh`); download to temporary files and inspect.

---

## 2. SVG Logo & Brand Vector Sourcing Standard (MANDATORY)

> [!IMPORTANT]
> **NEVER HALLUCINATE OR HAND-DRAW SVG PATHS.**
> LLMs must never attempt to invent SVG `<path d="...">` coordinates by hand.

### Primary Canonical Source: Simple Icons
For all cloud infrastructure providers and Linux OS distributions, **Simple Icons** is the mandated primary source:
* **Repository:** [github.com/simple-icons/simple-icons](https://github.com/simple-icons/simple-icons)
* **Web Catalog:** [simpleicons.org](https://simpleicons.org)
* **Raw Direct SVG URLs:**
  - `https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/<slug>.svg`
  - `https://unpkg.com/simple-icons/icons/<slug>.svg`

### Why Simple Icons is Mandated:
1. **Audited Vectors:** Clean, single `<path d="..."/>` elements without nested groups, fonts, or inline CSS.
2. **Standardized ViewBox:** Pre-normalized to `viewBox="0 0 24 24"`.
3. **Security Audited:** Zero `<script>`, `onload`, or `<foreignObject>` security hazards.
4. **Verified Brand Colors:** Provides canonical official hex brand colors for each entity.

### Standard Slugs for Reference:
| Category | Entity | Slug | Brand Hex |
| :--- | :--- | :--- | :--- |
| **Compute / Cloud** | Hetzner | `hetzner` | `#D50C2D` |
| | Google Cloud | `googlecloud` | `#4285F4` |
| | Amazon AWS | `amazonaws` | `#232F3E` |
| | DigitalOcean | `digitalocean` | `#0080FF` |
| | Vultr | `vultr` | `#007BFC` |
| | Linode / Akamai | `linode` | `#00A95C` |
| | Scaleway | `scaleway` | `#4F0599` |
| | Cloudflare | `cloudflare` | `#F38020` |
| | Backblaze | `backblaze` | `#E01E2E` |
| | OVHcloud | `ovh` | `#000E9C` |
| **Operating Systems** | Ubuntu | `ubuntu` | `#E95420` |
| | Debian | `debian` | `#A81D33` |
| | Alpine Linux | `alpinelinux` | `#0D597F` |
| | Arch Linux | `archlinux` | `#1793D1` |
| | Rocky Linux | `rockylinux` | `#10B981` |
| | AlmaLinux | `almalinux` | `#0F4266` |
| | Fedora | `fedora` | `#51A2DA` |
| | CentOS | `centos` | `#262577` |
| | openSUSE | `opensuse` | `#73BA25` |

### Embedding Rule:
Minify via `node tools/optimize_all_svgs.js` or `npx -y svgo`, escape double quotes (`\"`), and embed into `iconSvg` inside `plugin.json`.

---

## 3. Pricing Display Standard (Hourly First, Honest Billing)
* **Format:** Always show the **hourly rate as primary** and **monthly rate as secondary**.
  - Example: `€0.0058 / hr (€3.65 / mo)` or `$0.0084 / hr ($6.11 / mo)`.
* **Honesty Over Marketing:** Display the actual raw pricing returned by the provider's API. Do not hardcode promotional claims, rebate promises, or "free tier" asterisks into UI labels or driver pricing outputs.

---

## 4. Drop-in Plugin Architecture Standard
* **Zero Hardcoding:** The UI (e.g. `ProcureWizard.qml`, `AddNodeModal.qml`, `AddStorageWizard.qml`) must remain completely generic.
  - Compute providers are enumerated dynamically from `driver.listComputePlugins()`.
  - Step 2 (Hardware Tiers) binds directly to `catalog.server_types` or `catalog.machine_types`.
  - Step 3 (Locations/Zones) binds directly to `catalog.datacenters` or `catalog.zones`.
  - Step 4 (OS Images) binds dynamically to `catalog.images`. Never hardcode static OS lists (e.g. Alpine/Arch) for providers that do not support them.
