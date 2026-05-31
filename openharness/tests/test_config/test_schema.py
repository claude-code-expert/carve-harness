"""Schema regressions for openharness.config.schema channel configs."""

from __future__ import annotations

from openharness.config.schema import TelegramConfig


class TestTelegramConfig:
    def test_reply_to_message_field_is_declared_with_true_default(self):
        """Regression for #243: every outbound send raises AttributeError when
        ``reply_to_message`` is not in the parsed config because the field
        existed only as an interactive ``ohmo init`` prompt, not on the
        pydantic model. The CLI default is ``True``; the schema default
        mirrors that so non-interactive and hand-written configs behave the
        same as interactive configs accepting the default.
        """
        config = TelegramConfig()
        assert config.reply_to_message is True

    def test_reply_to_message_accessible_when_legacy_config_omits_field(self):
        """``ohmo init --no-interactive`` and pre-0.1.9 hand-written
        ``gateway.json`` files don't include ``reply_to_message``. Attribute
        access on the parsed instance must not raise — that AttributeError
        was the root cause of #243 (every outbound Telegram send crashed).
        """
        config = TelegramConfig.model_validate(
            {"token": "test-token", "chat_id": "12345", "allow_from": ["12345"]}
        )

        assert config.reply_to_message is True

    def test_reply_to_message_explicit_false_is_honored(self):
        config = TelegramConfig.model_validate(
            {"token": "t", "chat_id": "1", "reply_to_message": False}
        )

        assert config.reply_to_message is False

    def test_bot_name_defaults_to_ohmo(self):
        config = TelegramConfig()

        assert config.bot_name == "ohmo"
