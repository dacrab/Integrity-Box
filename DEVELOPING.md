# Developing StrongBox

StrongBox is an unofficial, de-branded fork of [MeowDump/Integrity-Box](https://github.com/MeowDump/Integrity-Box) (GPL-3.0), based on upstream v43. This document is the map: how the module runs, where things live, and how to extend, build and release it.

## Repository map

```
module.prop               Module identity shown by Magisk / KernelSU / APatch
customize.sh              Install-time entry point (runs once when flashing)
common_func.sh            Shared shell helpers (sourced by install / boot / action scripts)
common_setup.sh           PropImitationHooks conflict workarounds (install + boot)
action.sh                 Runs when the user taps the module Action button in the root manager
service.sh                late_start boot logic (prop spoofing, logging)
post-fs-data.sh           early boot logic (flags -> props, marker files)
uninstall.sh              Restores backed-up props and removes module state
verify.sh                 Install-time integrity check of packed files (reads the "hash" manifest)
system.prop               Static props applied by the module manager
META-INF/                 Flashable zip metadata (update-binary)

service.d/                Copied to /data/adb/service.d at install time:
  .box_cleanup.sh           Removes leftovers when another module replaces this one (see INVARIANTS)
  prop.sh, hash.sh, lineage.sh   Standalone boot-phase prop patchers

webroot/                  WebUI (KernelSU WebUI bridge), served from the module directory
  index.html, script.js, style.css   Dashboard + shared shell bridge / theme
  common_scripts/           Shell helpers invoked by WebUI buttons and boot logic
    UI/                       Alternative "modern" skin (swapped in/out by customize.sh)
  <Page>/index.html         One directory per dashboard page
  TRANSLATIONS/             i18n packs (git submodule, upstream repo)

toolkit/                  Runtime profiles & config (pif props, HMA config, modulehash)
build.sh                  Local release builder (assembles the zip, regenerates integrity manifests)
tests/check.sh            Static checks - run locally, used by CI
.github/workflows/        ci.yml (checks) + release.yml (tag-driven builds/releases)
assets/                   README screenshots (not shipped in the module zip)
PlayIntegrityFork/        PIF sources (git submodule; prebuilt binaries come from a donor zip)
```

## Runtime flows

### Install (`customize.sh`, once per flash)
1. `check_integrity` - validates packed files against the `hash` manifest via `verify.sh`.
2. `prepare_directories` / `handle_module_props` - creates `/data/adb/modules/playintegrityfix`, stages `module.prop`.
3. `detect_rom` - writes detection results to `/data/adb/Box-Brain/Integrity-Box-Logs/DeviceType.log` and sets flags (`disablegms`, `disablevending`, `skip`, `safemode`).
4. `cleanup` -> `check_boot_hash` -> `enable_recommended_settings` - housekeeping and first-run flags.
5. Fingerprint profile: `toolkit/legacy.prop` (SDK <= 31) or `toolkit/pixelify.prop`.
6. Copies `service.d/*` into `/data/adb/service.d` (installed scripts, not module files).
7. Zygiskless mode extras when `/sdcard/zygisk` existed before flashing.
8. Optional "modern" skin swap: when `Box-Brain/modern` exists, `webroot/common_scripts/UI/*` replaces the root WebUI files (originals kept as `*.bak`).

### Boot
- `post-fs-data.sh` - creates marker files, turns flags into persistent props, fixes permissions.
- `service.sh` - late boot: build / bootloader / warranty props via `resetprop`, structured logs.
- `/data/adb/service.d/{prop,hash,lineage}.sh` - standalone; source the module's `common_func.sh` when present and exit cleanly when the module is gone.

State locations:
- `/data/adb/Box-Brain/` - feature flags (consumed at boot / by actions) + `Integrity-Box-Logs/`.
- `/data/adb/modules/playintegrityfix/` - module payload.
- `/data/adb/tricky_store/` - target list, security patch, keybox.

### Action button (`action.sh`)
Handles OTA fingerprint updates (`key.sh`), per-app spoofing migration, patch-date spoofing, JSON export (`/sdcard/meow.json` - kept for PIF interop), and cleanup switches. Flags it consumes live in `/data/adb/Box-Brain/`.

## WebUI architecture

- `webroot/index.html` is the dashboard; every page lives in its own `webroot/<Page>/index.html` directory.
- `webroot/script.js` installs the root bridge (`ksu.exec` wrappers, toasts, iframe navigation) and contains the `pathMap` (page type -> page file). Adding a page = new directory + `pathMap` entry + a button in `index.html`; `tests/check.sh` verifies every `pathMap` target exists.
- `webroot/common_scripts/*.sh` are invoked by buttons and boot logic; they log to `Box-Brain/Integrity-Box-Logs/`. Keep them standalone-runnable (`sh script.sh`).
- i18n: pages load `TRANSLATIONS/meow.js`, which builds `window.i18nDict` from per-language packs keyed by normalized English strings (English is the fallback). New UI strings keep working untranslated until the packs (upstream submodule) catch up.
- Two skins: the default root files and the "modern" variant under `common_scripts/UI/`. When you change shared UI, update both.

## Remote dependencies (runtime, by design)

| What | Where it comes from |
| --- | --- |
| Keybox download (`key.sh`) | `raw.githubusercontent.com/MeowDump/MeowDump/.../Megatron` |
| Keybox status (Status page, dashboards) | `raw.githubusercontent.com/MeowDump/Integrity-Box/.../keybox/key-status` |
| Auto-pilot data (`autopilot.sh`) | `raw.githubusercontent.com/MeowDump/Integrity-Box/main/auto-pilot` |
| Translation updater (`UpdateTranslation.sh`) | `MeowDump/TG2Git` releases |
| Downloader mirrors | Mixed upstream projects, some MeowDump-hosted |

To self-host later, point these URLs at your fork and maintain the files yourself - no local mirrors are kept in this repo.

## Building

`./build.sh <donor-release.zip> [output-name]`

- The donor zip provides prebuilt PIF binaries that are not tracked here: `classes.dex`, `zygisk/*.so`, `legacy/*`, `osm0sis.sh`, `migrate.sh`, `credits.md`, `META-INF/`. Use the upstream IntegrityBox release matching this fork's base (v43) or a PlayIntegrityFork release zip.
- Repo files always win over donor files. Donor-only legacy pages/assets are pruned explicitly (see `build.sh`).
- The script regenerates `toolkit/modulehash` (sha256 of the shipped `module.prop`) and the `hash` manifest (`relpath|sha256` per shipped file, excluding `META-INF/` and `hash` itself), verifies every entry, then writes `dist/StrongBox-<version>.zip`.
- Output is gitignored (`dist/`, `*.zip`).

## Versioning & release

Single source of truth: `module.prop` (`version`, `versionCode`). Three files must stay in sync - `build.sh` and `tests/check.sh` enforce it:

1. `module.prop` - bump `version` / `versionCode`.
2. `release.json` - same `version` / `versionCode`; `zipUrl` must point at tag `v<version>` with asset `StrongBox-<version>.zip`.
3. `changelog.md` - add the release notes at the top.

Release steps:

```bash
bash tests/check.sh                 # static checks
git tag v1.0.0 && git push --tags   # CI builds + publishes the GitHub release (release.yml)
```

Locally you can do the same with:

```bash
DONOR_ZIP=/path/to/donor.zip bash tests/check.sh   # checks + build + manifest verify
gh release create v1.0.0 dist/StrongBox-1.0.0.zip --title "StrongBox v1.0.0" --notes-file changelog.md
```

CI notes: `release.yml` downloads the donor from the `DONOR_ZIP_URL` repository variable, falling back to the upstream v43 release URL baked into the workflow. Set `DONOR_ZIP_URL` if upstream removes that release.

## Testing & conventions

- `bash tests/check.sh` - `sh -n` (bash-aware) for every script, shellcheck at warning severity (repo `.shellcheckrc`; note-level hints are informational), `node --check` for JS, JSON validation, WebUI page-map existence, identity consistency (support signature, modulehash, release.json, module id), de-brand and repo-hygiene guards. CI runs exactly this on pushes/PRs.
- Shell: Android runs module scripts with mksh. Use `local`, `${var//pat/rep}` and `\>` freely (documented in `.shellcheckrc`), but **no brace expansion** (`{1..9}` - mksh refuses), quote everything, prefer `case` over `[[ ]]` in new code, and keep `sh -n` + shellcheck clean.
- One logging helper per script; logs go under `/data/adb/Box-Brain/Integrity-Box-Logs/`.
- WebUI: 2-space indent in `webroot/`, keep sub-pages network-light, and remember the twin-skin rule above.
- Commits: short imperative summary; bullets for details.

## INVARIANTS - don't break these

1. **Module ID is load-bearing.** `id=playintegrityfix` is the drop-in slot that replaces PlayIntegrityFix / upstream IntegrityBox; ~50 on-device paths in scripts and WebUI depend on `/data/adb/modules/playintegrityfix`. `tests/check.sh` guards it.
2. **The support-line signature.** `service.d/.box_cleanup.sh` treats `module.prop`'s `support=` line as "is this module still installed?". If you change `support=`, you MUST change `REQUIRED_LINE` in the same commit, or the script will delete `/data/adb/service.d` leftovers and `Box-Brain` on boot. `tests/check.sh` guards it.
3. **`toolkit/modulehash`** must equal sha256 of `module.prop`; the build regenerates and verifies it.
4. **`PATCH_DATE`** in `common_func.sh` is the single source of truth for the security patch date - don't hardcode it elsewhere.
5. **`PlayIntegrityFork/` submodule** holds sources only; its prebuilt binaries arrive via the donor zip at build time.
6. Upstream force-pushes history. When syncing, port changes file-by-file instead of merging; treat upstream commits as a reference, not a base.

## License & attribution

GPL-3.0. Original work (c) MeowDump and contributors; fork changes (c) dacrab. Keep upstream attribution (README, `credits.md`, LICENSE) intact when contributing.
