import ssl
import sys
from pathlib import Path
import http.client
from concurrent.futures import ThreadPoolExecutor, as_completed

HTTP_PORTS = [80, 9080]
HTTPS_PORTS = [9443, 9043]
PATHS = ["/", "/cmd/"]

INDICATORS = [
    "Commands with JSP",
    'name="cmd"',
    '<FORM METHOD="POST"',
    "<textarea",
]

# Speed knobs
TIMEOUT = 2.5          # per request seconds
MAX_WORKERS = 20       # parallel requests
EARLY_STOP_PER_HOST = True  # stop scanning a host after first match

RESULTS_FILE = "webshell_results.txt"


def fetch(host: str, port: int, scheme: str, path: str) -> tuple[int | None, str]:
    try:
        if scheme == "https":
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            conn = http.client.HTTPSConnection(host, port, timeout=TIMEOUT, context=ctx)
        else:
            conn = http.client.HTTPConnection(host, port, timeout=TIMEOUT)

        conn.request("GET", path, headers={"User-Agent": "webshell-detector/fast", "Connection": "close"})
        resp = conn.getresponse()
        status = resp.status
        raw = resp.read()
        conn.close()

        # decode robustly
        try:
            text = raw.decode("utf-8", errors="replace")
        except Exception:
            text = raw.decode("latin-1", errors="replace")

        return status, text
    except Exception:
        return None, ""


def looks_like_shell(body: str) -> bool:
    b = body.lower()
    hits = 0
    for s in INDICATORS:
        if s.lower() in b:
            hits += 1
    return hits >= 2


def tasks_for_host(host: str):
    for port in HTTP_PORTS:
        for path in PATHS:
            yield host, port, "http", path
    for port in HTTPS_PORTS:
        for path in PATHS:
            yield host, port, "https", path


def main() -> int:
    servers_path = Path("servers.txt")
    if not servers_path.exists():
        print("servers.txt not found in current folder.", file=sys.stderr)
        return 2

    hosts = []
    for line in servers_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        hosts.append(line)

    if not hosts:
        print("No valid hosts in servers.txt", file=sys.stderr)
        return 2

    Path(RESULTS_FILE).write_text("", encoding="utf-8")

    # Keep results in memory then flush once (faster)
    found_lines = []

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for host in hosts:
            futures = {}
            for (h, p, scheme, path) in tasks_for_host(host):
                url = f"{scheme}://{h}:{p}{path}"
                print(f"[*] GET {url}")
                fut = ex.submit(fetch, h, p, scheme, path)
                futures[fut] = (h, p, path)

            matched = False
            for fut in as_completed(futures):
                h, p, path = futures[fut]
                status, body = fut.result()

                if not matched and status == 200 and looks_like_shell(body):
                    line = f"[+] warning Web Shell found on {h}:{p}{path}"
                    print(line)
                    found_lines.append(line)
                    matched = True

                    if EARLY_STOP_PER_HOST:
                        # We can't truly cancel in-flight socket ops reliably,
                        # but we can stop waiting and move on.
                        break

    # Write results once
    with open(RESULTS_FILE, "a", encoding="utf-8") as f:
        for line in found_lines:
            f.write(line + "\n")

    print(f"Done. Results file: {RESULTS_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
