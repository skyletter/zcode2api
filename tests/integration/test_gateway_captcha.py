"""验证码惰性策略回归（2026-09-29 上游 3.14.4「关闭模型请求验证码校验」）。

- 首投不带参数：上游不挑战时，对话链路与求解器解耦（零取码）
- 上游仍挑战（3007）：取参数重试成功；首投被挑战不得误清参数池
"""

from __future__ import annotations

import pytest

from tests.conftest import seed_account

_LAZY_JWT = "hlazy01.eyJzdWIiOiJhIn0.sig"
_RETRY_JWT = "hretry1.eyJzdWIiOiJiIn0.sig"
_MSG = {"model": "GLM-5.3", "messages": [{"role": "user", "content": "hi"}]}
_CAPTCHA_HEADER = "x-aliyun-captcha-verify-param"


@pytest.mark.integration
class TestLazyCaptcha:
    async def test_first_attempt_sends_no_captcha(self, gateway_client, fresh_app, stub_captcha):
        client, mock = gateway_client
        seed_account(fresh_app, _LAZY_JWT, name="cap-lazy")

        res = await client.post("/v1/messages", json=_MSG)
        assert res.status_code == 200
        _, path, headers, _ = mock.state.calls[-1]
        assert path == "/api/v1/zcode-plan/anthropic/v1/messages"
        assert _CAPTCHA_HEADER not in headers
        assert stub_captcha.solve_calls == 0

    async def test_challenge_retries_with_param(self, gateway_client, fresh_app, stub_captcha):
        client, mock = gateway_client
        seed_account(fresh_app, _RETRY_JWT, name="cap-retry")
        mock.state.sequences[_RETRY_JWT[:16]] = ["captcha_3007", "ok"]

        res = await client.post("/v1/messages", json=_MSG)
        assert res.status_code == 200
        assert stub_captcha.solve_calls == 1
        # 首投未带参数，被挑战只说明"需要参数"，不得误清池（带参数被拒才清池）
        assert stub_captcha.invalidated == 0
        _, _, headers, _ = mock.state.calls[-1]
        assert headers.get(_CAPTCHA_HEADER) == "mock-verify-param"
