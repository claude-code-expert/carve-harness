#!/usr/bin/env bash
# bench/test-trigger.sh — 트리거 정확도 결정적 하니스 (축 3, M11-A2).
# squad-router.sh에 routing.tsv(정상 라우팅)·no-route.txt(오발화) 시드를 전수 입력해
# 라우팅 정확도와 오발화율을 카운트한다. 결정론(키워드 매칭) — LLM 불필요.
# (자연어→스킬 description 발화 등 비결정 트리거는 라이브 측정 = Phase B.)
# jq 없으면 graceful skip(run.mjs 관례와 동일).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROUTER="$ROOT/assets/squad/hooks/squad-router.sh"
SEEDS="$ROOT/bench/seeds"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq 없음 — 라우터 트리거 측정 생략(graceful skip)."
  exit 0
fi

# 프롬프트 → 라우팅된 에이전트명(squad-xxx) 또는 빈 문자열.
fire() {
  jq -n --arg p "$1" '{prompt:$p}' | bash "$ROUTER" 2>/dev/null | grep -oE 'squad-[a-z]+' | head -n1
}

correct=0; total=0
while IFS=$'\t' read -r prompt expected; do
  [ -z "${prompt:-}" ] && continue
  got="$(fire "$prompt")"
  total=$((total + 1))
  if [ "$got" = "$expected" ]; then
    correct=$((correct + 1))
  else
    echo "  MISS: '${prompt}' → '${got:-<none>}' (기대 '${expected}')"
  fi
done < "$SEEDS/routing.tsv"

falsefire=0; ntotal=0
while IFS= read -r prompt; do
  [ -z "${prompt:-}" ] && continue
  got="$(fire "$prompt")"
  ntotal=$((ntotal + 1))
  if [ -n "$got" ]; then
    falsefire=$((falsefire + 1))
    echo "  FALSE-FIRE: '${prompt}' → '${got}'"
  fi
done < "$SEEDS/no-route.txt"

racc=0; [ "$total" -gt 0 ] && racc=$(( correct * 100 / total ))
ffr=0; [ "$ntotal" -gt 0 ] && ffr=$(( falsefire * 100 / ntotal ))
echo "라우팅 정확도: ${correct}/${total} = ${racc}%"
echo "오발화율: ${falsefire}/${ntotal} = ${ffr}%"
