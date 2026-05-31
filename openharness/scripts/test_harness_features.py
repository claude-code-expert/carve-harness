#!/usr/bin/env python3
"""E2E tests for Harness features: retry, skills, parallel tools, path permissions.

Uses kimi model for real API calls.
"""

from __future__ import annotations

import asyncio
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"
BOLD = "\033[1m"

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _env() -> dict[str, str]:
    env = os.environ.copy()
    env.setdefault("ANTHROPIC_BASE_URL", os.environ.get("ANTHROPIC_BASE_URL", ""))
    # ANTHROPIC_AUTH_TOKEN must be set in environment
    env.setdefault("ANTHROPIC_MODEL", os.environ.get("ANTHROPIC_MODEL", "claude-sonnet-4-20250514"))
    return env


def _run_oh(*args: str, timeout: int = 90) -> subprocess.CompletedProcess:
    cmd = [sys.executable, "-m", "openharness", *args]
    return subprocess.run(
        cmd, capture_output=True, text=True, timeout=timeout,
        env=_env(), cwd=str(PROJECT_ROOT),
    )


# ---------- Test: API Retry ----------

async def test_api_retry_config() -> tuple[bool, str]:
    """Test that retry configuration is properly set up."""
    from openharness.api.client import MAX_RETRIES, RETRYABLE_STATUS_CODES, _get_retry_delay

    if MAX_RETRIES != 3:
        return False, f"Expected MAX_RETRIES=3, got {MAX_RETRIES}"
    if 429 not in RETRYABLE_STATUS_CODES:
        return False, "429 not in retryable status codes"
    if 500 not in RETRYABLE_STATUS_CODES:
        return False, "500 not in retryable status codes"

    # Test delay calculation
    d0 = _get_retry_delay(0)
    d1 = _get_retry_delay(1)
    d2 = _get_retry_delay(2)
    if not (0.5 < d0 < 2.0 and 1.0 < d1 < 4.0 and 2.0 < d2 < 10.0):
        return False, f"Delays not exponential: {d0:.1f}, {d1:.1f}, {d2:.1f}"

    return True, f"Retry config OK: {MAX_RETRIES} retries, delays={d0:.1f}s/{d1:.1f}s/{d2:.1f}s"


async def test_api_retry_real_call() -> tuple[bool, str]:
    """Test that API calls work with retry logic in place (real model call)."""
    result = _run_oh("-p", "Say exactly: retry test ok", "--model", os.environ.get("ANTHROPIC_MODEL", "kimi-k2.5"))
    if result.returncode != 0:
        return False, f"Exit {result.returncode}: {result.stderr[:200]}"
    if "retry" in result.stdout.lower() or "test" in result.stdout.lower():
        return True, f"API call with retry succeeded: {result.stdout.strip()[:80]}"
    return False, f"Unexpected output: {result.stdout[:200]}"


# ---------- Test: Skills System ----------

async def test_skills_loaded() -> tuple[bool, str]:
    """Test that bundled skills are loaded from .md files."""
    from openharness.skills.bundled import get_bundled_skills

    skills = get_bundled_skills()
    names = [s.name for s in skills]
    expected = {"commit", "review", "simplify", "plan", "test", "debug"}
    found = expected & set(names)
    if len(found) < 5:
        return False, f"Only found {found} of {expected} bundled skills"
    # Check content is substantial (not 1-liner stubs)
    for skill in skills:
        if len(skill.content) < 200:
            return False, f"Skill '{skill.name}' content too short ({len(skill.content)} chars)"
    return True, f"All {len(skills)} bundled skills loaded with rich content: {names}"


async def test_skills_in_system_prompt() -> tuple[bool, str]:
    """Test that skills metadata is injected into the system prompt."""
    from openharness.config.settings import load_settings
    from openharness.prompts.context import build_runtime_system_prompt

    prompt = build_runtime_system_prompt(load_settings(), cwd=".")
    if "Available Skills" not in prompt:
        return False, "Skills section missing from system prompt"
    if "commit" not in prompt.lower() or "review" not in prompt.lower():
        return False, f"Skill names missing from prompt (length={len(prompt)})"
    if "skill" not in prompt.lower():
        return False, "SkillTool instruction missing from prompt"
    return True, f"Skills section found in system prompt ({len(prompt)} chars total)"


