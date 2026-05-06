#!/usr/bin/env python3
"""
Benchmark Ollama/vLLM endpoint — outputs JSON for GHA step summary.
Usage: python3 benchmark.py <endpoint> <model>
"""
import sys, time, json, statistics
import urllib.request, urllib.error

PROMPTS = [
    "Explain the CAP theorem in 3 sentences.",
    "Write a Python function to merge two sorted lists.",
    "What is the difference between TCP and UDP?",
]

def query(url, model, prompt):
    payload = json.dumps({
        "model": model,
        "messages": [{"role": "user", "content": prompt}],
        "stream": False,
    }).encode()

    req = urllib.request.Request(
        f"{url}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
    elapsed = time.monotonic() - t0

    tokens = data.get("eval_count", 0)
    return {"tokens": tokens, "elapsed": elapsed, "tps": tokens / elapsed if elapsed else 0}

def main():
    if len(sys.argv) < 3:
        print("Usage: benchmark.py <endpoint> <model>", file=sys.stderr)
        sys.exit(1)

    endpoint, model = sys.argv[1], sys.argv[2]
    results = []

    for i, prompt in enumerate(PROMPTS):
        print(f"[{i+1}/{len(PROMPTS)}] Running: {prompt[:50]}...")
        try:
            r = query(endpoint, model, prompt)
            results.append(r)
            print(f"  {r['tokens']} tokens in {r['elapsed']:.1f}s = {r['tps']:.1f} tok/s")
        except Exception as e:
            print(f"  ERROR: {e}", file=sys.stderr)

    if results:
        avg_tps = statistics.mean(r["tps"] for r in results)
        avg_elapsed = statistics.mean(r["elapsed"] for r in results)
        print(f"\nSummary: avg {avg_tps:.1f} tok/s, avg latency {avg_elapsed:.1f}s over {len(results)} prompts")
        summary = {"endpoint": endpoint, "model": model, "avg_tps": avg_tps, "avg_latency_s": avg_elapsed, "runs": len(results)}
        print(json.dumps(summary))

if __name__ == "__main__":
    main()
