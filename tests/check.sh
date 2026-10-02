#!/usr/bin/env bash
# StrongBox — static checks (local + CI).
#
# Usage:
#   bash tests/check.sh                                # static checks only
#   DONOR_ZIP=/path/to/donor.zip bash tests/check.sh   # also run a full build + manifest verify
#
# Exits non-zero when any check fails.

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

FAIL=0
pass()  { printf '  ok    %s\n' "$1"; }
fail()  { printf '  FAIL  %s\n' "$1"; FAIL=1; }
head2() { printf '\n== %s\n' "$1"; }

list_files() {
    find . \
        \( -path './.git' -o -path './dist' -o -path './PlayIntegrityFork' -o -path './webroot/TRANSLATIONS' \) -prune \
        -o -name "$1" -type f -print | sort
}

mapfile -t SH_FILES   < <(list_files '*.sh')
mapfile -t JS_FILES   < <(list_files '*.js')
mapfile -t JSON_FILES < <(list_files '*.json')
mapfile -t HTML_FILES < <(list_files 'index.html')

head2 "shell syntax (sh -n / bash -n)"
for f in "${SH_FILES[@]}"; do
    if head -n1 "$f" | grep -q 'bash'; then
        if bash -n "$f" 2>/tmp/sb_syn.err; then
            pass "$f"
        else
            fail "$f — $(head -n1 /tmp/sb_syn.err)"
        fi
    elif sh -n "$f" 2>/tmp/sb_syn.err; then
        pass "$f"
    else
        fail "$f — $(head -n1 /tmp/sb_syn.err)"
    fi
done

head2 "shellcheck (warnings+)"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -f gcc "${SH_FILES[@]}" >/tmp/sb_sc_all.out 2>&1 || true
    grep -v ': note:' /tmp/sb_sc_all.out > /tmp/sb_sc.out 2>/dev/null || true
    if [ -s /tmp/sb_sc.out ]; then
        fail "shellcheck findings (error/warning):"
        sed 's/^/        /' /tmp/sb_sc.out
    else
        pass "shellcheck clean at warning severity (${#SH_FILES[@]} scripts)"
    fi
    printf '  info  %s note-level hints (not gated)\n' "$(grep -c ': note:' /tmp/sb_sc_all.out 2>/dev/null || echo 0)"
else
    printf '  skip  shellcheck not installed\n'
fi

head2 "javascript syntax (node --check)"
if command -v node >/dev/null 2>&1; then
    for f in "${JS_FILES[@]}"; do
        if node --check "$f" >/dev/null 2>&1; then
            pass "$f"
        else
            fail "$f"
        fi
    done
else
    printf '  skip  node not installed\n'
fi

head2 "json validity"
if command -v python3 >/dev/null 2>&1; then
    for f in "${JSON_FILES[@]}"; do
        if python3 -m json.tool "$f" >/dev/null 2>&1; then
            pass "$f"
        else
            fail "$f"
        fi
    done
else
    printf '  skip  python3 not installed\n'
fi

head2 "webui pages"
for f in "${HTML_FILES[@]}"; do
    if grep -q '</html>' "$f"; then
        pass "$f"
    else
        fail "$f (missing </html>)"
    fi
done
for pm in webroot/script.js webroot/common_scripts/UI/script.js; do
    [ -f "$pm" ] || continue
    for page in $(grep -oE '\./[A-Za-z]+/index\.html' "$pm" | sort -u); do
        if [ -f "webroot/${page#./}" ]; then
            pass "$pm -> $page"
        else
            fail "$pm -> $page (missing page file)"
        fi
    done
done

head2 "identity consistency"
BC_REQ="$(sed -n 's/^REQUIRED_LINE="\(.*\)"$/\1/p' service.d/.box_cleanup.sh)"
if [ -n "$BC_REQ" ] && grep -Fq "$BC_REQ" module.prop; then
    pass "module.prop contains the .box_cleanup.sh signature line"
