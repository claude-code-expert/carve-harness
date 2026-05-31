#!/usr/bin/env python3
"""Run real end-to-end OpenHarness scenarios against an Anthropic-compatible API."""

from __future__ import annotations

import argparse
import asyncio
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from openharness.api.client import AnthropicApiClient
from openharness.config.paths import get_project_issue_file, get_project_pr_comments_file
from openharness.config.settings import load_settings
from openharness.engine import QueryEngine
from openharness.engine.stream_events import (
    AssistantTurnComplete,
    ToolExecutionCompleted,
    ToolExecutionStarted,
)
from openharness.mcp.client import McpClientManager
from openharness.mcp.config import load_mcp_server_configs
from openharness.mcp.types import McpStdioServerConfig
from openharness.memory import add_memory_entry
from openharness.permissions import PermissionChecker, PermissionMode
from openharness.plugins import load_plugins
from openharness.prompts import build_runtime_system_prompt
from openharness.tools import create_default_tool_registry


ScenarioSetup = Callable[[Path, Path], dict[str, object] | None]
ScenarioValidate = Callable[[Path, str, list[str], int, int], tuple[bool, str]]
FIXTURE_SERVER = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "fake_mcp_server.py"


@dataclass(frozen=True)
class Scenario:
    """One real-model scenario."""

    name: str
    prompt: str
    expected_final: str
    required_tools: tuple[str, ...]
    validate: ScenarioValidate
    setup: ScenarioSetup | None = None
    ask_user_answer: str | None = None


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=None, help="Model name override")
    parser.add_argument("--base-url", default=None, help="Anthropic-compatible base URL")
    parser.add_argument(
        "--scenario",
        choices=[
            "file_io",
            "search_edit",
            "phase48",
            "task_flow",
            "skill_flow",
            "mcp_model",
            "mcp_resource",
            "context_flow",
            "agent_flow",
            "remote_agent_flow",
            "plugin_combo",
            "ask_user_flow",
            "task_update_flow",
            "notebook_flow",
            "lsp_flow",
            "cron_flow",
            "worktree_flow",
            "issue_pr_context_flow",
            "mcp_auth_flow",
            "all",
        ],
        default="all",
        help="Scenario to run",
    )
    parser.add_argument(
        "--api-key-stdin",
        action="store_true",
        help="Read the API key from stdin instead of environment variables",
    )
    return parser.parse_args()


