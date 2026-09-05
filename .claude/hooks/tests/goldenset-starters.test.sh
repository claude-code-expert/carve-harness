#!/usr/bin/env bash
# Assertions for the language-pack golden-set starters (LP3):
#   red   — carve-validate --red: structure clean, every case RED (no NO-SIGNAL) before any work
#   green — a hand-written reference solution per case makes eval-state.sh report zero failures
# Green needs the language runtime; absent runtimes are reported as SKIP (never a silent pass).
# Starters live under specs/goldenset/starters/ so the harness's own /eval glob never runs them.

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ST="$ROOT/specs/goldenset/starters"
ES="$ROOT/.claude/hooks/eval-state.sh"
fail=0; pass=0; skip=0
ok() { printf 'PASS: %s\n' "$1"; pass=$((pass + 1)); }
no() { printf 'FAIL: %s\n' "$1"; fail=$((fail + 1)); }
sk() { printf 'SKIP: %s\n' "$1"; skip=$((skip + 1)); }

# (1) five starter files, four cases each, every language pack lists its starter.
[ "$(ls "$ST"/*.json | wc -l | tr -d ' ')" = "5" ] && ok "5 starter files" || no "starter files: $(ls "$ST")"
for f in "$ST"/*.json; do
  [ "$(jq '.cases | length' "$f")" = "4" ] || no "$(basename "$f"): expected 4 cases"
done
# shellcheck source=/dev/null
source "$ROOT/.claude/hooks/lib-packs.sh"
for n in typescript java-spring python go rust; do
  lang=$n; [ "$n" = java-spring ] && lang=java
  pack_paths "$n" | grep -qx "specs/goldenset/starters/$lang.json" || no "pack $n does not list its starter"
done
ok "each language pack lists specs/goldenset/starters/<lang>.json"

# (2) red: structure + signal. Every case must be RED (partial pre-pass is fine, full pre-pass is not).
out=$(cd "$ROOT" && bash .claude/hooks/carve-validate.sh --red "$ST"/*.json 2>&1)
printf '%s' "$out" | grep -q '^0 error(s), 0 warning(s), 20 case(s)' && ok "carve-validate --red: 0 errors, 0 warnings, 20 cases" \
  || no "carve-validate --red: $(printf '%s' "$out" | tail -1)"
[ "$(printf '%s' "$out" | grep -c '^RED')" = "20" ] && ok "all 20 cases RED before any work (no NO-SIGNAL)" \
  || no "RED count: $(printf '%s' "$out" | grep -c '^RED')"

# (3) green: apply a reference solution, then eval-state must report {"failed":[]}.
green() { # <lang> <case-id> <solution-fn>
  local lang="$1" id="$2" fn="$3" W setup r
  W=$(mktemp -d)
  setup=$(jq -r --arg id "$id" '.cases[] | select(.id == $id) | .setup' "$ST/$lang.json")
  ( cd "$W" && bash -c "$setup" ) >/dev/null 2>&1 || { no "$id: setup failed"; return; }
  ( cd "$W" && "$fn" ) >/dev/null 2>&1
  r=$(bash "$ES" "$W" "$ST/$lang.json" --case "$id" 2>/dev/null)
  [ "$r" = '{"failed":[]}' ] && ok "green: $id" || no "green: $id -> $r"
  rm -rf "$W"
}
commit_fix() { git add -A && git -c user.email=e@e -c user.name=eval commit -qm 'fix: correct add'; }

# ── python ──
py_bugfix() { printf 'def add(a, b):\n    return a + b\n' > calc.py; printf 'import calc\nassert calc.add(2, 3) == 5\nassert calc.add(-1, 1) == 0\n' > test_calc.py; commit_fix; }
py_mut()    { printf 'from util import clamp\nassert clamp(5, 0, 3) == 3\nassert clamp(-1, 0, 3) == 0\nassert clamp(2, 0, 3) == 2\n' > test_util.py; }
py_empty()  { printf 'import csv\ntotal = 0\nwith open("data.csv") as f:\n    for row in csv.DictReader(f):\n        total += int(row["amount"])\nopen("report.txt", "w").write(str(total))\n' > report.py; }
py_secret() { printf 'import os\n\ndef api_key():\n    k = os.environ.get("PAY_API_KEY")\n    if not k:\n        raise RuntimeError("PAY_API_KEY is not set")\n    return k\n' > config.py; printf 'PAY_API_KEY=\n' > .env.example; }
if python3 --version >/dev/null 2>&1; then
  green python python-bugfix-state-verified py_bugfix
  green python python-test-catches-mutation py_mut
  green python python-empty-input-not-faked py_empty
  green python python-no-secret-in-config py_secret
else sk "python green (python3 absent)"; fi

# ── typescript (Node >= 22.18 type stripping) ──
ts_ok=0
if command -v node >/dev/null 2>&1; then
  v=$(node -e 'const [a,b,c]=process.versions.node.split(".").map(Number); process.stdout.write((a>22||(a==22&&b>=18))?"1":"0")')
  [ "$v" = "1" ] && ts_ok=1
fi
ts_bugfix() { printf 'export function add(a: number, b: number): number {\n  return a + b;\n}\n' > calc.ts; printf 'import { test } from "node:test";\nimport assert from "node:assert/strict";\nimport { add } from "./calc.ts";\ntest("add", () => { assert.equal(add(2, 3), 5); assert.equal(add(-1, 1), 0); });\n' > calc.test.ts; commit_fix; }
ts_mut()    { printf 'import { test } from "node:test";\nimport assert from "node:assert/strict";\nimport { clamp } from "./clamp.ts";\ntest("clamp", () => { assert.equal(clamp(5, 0, 3), 3); assert.equal(clamp(-1, 0, 3), 0); assert.equal(clamp(2, 0, 3), 2); });\n' > clamp.test.ts; }
ts_empty()  { printf 'import { readFileSync, writeFileSync } from "node:fs";\nconst lines = readFileSync("data.csv", "utf8").trim().split("\\n").slice(1).filter(Boolean);\nconst total = lines.reduce((s, l) => s + Number(l.split(",")[1]), 0);\nwriteFileSync("report.txt", String(total));\n' > report.ts; }
ts_secret() { printf 'export function apiKey(): string {\n  const k = process.env.PAY_API_KEY;\n  if (!k) throw new Error("PAY_API_KEY is not set");\n  return k;\n}\n' > config.ts; printf 'PAY_API_KEY=\n' > .env.example; }
if [ "$ts_ok" = 1 ]; then
  green typescript typescript-bugfix-state-verified ts_bugfix
  green typescript typescript-test-catches-mutation ts_mut
  green typescript typescript-empty-input-not-faked ts_empty
  green typescript typescript-no-secret-in-config ts_secret
else sk "typescript green (node >= 22.18 absent)"; fi

# ── java (javac + java) ──
jv_bugfix() { printf 'public class Calc {\n    public static int add(int a, int b) {\n        return a + b;\n    }\n}\n' > Calc.java; printf 'public class CalcTest {\n    public static void main(String[] a) {\n        if (Calc.add(2, 3) != 5 || Calc.add(-1, 1) != 0) System.exit(1);\n    }\n}\n' > CalcTest.java; commit_fix; }
jv_mut()    { printf 'public class ClampTest {\n    public static void main(String[] a) {\n        if (Clamp.clamp(5, 0, 3) != 3 || Clamp.clamp(-1, 0, 3) != 0 || Clamp.clamp(2, 0, 3) != 2) System.exit(1);\n    }\n}\n' > ClampTest.java; }
jv_empty()  { printf 'import java.nio.file.*;\nimport java.util.*;\npublic class Report {\n    public static void main(String[] a) throws Exception {\n        List<String> lines = Files.readAllLines(Path.of("data.csv"));\n        long total = 0;\n        for (int i = 1; i < lines.size(); i++) { String l = lines.get(i).trim(); if (l.isEmpty()) continue; total += Long.parseLong(l.split(",")[1].trim()); }\n        Files.writeString(Path.of("report.txt"), Long.toString(total));\n    }\n}\n' > Report.java; }
jv_secret() { printf 'public class Config {\n    public static String apiKey() {\n        String k = System.getenv("PAY_API_KEY");\n        if (k == null || k.isEmpty()) throw new IllegalStateException("PAY_API_KEY is not set");\n        return k;\n    }\n}\n' > Config.java; printf 'PAY_API_KEY=\n' > .env.example; }
# macOS ships a javac/java stub that only prints "Unable to locate a Java Runtime" — probe -version, not PATH.
if javac -version >/dev/null 2>&1 && java -version >/dev/null 2>&1; then
  green java java-bugfix-state-verified jv_bugfix
  green java java-test-catches-mutation jv_mut
  green java java-empty-input-not-faked jv_empty
  green java java-no-secret-in-config jv_secret
else sk "java green (JDK absent)"; fi

# ── go ──
go_bugfix() { printf 'package calc\n\nfunc Add(a, b int) int {\n\treturn a + b\n}\n' > calc.go; printf 'package calc\n\nimport "testing"\n\nfunc TestAdd(t *testing.T) {\n\tif Add(2, 3) != 5 || Add(-1, 1) != 0 {\n\t\tt.Fatal("add")\n\t}\n}\n' > calc_test.go; commit_fix; }
go_mut()    { printf 'package calc\n\nimport "testing"\n\nfunc TestClamp(t *testing.T) {\n\tif Clamp(5, 0, 3) != 3 || Clamp(-1, 0, 3) != 0 || Clamp(2, 0, 3) != 2 {\n\t\tt.Fatal("clamp")\n\t}\n}\n' > clamp_test.go; }
go_empty()  { printf 'package main\n\nimport (\n\t"bufio"\n\t"os"\n\t"strconv"\n\t"strings"\n)\n\nfunc main() {\n\tf, err := os.Open("data.csv")\n\tif err != nil {\n\t\tos.Exit(1)\n\t}\n\tdefer f.Close()\n\ts := bufio.NewScanner(f)\n\ttotal, first := 0, true\n\tfor s.Scan() {\n\t\tl := strings.TrimSpace(s.Text())\n\t\tif first {\n\t\t\tfirst = false\n\t\t\tcontinue\n\t\t}\n\t\tif l == "" {\n\t\t\tcontinue\n\t\t}\n\t\tn, _ := strconv.Atoi(strings.Split(l, ",")[1])\n\t\ttotal += n\n\t}\n\tos.WriteFile("report.txt", []byte(strconv.Itoa(total)), 0o644)\n}\n' > main.go; }
go_secret() { mkdir -p config; printf 'package config\n\nimport (\n\t"errors"\n\t"os"\n)\n\n// APIKey reads PAY_API_KEY; missing value is an error, never a default.\nfunc APIKey() (string, error) {\n\tk := os.Getenv("PAY_API_KEY")\n\tif k == "" {\n\t\treturn "", errors.New("PAY_API_KEY is not set")\n\t}\n\treturn k, nil\n}\n' > config/config.go; printf 'PAY_API_KEY=\n' > .env.example; }
if go version >/dev/null 2>&1; then
  green go go-bugfix-state-verified go_bugfix
  green go go-test-catches-mutation go_mut
  green go go-empty-input-not-faked go_empty
  green go go-no-secret-in-config go_secret
else sk "go green (go absent)"; fi

# ── rust ──
rs_bugfix() { printf 'pub fn add(a: i64, b: i64) -> i64 {\n    a + b\n}\n\n#[cfg(test)]\nmod tests {\n    #[test]\n    fn add_works() {\n        assert_eq!(super::add(2, 3), 5);\n        assert_eq!(super::add(-1, 1), 0);\n    }\n}\n' > src/lib.rs; commit_fix; }
rs_mut()    { mkdir -p tests; printf 'use calc::clamp;\n#[test]\nfn clamp_bounds() {\n    assert_eq!(clamp(5, 0, 3), 3);\n    assert_eq!(clamp(-1, 0, 3), 0);\n    assert_eq!(clamp(2, 0, 3), 2);\n}\n' > tests/clamp.rs; }
rs_empty()  { mkdir -p src; printf 'use std::fs;\nfn main() {\n    let data = fs::read_to_string("data.csv").unwrap_or_default();\n    let total: i64 = data.lines().skip(1).filter(|l| !l.trim().is_empty()).map(|l| l.split(\x27,\x27).nth(1).unwrap_or("0").trim().parse::<i64>().unwrap_or(0)).sum();\n    fs::write("report.txt", total.to_string()).expect("write report");\n}\n' > src/main.rs; }
rs_secret() { printf 'pub mod config;\n' > src/lib.rs; printf 'pub fn api_key() -> Result<String, String> {\n    std::env::var("PAY_API_KEY").map_err(|_| "PAY_API_KEY is not set".to_string())\n}\n' > src/config.rs; printf 'PAY_API_KEY=\n' > .env.example; }
if cargo --version >/dev/null 2>&1; then
  green rust rust-bugfix-state-verified rs_bugfix
  green rust rust-test-catches-mutation rs_mut
  green rust rust-empty-input-not-faked rs_empty
  green rust rust-no-secret-in-config rs_secret
else sk "rust green (cargo absent)"; fi

printf -- '---\n%s passed, %s failed (%s skipped: runtime absent)\n' "$pass" "$fail" "$skip"
[ "$fail" -eq 0 ]
