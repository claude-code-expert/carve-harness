#!/usr/bin/env python3
"""채점기를 채점하는 테스트.

발표자료 87p - 점수가 이상할 때 의심 순서는 ① 채점기 ② 문항 ③ 에이전트다.
에이전트를 맨 마지막에 의심하는 이유는 점수 하락의 상당수가 채점기 버그이기 때문이다.
그러니 채점기에도 테스트가 있어야 한다. 이 파일이 그 테스트다.

의존성 없이 실행:  python3 test_scorecard.py
"""

import sys

from rubric_judge import TestRun, judge, loop_status
from scorecard import Measurement, from_coverage, from_exit_code, score

FAILS: list[str] = []


def check(cond: bool, label: str, detail: str = "") -> None:
    if cond:
        print(f"  PASS  {label}")
    else:
        FAILS.append(label)
        print(f"  FAIL  {label}" + (f"\n        {detail}" if detail else ""))


def section(title: str) -> None:
    print(f"\n[{title}]")


# ══════════════════════════════════════════════════════════════════════════
section("채점표 - 거부권")

ok = {
    "g1_build": Measurement(1.0), "g2_test": Measurement(1.0), "g3_safety": Measurement(1.0),
    "lint": Measurement(1.0), "regression": Measurement(1.0),
    "coverage": Measurement(1.0), "antislop": Measurement(1.0),
}
card = score("python", ok)
check(card.total == 100 and card.verdict == "PASS", "전 항목 만점이면 100점 PASS", card.as_dict())

# 총점이 합격선을 넘어도 거부권 항목이 0이면 실패여야 한다. 이 한 줄이 채점표의 핵심이다.
vetoed = dict(ok, g3_safety=Measurement(0.0))
card = score("python", vetoed)
check(card.total == 85 and card.verdict == "FAIL",
      "G3 안전 0점이면 총점 85여도 FAIL (거부권)", card.as_dict())

# 거부권이 아닌 항목이 0이면 총점 비율로만 판단한다.
lint_zero = dict(ok, lint=Measurement(0.0))
card = score("python", lint_zero)
check(card.total == 90 and card.verdict == "PASS",
      "lint 0점은 거부권 아님 - 90/100 이면 PASS", card.as_dict())

section("채점표 - 못 잰 항목은 분모에서 뺀다")

# 커버리지를 못 쟀다고 0점을 주면 억울한 감점이 된다. 분모에서 빼야 한다.
no_cov = dict(ok)
no_cov.pop("coverage")
card = score("python", no_cov)
check(card.max_score == 95 and "coverage" in card.skipped,
      "커버리지 미측정 시 분모 95로 축소되고 skipped 로 표시", card.as_dict())
check(card.verdict == "PASS", "축소된 분모 기준으로 합격 판정", card.as_dict())

# 아무것도 못 쟀는데 PASS 가 나오면 안 된다. 빈 채점표는 만점이 아니다.
card = score("python", {})
check(card.verdict == "unable" and card.total == 0,
      "잴 수 있는 항목이 없으면 unable (fail-closed)", card.as_dict())

section("채점표 - 측정 어댑터")

check(from_exit_code(0, "npm test").value == 1.0, "exit 0 이면 만점")
check(from_exit_code(1, "npm test").value == 0.0, "exit 1 이면 0점")
check(from_exit_code(None, "cargo test").value is None,
      "툴체인 없어 실행 못 하면 None - 0점이 아니라 skipped 로 간다")
check(from_coverage(None).value is None, "커버리지 리포트 없으면 skipped")
check(from_coverage(0.85, 0.8).value == 1.0, "커버리지 85% >= 기준 80% 이면 만점")

# ══════════════════════════════════════════════════════════════════════════
section("루브릭 - test 축은 실행 출력으로만 채운다")

# 테스트를 돌리지 않고 나머지를 만점 받아도 임계를 넘을 수 없어야 한다.
never_ran = judge("x", exists=1, match=1, contract=1, no_regress=1, tests=TestRun(ran=False))
check(never_ran.score == 75 and not never_ran.passed,
      "테스트 미실행이면 나머지 만점이어도 75점 - 거짓 완료 차단", never_ran.as_dict())
check(any("미실행" in g for g in never_ran.gaps), "미실행 사유가 gap 에 남는다")

all_green = judge("x", exists=1, match=1, contract=1, no_regress=1,
                  tests=TestRun(ran=True, passed=4, failed=0))
check(all_green.score == 100 and all_green.passed, "전 축 충족이면 100점 통과")

partial = judge("x", exists=1, match=1, contract=1, no_regress=1,
                tests=TestRun(ran=True, passed=3, failed=1))
check(partial.score == 94 and not partial.passed,
      "테스트 3/4 통과면 94점 - 94도 미달은 미달이다", partial.as_dict())

section("루브릭 - 도메인 안전 항목은 만점 아니면 차단")

near = judge("safety", exists=1, match=1, contract=1, no_regress=1,
             tests=TestRun(ran=True, passed=9, failed=1), task_type="domain_safety")
check(not near.passed and near.blocked_by is not None,
      "domain_safety 는 97점이어도 차단 (허용 실패율 0%)", near.as_dict())

