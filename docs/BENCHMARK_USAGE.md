# Benchmark System Usage Guide

This guide provides comprehensive instructions for using the unified communication latency benchmark system.

## Overview

The benchmark system measures communication latency across three distinct patterns:

- **Direct**: `head → worker → ack → head` (single round-trip)
- **Sequential**: `head → worker1 → ack → head → worker2 → ack → head` (two sequential round-trips)  
- **Two-hop**: `head → worker1 → worker2 → ack → head` (forwarded request)

## Quick Start

### Basic Usage

```bash
# Build the benchmark system
make unified_benchmark

# Run individual patterns
make run_direct
make run_sequential  
make run_twohop

# Run all patterns
make run_unified

# Analyze results
make analyze
```

### Command Line Interface

#### Benchmark Head Node

```bash
./build/benchmarkHead [options]

Options:
  --pattern <direct|sequential|twohop>  Communication pattern (default: direct)
  --workers <addr1,addr2,...>           Comma-separated worker addresses
  --min-size SIZE                       Minimum payload size in bytes (default: 16)
  --max-size SIZE                       Maximum payload size in bytes (default: 8192)
  --increment SIZE                      Payload size increment in bytes (default: 16)
  --samples COUNT                       Number of samples per payload size (default: 100)
  --help                                Show help message
```

#### Benchmark Worker Node

```bash
./build/benchmarkWorker [options]

Options:
  --port PORT           Port to listen on (default: 50051)
  --forward-to ADDRESS  Forward requests to this worker (for two-hop pattern)
  --help                Show help message
```

## Communication Patterns

### 1. Direct Pattern

**Flow**: `head → worker → ack → head`

```bash
# Start worker
./build/benchmarkWorker --port 50060 &

# Run benchmark  
./build/benchmarkHead --pattern direct --workers localhost:50060 --samples 100
```

### 2. Sequential Pattern

**Flow**: `head → worker1 → ack → head → worker2 → ack → head`

```bash
# Start workers
./build/benchmarkWorker --port 50060 &
./build/benchmarkWorker --port 50061 &

# Run benchmark
./build/benchmarkHead --pattern sequential --workers localhost:50060,localhost:50061 --samples 100
```

### 3. Two-hop Pattern  

**Flow**: `head → worker1 → worker2 → ack → head`

```bash
# Start destination worker
./build/benchmarkWorker --port 50061 &

# Start forwarding worker
./build/benchmarkWorker --port 50060 --forward-to localhost:50061 &

# Run benchmark
./build/benchmarkHead --pattern twohop --workers localhost:50060 --samples 100
```

## Configuration Parameters

### Payload Configuration

Control the payload sizes tested:

```bash
# Test small payloads (16B to 512B)
./build/benchmarkHead --min-size 16 --max-size 512 --increment 16

# Test large payloads (1KB to 64KB)  
./build/benchmarkHead --min-size 1024 --max-size 65536 --increment 1024

# High-resolution testing
./build/benchmarkHead --min-size 64 --max-size 1024 --increment 8
```

### Sample Size Configuration

Adjust the number of measurements per payload size:

```bash
# Quick test (low accuracy)
./build/benchmarkHead --samples 10

# Standard test (good accuracy)
./build/benchmarkHead --samples 100

# High-precision test (best accuracy)
./build/benchmarkHead --samples 1000
```

## Results and Analysis

### Output Format

Benchmarks generate CSV files with detailed measurements:

```csv
PayloadSize,LatencyMs,Success,RequestTimestamp,ResponseTimestamp,Pattern
16,0.198,1,1758517123456789,1758517123654321,direct
32,0.164,1,1758517123756789,1758517123920321,direct
...
```

**Fields:**
- `PayloadSize`: Request payload size in bytes
- `LatencyMs`: Round-trip latency in milliseconds  
- `Success`: 1 for successful requests, 0 for failures
- `RequestTimestamp`: Nanosecond timestamp when request was sent
- `ResponseTimestamp`: Nanosecond timestamp when response was received
- `Pattern`: Communication pattern used

### Result Files

Results are saved in the `csvfiles/` directory:

```bash
csvfiles/
├── benchmark_results_direct.csv
├── benchmark_results_sequential.csv
└── benchmark_results_twohop.csv
```

### Analysis Tools

#### Automated Analysis

```bash
python3 simple_analyze.py

# Output includes:
# - Statistical summaries for each pattern
# - Performance comparisons  
# - Overhead calculations
# - Visualization plots
```

## Custom Benchmark Scripts

The `run_unified_benchmark.sh` script provides a template for custom benchmarks:

```bash
#!/bin/bash
# Custom benchmark with specific parameters

PATTERN=$1
SAMPLES=${2:-100}

# Start workers based on pattern
case $PATTERN in
    "direct")
        ./build/benchmarkWorker --port 50060 &
        WORKER_PIDS=$!
        sleep 2
        ./build/benchmarkHead --pattern direct --workers localhost:50060 --samples $SAMPLES
        ;;
    "sequential")  
        ./build/benchmarkWorker --port 50060 &
        ./build/benchmarkWorker --port 50061 &
        WORKER_PIDS="$! $(jobs -p)"
        sleep 2
        ./build/benchmarkHead --pattern sequential --workers localhost:50060,localhost:50061 --samples $SAMPLES
        ;;
esac

# Cleanup
kill $WORKER_PIDS 2>/dev/null
```

## Running distributed jobs on SLURM

If you want to run the head and workers on separate compute nodes (recommended for true distributed measurements on the Swarm cluster), use the `scripts/run_distributed_benchmark.sh` SLURM helper. The script:

- Allocates multiple nodes via SBATCH (`#SBATCH --nodes` in the script or passed to `sbatch`).
- Launches one worker process per allocated worker node using `srun`.
- Starts the benchmark head on the primary allocated node and passes the correct `--workers host:port` list.

Important details:

- The script defaults to the `direct` pattern unless you override `PATTERN`.
- To change patterns, pass environment variables when submitting the job with `sbatch` using the `--export` flag (or export them inside your environment).

Examples:

```bash
# Default (direct)
sbatch scripts/run_distributed_benchmark.sh

# Sequential pattern
sbatch --nodes=3 --export=PATTERN=sequential,SAMPLES=100 scripts/run_distributed_benchmark.sh

# Two-hop pattern
sbatch --nodes=3 --export=PATTERN=twohop,SAMPLES=100 scripts/run_distributed_benchmark.sh
```

If you prefer interactive debugging, allocate nodes with `salloc --nodes=3 --ntasks-per-node=1` and then run the same `srun` commands from the script manually so you can observe logs and processes.