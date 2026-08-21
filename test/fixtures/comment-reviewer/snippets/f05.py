def fetch_after_restart(url):
    # Wait 250ms before the first attempt: the edge cache serves a stale 503
    # for ~200ms after a backend restart, so an immediate request re-reads
    # that cached error instead of reaching the new backend.
    time.sleep(0.25)
    return requests.get(url, timeout=5)
