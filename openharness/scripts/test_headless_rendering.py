#!/usr/bin/env python3
"""E2E tests for headless REPL rendering improvements using kimi model.

Tests markdown rendering, tool output formatting, and spinner indicators.
"""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"
BOLD = "\033[1m"


def _env_settings() -> dict[str, str | None]:
    """Return kimi model settings."""
    return {
        "model": os.environ.get("ANTHROPIC_MODEL", "kimi-k2.5"),
        "base_url": os.environ.get("ANTHROPIC_BASE_URL", "https://api.moonshot.cn/anthropic"),
        "api_key": os.environ.get("ANTHROPIC_AUTH_TOKEN"),
    }


async def test_markdown_render() -> tuple[bool, str]:
    """Test that assistant output with markdown is rendered by rich."""
    from io import StringIO
    from rich.console import Console

    from openharness.ui.output import OutputRenderer
    from openharness.engine.stream_events import AssistantTextDelta, AssistantTurnComplete
    from openharness.engine.messages import ConversationMessage, TextBlock
    from openharness.api.usage import UsageSnapshot

    renderer = OutputRenderer(style_name="default")
    buffer = StringIO()
    renderer.console = Console(file=buffer, force_terminal=True)

    md_text = "Here is some code:\n```python\nprint('hello')\n```\nAnd a list:\n- item 1\n- item 2"
    msg = ConversationMessage(role="assistant", content=[TextBlock(text=md_text)])
    usage = UsageSnapshot(input_tokens=100, output_tokens=50)

    renderer.start_assistant_turn()
    renderer.render_event(AssistantTextDelta(text=md_text))
    renderer.render_event(AssistantTurnComplete(message=msg, usage=usage))

    output = buffer.getvalue()
    if "hello" in output and "item" in output:
        return True, f"Markdown rendered ({len(output)} chars)"
    return False, f"Markdown not properly rendered: {output[:200]}"


async def test_tool_output_format() -> tuple[bool, str]:
    """Test that tool output is formatted with panels."""
    from io import StringIO
    from rich.console import Console

    from openharness.ui.output import OutputRenderer
    from openharness.engine.stream_events import ToolExecutionStarted, ToolExecutionCompleted

    renderer = OutputRenderer(style_name="default")
    buffer = StringIO()
    renderer.console = Console(file=buffer, force_terminal=True)

    renderer.render_event(ToolExecutionStarted(
        tool_name="Bash",
        tool_input={"command": "echo hello"},
    ))
    renderer.render_event(ToolExecutionCompleted(
        tool_name="Bash",
        output="hello\n",
        is_error=False,
    ))

    output = buffer.getvalue()
    if "Bash" in output or "bash" in output.lower() or "echo" in output:
        return True, f"Tool output formatted ({len(output)} chars)"
    return False, f"Tool output not formatted: {output[:200]}"


async def test_spinner_display() -> tuple[bool, str]:
    """Test that spinner starts on tool execution."""
    from io import StringIO
    from rich.console import Console

    from openharness.ui.output import OutputRenderer
    from openharness.engine.stream_events import ToolExecutionStarted, ToolExecutionCompleted

    renderer = OutputRenderer(style_name="default")
    buffer = StringIO()
    renderer.console = Console(file=buffer, force_terminal=True)

    renderer.render_event(ToolExecutionStarted(
        tool_name="Bash",
        tool_input={"command": "sleep 1"},
    ))
    has_spinner = renderer._spinner_status is not None
    renderer.render_event(ToolExecutionCompleted(
        tool_name="Bash",
        output="done",
        is_error=False,
    ))
    spinner_stopped = renderer._spinner_status is None

    if has_spinner and spinner_stopped:
        return True, "Spinner started and stopped correctly"
    return False, f"Spinner state: started={has_spinner}, stopped={spinner_stopped}"


async def test_real_model_headless() -> tuple[bool, str]:
    """Test headless REPL with real model call."""
    settings = _env_settings()
    if not settings["api_key"]:
        return False, "ANTHROPIC_AUTH_TOKEN not set"

    from openharness.ui.app import run_print_mode

    try:
        await run_print_mode(
            prompt="Say exactly: headless test ok",
            output_format="text",
            model=settings["model"],
            base_url=settings["base_url"],
            api_key=settings["api_key"],
        )
        return True, "Real model headless call completed"
    except Exception as exc:
        return False, f"Error: {exc}"


def main() -> None:
    tests = [
        ("markdown_render", test_markdown_render),
        ("tool_output_format", test_tool_output_format),
        ("spinner_display", test_spinner_display),
        ("real_model_headless", test_real_model_headless),
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