else
    fail "module.prop does not contain the .box_cleanup.sh signature '$BC_REQ' — boot cleanup would misfire!"
fi

MPH="$(sha256sum module.prop | cut -d' ' -f1)"
if [ "$MPH" = "$(cat toolkit/modulehash)" ]; then
    pass "toolkit/modulehash matches module.prop"
else
    fail "toolkit/modulehash is stale (expected $MPH)"
fi

VER="$(sed -n 's/^version=//p' module.prop)"
CODE="$(sed -n 's/^versionCode=//p' module.prop)"
RVER="$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' release.json)"
RCODE="$(sed -n 's/.*"versionCode": *\([0-9]*\).*/\1/p' release.json)"
RASSET="$(sed -n 's|.*/download/[^/]*/\([^/"]*\)".*|\1|p' release.json)"
[ "$RVER" = "$VER" ] && pass "release.json version ($VER)" || fail "release.json version '$RVER' != module.prop '$VER'"
[ "$RCODE" = "$CODE" ] && pass "release.json versionCode ($CODE)" || fail "release.json versionCode '$RCODE' != module.prop '$CODE'"
[ "$RASSET" = "StrongBox-$VER.zip" ] && pass "release.json asset ($RASSET)" || fail "release.json asset '$RASSET' != 'StrongBox-$VER.zip'"

grep -q '^id=playintegrityfix$' module.prop \
    && pass "module id is the intentional drop-in slot (playintegrityfix)" \
    || fail "module id changed — load-bearing (see DEVELOPING.md)"

for key in id name version versionCode author description; do
    grep -q "^$key=" module.prop && pass "module.prop has $key" || fail "module.prop missing $key"
done

head2 "de-brand guard (shipped files)"
if grep -rIl --exclude='*.md' --exclude-dir=.git --exclude-dir=dist --exclude-dir=assets \
        --exclude-dir=PlayIntegrityFork --exclude-dir=TRANSLATIONS --exclude-dir=tests \
        -e 't\.me/' . >/tmp/sb_brand.out 2>/dev/null; then
    fail "Telegram links found in shipped files:"
    sed 's/^/        /' /tmp/sb_brand.out
else
    pass "no t.me links in shipped files"
fi
if grep -rIl --exclude='*.md' --exclude='build.sh' --exclude-dir=.git --exclude-dir=dist \
        --exclude-dir=PlayIntegrityFork --exclude-dir=TRANSLATIONS --exclude-dir=tests \
        -e 'meowna\.ttf' -e 'font-family:[^;]*meowna' . >/tmp/sb_font.out 2>/dev/null; then
    fail "MeowDump font references found:"
    sed 's/^/        /' /tmp/sb_font.out
else
    pass "no MeowDump font references"
fi

head2 "repo hygiene"
if git ls-files | grep -qE '\.(zip|dex|so)$'; then
    fail "binary build artifacts are tracked:"
    git ls-files | grep -E '\.(zip|dex|so)$' | sed 's/^/        /'
else
    pass "no build artifacts tracked"
fi

if [ -n "${DONOR_ZIP:-}" ] && [ -f "${DONOR_ZIP:-}" ]; then
    head2 "full build + manifest verify (DONOR_ZIP set)"
    if bash build.sh "$DONOR_ZIP" >/tmp/sb_build.out 2>&1; then
        pass "build.sh: $(grep -E 'entries verified' /tmp/sb_build.out | head -n1 | sed 's/^ *//')"
    else
        fail "build failed:"
        sed 's/^/        /' /tmp/sb_build.out
    fi
else
    printf '\n== full build + manifest verify\n  skip  (set DONOR_ZIP=/path/to/donor.zip to enable)\n'
fi

printf '\n'
if [ "$FAIL" -eq 0 ]; then
    printf 'ALL CHECKS PASSED\n'
else
    printf 'CHECKS FAILED\n'
fi
exit "$FAIL"
