import ssl
import sys
import threading
from pathlib import Path
import http.client
from concurrent.futures import ThreadPoolExecutor, as_completed

HTTP_PORTS = [80, 9080]
HTTPS_PORTS = [9443, 9043]
PATHS = ["/", "/cmd/"]

# Require >=2 indicators to reduce false positives
INDICATORS = [
    "Commands with JSP",
    'name="cmd"',
    '<FORM METHOD="POST"',
    "<textarea",
]

# Speed/accuracy knobs
TIMEOUT = 5.0          # increase to reduce misses
MAX_WORKERS = 30       # adjust up if many hosts (50 is ok on strong machines)

RESULTS_FILE = "webshell_results.txt"
lock = threading.Lock()


def fetch(host: str, port: int, scheme: str, path: str) -> tuple[int | None, str]:
    try:
        if scheme == "https":
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            conn = http.client.HTTPSConnection(host, port, timeout=TIMEOUT, context=ctx)
        else:
            conn = http.client.HTTPConnection(host, port, timeout=TIMEOUT)

        conn.request("GET", path, headers={"User-Agent": "webshell-detector/fast-safe", "Connection": "close"})
        resp = conn.getresponse()
        status = resp.status
        raw = resp.read()
        conn.close()

        try:
            text = raw.decode("utf-8", errors="replace")
        except Exception:
            text = raw.decode("latin-1", errors="replace")  # matches your ISO-8859-1 case

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


def build_tasks(host: str):
    # HTTP
    for port in HTTP_PORTS:
        for path in PATHS:
            yield host, port, "http", path
    # HTTPS
    for port in HTTPS_PORTS:
        for path in PATHS:
            yield host, port, "https", path


def main() -> int:
    servers_path = Path("servers.txt")
    if not servers_path.exists():
        print("servers.txt not found.", file=sys.stderr)
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

    # clear results
    Path(RESULTS_FILE).write_text("", encoding="utf-8")

    # de-dupe so same ip:port:path only written once
    seen = set()

    futures = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for host in hosts:
            for (h, p, scheme, path) in build_tasks(host):
                url = f"{scheme}://{h}:{p}{path}"
                print(f"[*] GET {url}")
                futures.append(ex.submit(fetch, h, p, scheme, path))

        # We need task context for each future; easiest is to re-submit with context:
        # So instead, re-do submission properly:
    # (Redo with context mapping)
    futures = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        fmap = {}
        for host in hosts:
            for (h, p, scheme, path) in build_tasks(host):
                url = f"{scheme}://{h}:{p}{path}"
                print(f"[*] GET {url}")
                fut = ex.submit(fetch, h, p, scheme, path)
                fmap[fut] = (h, p, path)

        for fut in as_completed(fmap):
            h, p, path = fmap[fut]
            status, body = fut.result()

            if status == 200 and looks_like_shell(body):
                key = f"{h}:{p}{path}"
                with lock:
                    if key not in seen:
                        seen.add(key)
                        line = f"[+] warning Web Shell found on {key}"
                        print(line)
                        with open(RESULTS_FILE, "a", encoding="utf-8") as f:
                            f.write(line + "\n")

    print(f"Done. Results file: {RESULTS_FILE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
