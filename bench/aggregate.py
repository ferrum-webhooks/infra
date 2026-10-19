#!/usr/bin/env python3
"""Aggregate repeated k6 runs (the --summary-export JSON files written by run.sh): mean +/- sd per (variant, concurrency).

usage: aggregate.py DIR [--window 20] [--rep-re REGEX] [--md] [--vus 50,200] [--variants final,original]

File names are  <variant>_VUS_<n>_rep_<rep>.json  (run.sh slugifies the label "<variant> VUS=<n> rep=<rep>").
Throughput = completed requests in the measurement phase / window (k6's own `rate` includes warm-up and understates it).
"""
import argparse
import collections
import glob
import json
import re
import statistics

ap = argparse.ArgumentParser()
ap.add_argument("dir")
ap.add_argument("--window", type=float, default=20.0)
ap.add_argument("--rep-re", default="", help="only runs whose rep label matches this regex, e.g. '^[0-9]+$' (main) or '^a' (attribution)")
ap.add_argument("--md", action="store_true")
ap.add_argument("--vus", default="")
ap.add_argument("--variants", default="")
args = ap.parse_args()


def load(d, window, rep_re=""):
    groups = collections.defaultdict(list)
    for f in sorted(glob.glob(f"{d}/*.json")):
        m = re.match(r"(.+?)_VUS_(\d+)_rep_(.+)\.json$", f.split("/")[-1])
        if not m or (rep_re and not re.search(rep_re, m.group(3))):
            continue
        j = json.load(open(f))["metrics"]
        dur, cnt, err = (j.get(k) for k in ("http_req_duration{phase:measure}", "http_reqs{phase:measure}", "http_req_failed{phase:measure}"))
        key = (m.group(1), int(m.group(2)))
        if not cnt or not cnt["count"]:
            groups[key].append({"rps": 0.0, "p50": float("nan"), "p95": float("nan"), "p99": float("nan"), "err": 100.0, "n": 0})
        else:
            groups[key].append({"rps": cnt["count"] / window, "p50": dur["med"], "p95": dur["p(95)"], "p99": dur["p(99)"],
                                "err": err["value"] * 100, "n": int(cnt["count"])})
    return groups


def ms(xs):
    xs = [x for x in xs if x == x]
    return (statistics.mean(xs), statistics.stdev(xs) if len(xs) > 1 else 0.0) if xs else (float("nan"), 0.0)


def summarize(rows):
    return {k: ms([r[k] for r in rows]) for k in ("rps", "p50", "p95", "p99")} | {"err": statistics.mean(r["err"] for r in rows), "runs": len(rows),
                                                                                   "completed": statistics.mean(r["n"] for r in rows)}


if __name__ == "__main__":
    groups = load(args.dir, args.window, args.rep_re)
    vus = [int(x) for x in args.vus.split(",")] if args.vus else None
    order = args.variants.split(",") if args.variants else None
    keys = [k for k in groups if (vus is None or k[1] in vus) and (order is None or k[0] in order)]
    keys.sort(key=lambda k: (k[1], order.index(k[0]) if order else k[0]))
    if args.md:
        print("| Clients | Variant | Runs | Throughput (req/s) | p50 (ms) | p95 (ms) | Errors |")
        print("|---:|---|---:|---:|---:|---:|---:|")
    else:
        print(f"{'variant':12s} {'VUS':>4s} {'runs':>4s} {'req/s (mean ± sd)':>20s} {'p50 ms':>14s} {'p95 ms (mean ± sd)':>20s} {'errors %':>9s}")
    for k in keys:
        s = summarize(groups[k])
        if args.md:
            print(f"| {k[1]} | {k[0]} | {s['runs']} | {s['rps'][0]:.0f} ± {s['rps'][1]:.0f} | {s['p50'][0]:.1f} | {s['p95'][0]:.0f} ± {s['p95'][1]:.0f} | {s['err']:.2f}% |")
        else:
            print(f"{k[0]:12s} {k[1]:>4d} {s['runs']:>4d} {s['rps'][0]:>13.1f} ± {s['rps'][1]:<5.1f} {s['p50'][0]:>9.1f} ± {s['p50'][1]:<4.1f} "
                  f"{s['p95'][0]:>13.1f} ± {s['p95'][1]:<5.1f} {s['err']:>9.2f}")
