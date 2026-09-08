"""빌드 건강도 채점표 - 발표자료 66~68p의 100점 만점 채점표를 그대로 구현한다.

이 모듈은 LLM을 호출하지 않는다. 빌드·테스트·린트를 실제로 돌린 결과(exit code,
커버리지 수치)를 받아 점수를 계산할 뿐이다. 결정론 층을 먼저 두껍게 깔라는 원칙이
코드 형태로 드러나는 자리다.

핵심 규칙 세 가지:
  1. G1(빌드)·G2(테스트)·G3(안전)은 거부권을 갖는다. 하나라도 0이면 총점과 무관하게 FAIL.
  2. 못 잰 항목은 skipped 로 표시하고 분모에서 뺀다. 조용한 통과를 만들지 않는다.
  3. 잴 수 있는 항목이 하나도 없으면 verdict 는 PASS 가 아니라 "unable" 이다(fail-closed).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

# 배점 - 발표자료 66p 표와 동일하다. 합 100.
WEIGHTS: dict[str, int] = {
    "g1_build": 25,
    "g2_test": 25,
    "g3_safety": 15,
    "lint": 10,
    "regression": 10,
    "coverage": 5,
    "antislop": 10,
}

# 거부권을 갖는 항목. 이 셋 중 하나라도 0점이면 총점이 아무리 높아도 실패다.
VETO_ITEMS = ("g1_build", "g2_test", "g3_safety")

PASS_RATIO = 0.9  # 90점 합격 - 분모가 줄면 비율로 판단한다.


@dataclass
class Measurement:
    """한 항목의 측정 결과.

    value 가 None 이면 "재지 못했다"는 뜻이고 skipped 로 분류된다.
    측정 실패를 0점으로 바꾸지 않는 것이 중요하다 - 0점은 "쟀는데 나빴다"이고,
    skipped 는 "재지 못했다"이며 둘은 다른 판단을 부른다.
    """

    value: Optional[float]  # 0.0 ~ 1.0 사이의 달성률, 못 쟀으면 None
    evidence: str = ""      # 무엇을 근거로 이 값이 나왔는가 (명령·출력)


@dataclass
class ScoreCard:
    stack: str
    items: dict[str, int] = field(default_factory=dict)
    skipped: list[str] = field(default_factory=list)
    evidence: dict[str, str] = field(default_factory=dict)
    total: int = 0
    max_score: int = 0
    verdict: str = "unable"

    def as_dict(self) -> dict:
        return {
            "stack": self.stack,
            "total": self.total,
            "max": self.max_score,
            "items": self.items,
            "skipped": self.skipped,
            "evidence": self.evidence,
            "verdict": self.verdict,
        }


def score(stack: str, measurements: dict[str, Measurement]) -> ScoreCard:
    """측정 결과를 채점표로 바꾼다.

    measurements 의 키는 WEIGHTS 의 키와 같다. 빠진 키는 skipped 로 처리한다.
    """
    card = ScoreCard(stack=stack)

    for key, weight in WEIGHTS.items():
        m = measurements.get(key)
        if m is None or m.value is None:
            # 재지 못한 항목 - 분모에서 뺀다. 0점으로 깎지 않는다.
            card.skipped.append(key)
            continue
        earned = round(weight * _clamp01(m.value))
        card.items[key] = earned
        card.max_score += weight
        if m.evidence:
            card.evidence[key] = m.evidence

    card.total = sum(card.items.values())

    # 잴 수 있는 항목이 없으면 통과시키지 않는다. 빈 채점표가 만점처럼 보이면 안 된다.
    if card.max_score == 0:
        card.verdict = "unable"
        return card

    vetoed = [k for k in VETO_ITEMS if card.items.get(k) == 0]
    if vetoed:
        card.verdict = "FAIL"
        card.evidence["veto"] = f"거부권 발동: {', '.join(vetoed)}"
    elif card.total / card.max_score >= PASS_RATIO:
        card.verdict = "PASS"
    else:
        card.verdict = "FAIL"

    return card


def _clamp01(v: float) -> float:
    return 0.0 if v < 0 else 1.0 if v > 1 else v


# ── 측정 어댑터 ────────────────────────────────────────────────────────────
# 실제 프로젝트에서는 아래를 각자 툴체인에 맞게 바꾼다. 반환 타입만 지키면 된다.

def from_exit_code(rc: Optional[int], command: str) -> Measurement:
    """명령의 종료 코드를 측정값으로. 명령을 못 돌렸으면 rc=None 을 주고 skipped 로 보낸다."""
    if rc is None:
        return Measurement(None, f"{command} - 실행 불가(툴체인 없음)")
    return Measurement(1.0 if rc == 0 else 0.0, f"{command} -> exit {rc}")


def from_coverage(pct: Optional[float], minimum: float = 0.8) -> Measurement:
    """커버리지 비율을 측정값으로. 리포트가 없으면 None 을 주어 skipped 로 보낸다."""
    if pct is None:
        return Measurement(None, "커버리지 리포트 없음")
    return Measurement(1.0 if pct >= minimum else pct / minimum, f"coverage {pct:.0%} (기준 {minimum:.0%})")
