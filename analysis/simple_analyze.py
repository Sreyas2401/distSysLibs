#!/usr/bin/env python3
"""
Simple Analysis Script for Communication Latency Benchmarks
Analyzes and compares results from direct, sequential, and two-hop patterns with individual plots
"""

import csv
import os
import statistics

def load_pattern_data(pattern):
    """Load benchmark data for a specific pattern"""
    # Ensure csvfiles directory exists
    if not os.path.exists("csvfiles"):
        print(f"csvfiles directory not found - no benchmark data available")
        return None
        
    filename = f"csvfiles/benchmark_results_{pattern}.csv"
    if not os.path.exists(filename):
        print(f"Warning: {filename} not found, skipping {pattern} pattern")
        return None
    
    try:
        measurements = []
        with open(filename, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                if row['Success'] == '1':  # Only successful measurements
                    measurements.append({
                        'payload_size': int(row['PayloadSize']),
                        'latency_ms': float(row['LatencyMs']),
                        'pattern': row.get('Pattern', pattern)
                    })
        
        print(f"Loaded {len(measurements)} successful measurements for {pattern} pattern")
        return measurements
    except Exception as e:
        print(f"Error loading {filename}: {e}")
        return None

def calculate_stats(measurements):
    """Calculate latency statistics for measurements"""
    if not measurements:
        return None
    
    # Group by payload size
    payload_groups = {}
    for m in measurements:
        size = m['payload_size']
        if size not in payload_groups:
            payload_groups[size] = []
        payload_groups[size].append(m['latency_ms'])
    
    stats = {}
    for size, latencies in payload_groups.items():
        stats[size] = {
            'count': len(latencies),
            'mean': statistics.mean(latencies),
            'median': statistics.median(latencies),
            'min': min(latencies),
            'max': max(latencies),
            'p95': sorted(latencies)[int(len(latencies) * 0.95)] if len(latencies) > 1 else latencies[0],
            'p99': sorted(latencies)[int(len(latencies) * 0.99)] if len(latencies) > 1 else latencies[0]
        }
    
    return stats

def print_pattern_summary(pattern, stats):
    """Print summary statistics for a pattern"""
    if stats is None:
        print(f"\n{pattern.upper()} PATTERN: No data available")
        return
    
    print(f"\n{pattern.upper()} PATTERN SUMMARY:")
    print("=" * 50)
    
    # Overall statistics
    all_means = [s['mean'] for s in stats.values()]
    all_p95s = [s['p95'] for s in stats.values()]
    
    print(f"Payload sizes tested: {len(stats)} different sizes")
    print(f"Total measurements: {sum(s['count'] for s in stats.values())}")
    print(f"Overall latency range: {min(all_means):.3f} - {max(all_means):.3f} ms")
    print(f"Average latency: {statistics.mean(all_means):.3f} ms")
    print(f"P95 latency range: {min(all_p95s):.3f} - {max(all_p95s):.3f} ms")
    
    # Show sample results for key payload sizes
    print(f"\nSample results (payload size -> mean latency):")
    key_sizes = [16, 64, 256, 512, 1024]
    for size in key_sizes:
        if size in stats:
            print(f"  {size:4d} bytes: {stats[size]['mean']:.3f} ms")

def create_pattern_plot(pattern, stats, measurements):
    """Create individual plot for a specific pattern"""
    if stats is None or not measurements:
        print(f"No data available for {pattern} pattern plotting")
        return
    
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("Matplotlib not available - skipping plot generation")
        return
    
    # Prepare data for plotting
    payload_sizes = sorted(stats.keys())
    mean_latencies = [stats[size]['mean'] for size in payload_sizes]
    
    # Create the plot
    plt.figure(figsize=(12, 8))
    
    # Plot only mean latency
    plt.plot(payload_sizes, mean_latencies, 'b-o', label='Mean Latency', linewidth=2, markersize=6)
    
    # Customize the plot
    plt.xlabel('Payload Size (bytes)', fontsize=12)
    plt.ylabel('Latency (milliseconds)', fontsize=12)
    plt.title(f'{pattern.capitalize()} Communication Pattern - Mean Latency', fontsize=14, fontweight='bold')
    plt.legend(fontsize=11)
    plt.grid(True, alpha=0.3)
    
    # Add some statistics as text
    avg_latency = statistics.mean(mean_latencies)
    min_latency = min(mean_latencies)
    max_latency = max(mean_latencies)
    
    stats_text = f'Avg: {avg_latency:.3f}ms\nMin: {min_latency:.3f}ms\nMax: {max_latency:.3f}ms\nSamples: {len(measurements)}'
    plt.text(0.02, 0.98, stats_text, transform=plt.gca().transAxes, 
             verticalalignment='top', bbox=dict(boxstyle='round', facecolor='lightgray', alpha=0.8),
             fontsize=10)
    
    # Save the plot with pattern-specific filename
    plots_dir = 'benchmark_plots'
    if not os.path.exists(plots_dir):
        os.makedirs(plots_dir)
    
    filename = f'{plots_dir}/{pattern}_latency_analysis.png'
    plt.tight_layout()
    plt.savefig(filename, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"  Plot saved: {filename}")

def create_comparison_plot(pattern_stats, patterns):
    """Create comparison plot showing all patterns together"""
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("Matplotlib not available - skipping comparison plot generation")
        return
    
    # Filter out patterns with no data
    valid_patterns = [p for p in patterns if pattern_stats[p] is not None]
    if len(valid_patterns) < 2:
        print("Need at least 2 patterns for comparison plot")
        return
    
    plt.figure(figsize=(14, 10))
    
    # Colors for different patterns
    colors = {'direct': 'blue', 'sequential': 'red', 'twohop': 'green'}
    markers = {'direct': 'o', 'sequential': 's', 'twohop': '^'}
    
    for pattern in valid_patterns:
        stats = pattern_stats[pattern]
        payload_sizes = sorted(stats.keys())
        mean_latencies = [stats[size]['mean'] for size in payload_sizes]
        
        plt.plot(payload_sizes, mean_latencies, 
                color=colors.get(pattern, 'black'),
                marker=markers.get(pattern, 'o'),
                label=f'{pattern.capitalize()} Pattern',
                linewidth=2, markersize=6)
    
    plt.xlabel('Payload Size (bytes)', fontsize=12)
    plt.ylabel('Mean Latency (milliseconds)', fontsize=12)
    plt.title('Communication Pattern Comparison - Mean Latency', fontsize=14, fontweight='bold')
    plt.legend(fontsize=11)
    plt.grid(True, alpha=0.3)
    
    # Save the comparison plot
    plots_dir = 'benchmark_plots'
    if not os.path.exists(plots_dir):
        os.makedirs(plots_dir)
    
    filename = f'{plots_dir}/comparison_all_patterns.png'
    plt.tight_layout()
    plt.savefig(filename, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"  Comparison plot saved: {filename}")

def main():
    print("=== Unified Communication Latency Benchmark Analysis ===")
    print()
    
    # Load data for all patterns
    patterns = ['direct', 'sequential', 'twohop']
    pattern_data = {}
    pattern_stats = {}
    
    for pattern in patterns:
        measurements = load_pattern_data(pattern)
        pattern_data[pattern] = measurements
        pattern_stats[pattern] = calculate_stats(measurements)
    
    # Print individual pattern summaries
    for pattern in patterns:
        print_pattern_summary(pattern, pattern_stats[pattern])
    
    # Generate individual plots for each pattern
    print(f"\nGenerating individual plots...")
    for pattern in patterns:
        if pattern_data[pattern] is not None:
            create_pattern_plot(pattern, pattern_stats[pattern], pattern_data[pattern])
    
    # Create comparison plot
    print(f"\nGenerating comparison plot...")
    create_comparison_plot(pattern_stats, patterns)
    
    # Print comparison analysis
    print("\n" + "=" * 60)
    print("ANALYSIS SUMMARY")
    print("=" * 60)
    
    valid_patterns = [p for p, s in pattern_stats.items() if s is not None]
    if len(valid_patterns) <= 1:
        print("Need at least 2 patterns for comparison analysis")
        return
    
    print("Pattern Performance Ranking (by average latency):")
    
    avg_latencies = {}
    for pattern in valid_patterns:
        if pattern_stats[pattern] is not None:
            all_means = [s['mean'] for s in pattern_stats[pattern].values()]
            avg_latencies[pattern] = statistics.mean(all_means)
    
    sorted_patterns = sorted(avg_latencies.items(), key=lambda x: x[1])
    for i, (pattern, latency) in enumerate(sorted_patterns, 1):
        print(f"  {i}. {pattern.capitalize()}: {latency:.3f} ms average")
    
    if 'direct' in avg_latencies:
        print(f"\nOverhead Analysis (vs Direct pattern):")
        direct_latency = avg_latencies['direct']
        for pattern, latency in avg_latencies.items():
            if pattern != 'direct':
                overhead = ((latency - direct_latency) / direct_latency) * 100
                print(f"  {pattern.capitalize()} adds {overhead:.1f}% overhead vs direct")
    
    # Communication efficiency analysis
    print(f"\nCommunication Pattern Efficiency:")
    if 'direct' in avg_latencies and 'sequential' in avg_latencies and 'twohop' in avg_latencies:
        direct_lat = avg_latencies['direct']
        sequential_lat = avg_latencies['sequential']
        twohop_lat = avg_latencies['twohop']
        
        print(f"  Direct (1 hop):     {direct_lat:.3f} ms")
        print(f"  Two-hop (2 hops):   {twohop_lat:.3f} ms")
        print(f"  Sequential (2 RTT): {sequential_lat:.3f} ms")
        
        print(f"\nEfficiency observations:")
        if twohop_lat < sequential_lat:
            savings = ((sequential_lat - twohop_lat) / sequential_lat) * 100
            print(f"  Two-hop is {savings:.1f}% faster than sequential")
            print(f"  Benefit of pipelined vs round-trip communication")
        
        if twohop_lat < 2 * direct_lat:
            efficiency = (1 - (twohop_lat - direct_lat) / direct_lat) * 100
            print(f"  Two-hop has {efficiency:.1f}% efficiency compared to 2x direct latency")

    print(f"\nResults and plots are available:")
    print(f"  Data files:")
    for pattern in valid_patterns:
        print(f"    - csvfiles/benchmark_results_{pattern}.csv")
    
    print(f"  Plot files:")
    for pattern in valid_patterns:
        print(f"    - benchmark_plots/{pattern}_latency_analysis.png")
    print(f"    - benchmark_plots/comparison_all_patterns.png")

if __name__ == "__main__":
    main()