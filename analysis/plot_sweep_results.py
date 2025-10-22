#!/usr/bin/env python3
"""
Aggregate CSV results from sweep runs and plot p50/p95 latencies across N for direct and sequential patterns.

Usage:
    python3 analysis/plot_sweep_results.py --results-dir results_sweep --out-dir analysis/plots

This script expects CSV files named like:
  results_sweep/<pattern>/N<N>/benchmark_results_<pattern>_job<JID>.csv

It reads each CSV, computes median (p50) and p95 per payload size, then selects a few payload sizes to plot
p50/p95 vs N for each pattern.
"""

import argparse
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt


def load_csvs_for_pattern(results_dir: Path, pattern: str):
    pattern_dir = results_dir / pattern
    if not pattern_dir.exists():
        return {}
    data = {}
    for n_dir in sorted(pattern_dir.iterdir()):
        if not n_dir.is_dir():
            continue
        N = int(n_dir.name.lstrip('N'))
        files = list(n_dir.glob('*.csv'))
        if not files:
            continue
        # concatenate all CSVs for this N
        dfs = [pd.read_csv(f) for f in files]
        df = pd.concat(dfs, ignore_index=True)
        data[N] = df
    return data


def compute_stats(df: pd.DataFrame):
    # Expect columns: PayloadSize,LatencyMs,Success,... Pattern
    grouped = df[df['Success'] == 1].groupby('PayloadSize')['LatencyMs']
    stats = grouped.agg([('p50', lambda x: np.percentile(x,50)), ('p95', lambda x: np.percentile(x,95))])
    return stats


def plot_for_payloads(results, pattern, payloads, out_dir: Path):
    # results: dict N->DataFrame
    Ns = sorted(results.keys())
    all_stats = {N: compute_stats(results[N]) for N in Ns}

    out_dir.mkdir(parents=True, exist_ok=True)

    for p in payloads:
        p50s = []
        p95s = []
        for N in Ns:
            stats = all_stats[N]
            if p in stats.index:
                p50s.append(stats.loc[p,'p50'])
                p95s.append(stats.loc[p,'p95'])
            else:
                p50s.append(np.nan)
                p95s.append(np.nan)

        plt.figure(figsize=(8,5))
        plt.plot(Ns, p50s, marker='o', label='p50')
        plt.plot(Ns, p95s, marker='x', label='p95')
        plt.xlabel('Number of workers (N)')
        plt.ylabel('Latency (ms)')
        plt.title(f'{pattern}: latency vs N (payload={p} bytes)')
        plt.grid(True)
        plt.legend()
        plt.tight_layout()
        out_file = out_dir / f'{pattern}_latency_payload{p}.png'
        plt.savefig(out_file)
        plt.close()
        print('Wrote', out_file)


def main():
    default = [i for i in range(16, 8193, 16)]
    parser = argparse.ArgumentParser()
    parser.add_argument('--results-dir', type=Path, default=Path('results_sweep'))
    parser.add_argument('--out-dir', type=Path, default=Path('analysis/plots'))
    parser.add_argument('--payloads', type=int, nargs='*', default=default,
                        help='Payload sizes (only used if --per-payload is set)')
    parser.add_argument('--per-payload', action='store_true',
                        help='Also generate per-payload p50/p95 plots (disabled by default)')
    args = parser.parse_args()

    results_dir = args.results_dir
    out_dir = args.out_dir

    # Generate per-payload plots only if requested (disabled by default to speed up analysis)
    if args.per_payload:
        for pattern in ['direct','sequential']:
            print('Loading pattern', pattern)
            data = load_csvs_for_pattern(results_dir, pattern)
            if not data:
                print('  no data for', pattern)
                continue
            plot_for_payloads(data, pattern, args.payloads, out_dir)

        # Combined plot (p50) for a single payload across patterns (only when per-payload requested)
        payload = args.payloads[1] if len(args.payloads)>1 else args.payloads[0]
        plt.figure(figsize=(8,5))
        for pattern in ['direct','sequential']:
            data = load_csvs_for_pattern(results_dir, pattern)
            if not data:
                continue
            Ns = sorted(data.keys())
            p50s = []
            for N in Ns:
                stats = compute_stats(data[N])
                p50s.append(stats.loc[payload,'p50'] if payload in stats.index else np.nan)
            plt.plot(Ns, p50s, marker='o', label=pattern)
        plt.xlabel('Number of workers (N)')
        plt.ylabel('Latency p50 (ms)')
        plt.title(f'Compare p50 for payload={payload} bytes')
        plt.legend()
        plt.grid(True)
        out_file = out_dir / f'compare_p50_payload{payload}.png'
        out_dir.mkdir(parents=True, exist_ok=True)
        plt.savefig(out_file)
        plt.close()
        print('Wrote', out_file)

    # --- Overall mean and p95 comparison across patterns ---
    # For each pattern and N compute overall mean latency and overall p95 across all payloads
    def compute_overall_stats(df: pd.DataFrame):
        lat = df[df['Success'] == 1]['LatencyMs'].dropna()
        if lat.empty:
            return (np.nan, np.nan)
        return (lat.mean(), np.percentile(lat, 95))

    patterns = ['direct', 'sequential']
    mean_fig, axes = plt.subplots(1, 2, figsize=(14,5), sharex=True)
    for pattern in patterns:
        data = load_csvs_for_pattern(results_dir, pattern)
        if not data:
            continue
        Ns = sorted(data.keys())
        means = []
        p95s = []
        for N in Ns:
            mean_val, p95_val = compute_overall_stats(data[N])
            means.append(mean_val)
            p95s.append(p95_val)

        axes[0].plot(Ns, means, marker='o', label=pattern)
        axes[1].plot(Ns, p95s, marker='o', label=pattern)

    axes[0].set_xlabel('Number of workers (N)')
    axes[0].set_ylabel('Overall mean latency (ms)')
    axes[0].set_title('Overall mean latency vs N')
    axes[0].grid(True)
    axes[0].legend()

    axes[1].set_xlabel('Number of workers (N)')
    axes[1].set_ylabel('Overall p95 latency (ms)')
    axes[1].set_title('Overall p95 latency vs N')
    axes[1].grid(True)
    axes[1].legend()

    out_file2 = out_dir / 'compare_overall_mean_p95.png'
    mean_fig.tight_layout()
    mean_fig.savefig(out_file2)
    plt.close(mean_fig)
    print('Wrote', out_file2)

if __name__ == '__main__':
    main()
