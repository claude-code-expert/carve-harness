"""5축 루브릭 채점기 - checklist-loop 의 P3 Score 단계를 그대로 구현한다.

축과 배점(합 100):
    exists     25   주장한 산출물이 실제로 존재하는가
    match      25   acceptance 를 문자 그대로 충족하는가
    test       25   테스트가 실행됐고 통과했는가   ← 실행 출력으로만 채운다
    contract   15   스키마·시그니처 등 계약을 지켰는가
    no_regress 10   기존 동작을 깨뜨리지 않았는가

임계 95. 발표자료 74~75p 워크스루가 이 임계를 쓴다.

test 축이 이 설계의 핵심이다. 실행 결과가 없으면 test=0 이 되고, 나머지를 만점 받아도
합이 75라 임계 95를 넘지 못한다. 즉 "테스트를 돌리지 않은 채 완료를 주장하는 것"이
산술적으로 불가능하다. 게이트에 별도 규칙을 넣지 않아도 배점 자체가 막는다.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

AXES: dict[str, int] = {
    "exists": 25,
    "match": 25,
    "test": 25,
    "contract": 15,
    "no_regress": 10,
}

DEFAULT_THRESHOLD = 95

# 도메인 안전 항목은 만점이 아니면 임계와 무관하게 차단된다(허용 실패율 0%).
DOMAIN_SAFETY = "domain_safety"


@dataclass
class TestRun:
    """테스트 실행 결과. 실행하지 않았으면 ran=False 이고 test 축은 0점이 된다."""

    ran: bool = False
    passed: int = 0
    failed: int = 0
    output: str = ""

    @property
    def ratio(self) -> float:
        total = self.passed + self.failed
        if not self.ran or total == 0:
            return 0.0
        return self.passed / total


@dataclass
class Verdict:
    task_id: str
    axes: dict[str, int]
    score: int
    passed: bool
    gaps: list[str] = field(default_factory=list)
    evidence: str = ""
    blocked_by: Optional[str] = None

    def as_dict(self) -> dict:
        d = {
            "id": self.task_id,
            "axes": self.axes,
            "score": self.score,
            "pass": self.passed,
            "gaps": self.gaps,
            "evidence": self.evidence,
        }
        if self.blocked_by:
            d["blocked_by"] = self.blocked_by
        return d


def judge(
    task_id: str,
    *,
    exists: float,
    match: float,
    contract: float,
    no_regress: float,
    tests: TestRun,
    gaps: Optional[list[str]] = None,
    evidence: str = "",
    task_type: Optional[str] = None,
    threshold: int = DEFAULT_THRESHOLD,
) -> Verdict:
    """다섯 축의 달성률(0.0~1.0)을 받아 채점한다. test 축만 실행 결과에서 계산한다."""
    raw = {
        "exists": exists,
        "match": match,
        "test": tests.ratio,      # 실행하지 않았으면 0
        "contract": contract,
        "no_regress": no_regress,
    }
    axes = {k: round(AXES[k] * _clamp01(v)) for k, v in raw.items()}
    total = sum(axes.values())

    gaps = list(gaps or [])
    if not tests.ran:
        gaps.append("테스트 미실행 - test 축 0점, 합 75 상한이라 임계를 넘을 수 없다")

    passed = total >= threshold
    blocked = None
    # 도메인 안전 항목은 만점 아니면 차단. 임계보다 엄격하다.
    if task_type == DOMAIN_SAFETY and total < 100:
        passed = False
        blocked = f"{DOMAIN_SAFETY}: 100점이 아니면 차단(허용 실패율 0%)"

    return Verdict(task_id, axes, total, passed, gaps, evidence, blocked)


def loop_status(verdicts: list[Verdict], threshold: int = DEFAULT_THRESHOLD) -> dict:
    """루프를 계속할지 판정한다. 미달 항목만 재작업 대상으로 돌려준다.

    통과한 항목은 건드리지 않는다 - 전체 재생성이 아니라 미달만 고치는 것이
    빠르고, 이미 좋은 것을 망치지 않는다(발표자료 75p).
    """
    failing = [v for v in verdicts if not v.passed]
    return {
        "threshold": threshold,
        "total_tasks": len(verdicts),
        "passing": len(verdicts) - len(failing),
        "rework": [v.task_id for v in failing],
        "gate": "BLOCKED" if failing else "RELEASED",
    }


def _clamp01(v: float) -> float:
    return 0.0 if v < 0 else 1.0 if v > 1 else v
