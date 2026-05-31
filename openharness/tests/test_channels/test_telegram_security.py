from __future__ import annotations

import logging
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from openharness.channels.bus.queue import MessageBus
from openharness.channels.impl.manager import ChannelManager
from openharness.channels.impl.telegram import TelegramChannel, silence_telegram_token_url_loggers
from openharness.config.schema import Config, TelegramConfig


def test_silence_telegram_token_url_loggers_raises_dependency_log_levels():
    for name in ("httpx", "httpcore", "telegram.ext"):
        logging.getLogger(name).setLevel(logging.INFO)

    silence_telegram_token_url_loggers()

    for name in ("httpx", "httpcore", "telegram.ext"):
        assert logging.getLogger(name).level == logging.WARNING


@pytest.mark.asyncio
async def test_telegram_start_and_help_use_configured_bot_name():
    channel = TelegramChannel(TelegramConfig(token="token", bot_name="ohmo", allow_from=["*"]), MessageBus())
    message = SimpleNamespace(chat_id=1, reply_text=AsyncMock())
    user = SimpleNamespace(first_name="Jabin")
    update = SimpleNamespace(message=message, effective_user=user)

    await channel._on_start(update, SimpleNamespace())
    await channel._on_help(update, SimpleNamespace())

    start_text = message.reply_text.await_args_list[0].args[0]
    help_text = message.reply_text.await_args_list[1].args[0]
    assert "I'm ohmo" in start_text
    assert "ohmo commands" in help_text
    assert "nanobot" not in start_text
    assert "nanobot" not in help_text


@pytest.mark.asyncio
async def test_telegram_error_handler_records_last_error():
    channel = TelegramChannel(TelegramConfig(token="token", allow_from=["*"]), MessageBus())

    await channel._on_error(None, SimpleNamespace(error=RuntimeError("poll failed")))

    assert channel.last_error == "poll failed"


@pytest.mark.asyncio
async def test_channel_manager_records_start_failure_on_channel():
    bus = MessageBus()
    manager = ChannelManager(Config(), bus)

    class BrokenChannel:
        async def start(self):
            raise RuntimeError("boom")

    channel = BrokenChannel()
    await manager._start_channel("telegram", channel)  # type: ignore[arg-type]

    assert getattr(channel, "last_error") == "boom"