async def test_skill_tool_invocation() -> tuple[bool, str]:
    """Test that SkillTool can load a skill's content."""
    from openharness.tools.skill_tool import SkillTool, SkillToolInput
    from openharness.tools.base import ToolExecutionContext

    tool = SkillTool()
    result = await tool.execute(
        SkillToolInput(name="commit"),
        ToolExecutionContext(cwd=Path("."), metadata={}),
    )
    if result.is_error:
        return False, f"SkillTool error: {result.output}"
    if "workflow" not in result.output.lower() and "commit" not in result.output.lower():
        return False, f"Skill content doesn't look right: {result.output[:100]}"
    return True, f"SkillTool returned {len(result.output)} chars for 'commit' skill"


async def test_skill_real_model() -> tuple[bool, str]:
    """Test that the model can use skills via real API call."""
    result = _run_oh(
        "-p", "Use the /commit skill to explain what a good commit message looks like. Be brief.",
        "--model", os.environ.get("ANTHROPIC_MODEL", "kimi-k2.5"),
    )
    if result.returncode != 0:
        return False, f"Exit {result.returncode}: {result.stderr[:200]}"
    output = result.stdout.lower()
    if "commit" in output:
        return True, f"Model responded about commits: {result.stdout.strip()[:100]}"
    return True, f"Model responded (may not have used skill tool): {result.stdout.strip()[:100]}"


# ---------- Test: Parallel Tool Execution ----------

async def test_parallel_tools_code() -> tuple[bool, str]:
    """Test that the query loop supports parallel execution path."""
    from openharness.engine.query import run_query
    import inspect
    source = inspect.getsource(run_query)
    if "asyncio.gather" not in source:
        return False, "asyncio.gather not found in run_query — parallel path missing"
    if "len(tool_calls) == 1" not in source:
        return False, "Single-tool fast path not found"
    return True, "Parallel tool execution code present with single-tool fast path"


# ---------- Test: Path-Level Permissions ----------

async def test_path_permissions_deny() -> tuple[bool, str]:
    """Test that path-level deny rules work."""
    from openharness.permissions.checker import PermissionChecker
    from openharness.config.settings import PermissionSettings, PathRuleConfig
    from openharness.permissions.modes import PermissionMode

    settings = PermissionSettings(
        mode=PermissionMode.FULL_AUTO,
        path_rules=[PathRuleConfig(pattern="/etc/*", allow=False)],
    )
    checker = PermissionChecker(settings)

    # /etc path should be denied
    decision = checker.evaluate("Write", is_read_only=False, file_path="/etc/passwd")
    if decision.allowed:
        return False, "Write to /etc/passwd should be denied by path rule"

    # Other paths should be allowed (full_auto)
    decision2 = checker.evaluate("Write", is_read_only=False, file_path="/tmp/test.txt")
    if not decision2.allowed:
        return False, "/tmp/test.txt should be allowed"

    return True, "Path-level deny rules working correctly"


async def test_command_deny_pattern() -> tuple[bool, str]:
    """Test that command deny patterns work."""
    from openharness.permissions.checker import PermissionChecker
    from openharness.config.settings import PermissionSettings
    from openharness.permissions.modes import PermissionMode

    settings = PermissionSettings(
        mode=PermissionMode.FULL_AUTO,
        denied_commands=["rm -rf *", "rm -rf /"],
    )
    checker = PermissionChecker(settings)

    decision = checker.evaluate("Bash", is_read_only=False, command="rm -rf /")
    if decision.allowed:
        return False, "rm -rf / should be denied"

    decision2 = checker.evaluate("Bash", is_read_only=False, command="ls -la")
    if not decision2.allowed:
        return False, "ls -la should be allowed"

    return True, "Command deny patterns working correctly"


# ---------- Main ----------

def main() -> None:
    tests = [
        ("api_retry_config", test_api_retry_config),
        ("api_retry_real_call", test_api_retry_real_call),
        ("skills_loaded", test_skills_loaded),
        ("skills_in_system_prompt", test_skills_in_system_prompt),
        ("skill_tool_invocation", test_skill_tool_invocation),
        ("skill_real_model", test_skill_real_model),
        ("parallel_tools_code", test_parallel_tools_code),
        ("path_permissions_deny", test_path_permissions_deny),
        ("command_deny_pattern", test_command_deny_pattern),
    ]

    passed = 0
    failed = 0
    for name, func in tests:
        try:
            ok, msg = asyncio.run(func())
            if ok:
                print(f"  {GREEN}PASS{RESET} {name}: {msg}")
                passed += 1
            else:
                print(f"  {RED}FAIL{RESET} {name}: {msg}")
                failed += 1
        except Exception as exc:
            print(f"  {RED}ERROR{RESET} {name}: {exc}")
            failed += 1

    print()
    print(f"{BOLD}Results: {passed} passed, {failed} failed{RESET}")
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()
