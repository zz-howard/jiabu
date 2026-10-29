#!/usr/bin/env python3
"""Loopback-only Responses SSE fixture. Python standard library, synthetic data.

Control: POST /__control/script {match, turns}; POST /__control/release {barrier};
GET /__control/events. A turn can contain text, tools, barrier, error, or
omit_completed. No upstream forwarding, credential logging or request dumps.
"""
import argparse
import json
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Scripts:
    def __init__(self):
        self.lock = threading.Lock()
        self.scripts = []
        self.sessions = {}
        self.barriers = {}
        self.events = []

    def select(self, request):
        session = request.get("prompt_cache_key", "")
        with self.lock:
            index = self.sessions.get(session)
            if index is None:
                text = json.dumps(request.get("input", []), ensure_ascii=False)
                matches = [i for i, script in enumerate(self.scripts)
                           if script["match"] in text]
                if not matches:
                    raise ValueError("No fixture script matches this request")
                index = matches[-1]
                self.sessions[session] = index
            script = self.scripts[index]
            turn = script["cursor"]
            script["cursor"] += 1
            self.events.append({"script": index, "turn": turn})
            if turn >= len(script["turns"]):
                raise ValueError("Fixture script exhausted")
            return index, turn, script["turns"][turn]


STATE = Scripts()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def body(self):
        length = int(self.headers.get("Content-Length", "0"))
        if not 0 <= length <= 8 * 1024 * 1024:
            raise ValueError("Invalid fixture request size")
        return json.loads(self.rfile.read(length))

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            self.reply(200, {"ok": True})
        elif self.path == "/__control/events":
            with STATE.lock:
                result = list(STATE.events)
            self.reply(200, {"events": result})
        else:
            self.reply(404, {"error": "fixture_path_not_found"})

    def do_POST(self):
        try:
            if self.path == "/oauth/token":
                self.rfile.read(int(self.headers.get("Content-Length", "0")))
                self.reply(200, {"access_token": "synthetic-refreshed", "refresh_token": "synthetic-refresh", "expires_in": 3600, "token_type": "Bearer"})
                return
            request = self.body()
            if self.path == "/__control/script":
                if not isinstance(request.get("match"), str) or not isinstance(request.get("turns"), list):
                    raise ValueError("Invalid fixture script")
                with STATE.lock:
                    index = len(STATE.scripts)
                    STATE.scripts.append({**request, "cursor": 0})
                self.reply(200, {"script": index})
                return
            if self.path == "/__control/release":
                with STATE.lock:
                    gate = STATE.barriers.setdefault(request["barrier"], threading.Event())
                gate.set()
                self.reply(200, {"ok": True})
                return
            if self.path != "/v1/responses":
                self.reply(404, {"error": "fixture_path_not_found"})
                return
            if request.get("stream") is not True or request.get("store") is not False:
                raise ValueError("Expected stream=true and store=false")
            if not self.headers.get("Authorization", "").startswith("Bearer synthetic-"):
                self.reply(401, {"error": {"code": "invalid_token"}})
                return
            script, turn_index, turn = STATE.select(request)
            if "before_barrier" in turn:
                with STATE.lock:
                    gate = STATE.barriers.setdefault(turn["before_barrier"], threading.Event())
                if not gate.wait(120):
                    raise ValueError("Fixture barrier timed out")
            if "http_error" in turn:
                self.reply(turn["http_error"], {"error": {"code": turn.get("error", "insufficient_quota")}})
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Connection", "close")
            self.end_headers()
            self.close_connection = True

            def emit(event):
                raw = ("event: " + event["type"] + "\r\ndata: " + json.dumps(event, ensure_ascii=False) + "\r\n\r\n").encode()
                # Split UTF-8 as well as SSE frames, exercising the real decoder.
                for start in range(0, len(raw), 17):
                    self.wfile.write(raw[start:start + 17])
                    self.wfile.flush()

            text = turn.get("text", "")
            for start in range(0, len(text), 3):
                emit({"type": "response.output_text.delta", "output_index": 0, "delta": text[start:start + 3]})
                if turn.get("slow"):
                    time.sleep(0.02)
            if "barrier" in turn:
                with STATE.lock:
                    gate = STATE.barriers.setdefault(turn["barrier"], threading.Event())
                if not gate.wait(120):
                    raise ValueError("Fixture barrier timed out")
            if "error" in turn:
                emit({"type": "response.failed", "response": {"error": {"code": turn["error"]}}})
                return
            if text:
                emit({"type": "response.output_item.done", "output_index": 0,
                      "item": {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": text}]}})
            for index, tool in enumerate(turn.get("tools", []), start=1):
                emit({"type": "response.output_item.done", "output_index": index,
                      "item": {"type": "function_call", "call_id": f"fixture-{script}-{turn_index}-{index}",
                               "name": tool["name"], "arguments": json.dumps(tool["arguments"], ensure_ascii=False)}})
            if not turn.get("omit_completed"):
                emit({"type": "response.completed", "response": {"status": "completed", "output": [],
                      "usage": {"input_tokens": 20, "output_tokens": 10, "input_tokens_details": {"cached_tokens": 0}}}})
        except (BrokenPipeError, ConnectionResetError):
            pass
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            # Fixed diagnostics only; never echo request content or credentials.
            if not self.close_connection:
                self.reply(422, {"error": "invalid_fixture_script_or_request"})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    server.serve_forever()


if __name__ == "__main__":
    main()
