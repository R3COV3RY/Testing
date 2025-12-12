import ssl
import sys
from pathlib import Path
from urllib.parse import urlunparse

import http.client

HTTP_PORTS = [80, 9080]
HTTPS_PORTS = [9443, 9043]
PATHS = ["/", "/cmd/"]

# Indicators from your sample page (use >= 2 to avoid false positives)
INDICATORS = [
    "Commands with JSP",
    'name="cmd"',
    '<FORM METHOD="POST"',
    "<textarea",
]

TIMEOUT = 5  # seconds
RESULTS_FILE = "webshell_results.txt"


def fetch(host: str, port: int, scheme: str, path: str) -> tuple[int | None, str]:
    """
    Returns (status_code, body_text). status_code None if connection failed.
    """
    try:
        if scheme == "https":
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            conn = http.client.HTTPSConnection(host, port, timeout=TIMEOUT, context=ctx)
        else:
            conn = http.client.HTTPConnection(host, port, timeout=TIMEOUT)

        # Send minimal headers; keep-alive off for simplicity
        conn.request("GET", path, headers={"User-Agent": "webshell-detector/1.0", "Connection": "close"})
        resp = conn.getresponse()
        status = resp.status

        raw = resp.read()  # bytes
        conn.close()

        # Decode robustly: try utf-8, fallback to latin-1 (covers ISO-8859-1 from your response)
        try:
            text = raw.decode("utf-8", errors="replace")
        except Exception:
            text = raw.decode("latin-1", errors="replace")

        return status, text
    except Exception:
        return None, ""


def looks_like_shell(body: str) -> bool:
    body_lower = body.lower()
    hits = 0
    for s in INDICATORS:
        if s.lower() in body_lower:
            hits += 1
    return hits >= 2


def main() -> int:
    servers_path = Path("servers.txt")
    if not servers_path.exists():
        print("servers.txt not found in current folder.", file=sys.stderr)
        return 2

    # Read hosts
    hosts = []
    for line in servers_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        hosts.append(line)

    if not hosts:
        print("No valid hosts in servers.txt", file=sys.stderr)
        return 2

    # Clear results file
    Path(RESULTS_FILE).write_text("", encoding="utf-8")

    for host in hosts:
        # HTTP ports
        for port in HTTP_PORTS:
            for path in PATHS:
                url = f"http://{host}:{port}{path}"
                print(f"[*] GET {url}")
                status, body = fetch(host, port, "http", path)
                if status == 200 and looks_like_shell(body):
                    line = f"[+] warning Web Shell found on {host}:{port}{path}"
                    print(line)
                    with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                        f.write(line + "\n")

        # HTTPS ports
        for port in HTTPS_PORTS:
            for path in PATHS:
                url = f"https://{host}:{port}{path}"
                print(f"[*] GET {url}")
                status, body = fetch(host, port, "https", path)
                if status == 200 and looks_like_shell(body):
                    line = f"[+] warning Web Shell found on {host}:{port}{path}"
                    print(line)
                    with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                        f.write(line + "\n")

    print(f"Done. Results file: {RESULTS_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
