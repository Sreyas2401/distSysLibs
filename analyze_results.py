#!/usr/bin/env python3
"""
Benchmark Results Analysis Script

This script analyzes the communication latency benchmark results and generates
visualizations to help understand the relationship between payload size and latency.
"""

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import sys
import os
from pathlib import Path

def load_results(filename="benchmark_results.csv"):
    """Load benchmark results from CSV file."""
    if not os.path.exists(filename):
        print(f"Error: Results file '{filename}' not found!")
        print("Please run the benchmark first using: ./run_benchmark.sh")
        return None
    
    df = pd.read_csv(filename)
    print(f"Loaded {len(df)} measurements from {filename}")
    
    # Filter successful measurements
    successful = df[df['Success'] == 1]
    failed = df[df['Success'] == 0]
    
    print(f"Successful: {len(successful)}, Failed: {len(failed)}")
    
    if len(failed) > 0:
        print(f"Warning: {len(failed)} failed measurements detected")
    
    return successful if len(successful) > 0 else None

def analyze_latency_by_payload_size(df):
    """Analyze latency statistics grouped by payload size."""
    stats = df.groupby('PayloadSize')['LatencyMs'].agg([
        'count', 'mean', 'median', 'std', 'min', 'max',
        lambda x: x.quantile(0.95),  # P95
        lambda x: x.quantile(0.99),  # P99
    ]).round(4)
    
    stats.columns = ['Count', 'Mean', 'Median', 'StdDev', 'Min', 'Max', 'P95', 'P99']
    return stats

def plot_latency_analysis(df, output_dir="benchmark_plots"):
    """Generate mean latency vs payload size plot."""
    os.makedirs(output_dir, exist_ok=True)
    
    # Calculate statistics
    stats = analyze_latency_by_payload_size(df)
    
    # Create single plot: Mean latency vs payload size
    plt.figure(figsize=(12, 8))
    
    plt.plot(stats.index, stats['Mean'], 'b-', marker='o', linewidth=3, markersize=6, 
             color='#2E86C1', markerfacecolor='white', markeredgewidth=2)
    
    plt.xlabel('Payload Size (bytes)', fontsize=14, fontweight='bold')
    plt.ylabel('Mean Latency (ms)', fontsize=14, fontweight='bold')
    plt.title('Communication Latency: Mean Latency vs Payload Size\nDirect Worker Communication', 
              fontsize=16, fontweight='bold', pad=20)
    plt.grid(True, alpha=0.3)
    
    # Format axes
    plt.gca().tick_params(labelsize=12)
    
    # Add some padding to y-axis for better visualization
    ymin, ymax = plt.ylim()
    plt.ylim(ymin * 0.95, ymax * 1.05)
    
    plt.tight_layout()
    plot_file = os.path.join(output_dir, 'mean_latency.png')
    plt.savefig(plot_file, dpi=300, bbox_inches='tight')
    print(f"Mean latency plot saved to: {plot_file}")
    
    return stats

def calculate_throughput_estimates(df):
    """Calculate approximate throughput estimates."""
    stats = analyze_latency_by_payload_size(df)
    
    # Calculate throughput (requests/second) based on mean latency
    stats['Throughput_RPS'] = 1000.0 / stats['Mean']  # Convert ms to seconds
    
    # Calculate data throughput (bytes/second) 
    stats['DataThroughput_BPS'] = stats.index * stats['Throughput_RPS']
    stats['DataThroughput_MBps'] = stats['DataThroughput_BPS'] / (1024 * 1024)
    
    return stats[['Mean', 'Throughput_RPS', 'DataThroughput_MBps']]

def print_summary(df):
    """Print a comprehensive summary of the benchmark results."""
    print("\n" + "="*80)
    print("BENCHMARK RESULTS SUMMARY")
    print("="*80)
    
    print(f"Total measurements: {len(df)}")
    print(f"Payload size range: {df['PayloadSize'].min()} - {df['PayloadSize'].max()} bytes")
    print(f"Overall latency range: {df['LatencyMs'].min():.3f} - {df['LatencyMs'].max():.3f} ms")
    print(f"Overall mean latency: {df['LatencyMs'].mean():.3f} ms")
    print(f"Overall median latency: {df['LatencyMs'].median():.3f} ms")
    
    # Latency statistics by payload size
    print("\nLATENCY STATISTICS BY PAYLOAD SIZE:")
    print("-" * 80)
    stats = analyze_latency_by_payload_size(df)
    print(stats.to_string())
    
    # Throughput estimates
    print("\nTHROUGHPUT ESTIMATES:")
    print("-" * 50)
    throughput = calculate_throughput_estimates(df)
    print(throughput.to_string())
    
    # Key insights
    print("\nKEY INSIGHTS:")
    print("-" * 30)
    
    # Calculate correlation between payload size and latency
    correlation = df['PayloadSize'].corr(df['LatencyMs'])
    print(f"• Correlation between payload size and latency: {correlation:.4f}")
    
    # Find the latency increase ratio
    min_size_latency = stats.loc[stats.index.min(), 'Mean']
    max_size_latency = stats.loc[stats.index.max(), 'Mean']
    size_ratio = df['PayloadSize'].max() / df['PayloadSize'].min()
    latency_ratio = max_size_latency / min_size_latency
    
    print(f"• Payload size increased by: {size_ratio:.1f}x")
    print(f"• Mean latency increased by: {latency_ratio:.2f}x")
    print(f"• Latency scaling efficiency: {(size_ratio/latency_ratio):.2f}")
    
    # Overhead analysis
    min_payload_latency = stats.loc[stats.index.min(), 'Mean']
    print(f"• Estimated base overhead (minimum payload): {min_payload_latency:.3f} ms")

def main():
    """Main function to run the analysis."""
    print("Benchmark Results Analysis")
    print("=" * 40)
    
    # Load the results
    df = load_results()
    if df is None:
        return 1
    
    # Generate plots and analysis
    try:
        stats = plot_latency_analysis(df)
        print_summary(df)
        
        print(f"\nAnalysis complete! Check the 'benchmark_plots' directory for visualizations.")
        
    except Exception as e:
        print(f"Error during analysis: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())