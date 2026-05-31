#!/usr/bin/env python3
"""Run local system scenarios for MCP, plugins, bridge, and slash commands."""

from __future__ import annotations

import asyncio
import json
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from openharness.commands.registry import CommandContext, create_default_command_registry
from openharness.config.settings import Settings, load_settings
from openharness.engine.messages import ConversationMessage, TextBlock
from openharness.engine.query_engine import QueryEngine
from openharness.mcp.client import McpClientManager
from openharness.mcp.config import load_mcp_server_configs
from openharness.mcp.types import McpStdioServerConfig
from openharness.permissions import PermissionChecker
from openharness.plugins import load_plugins
from openharness.plugins.installer import install_plugin_from_path, uninstall_plugin
from openharness.state import AppState, AppStateStore
from openharness.bridge import build_sdk_url, decode_work_secret, encode_work_secret, spawn_session
from openharness.bridge.types import WorkSecret
from openharness.tools import create_default_tool_registry
from openharness.tools.base import ToolExecutionContext


FIXTURE_SERVER = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "fake_mcp_server.py"


class FakeApiClient:
    async def stream_message(self, request):
        del request
        raise AssertionError("No model call expected in local system scenarios")


def _make_command_context(cwd: Path) -> CommandContext:
    tool_registry = create_default_tool_registry()
    engine = QueryEngine(
        api_client=FakeApiClient(),
        tool_registry=tool_registry,
        permission_checker=PermissionChecker(load_settings().permission),
        cwd=cwd,
        model="claude-test",
        system_prompt="system",
    )
    engine.load_messages(
        [
            ConversationMessage(role="user", content=[TextBlock(text="one")]),
            ConversationMessage(role="assistant", content=[TextBlock(text="two")]),
            ConversationMessage(role="user", content=[TextBlock(text="three")]),
        ]
    )
    return CommandContext(
        engine=engine,
        cwd=str(cwd),
        tool_registry=tool_registry,
        app_state=AppStateStore(
            AppState(model="claude-test", permission_mode="default", theme="default", keybindings={})
        ),
    )


def _write_plugin(source_root: Path) -> Path:
    plugin_dir = source_root / "fixture-plugin"
    (plugin_dir / "skills").mkdir(parents=True)
    (plugin_dir / "plugin.json").write_text(
        json.dumps({"name": "fixture-plugin", "version": "1.0.0", "description": "Fixture plugin"}),
        encoding="utf-8",
    )
    (plugin_dir / "skills" / "fixture.md").write_text(
        "# FixtureSkill\nFixture skill content for local scenario.\n",
        encoding="utf-8",
    )
    (plugin_dir / "mcp.json").write_text(
        json.dumps(
            {
                "mcpServers": {
                    "fixture": {
                        "type": "stdio",
                        "command": sys.executable,
                        "args": [str(FIXTURE_SERVER)],
                    }
                }
            }
        ),
        encoding="utf-8",
    )
    return plugin_dir


async def _run_mcp_flow(temp_root: Path) -> None:
    manager = McpClientManager(
        {"fixture": McpStdioServerConfig(command=sys.executable, args=[str(FIXTURE_SERVER)])}
    )
    await manager.connect_all()
    try:
        registry = create_default_tool_registry(manager)
        tool = registry.get("mcp__fixture__hello")
        result = await tool.execute(
            tool.input_model.model_validate({"name": "system"}),
            ToolExecutionContext(cwd=temp_root),
        )
        if result.output != "fixture-hello:system":
            raise AssertionError(result.output)
        print("[mcp] PASS")
    finally:
        await manager.close()


async def _run_plugin_flow(temp_root: Path) -> None:
    plugin_source = _write_plugin(temp_root / "plugin-source")
    install_plugin_from_path(plugin_source)
    project = temp_root / "project"
    project.mkdir()
    try:
        plugins = load_plugins(Settings(), project)
        manager = McpClientManager(load_mcp_server_configs(Settings(), plugins))
        await manager.connect_all()
        try:
            registry = create_default_tool_registry(manager)
            skill_tool = registry.get("skill")
            skill_result = await skill_tool.execute(
                skill_tool.input_model.model_validate({"name": "FixtureSkill"}),
                ToolExecutionContext(cwd=project),
            )
            mcp_tool = registry.get("mcp__fixture-plugin_fixture__hello")
            mcp_result = await mcp_tool.execute(
                mcp_tool.input_model.model_validate({"name": "plugin"}),
                ToolExecutionContext(cwd=project),
            )
            if "Fixture skill content" not in skill_result.output or mcp_result.output != "fixture-hello:plugin":
                raise AssertionError("plugin flow failed")
            print("[plugin] PASS")
        finally:
            await manager.close()
    finally:
        uninstall_plugin("fixture-plugin")


