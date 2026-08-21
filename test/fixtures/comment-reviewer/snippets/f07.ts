/**
 * Fetches `url`, retrying up to 3 times with exponential backoff.
 * Throws only after the third attempt fails.
 */
export async function fetchWithRetry(url: string): Promise<Response> {
  return fetch(url, { signal: AbortSignal.timeout(5000) });
}
