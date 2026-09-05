#!/usr/bin/env bash
# lib-packs.sh — language-pack manifest reader. Sourced; defines functions only,
# never executes anything on load (same contract as lib-protected.sh).
#
# A pack is packs/<name>.pack — plain text so install.sh can read it with bash
# alone (jq may not exist yet at install time):
#   # comment
#   key: value            header (name · label · summary · detect · detect_grep · lsp)
#   <path>                one install path per line — the unit install/manifest/prune use
#
#   pack_list             -> pack names, one per line
#   pack_meta NAME KEY    -> header value ('' if absent; rc 1 if pack missing)
#   pack_paths NAME       -> install paths, one per line (may be empty)
#   pack_check NAME [SRC] -> prints paths missing under SRC (default $PWD); rc 1 if any
#   pack_detect [DIR]     -> names of packs whose markers exist at DIR or DIR/*/
#                            (one level down covers backend/gradlew, frontend/package.json —
#                            the same convention stop-verify.sh uses)
#
# PACKS_DIR overrides the pack root (tests point it at fixtures; install.sh at $SRC/packs).

PACKS_DIR="${PACKS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." 2>/dev/null && pwd)/packs}"

# Dependency manifests that detect_grep scans — a pack like `database` has no
# marker file of its own, it is recognized by an ORM dependency in these.
PACK_MANIFESTS='package.json pyproject.toml requirements.txt build.gradle build.gradle.kts pom.xml go.mod Cargo.toml'

pack_file() { printf '%s/%s.pack' "$PACKS_DIR" "$1"; }

pack_list() {
  local f
  for f in "$PACKS_DIR"/*.pack; do
    [ -f "$f" ] || continue
    f="${f##*/}"; printf '%s\n' "${f%.pack}"
  done
  return 0
}

pack_meta() { # NAME KEY
  local f; f=$(pack_file "$1")
  [ -f "$f" ] || return 1
  sed -n "s/^$2:[[:space:]]*//p" "$f" | head -1
  return 0
}

# Header lines are `identifier:` — an install path never starts that way
# (it always carries a `/` or `.` before any colon).
pack_paths() { # NAME
  local f; f=$(pack_file "$1")
  [ -f "$f" ] || return 1
  grep -vE '^[[:space:]]*(#|$)' "$f" | grep -vE '^[a-z_]+:' || true
  return 0
}

pack_check() { # NAME [SRC]
  local src="${2:-$PWD}" p miss=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    [ -e "$src/$p" ] || { printf '%s\n' "$p"; miss=1; }
  done < <(pack_paths "$1")
  return "$miss"
}

pack_detect() { # [DIR]
  local dir="${1:-$PWD}" n m hit re mf f
  for n in $(pack_list); do
    hit=0
    for m in $(pack_meta "$n" detect); do
      # shellcheck disable=SC2086
      if [ -e "$dir/$m" ] || ls -d "$dir"/*/"$m" >/dev/null 2>&1; then hit=1; break; fi
    done
    re=$(pack_meta "$n" detect_grep)
    if [ "$hit" -eq 0 ] && [ -n "$re" ]; then
      for mf in $PACK_MANIFESTS; do
        for f in "$dir/$mf" "$dir"/*/"$mf"; do
          [ -f "$f" ] && grep -Eq "$re" "$f" && { hit=1; break 2; }
        done
      done
    fi
    [ "$hit" -eq 1 ] && printf '%s\n' "$n"
  done
  return 0
}
