#!/usr/bin/env python3
import json
import os
import urllib.error
import urllib.request

import pytest


def _get_access_token() -> str:
    static_token = os.getenv("DIRECTUS_TOKEN")
    if static_token:
        return static_token

    email = os.getenv("ADMIN_EMAIL")
    password = os.getenv("ADMIN_PASSWORD")
    if not email or not password:
        pytest.skip("Set DIRECTUS_TOKEN or ADMIN_EMAIL/ADMIN_PASSWORD to run this test")

    login_url = os.getenv("DIRECTUS_LOGIN_URL", "http://localhost:8055/auth/login")
    payload = json.dumps({"email": email, "password": password}).encode("utf-8")
    req = urllib.request.Request(
        login_url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(req) as response:
        body = json.loads(response.read().decode("utf-8"))

    token = body.get("data", {}).get("access_token")
    if not token:
        pytest.fail(f"Login succeeded but no access token was returned: {body}")

    return token


def test_endpoint() -> None:
    url = os.getenv("REFRESH_DASH_URL", "http://localhost:8055/refresh-dash")
    token = _get_access_token()
    req = urllib.request.Request(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="GET",
    )

    try:
        with urllib.request.urlopen(req) as response:
            status = response.status
            body = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace")
        pytest.fail(f"HTTP {exc.code} from {url}: {details}")

    assert status == 200
    assert body.get("ok") is True
    assert isinstance(body.get("before"), dict)
    assert isinstance(body.get("after"), dict)
    assert "at" in body
