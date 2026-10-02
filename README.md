# StrongBox

Community fork of [IntegrityBox](https://github.com/MeowDump/Integrity-Box) by MeowDump — a Play Integrity & system environment toolkit, cleaned up and de-branded.

> [!WARNING]
> **Unofficial fork — not affiliated with or endorsed by the original author.**
> StrongBox keeps the upstream v43 feature set, but removes dead code, deduplicates helpers, fixes latent bugs, rebuilds the WebUI on a single design system, and drops MeowDump-specific branding (custom font, name, links).
>
> - **Versioning:** this fork has its own versioning — currently `1.0.0` (base: IntegrityBox v43). The module ID stays `playintegrityfix` on purpose: StrongBox is a drop-in replacement for PlayIntegrityFix / IntegrityBox (upstream, by MeowDump) and all on-device paths depend on it. Do **not** flash it alongside another PIF-style module.
> - **Building:** `./build.sh <donor-release.zip>` assembles a flashable zip and regenerates the install-time integrity manifest. `bash tests/check.sh` runs all static checks (also used by CI). See [DEVELOPING.md](DEVELOPING.md) for the repo map, conventions and release workflow.
> - **Runtime dependencies:** keybox updates, keybox status, auto-pilot files and translations are fetched from upstream MeowDump repositories at runtime; no local mirrors are kept in this repo (deliberate dependency).
> - **Support:** fork-specific bugs belong in [this repo's issues](https://github.com/dacrab/Integrity-Box/issues). Upstream community links are kept where they are still useful.
> - **License:** GPL-3.0. Original work © MeowDump and contributors; fork changes © dacrab. See [LICENSE](LICENSE).
> - **Want the official module?** Use the [upstream repo](https://github.com/MeowDump/Integrity-Box) and its releases.

<details>
<summary><strong>Requirements</strong></summary>

> Please make sure you have the following **modules installed** before using StrongBox:

1) - [**Tricky Store OOS**](https://github.com/beakthoven/TrickyStoreOSS/releases) or [**TEE Simulator**](https://github.com/JingMatrix/TEESimulator/releases) (use any one)

2) - [**Zygisk Next**](https://github.com/Dr-TSNG/ZygiskNext/releases) or [**Meow Zygisk**](https://github.com/MeowDump/MeowZygisk/releases) (use any one) (ZygiskNext is recommended for magisk)


> - If you are using Google Pixel stock ROM, or if you want to use your custom ROM's inbuilt spoofing feature, you do not need Zygisk. Simply create a file or folder named `zygisk` in your internal storage `/sdcard/zygisk` (make sure the name is exactly lowercase), and then flash StrongBox. This will disable all zygisk related components and grant you full CONTROL without any conflict

#
</details>

<details>
<summary><strong>FAQ</strong></summary>

- **What is StrongBox?**  
  A complete Play Integrity compatibility and system-signal management toolkit.

- **Who should use StrongBox?**  
  Rooted users and custom ROM users who care about Play Integrity reliability.

- **Why was StrongBox created?**  
  Honestly? It started because so many people were selling keyboxes and I thought, “this is bad, everyone should have access to this for free.” So I made a tool that just gives you keyboxes without paying a cent. Then, well… I kept adding stuff. I kept improving things, fixing bugs, adding new ways to spoof, hide, clean, and optimize. And before I knew it… it turned into a beast of a module, probably the most powerful Play Integrity Fix anyone’s ever seen. It has so many features now that even I sometimes forget half of them. But yeah, that’s the story: started small, got greedy with features, and now it’s the one-stop solution for anyone who wants STRONG or DEVICE integrity without the headaches. Just flash & forget, no need to do anything manually.

- **Does StrongBox replace Play Integrity Fix/Fork module?**  
  Yes! PIF is fully integrated into StrongBox. The module ID is kept as `playintegrityfix`, because honestly, using both at the same time doesn’t make sense. StrongBox handles everything PIF did, plus the extra features on top
  
- **Does StrongBox improve compatibility with banking apps**  
  Yes.

- **Does it support DEVICE and STRONG integrity?**  
  Yes, make sure you have installed tricky store or TEE simulator module.

- **Is StrongBox safe to use?**  
  Yes.

- **Does it modify user data?**  
  No.

- **Does it modify installed apps?**  
  No.

- **Does it run constantly in the background?**  
  No.

- **Is it lightweight?**  
  Yes.

- **Does it increase CPU usage?**  
  No, it may reduce it by optimizing targets.

- **Does it drain battery?**  
  No.

- **Is everything configurable?**  
  Yes.

- **Can features be disabled individually?**  
  Yes.

- **Is there a global safety option?**  
  Yes, the Safe Mode.

- **What does the Safe Mode do?**  
  Disables all experimental features.

- **Can I recover easily if something breaks?**  
  Yes.

- **Is it safe to uninstall?**  
  Yes.

- **Does StrongBox collect any data?**  
  No.

- **Does it include telemetry or tracking?**  
  No.

- **Are any network connections required?**  
  No (except optional downloads).

- **Are downloads verified?**  
  Yes, using hash verification.

- **Does it automatically manage target.txt?**  
  Yes.

- **Does it reduce unnecessary Play Services load?**  
  Yes.

- **Does it handle keybox management?**  
  Yes.

- **Does it support multiple keybox injections?**  
  Yes.

- **Does it help with “Device not certified” issues?**  
  Yes.

- **Does it work on all ROMs?**  
  It works best on clean, enforcing AOSP-based ROMs.

- **Is SELinux enforcing recommended?**  
  Yes.

- **Does it support Pixel spoofing?**  
  Yes.

- **Can fingerprints be customized?**  
  Yes.

- **Does it handle ROM-specific spoofing conflicts?**  
  Yes.

- **Is this module actively maintained?**  
  Yes.

- **Is it beginner-friendly?**  
  Yes, with built-in guidance.

- **Is it suitable for advanced users?**  
  Yes.

- **Should I reboot after changes?**  
  Only if you see a popup saying **"Reboot to apply changes"**.

- **Should I reboot after flashing?**  
  Yes.

- **Where should issues be reported?**  
  Through the WebUI report option.

#
</details>


<details>
<summary><strong>Module Features</strong></summary>
  
> This module provides a wide range of tools designed to improve compatibility, integrity results, and overall system cleanliness. All features are optional and fully configurable.

### Core Utilities
- Built-in assistant to help answer common questions and guide setup
- Option downloads recommended tools from their official release sources with hash verification
- Detects flagged, suspicious, or spoofed applications
- Fixes **“Device not certified”** issue in playstore
- Terminates GMS Vending process when required

### Spoofing & Integrity Enhancements
- Spoofs Android and boot security patch levels
- Spoofs ROM `release keys` and `build tags`
- Spoofs LineageOS-specific property detection
- Spoofs `debug fingerprint` detection
- Supports custom pixel beta fingerprint configuration
- Disables inbuilt PIF spoofing on various custom ROMs when needed
- Fixes `abnormal` or `invalid` boot hash values

### System & Environment Masking
- Spoofs `SELinux` status
- Spoofs storage `encryption` state
- Spoofs `custom recovery` detection
- Hides `PIF hook` detection
- Prevents detection of `debug` or `modified` system states

### Keybox & TEE Management
- Updates and maintains a valid `keybox.xml`
- Supports multiple keybox injections via TEE Simulator
- Automatically updates `target.txt` based on current TEE status
- Blacklists unnecessary packages from `target.txt` (this reduces cpu usage)

### Log & Trace Cleanup
- Removes logs generated during `GApps` installation
- Removes logs generated by `KSU / AP / Magisk` modules

### Additional Controls
- Disables `EU injector` by default
- Spoofs storage-related and ROM-specific identifiers
- Spoofs `debug-related` signals
- **[Deprecated]** ~Switch Shamiko & NoHello modes~

### Many more features exist, but these are the most notable ones. 
### (Honestly, I got tired writing them)

#
</details>

<details>
<summary><strong>About Module Settings</strong></summary>

- `Safe Mode :` Enable this & reboot your device if you face any issue after flashing StrongBox, this will disable all experimental settings.
- `Debug Fingerprint :` cleans debug tag from fingerprint to bypass custom rom detection and pass play integrity with stock fingerprint
- `Debug Build :` spoofs developement build as user
- `Build Tag :` spoofs build tag to bypass custom rom detection
- `Storage Encryption :` spoofs device storage as encrypted to fool banking apps
- `Spoof Custom Recovery :` spoofs custom recovery folder to bypass root detection
- `Get Recommended Modules :` the most easiest and trusted way to download modules which are recommended to use with StrongBox
- `No Redirect :` you won't be redirected to release source on installation
#
</details>

<details>
<summary><strong>About Module Description</strong></summary>
<table align="center">
  <tr>
    <td><img src="assets/valid.png" alt="1" style="max-width: 25%; height: auto;" /></td>
    <td><img src="assets/soft.png" alt="2" style="max-width: 25%; height: 2400;" /></td>
    <td><img src="assets/revoked.png" alt="3" style="max-width: 25%; height: auto;" /></td>
  </tr>
</table>
  
  - 🟢🟢🟢 means the current keybox can pass **STRONG integrity**
  - 🟢🟢🔴 means the current keybox can pass **DEVICE integrity**
  - 🔴🔴🔴 means the current keybox is **REVOKED** and **cannot** pass play integrity
#
</details>


<details>
<summary><strong>Common Failure Reasons</strong></summary>

Play Integrity may fail if any of the following conditions are present:

- **SELinux is set to `permissive`**
- **Higher Play Store version (higher than 40.xx)**
- **Conflicting Magisk / KernelSU / LSPosed modules**
- **Revoked or invalid keybox**
- **Banned fingerprint**
- **ROM inbuilt GMS spoofing is enabled (create `/sdcard/zygisk` & flash StrongBox if you want to use ROM's inbuilt spoofing with StrongBox)**
- **ROM inbuilt Play Store spoofing is enabled**
- **Root access is visible or not properly hidden**
- **StrongBox is not updated to the latest version**
- **Tricky Store is out of sync and requires reflashing**

Ensure all requirements are met and recheck this list before reporting an issue.
#
</details>


<details>
<summary><strong>About WEB UI Dashboard</strong></summary>

<img src="assets/dashboard.png" width="25%">

- `Profile :` Your current PlayIntegrity Profile
- `Vending :` Your current PlayStore version
- `Lineage :` Tells whether any lineageos prop exists or not
- `Spoofing :` Tell whether you're using ROM's inbuilt GMS spoofing or not
- `Spoof :` The name of pixel device, your playstore spoofed to!
- `Patch :` Your Android, Vendor security patch date
- `SELinux :` Your ROM's selinux status. It should not be PERMISSIVE
- `Target :` Number of apps in tricky store's target.txt file
- `Android :` Your android version
- `Zygote :` The zygisk implementation you are using
#
</details>


<details>
<summary><strong>Credit & Acknowledgement</strong></summary>
  
#### This project uses code from the following external open-source work:
- **[ezme-nodebug](https://github.com/ez-me/ezme-nodebug)**
- **[PlayIntegrityFork](https://github.com/osm0sis/PlayIntegrityFork)**
#
</details>

<details>
<summary><strong>Report a Problem</strong></summary>
  
- Use Report a bug/issue button in WebUI to report bugs/issues/feedback
- Enable `SAFE MODE` toggle from webui > `module settings` and reboot your device if you're facing any issue after flashing StrongBox. This wil disable all experimental features.
#
</details>

<details>
<summary><strong>Troubleshooting</strong></summary>

Google Play Integrity has fully replaced SafetyNet and is now the only attestation system used by modern apps. It checks whether a device looks *trustworthy and close to a certified Android environment*. Because of this, failures are common on outdated, heavily modified, or poorly configured systems.

Play Integrity checks do **not** only look at root status. They evaluate multiple system signals, including ROM configuration, SELinux state, system hooks, and how Google services behave at runtime.

To reduce false negatives and improve reliability:

- **Use a ROM with SELinux set to `enforcing`.**  
  ROMs running in permissive mode are frequently flagged. Even if everything else looks fine, permissive SELinux alone can cause integrity checks to fail.

- **Keep Google Play Services and the Play Store fully up to date.**  
  Play Integrity relies on Play Services to perform attestation. Old or mismatched versions can break communication with Google’s servers and lead to unexpected failures.

- **Avoid system-level frameworks that hook core services.**  
  Xposed, LSPosed, or similar frameworks, especially modules that interact with Google Play Services or the Play Store, are a common cause of integrity failures. Even “harmless” hooks can be detected.

- **Minimize invasive system modifications.**  
  Changes such as aggressive build.prop spoofing, signature spoofing, or runtime code injection increase the likelihood of detection unless they are carefully handled.

- **Keep the system as close to stock behavior as possible.**  
  The closer your device behaves to a certified, unmodified Android environment, the more consistent Play Integrity results will be.

Play Integrity is stricter than older systems and is actively updated by Google. Passing checks today does not guarantee passing them forever, especially on custom ROMs. Treat integrity passing as something that requires maintenance, not a one-time setup.
#
</details>

<p align="center">
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/footers/gray0_ctp_on_line.svg?sanitize=true" alt="Catppuccin Footer" />
</p>

<div align="center">
  <a href="https://github.com/dacrab/Integrity-Box/releases" target="_blank">
    <img src="https://img.shields.io/badge/Download-StrongBox%20releases-2ea44f?style=for-the-badge&logo=github" alt="Download StrongBox releases">
  </a>
</div>

<br>

<div align="center" style="display: flex; justify-content: center; gap: 24px; flex-wrap: wrap;">
  <a href="https://github.com/dacrab/Integrity-Box/issues" target="_blank">
    <img src="https://img.shields.io/badge/Report%20a%20bug-GitHub%20issues-blue?style=for-the-badge&logo=github" alt="Report a bug">
  </a>
  <a href="https://github.com/dacrab/Integrity-Box/releases" target="_blank">
    <img src="https://img.shields.io/badge/Releases-StrongBox-black?style=for-the-badge&logo=github" alt="Releases">
  </a>
  <a href="https://github.com/MeowDump/Integrity-Box" target="_blank">
    <img src="https://img.shields.io/badge/Upstream-IntegrityBox-lightgrey?style=for-the-badge" alt="Upstream project">
  </a>
</div>

## Preview
<p align="center">
  <a href="https://github.com/dacrab/Integrity-Box/stargazers">
    <img src="https://m3-markdown-badges.vercel.app/stars/7/1/dacrab/Integrity-Box" alt="GitHub Stars" />
  </a>
  <br />
  <a href="https://github.com/dacrab/Integrity-Box/releases">
    <img src="https://img.shields.io/github/downloads/dacrab/Integrity-Box/total?label=Downloads&color=%2300add8&style=flat" alt="GitHub Releases" />
  </a>
</p>

<table align="center">
  <tr>
    <td><img src="assets/home.gif" alt="1" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/toolkit.png" alt="2" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/simulator.png" alt="3" style="max-width: 100%; height: auto;" /></td>
  </tr>
  <tr>
    <td><img src="assets/profile.png" alt="4" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/pif.png" alt="5" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/patch.png" alt="6" style="max-width: 100%; height: auto;" /></td>
  </tr>
  <tr>
    <td><img src="assets/load.png" alt="7" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/hash.png" alt="8" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/fingerprint.png" alt="9" style="max-width: 100%; height: auto;" /></td>
  </tr>
  <tr>
    <td><img src="assets/ctrlcentre.png" alt="10" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/certified.png" alt="11" style="max-width: 100%; height: 2400;" /></td>
    <td><img src="assets/blacklist.png" alt="12" style="max-width: 100%; height: auto;" /></td>
  </tr>
  <tr>
    <td><img src="assets/assistant.png" alt="13" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/apps.png" alt="14" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/help.png" alt="15" style="max-width: 100%; height: auto;" /></td>
  </tr>
  <tr>
    <td><img src="assets/action.png" alt="16" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/strong.png" alt="17" style="max-width: 100%; height: auto;" /></td>
    <td><img src="assets/attestation.png" alt="18" style="max-width: 100%; height: auto;" /></td>
  </tr>
</table>
