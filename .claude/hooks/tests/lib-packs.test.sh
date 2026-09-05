#!/usr/bin/env bash
# Assertions for lib-packs.sh — the language-pack manifest reader (LP0).
# Pins: pack enumeration, header parsing, install-path parsing, every listed path
# exists in the source tree, and stack detection on fixture directories
# (root + one level down, marker files and ORM dependency grep).

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
LIB="$ROOT/.claude/hooks/lib-packs.sh"
fail=0; pass=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }

# shellcheck source=/dev/null
source "$LIB" || { no "lib-packs.sh sources"; printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"; exit 1; }
ok "lib-packs.sh sources cleanly"
bash -n "$LIB" 2>/dev/null && ok "bash -n lib-packs.sh" || no "bash -n lib-packs.sh"

# (1) enumeration — the six packs the plan defines, sorted (glob order).
want=$'database\ngo\njava-spring\npython\nrust\ntypescript'
[ "$(pack_list)" = "$want" ] && ok "pack_list -> 6 packs" || no "pack_list: $(pack_list | tr '\n' ' ')"

# (2) header parsing.
[ "$(pack_meta typescript lsp)" = "vtsls@claude-code-lsps" ] && ok "pack_meta lsp" || no "pack_meta lsp: $(pack_meta typescript lsp)"
[ "$(pack_meta java-spring detect)" = "gradlew build.gradle build.gradle.kts pom.xml" ] && ok "pack_meta detect (multi-marker)" || no "pack_meta detect"
[ -z "$(pack_meta database detect)" ] && ok "empty header value -> ''" || no "empty header value"
pack_meta nope lsp >/dev/null 2>&1 && no "pack_meta unknown pack should rc 1" || ok "pack_meta unknown pack -> rc 1"

# (3) install paths: headers and comments excluded, paths kept in order.
p=$(pack_paths typescript | head -1)
[ "$p" = ".claude/rules/react-next" ] && ok "pack_paths first path" || no "pack_paths first: $p"
pack_paths typescript | grep -Eq '^(name|lsp|detect):' && no "pack_paths leaks headers" || ok "pack_paths excludes headers"
[ -z "$(pack_paths go)" ] && ok "pack with no paths -> empty, rc 0" || no "empty pack paths"

# (4) every listed path exists in the source tree — a dangling path would be a
#     silent SKIP at install and an orphan in the manifest.
missing=""
for n in $(pack_list); do
  m=$(pack_check "$n" "$ROOT") || missing="$missing $n:$(printf '%s' "$m" | tr '\n' ',')"
done
[ -z "$missing" ] && ok "all pack paths exist in source" || no "dangling pack paths:$missing"

# (5) detection fixtures.
F=$(mktemp -d)
[ -z "$(pack_detect "$F")" ] && ok "empty dir -> no pack" || no "empty dir detected: $(pack_detect "$F")"

mkdir -p "$F/ts" && : > "$F/ts/package.json" && : > "$F/ts/tsconfig.json"
[ "$(pack_detect "$F/ts")" = "typescript" ] && ok "package.json+tsconfig -> typescript" || no "ts detect: $(pack_detect "$F/ts")"

mkdir -p "$F/java/backend" && : > "$F/java/backend/gradlew"
[ "$(pack_detect "$F/java")" = "java-spring" ] && ok "backend/gradlew (one level down) -> java-spring" || no "java nested detect: $(pack_detect "$F/java")"

mkdir -p "$F/py" && : > "$F/py/requirements.txt"
[ "$(pack_detect "$F/py")" = "python" ] && ok "requirements.txt -> python" || no "py detect"

mkdir -p "$F/go" && : > "$F/go/go.mod"
[ "$(pack_detect "$F/go")" = "go" ] && ok "go.mod -> go" || no "go detect"

mkdir -p "$F/rs" && : > "$F/rs/Cargo.toml"
[ "$(pack_detect "$F/rs")" = "rust" ] && ok "Cargo.toml -> rust" || no "rust detect"

# ORM dependency in a manifest -> companion `database` pack, alongside the language pack.
mkdir -p "$F/orm" && printf '{"dependencies":{"@prisma/client":"5"}}\n' > "$F/orm/package.json"
[ "$(pack_detect "$F/orm" | tr '\n' ' ')" = "database typescript " ] \
  && ok "prisma in package.json -> database + typescript" || no "orm detect: $(pack_detect "$F/orm" | tr '\n' ' ')"

# Polyglot monorepo: every matching pack, once each.
mkdir -p "$F/poly/api" "$F/poly/web" && : > "$F/poly/api/pyproject.toml" && : > "$F/poly/web/package.json"
[ "$(pack_detect "$F/poly" | tr '\n' ' ')" = "python typescript " ] \
  && ok "monorepo -> python + typescript" || no "monorepo detect: $(pack_detect "$F/poly" | tr '\n' ' ')"

# (6) PACKS_DIR override — tests and install.sh point it at another root.
mkdir -p "$F/alt" && printf 'name: x\ndetect: marker.x\nfoo/bar\n' > "$F/alt/x.pack"
[ "$(PACKS_DIR="$F/alt" bash -c "source '$LIB'; pack_list")" = "x" ] \
  && ok "PACKS_DIR override" || no "PACKS_DIR override"

rm -rf "$F"
printf -- '---\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
