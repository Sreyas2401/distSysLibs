#!/bin/bash

# Benchmark Experiment Runner
# This script runs the baseline communication latency benchmark

set -e

echo "=== Distributed Systems Latency Benchmark ==="
echo "Experiment: Baseline Direct Worker Communication"
echo ""

# Default parameters
WORKER_PORT=50052
MIN_SIZE=16
MAX_SIZE=8192
INCREMENT=16
SAMPLES=100
CLEANUP_ON_EXIT=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            WORKER_PORT="$2"
            shift 2
            ;;
        --min-size)
            MIN_SIZE="$2"
            shift 2
            ;;
        --max-size)
            MAX_SIZE="$2"
            shift 2
            ;;
        --increment)
            INCREMENT="$2"
            shift 2
            ;;
        --samples)
            SAMPLES="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP_ON_EXIT=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --port PORT          Worker port (default: 50052)"
            echo "  --min-size SIZE      Minimum payload size in bytes (default: 16)"
            echo "  --max-size SIZE      Maximum payload size in bytes (default: 8192)"
            echo "  --increment SIZE     Payload size increment in bytes (default: 16)"
            echo "  --samples COUNT      Number of samples per payload size (default: 100)"
            echo "  --no-cleanup         Don't stop worker process on exit"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to cleanup processes
cleanup() {
    if [ "$CLEANUP_ON_EXIT" = true ]; then
        echo ""
        echo "Cleaning up..."
        if [ -n "$WORKER_PID" ]; then
            echo "Stopping worker process (PID: $WORKER_PID)"
            kill $WORKER_PID 2>/dev/null || true
            wait $WORKER_PID 2>/dev/null || true
        fi
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Build the benchmark components
echo "Building benchmark components..."
make benchmark-proto
make all

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Build completed successfully."
echo ""

# Display configuration
echo "Benchmark Configuration:"
echo "  Worker Port: $WORKER_PORT"
echo "  Payload Size Range: $MIN_SIZE - $MAX_SIZE bytes"
echo "  Increment: $INCREMENT bytes"
echo "  Samples per Size: $SAMPLES"
echo "  Total Tests: $(((MAX_SIZE - MIN_SIZE) / INCREMENT + 1))"
echo "  Estimated Total Samples: $(((MAX_SIZE - MIN_SIZE) / INCREMENT + 1 * SAMPLES))"
echo ""

# Start the worker in background
echo "Starting benchmark worker on port $WORKER_PORT..."
./build/benchmarkWorker $WORKER_PORT &
WORKER_PID=$!

# Wait for worker to start
sleep 2

# Check if worker is still running
if ! kill -0 $WORKER_PID 2>/dev/null; then
    echo "Failed to start worker process!"
    exit 1
fi

echo "Worker started successfully (PID: $WORKER_PID)"
echo ""

# Run the benchmark
echo "Starting benchmark experiment..."
echo "This may take several minutes depending on the configuration..."
echo ""

./build/benchmarkHead \
    --worker "localhost:$WORKER_PORT" \
    --min-size $MIN_SIZE \
    --max-size $MAX_SIZE \
    --increment $INCREMENT \
    --samples $SAMPLES

BENCHMARK_EXIT_CODE=$?

echo ""
if [ $BENCHMARK_EXIT_CODE -eq 0 ]; then
    echo "=== Benchmark Completed Successfully ==="
    echo ""
    echo "Results have been saved to: benchmark_results.csv"
    echo ""
    echo "To analyze the results, you can:"
    echo "  1. Open benchmark_results.csv in a spreadsheet application"
    echo "  2. Use data analysis tools like Python/pandas, R, or similar"
    echo "  3. Plot latency vs payload size to visualize the relationship"
    echo ""
    echo "Quick statistics from this run:"
    if [ -f "benchmark_results.csv" ]; then
        echo "  Total measurements: $(tail -n +2 benchmark_results.csv | wc -l)"
        echo "  Successful measurements: $(tail -n +2 benchmark_results.csv | awk -F',' '$3==1' | wc -l)"
        echo "  Failed measurements: $(tail -n +2 benchmark_results.csv | awk -F',' '$3==0' | wc -l)"
    fi
else
    echo "=== Benchmark Failed ==="
    echo "Exit code: $BENCHMARK_EXIT_CODE"
    exit 1
fi