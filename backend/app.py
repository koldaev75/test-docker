"""Минимальный backend: /health, /whoami (эхо заголовков), /hits (счётчик в Redis + запись в Postgres)."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg
import redis

PG_DSN = (
    f"host={os.environ['POSTGRES_HOST']} dbname={os.environ['POSTGRES_DB']} "
    f"user={os.environ['POSTGRES_USER']} password={os.environ['POSTGRES_PASSWORD']} connect_timeout=3"
)
r = redis.Redis(
    host=os.environ["REDIS_HOST"], password=os.environ["REDIS_PASSWORD"],
    socket_connect_timeout=3, decode_responses=True,
)


def pg():
    return psycopg.connect(PG_DSN, autocommit=True)


with pg() as c:
    c.execute("CREATE TABLE IF NOT EXISTS hits (id serial PRIMARY KEY, ip text, ts timestamptz DEFAULT now())")


class H(BaseHTTPRequestHandler):
    def send_json(self, code, obj):
        body = json.dumps(obj, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            try:
                with pg() as c:
                    c.execute("SELECT 1")
                r.ping()
                return self.send_json(200, {"status": "ok"})
            except Exception as e:
                return self.send_json(503, {"status": "fail", "error": str(e)})
        if self.path == "/hits":
            ip = self.headers.get("X-Forwarded-For", self.client_address[0])
            with pg() as c:
                c.execute("INSERT INTO hits (ip) VALUES (%s)", (ip,))
                total = c.execute("SELECT count(*) FROM hits").fetchone()[0]
            return self.send_json(200, {"redis_counter": r.incr("hits"), "postgres_rows": total})
        self.send_json(200, {"client": self.client_address[0], "path": self.path, "headers": dict(self.headers)})

    do_POST = do_PUT = do_GET

    def log_message(self, fmt, *args):
        if self.path != "/health":
            super().log_message(fmt, *args)


ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