async def _run_plugin_command_flow(temp_root: Path) -> None:
    registry = create_default_command_registry()
    context = _make_command_context(temp_root)
    plugin_source = _write_plugin(temp_root / "plugin-command-source")

    for raw in [
        f"/plugin install {plugin_source}",
        "/plugin disable fixture-plugin",
        "/plugin enable fixture-plugin",
        "/plugin uninstall fixture-plugin",
    ]:
        command, args = registry.lookup(raw)
        result = await command.handler(args, context)
        if result.message is None:
            raise AssertionError(f"no result for {raw}")
    print("[plugin-commands] PASS")


async def _run_bridge_flow(temp_root: Path) -> None:
    handle = await spawn_session(
        session_id="local-bridge",
        command="printf 'bridge-system-ok' > bridge.txt",
        cwd=temp_root,
    )
    await handle.process.wait()
    secret = WorkSecret(version=1, session_ingress_token="tok", api_base_url="http://localhost:8080")
    encoded = encode_work_secret(secret)
    decoded = decode_work_secret(encoded)
    url = build_sdk_url(decoded.api_base_url, "abc")
    if (temp_root / "bridge.txt").read_text(encoding="utf-8") != "bridge-system-ok":
        raise AssertionError("bridge file missing")
    if url != "ws://localhost:8080/v2/session_ingress/ws/abc":
        raise AssertionError(url)
    print("[bridge] PASS")


async def _run_command_flow(temp_root: Path) -> None:
    registry = create_default_command_registry()
    context = _make_command_context(temp_root)
    (temp_root / "src").mkdir()
    (temp_root / "src" / "demo.py").write_text("print('demo')\n", encoding="utf-8")
    for raw in [
        "/memory add Notes :: local command note",
        "/output-style set minimal",
        "/vim on",
        "/voice on",
        "/plan on",
        "/effort high",
        "/passes 2",
        "/tasks run printf 'local-command-task'",
        "/init",
    ]:
        command, args = registry.lookup(raw)
        await command.handler(args, context)
    doctor_command, doctor_args = registry.lookup("/doctor")
    doctor_result = await doctor_command.handler(doctor_args, context)
    if "- output_style: minimal" not in doctor_result.message:
        raise AssertionError(doctor_result.message)

    for raw, expected in [
        ("/files demo.py", "src/demo.py"),
        ("/session", "Session directory:"),
        ("/session tag local-smoke", "local-smoke.json"),
        ("/bridge show", "Bridge summary:"),
        ("/privacy-settings", "Privacy settings:"),
        ("/rate-limit-options", "Rate limit options:"),
        ("/release-notes", "Release Notes"),
        ("/upgrade", "Upgrade instructions:"),
    ]:
        command, args = registry.lookup(raw)
        result = await command.handler(args, context)
        if expected not in (result.message or ""):
            raise AssertionError(f"{raw} failed: {result.message}")

    print("[commands] PASS")


async def main() -> int:
    with tempfile.TemporaryDirectory(prefix="openharness-local-system-") as temp_dir:
        temp_root = Path(temp_dir)
        previous = {
            "OPENHARNESS_CONFIG_DIR": os.environ.get("OPENHARNESS_CONFIG_DIR"),
            "OPENHARNESS_DATA_DIR": os.environ.get("OPENHARNESS_DATA_DIR"),
        }
        os.environ["OPENHARNESS_CONFIG_DIR"] = str(temp_root / "config")
        os.environ["OPENHARNESS_DATA_DIR"] = str(temp_root / "data")
        try:
            await _run_mcp_flow(temp_root)
            await _run_plugin_flow(temp_root)
            await _run_plugin_command_flow(temp_root)
            await _run_bridge_flow(temp_root)
            await _run_command_flow(temp_root)
            print("Local system scenarios passed")
            return 0
        finally:
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