# ══════════════════════════════════════════════════════════════════════════
section("워크스루 재현 - 발표자료 74~75p 쿠폰 API")

def task(tid, exists, match, contract, no_regress, passed, failed):
    """다섯 축 입력을 받아 채점한다. 덱의 점수를 재현하도록 각 축을 조정한 값이다."""
    return judge(tid, exists=exists, match=match, contract=contract, no_regress=no_regress,
                 tests=TestRun(ran=True, passed=passed, failed=failed))

# 1회차 - 중복 사용 방지는 테스트가 아예 없어 test 축 0점(70), 만료는 경계 케이스가
# acceptance 를 못 채워 match 축이 깎인다(92).
round1 = [
    task("coupon-applies",        1.00, 1.00, 1.00, 1.00, 7, 1),   # 97
    task("coupon-no-reuse",       1.00, 0.80, 1.00, 1.00, 0, 3),   # 70
    task("coupon-expiry",         1.00, 0.68, 1.00, 1.00, 8, 0),   # 92
    task("coupon-response-shape", 1.00, 1.00, 1.00, 1.00, 5, 0),   # 100
]
got1 = {v.task_id: v.score for v in round1}
print("        1회차:", got1)
check(got1 == {"coupon-applies": 97, "coupon-no-reuse": 70,
               "coupon-expiry": 92, "coupon-response-shape": 100},
      "1회차 점수가 발표자료 74p 표와 일치 (97/70/92/100)", got1)

s1 = loop_status(round1)
check(s1["gate"] == "BLOCKED", "1회차 - 미달 항목이 있어 게이트 차단", s1)
check(set(s1["rework"]) == {"coupon-no-reuse", "coupon-expiry"},
      "미달 2개만 재작업 대상 - 통과한 항목은 건드리지 않는다", s1)

# 2회차 - 지적된 두 항목에만 테스트·검증을 보강했다. 나머지는 손대지 않는다.
round2 = [
    round1[0],                                                     # 97 유지
    task("coupon-no-reuse",       1.00, 0.84, 1.00, 1.00, 6, 0),   # 96
    task("coupon-expiry",         1.00, 0.88, 1.00, 1.00, 8, 0),   # 97
    round1[3],                                                     # 100 유지
]
got2 = {v.task_id: v.score for v in round2}
print("        2회차:", got2)
check(got2 == {"coupon-applies": 97, "coupon-no-reuse": 96,
               "coupon-expiry": 97, "coupon-response-shape": 100},
      "2회차 점수가 발표자료 75p 표와 일치 (97/96/97/100)", got2)

s2 = loop_status(round2)
check(s2["gate"] == "RELEASED" and not s2["rework"],
      "2회차 - 전 항목 합격, 게이트 해제", s2)
check(got1["coupon-applies"] == got2["coupon-applies"],
      "통과한 항목의 점수는 재작업 후에도 그대로", (got1, got2))

# ══════════════════════════════════════════════════════════════════════════
section("채점기 버그 재현 - 87p '채점기부터 의심'")

# 실화: 에이전트가 96.12 라고 정답을 냈는데 채점기가 표기 방식 차이로 0점을 줬다.
# 채점기를 고치자 통과율이 42% -> 95% 로 뛰었다. 에이전트는 처음부터 죄가 없었다.
def naive_match(expected: str, actual: str) -> bool:
    """나쁜 채점기 - 문자열이 같아야만 정답으로 본다."""
    return expected == actual

def numeric_match(expected: str, actual: str, tol: float = 1e-9) -> bool:
    """고친 채점기 - 숫자로 비교한다."""
    try:
        return abs(float(expected) - float(actual)) <= tol
    except ValueError:
        return expected.strip() == actual.strip()

answers = [("96.12", "96.120"), ("96.12", " 96.12"), ("96.12", "96.12"), ("100", "100.0")]
naive_ok = sum(naive_match(e, a) for e, a in answers)
fixed_ok = sum(numeric_match(e, a) for e, a in answers)
print(f"        같은 답, 나쁜 채점기 {naive_ok}/4  ->  고친 채점기 {fixed_ok}/4")
check(naive_ok == 1 and fixed_ok == 4,
      "답은 그대로인데 채점기만 고쳐도 통과율이 뛴다 - 에이전트를 먼저 의심하면 안 되는 이유")

section("극단 점수는 그 자체가 경보 - 87p")

def alarm(scores: list[int]) -> str:
    if scores and all(s == 0 for s in scores):
        return "채점 환경이 깨졌을 가능성 - 문항이 아니라 실행부터 확인"
    if scores and all(s == 100 for s in scores):
        return "문항이 너무 쉬워졌을 가능성 - 난이도 갱신 필요"
    return "정상 범위"

check(alarm([0, 0, 0]).startswith("채점 환경"), "전원 0% 는 채점 환경 경보")
check(alarm([100, 100]).startswith("문항이"), "전원 100% 는 난이도 경보")
check(alarm([97, 70, 92]) == "정상 범위", "섞인 점수는 정상")

# ══════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 62)
if FAILS:
    print(f"FAILED {len(FAILS)}건")
    for f in FAILS:
        print(f"  - {f}")
    sys.exit(1)
print("전 항목 통과")
