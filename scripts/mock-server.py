
#!/usr/bin/env python3
"""
Mock Anthropic usage API server for testing ClaudeScope.

Usage:
    python3 scripts/mock-server.py [--port 8080] [--scenario normal]

Scenarios:
    normal              - Moderate usage (5h: 25%, 7d: 45%)
    high                - Near rate limit (5h: 85%, 7d: 92%)
    maxed               - Fully rate limited (5h: 100%, 7d: 100%)
    low                 - Barely used (5h: 2%, 7d: 5%)
    extra               - Extra usage enabled with credits
    extra_high          - Extra usage near limit
    per_model           - Per-model breakdown (Opus + Sonnet)
    all_features        - Everything enabled: per-model, extra usage
    possible_usage_limit - Possible usage limit news (2026-08-09)
    unauthenticated     - Returns 401 for all requests
    rate_limited        - Returns 429 with Retry-After header
    error               - Returns 500 server error

To point the app at this server, modify UsageService.swift:
    private let usageEndpoint = URL(string: "http://localhost:8080/api/oauth/usage")!

Then restart the app. This only mocks the usage endpoint for refresh/testing.
The server also exposes a fake /v1/oauth/token endpoint for manual experiments,
but the app does not use it unless you explicitly repoint its auth flow too.
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler


def iso_future(hours=0, days=0):
    dt = datetime.now(timezone.utc) + timedelta(hours=hours, days=days)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.%f+00:00")


SCENARIOS = {
    "normal": {
        "five_hour": {"utilization": 25.0, "resets_at": iso_future(hours=3)},
        "seven_day": {"utilization": 45.0, "resets_at": iso_future(days=4)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
    "high": {
        "five_hour": {"utilization": 85.0, "resets_at": iso_future(hours=1)},
        "seven_day": {"utilization": 92.0, "resets_at": iso_future(days=2)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
    "maxed": {
        "five_hour": {"utilization": 100.0, "resets_at": iso_future(hours=4)},
        "seven_day": {"utilization": 100.0, "resets_at": iso_future(days=6)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
    "low": {
        "five_hour": {"utilization": 2.0, "resets_at": iso_future(hours=4)},
        "seven_day": {"utilization": 5.0, "resets_at": iso_future(days=6)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
    "extra": {
        "five_hour": {"utilization": 40.0, "resets_at": iso_future(hours=2)},
        "seven_day": {"utilization": 60.0, "resets_at": iso_future(days=3)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": True,
            "monthly_limit": 28000,
            "used_credits": 5230,
            "utilization": 18.68,
        },
    },
    "extra_high": {
        "five_hour": {"utilization": 95.0, "resets_at": iso_future(hours=1)},
        "seven_day": {"utilization": 98.0, "resets_at": iso_future(days=1)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": True,
            "monthly_limit": 10000,
            "used_credits": 9450,
            "utilization": 94.5,
        },
    },
    "per_model": {
        "five_hour": {"utilization": 35.0, "resets_at": iso_future(hours=3)},
        "seven_day": {"utilization": 55.0, "resets_at": iso_future(days=4)},
        "seven_day_opus": {"utilization": 70.0, "resets_at": iso_future(days=5)},
        "seven_day_sonnet": {"utilization": 15.0, "resets_at": iso_future(days=5)},
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
    "all_features": {
        "five_hour": {"utilization": 55.0, "resets_at": iso_future(hours=2)},
        "seven_day": {"utilization": 75.0, "resets_at": iso_future(days=3)},
        "seven_day_opus": {"utilization": 80.0, "resets_at": iso_future(days=4)},
        "seven_day_sonnet": {"utilization": 30.0, "resets_at": iso_future(days=4)},
        "seven_day_oauth_apps": {"utilization": 10.0, "resets_at": iso_future(days=4)},
        "seven_day_cowork": {"utilization": 5.0, "resets_at": iso_future(days=4)},
        "iguana_necktie": None,
        "extra_usage": {
            "is_enabled": True,
            "monthly_limit": 50000,
            "used_credits": 12500,
            "utilization": 25.0,
        },
    },
    # Issue #3: Possible usage-limit news (2026-08-09)
    # Simulates the state where a possible usage limit has been announced/detected.
    # The iguana_necktie field carries the possible-limit signal from the API.
    "possible_usage_limit": {
        "five_hour": {"utilization": 50.0, "resets_at": iso_future(hours=2)},
        "seven_day": {"utilization": 65.0, "resets_at": iso_future(days=3)},
        "seven_day_opus": None,
        "seven_day_sonnet": None,
        "seven_day_oauth_apps": None,
        "seven_day_cowork": None,
        "iguana_necktie": {
            "possible_limit": True,
            "message": "Possible usage limit may apply to your account.",
            "effective_date": "2026-08-09",
        },
        "extra_usage": {
            "is_enabled": False,
            "monthly_limit": None,
            "used_credits": None,
            "utilization": None,
        },
    },
}


class MockHandler(BaseHTTPRequestHandler):
    scenario = "normal"

    def log_message(self, fmt, *args):
        print(f"[mock-server] {fmt % args}", file=sys.stderr)

    def _send_json(self, status: int, body: object, extra_headers: dict = None):
        data = json.dumps(body, indent=2).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        if extra_headers:
            for k, v in extra_headers.items():
                self.send_header(k, v)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path.startswith("/api/oauth/usage"):
            self._handle_usage()
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path.startswith("/v1/oauth/token"):
            self._handle_token()
        else:
            self._send_json(404, {"error": "not found"})

    def _handle_usage(self):
        s = self.scenario

        if s == "unauthenticated":
            self._send_json(401, {"error": "unauthorized"})
            return
        if s == "rate_limited":
            self._send_json(
                429,
                {"error": "rate limited"},
                extra_headers={"Retry-After": "60"},
            )
            return
        if s == "error":
            self._send_json(500, {"error": "internal server error"})
            return

        data = SCENARIOS.get(s, SCENARIOS["normal"])
        self._send_json(200, data)

    def _handle_token(self):
        self._send_json(
            200,
            {
                "access_token": "mock_access_token_12345",
                "token_type": "Bearer",
                "expires_in": 3600,
                "refresh_token": "mock_refresh_token_67890",
                "scope": "usage:read",
            },
        )


def main():
    parser = argparse.ArgumentParser(description="Mock Anthropic usage API server")
    parser.add_argument("--port", type=int, default=8080, help="Port to listen on")
    parser.add_argument(
        "--scenario",
        default="normal",
        choices=list(SCENARIOS.keys())
        + ["unauthenticated", "rate_limited", "error"],
        help="Response scenario to simulate",
    )
    args = parser.parse_args()

    MockHandler.scenario = args.scenario

    server = HTTPServer(("localhost", args.port), MockHandler)
    print(
        f"[mock-server] Listening on http://localhost:{args.port} "
        f"(scenario: {args.scenario})",
        file=sys.stderr,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[mock-server] Shutting down.", file=sys.stderr)


if __name__ == "__main__":
    main()