def _validate_file_io(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "smoke.txt"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    if started < 2 or completed < 2:
        return False, "model did not complete both tool calls"
    if "write_file" not in tool_names or "read_file" not in tool_names:
        return False, f"unexpected tool sequence: {tool_names}"
    if contents != "OPENHARNESS_E2E_OK":
        return False, f"unexpected smoke.txt contents: {contents!r}"
    if "FINAL_OK" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_search_edit(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "src" / "demo.py"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    required = {"write_file", "glob", "grep", "edit_file", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "gamma" not in contents or "beta" in contents:
        return False, f"unexpected src/demo.py contents: {contents!r}"
    if "FINAL_OK_SEARCH_EDIT" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_phase48(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "TODO.md"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    required = {"tool_search", "todo_write", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "phase48 smoke item" not in contents:
        return False, f"unexpected TODO.md contents: {contents!r}"
    if "FINAL_OK_PHASE48" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_task_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    required = {"task_create", "sleep", "task_output"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_TASK" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _setup_skill_flow(_: Path, config_dir: Path) -> None:
    skills_dir = config_dir / "skills"
    skills_dir.mkdir(parents=True, exist_ok=True)
    (skills_dir / "pytest.md").write_text(
        "# Pytest\nPytest fixtures help share setup across tests.\n",
        encoding="utf-8",
    )
    return None


def _setup_mcp_model_flow(_: Path, __: Path) -> dict[str, object]:
    return {
        "fixture": McpStdioServerConfig(
            command=sys.executable,
            args=[str(FIXTURE_SERVER)],
        )
    }


def _setup_context_flow(cwd: Path, _: Path) -> None:
    (cwd / "CLAUDE.md").write_text(
        "# Project Rules\nWhen asked to create config-like files, use KEY=value lines and always set COLOR=orange.\n",
        encoding="utf-8",
    )
    add_memory_entry(cwd, "Codename", "CODENAME=aurora")
    return None


def _setup_plugin_combo_flow(cwd: Path, _: Path) -> None:
    plugin_dir = cwd / ".openharness" / "plugins" / "fixture-plugin"
    (plugin_dir / "skills").mkdir(parents=True, exist_ok=True)
    (plugin_dir / "plugin.json").write_text(
        '{"name":"fixture-plugin","version":"1.0.0","description":"Fixture project plugin"}\n',
        encoding="utf-8",
    )
    (plugin_dir / "skills" / "fixture.md").write_text(
        "# FixtureSkill\nThis plugin skill says COMBO_SKILL_OK.\n",
        encoding="utf-8",
    )
    (plugin_dir / "mcp.json").write_text(
        (
            '{"mcpServers":{"fixture":{"type":"stdio","command":"%s","args":["%s"]}}}\n'
            % (sys.executable, str(FIXTURE_SERVER))
        ),
        encoding="utf-8",
    )
    return None


def _setup_worktree_flow(cwd: Path, _: Path) -> None:
    import subprocess

    subprocess.run(["git", "init"], cwd=cwd, check=True, capture_output=True, text=True)
    subprocess.run(
        ["git", "config", "user.email", "openharness@example.com"],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "OpenHarness Tests"],
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
    )
    (cwd / "demo.txt").write_text("WORKTREE_OK\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=cwd, check=True, capture_output=True, text=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=cwd, check=True, capture_output=True, text=True)
    return None


def _setup_issue_pr_context_flow(cwd: Path, _: Path) -> None:
    get_project_issue_file(cwd).write_text(
        "# Fix flaky tasks\n\nThe main problem is the task retry path.\n",
        encoding="utf-8",
    )
    get_project_pr_comments_file(cwd).write_text(
        "# PR Comments\n- src/tasks/manager.py:120: reviewer wants simpler restart handling.\n",
        encoding="utf-8",
    )
    return None


def _validate_skill_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    if "skill" not in tool_names:
        return False, f"expected skill tool usage, got {tool_names}"
    if "FINAL_OK_SKILL" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _validate_mcp_model_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    if "mcp__fixture__hello" not in tool_names:
        return False, f"expected mcp tool usage, got {tool_names}"
    if "FINAL_OK_MCP" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _validate_mcp_resource_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"list_mcp_resources", "read_mcp_resource"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_MCP_RESOURCE" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _validate_context_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "note.env"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    required = {"write_file", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "COLOR=orange" not in contents or "CODENAME=aurora" not in contents:
        return False, f"unexpected note.env contents: {contents!r}"
    if "FINAL_OK_CONTEXT" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_agent_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"agent", "send_message", "sleep", "task_output"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_AGENT" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "AGENT_ECHO:agent ping" not in final_text:
        return False, f"final text missing echoed agent output: {final_text!r}"
    return True, final_text


def _validate_remote_agent_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"agent", "send_message", "sleep", "task_output"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_REMOTE_AGENT" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "AGENT_ECHO:remote ping" not in final_text:
        return False, f"final text missing remote echoed output: {final_text!r}"
    return True, final_text


def _validate_plugin_combo_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    if "skill" not in tool_names:
        return False, f"expected plugin skill usage, got {tool_names}"
    if "mcp__fixture-plugin_fixture__hello" not in tool_names:
        return False, f"expected plugin mcp usage, got {tool_names}"
    if "FINAL_OK_PLUGIN_COMBO" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _validate_ask_user_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "answer.txt"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    required = {"ask_user_question", "write_file", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if contents != "green":
        return False, f"unexpected answer.txt contents: {contents!r}"
    if "FINAL_OK_ASK_USER" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_task_update_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"task_create", "task_update", "task_get"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_TASK_UPDATE" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "75" not in final_text or "waiting on review" not in final_text:
        return False, f"final text missing updated task state: {final_text!r}"
    return True, final_text


def _validate_notebook_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "analysis.ipynb"
    contents = path.read_text(encoding="utf-8") if path.exists() else ""
    required = {"notebook_edit", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "NB_OK" not in contents:
        return False, f"unexpected notebook contents: {contents!r}"
    if "FINAL_OK_NOTEBOOK" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, "NB_OK"


def _setup_lsp_flow(cwd: Path, _: Path) -> None:
    (cwd / "pkg").mkdir(parents=True, exist_ok=True)
    (cwd / "pkg" / "utils.py").write_text(
        'def greet(name):\n    """Return a greeting."""\n    return f"hi {name}"\n',
        encoding="utf-8",
    )
    (cwd / "pkg" / "app.py").write_text(
        "from pkg.utils import greet\n\nprint(greet('world'))\n",
        encoding="utf-8",
    )
    return None


def _validate_lsp_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"lsp"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_LSP" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "pkg/utils.py" not in final_text or "Return a greeting" not in final_text:
        return False, f"final text missing definition or docstring details: {final_text!r}"
    return True, final_text


def _validate_cron_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"cron_create", "cron_list", "remote_trigger", "cron_delete"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_CRON" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "CRON_SMOKE_OK" not in final_text:
        return False, f"missing cron output in final text: {final_text!r}"
    return True, final_text


def _validate_worktree_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    worktree_path = cwd / ".openharness" / "worktrees" / "smoke-worktree"
    required = {"enter_worktree", "read_file", "exit_worktree"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if worktree_path.exists():
        return False, f"worktree still exists: {worktree_path}"
    if "FINAL_OK_WORKTREE" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, final_text


def _validate_issue_pr_context_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    path = cwd / "review_summary.md"
    contents = path.read_text(encoding="utf-8").strip() if path.exists() else ""
    required = {"write_file", "read_file"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "Fix flaky tasks" not in contents or "simpler restart handling" not in contents:
        return False, f"unexpected review_summary.md contents: {contents!r}"
    if "FINAL_OK_CONTEXT_REVIEW" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    return True, contents


def _validate_mcp_auth_flow(cwd: Path, final_text: str, tool_names: list[str], started: int, completed: int) -> tuple[bool, str]:
    del cwd, started, completed
    required = {"mcp_auth", "mcp__fixture__hello"}
    if not required.issubset(set(tool_names)):
        return False, f"missing required tools: {sorted(required - set(tool_names))}"
    if "FINAL_OK_MCP_AUTH" not in final_text:
        return False, f"unexpected final text: {final_text!r}"
    if "fixture-hello:auth" not in final_text:
        return False, f"tool output missing after auth update: {final_text!r}"
    return True, final_text


SCENARIOS: dict[str, Scenario] = {
    "file_io": Scenario(
        name="file_io",
        prompt=(
            "You are running an OpenHarness smoke test. "
            "You must use tools. "
            "1. Use write_file to create smoke.txt with the exact content OPENHARNESS_E2E_OK. "
            "2. Use read_file to verify the file content. "
            "3. Reply with exactly FINAL_OK once verification succeeds."
        ),
        expected_final="FINAL_OK",
        required_tools=("write_file", "read_file"),
        validate=_validate_file_io,
    ),
    "search_edit": Scenario(
        name="search_edit",
        prompt=(
            "You are running an OpenHarness search and edit test. "
            "You must use tools. "
            "1. Use write_file to create src/demo.py with two lines: alpha and beta. "
            "2. Use glob to find the python file. "
            "3. Use grep to confirm beta exists. "
            "4. Use edit_file to replace beta with gamma. "
            "5. Use read_file to confirm gamma is present. "
            "6. Reply with exactly FINAL_OK_SEARCH_EDIT."
        ),
        expected_final="FINAL_OK_SEARCH_EDIT",
        required_tools=("write_file", "glob", "grep", "edit_file", "read_file"),
        validate=_validate_search_edit,
    ),
    "phase48": Scenario(
        name="phase48",
        prompt=(
            "You are running an OpenHarness Phase 4-8 smoke test. "
            "You must use tools. "
            "1. Use tool_search to find the todo tool. "
            "2. Use todo_write to append a TODO item with the exact text phase48 smoke item. "
            "3. Use read_file to verify TODO.md contains that exact text. "
            "4. Reply with exactly FINAL_OK_PHASE48 once verification succeeds."
        ),
        expected_final="FINAL_OK_PHASE48",
        required_tools=("tool_search", "todo_write", "read_file"),
        validate=_validate_phase48,
    ),
    "task_flow": Scenario(
        name="task_flow",
        prompt=(
            "You are running an OpenHarness background task test. "
            "You must use tools. "
            "1. Use task_create with type local_bash and command printf 'TASK_FLOW_OK'. "
            "2. Use sleep for 0.2 seconds. "
            "3. Use task_output to read the created task output and verify it contains TASK_FLOW_OK. "
            "4. Reply with exactly FINAL_OK_TASK."
        ),
        expected_final="FINAL_OK_TASK",
        required_tools=("task_create", "sleep", "task_output"),
        validate=_validate_task_flow,
    ),
    "skill_flow": Scenario(
        name="skill_flow",
        prompt=(
            "You are running an OpenHarness skill loading test. "
            "You must use tools. "
            "1. Use the skill tool to read the Pytest skill. "
            "2. Verify it mentions fixtures. "
            "3. Reply with exactly FINAL_OK_SKILL."
        ),
        expected_final="FINAL_OK_SKILL",
        required_tools=("skill",),
        validate=_validate_skill_flow,
        setup=_setup_skill_flow,
    ),
    "mcp_model": Scenario(
        name="mcp_model",
        prompt=(
            "You are running an OpenHarness MCP integration test. "
            "You must use tools. "
            "1. Use mcp__fixture__hello with the argument name='kimi'. "
            "2. Verify the tool result contains fixture-hello:kimi. "
            "3. Reply with exactly FINAL_OK_MCP."
        ),
        expected_final="FINAL_OK_MCP",
        required_tools=("mcp__fixture__hello",),
        validate=_validate_mcp_model_flow,
        setup=_setup_mcp_model_flow,
    ),
    "mcp_resource": Scenario(
        name="mcp_resource",
        prompt=(
            "You are running an OpenHarness MCP resource test. "
            "You must use tools. "
            "1. Use list_mcp_resources. "
            "2. Use read_mcp_resource to read fixture://readme from server fixture. "
            "3. Verify the contents mention fixture resource contents. "
            "4. Reply with exactly FINAL_OK_MCP_RESOURCE."
        ),
        expected_final="FINAL_OK_MCP_RESOURCE",
        required_tools=("list_mcp_resources", "read_mcp_resource"),
        validate=_validate_mcp_resource_flow,
        setup=_setup_mcp_model_flow,
    ),
    "context_flow": Scenario(
        name="context_flow",
        prompt=(
            "Use the project instructions and persistent memory. "
            "Create note.env with exactly two lines: COLOR=orange and CODENAME=aurora. "
            "Use tools and verify the file by reading it. "
            "Reply with exactly FINAL_OK_CONTEXT."
        ),
        expected_final="FINAL_OK_CONTEXT",
        required_tools=("write_file", "read_file"),
        validate=_validate_context_flow,
        setup=_setup_context_flow,
    ),
    "agent_flow": Scenario(
        name="agent_flow",
        prompt=(
            "You are running an OpenHarness agent delegation test. "
            "You must use tools. "
            "1. Use the agent tool with description 'echo agent' and prompt 'ready'. "
            "Set command to exactly: while read line; do echo AGENT_ECHO:$line; break; done "
            "2. Use sleep for 0.2 seconds so the first agent run can finish. "
            "3. Use send_message to send exactly agent ping to the spawned task. "
            "4. Use sleep for 0.2 seconds. "
            "5. Use task_output to read the task output. "
            "6. Reply with exactly FINAL_OK_AGENT and include the observed AGENT_ECHO line."
        ),
        expected_final="FINAL_OK_AGENT",
        required_tools=("agent", "send_message", "sleep", "task_output"),
        validate=_validate_agent_flow,
    ),
    "remote_agent_flow": Scenario(
        name="remote_agent_flow",
        prompt=(
            "You are running an OpenHarness remote-agent mode test. "
            "You must use tools. "
            "1. Use the agent tool with mode remote_agent, description 'remote echo agent', and prompt 'ready'. "
            "Set command to exactly: while read line; do echo AGENT_ECHO:$line; break; done "
            "2. Use sleep for 0.2 seconds so the first agent run can finish. "
            "3. Use send_message to send exactly remote ping to the spawned task. "
            "4. Use sleep for 0.2 seconds. "
            "5. Use task_output to read the task output. "
            "6. Reply with exactly FINAL_OK_REMOTE_AGENT and include the observed AGENT_ECHO line."
        ),
        expected_final="FINAL_OK_REMOTE_AGENT",
        required_tools=("agent", "send_message", "sleep", "task_output"),
        validate=_validate_remote_agent_flow,
    ),
    "plugin_combo": Scenario(
        name="plugin_combo",
        prompt=(
            "You are running an OpenHarness plugin combo test. "
            "You must use tools. "
            "1. Use the skill tool to read FixtureSkill and verify it says COMBO_SKILL_OK. "
            "2. Use mcp__fixture-plugin_fixture__hello with name='combo'. "
            "3. Reply with exactly FINAL_OK_PLUGIN_COMBO."
        ),
        expected_final="FINAL_OK_PLUGIN_COMBO",
        required_tools=("skill", "mcp__fixture-plugin_fixture__hello"),
        validate=_validate_plugin_combo_flow,
        setup=_setup_plugin_combo_flow,
    ),
    "ask_user_flow": Scenario(
        name="ask_user_flow",
        prompt=(
            "You are running an OpenHarness ask-user test. "
            "You must use tools. "
            "1. Use ask_user_question to ask exactly What color should answer.txt contain? "
            "2. Use write_file to create answer.txt with the returned answer and nothing else. "
            "3. Use read_file to verify the file content. "
            "4. Reply with exactly FINAL_OK_ASK_USER."
        ),
        expected_final="FINAL_OK_ASK_USER",
        required_tools=("ask_user_question", "write_file", "read_file"),
        validate=_validate_ask_user_flow,
        ask_user_answer="green",
    ),
    "task_update_flow": Scenario(
        name="task_update_flow",
        prompt=(
            "You are running an OpenHarness task update test. "
            "You must use tools. "
            "1. Use task_create with type local_bash and command printf 'TASK_UPDATE_OK'. "
            "2. Use task_update to set progress to 75 and status_note to waiting on review. "
            "3. Use task_get to inspect the task and verify both updates are present. "
            "4. Reply with exactly FINAL_OK_TASK_UPDATE and include 75 and waiting on review."
        ),
        expected_final="FINAL_OK_TASK_UPDATE",
        required_tools=("task_create", "task_update", "task_get"),
        validate=_validate_task_update_flow,
    ),
    "notebook_flow": Scenario(
        name="notebook_flow",
        prompt=(
            "You are running an OpenHarness notebook test. "
            "You must use tools. "
            "1. Use notebook_edit to create analysis.ipynb and set cell 0 to exactly print('NB_OK'). "
            "2. Use read_file to verify the notebook JSON contains NB_OK. "
            "3. Reply with exactly FINAL_OK_NOTEBOOK."
        ),
        expected_final="FINAL_OK_NOTEBOOK",
        required_tools=("notebook_edit", "read_file"),
        validate=_validate_notebook_flow,
    ),
    "lsp_flow": Scenario(
        name="lsp_flow",
        prompt=(
            "You are running an OpenHarness LSP test. "
            "You must use tools. "
            "1. Use lsp on pkg/app.py to find the definition of greet. "
            "2. Use lsp hover on greet to confirm the docstring says Return a greeting. "
            "3. Reply with exactly FINAL_OK_LSP and include the definition path and the docstring text."
        ),
        expected_final="FINAL_OK_LSP",
        required_tools=("lsp",),
        validate=_validate_lsp_flow,
        setup=_setup_lsp_flow,
    ),
    "cron_flow": Scenario(
        name="cron_flow",
        prompt=(
            "You are running an OpenHarness cron test. "
            "You must use tools. "
            "1. Use cron_create with name smoke-cron, schedule daily, and command printf 'CRON_SMOKE_OK'. "
            "2. Use cron_list to verify smoke-cron exists. "
            "3. Use remote_trigger with name smoke-cron and verify the output contains CRON_SMOKE_OK. "
            "4. Use cron_delete to remove smoke-cron. "
            "5. Reply with exactly FINAL_OK_CRON and include CRON_SMOKE_OK."
        ),
        expected_final="FINAL_OK_CRON",
        required_tools=("cron_create", "cron_list", "remote_trigger", "cron_delete"),
        validate=_validate_cron_flow,
    ),
    "worktree_flow": Scenario(
        name="worktree_flow",
        prompt=(
            "You are running an OpenHarness worktree test. "
            "You must use tools. "
            "1. Use enter_worktree with branch smoke/worktree. "
            "2. Use read_file to read demo.txt inside the returned worktree path and verify it contains WORKTREE_OK. "
            "3. Use exit_worktree to remove that worktree path. "
            "4. Reply with exactly FINAL_OK_WORKTREE."
        ),
        expected_final="FINAL_OK_WORKTREE",
        required_tools=("enter_worktree", "read_file", "exit_worktree"),
        validate=_validate_worktree_flow,
        setup=_setup_worktree_flow,
    ),
    "issue_pr_context_flow": Scenario(
        name="issue_pr_context_flow",
        prompt=(
            "Use the project issue and PR comment context. "
            "Create review_summary.md with one line containing the issue title and one line containing the reviewer request. "
            "Use tools to write and verify the file. "
            "Reply with exactly FINAL_OK_CONTEXT_REVIEW."
        ),
        expected_final="FINAL_OK_CONTEXT_REVIEW",
        required_tools=("write_file", "read_file"),
        validate=_validate_issue_pr_context_flow,
        setup=_setup_issue_pr_context_flow,
    ),
    "mcp_auth_flow": Scenario(
        name="mcp_auth_flow",
        prompt=(
            "You are running an OpenHarness MCP auth reconfiguration test. "
            "You must use tools. "
            "1. Use mcp_auth on server fixture with mode bearer and value token-smoke. "
            "2. Use mcp__fixture__hello with name='auth'. "
            "3. Verify the output contains fixture-hello:auth. "
            "4. Reply with exactly FINAL_OK_MCP_AUTH and include fixture-hello:auth."
        ),
        expected_final="FINAL_OK_MCP_AUTH",
        required_tools=("mcp_auth", "mcp__fixture__hello"),
        validate=_validate_mcp_auth_flow,
        setup=_setup_mcp_model_flow,
    ),
}


async def _run_scenario(
    *,
    scenario: Scenario,
    suite_root: Path,
    client: AnthropicApiClient,
    model: str,
) -> tuple[bool, str]:
    cwd = suite_root / scenario.name
    cwd.mkdir(parents=True, exist_ok=True)
    config_dir = suite_root / "config"
    config_dir.mkdir(parents=True, exist_ok=True)
    server_configs = scenario.setup(cwd, config_dir) if scenario.setup is not None else None

    settings = load_settings().merge_cli_overrides(model=model)
    plugins = load_plugins(settings, cwd)
    permission_settings = settings.permission.model_copy(update={"mode": PermissionMode.FULL_AUTO})
    merged_server_configs = load_mcp_server_configs(settings, plugins)
    if server_configs:
        merged_server_configs.update(server_configs)
    mcp_manager = McpClientManager(merged_server_configs) if merged_server_configs else None
    if mcp_manager is not None:
        await mcp_manager.connect_all()
    try:
        engine = QueryEngine(
            api_client=client,
            tool_registry=create_default_tool_registry(mcp_manager),
            permission_checker=PermissionChecker(permission_settings),
            cwd=cwd,
            model=settings.model,
            system_prompt=build_runtime_system_prompt(settings, cwd=cwd),
            max_tokens=min(settings.max_tokens, 4096),
            tool_metadata={"mcp_manager": mcp_manager} if mcp_manager is not None else None,
            ask_user_prompt=(
                None
                if scenario.ask_user_answer is None
                else (lambda _question: asyncio.sleep(0, result=scenario.ask_user_answer))
            ),
        )

        tool_names: list[str] = []
        started = 0
        completed = 0
        final_text = ""
        async for event in engine.submit_message(scenario.prompt):
            if isinstance(event, ToolExecutionStarted):
                started += 1
                tool_names.append(event.tool_name)
                print(f"[{scenario.name}] tool-start {event.tool_name}")
            elif isinstance(event, ToolExecutionCompleted):
                completed += 1
                print(f"[{scenario.name}] tool-done {event.tool_name} error={event.is_error}")
            elif isinstance(event, AssistantTurnComplete):
                final_text = event.message.text.strip()

        ok, detail = scenario.validate(cwd, final_text, tool_names, started, completed)
        status = "PASS" if ok else "FAIL"
        print(f"[{scenario.name}] final_text={final_text}")
        print(f"[{scenario.name}] tools={tool_names}")
        print(f"[{scenario.name}] result={status} detail={detail}")
        return ok, detail
    finally:
        if mcp_manager is not None:
            await mcp_manager.close()


async def _run() -> int:
    args = _parse_args()
    api_key = sys.stdin.readline().strip() if args.api_key_stdin else load_settings().resolve_api_key()
    if not api_key:
        raise SystemExit("Missing API key.")

    selected = list(SCENARIOS) if args.scenario == "all" else [args.scenario]
    with tempfile.TemporaryDirectory(prefix="openharness-e2e-suite-") as temp_dir:
        suite_root = Path(temp_dir)
        previous_env = {
            "OPENHARNESS_CONFIG_DIR": os.environ.get("OPENHARNESS_CONFIG_DIR"),
            "OPENHARNESS_DATA_DIR": os.environ.get("OPENHARNESS_DATA_DIR"),
        }
        os.environ["OPENHARNESS_CONFIG_DIR"] = str(suite_root / "config")
        os.environ["OPENHARNESS_DATA_DIR"] = str(suite_root / "data")
        try:
            settings = load_settings().merge_cli_overrides(model=args.model, base_url=args.base_url)
            client = AnthropicApiClient(api_key=api_key, base_url=settings.base_url)
            failures: list[str] = []
            for name in selected:
                ok, detail = await _run_scenario(
                    scenario=SCENARIOS[name],
                    suite_root=suite_root,
                    client=client,
                    model=settings.model,
                )
                if not ok:
                    failures.append(f"{name}: {detail}")
            if failures:
                print("Suite failed:", file=sys.stderr)
                for failure in failures:
                    print(f"- {failure}", file=sys.stderr)
                return 1
            print(f"Suite passed for scenarios: {', '.join(selected)}")
            return 0
        finally:
            for key, value in previous_env.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


def main() -> int:
    return asyncio.run(_run())


if __name__ == "__main__":
    raise SystemExit(main())
