#!/bin/bash

# Quick Demo Script - Communication Latency Benchmark
# This runs a small-scale demonstration of the benchmark

echo "=== Quick Benchmark Demo ==="
echo "This demonstrates the communication latency benchmark with a small dataset"
echo ""

# Build components if needed
echo "Building benchmark components..."
make benchmark-proto > /dev/null 2>&1
make build/benchmarkHead build/benchmarkWorker > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "Build failed! Please check your gRPC installation."
    exit 1
fi

echo "Build successful."
echo ""

# Start worker in background
echo "Starting benchmark worker on port 50052..."
./build/benchmarkWorker 50052 &
WORKER_PID=$!

# Wait for worker to start
sleep 1

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ -n "$WORKER_PID" ]; then
        kill $WORKER_PID 2>/dev/null || true
        wait $WORKER_PID 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Check if worker is running
if ! kill -0 $WORKER_PID 2>/dev/null; then
    echo "Failed to start worker!"
    exit 1
fi

echo "Worker started (PID: $WORKER_PID)"
echo ""

# Run a quick benchmark with limited scope
echo "Running quick benchmark (16-1024 bytes, 16-byte increments, 10 samples each)..."
echo "This should take about 30 seconds..."
echo ""

./build/benchmarkHead \
    --worker "localhost:50052" \
    --min-size 16 \
    --max-size 1024 \
    --increment 16 \
    --samples 10

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "=== Quick Demo Completed Successfully ==="
    echo ""
    echo "Results saved to: benchmark_results.csv"
    echo ""
    echo "Sample results:"
    if [ -f "benchmark_results.csv" ]; then
        echo "Total measurements: $(tail -n +2 benchmark_results.csv | wc -l)"
        echo ""
        echo "First few measurements:"
        head -n 6 benchmark_results.csv
        echo ""
        echo "To run the full benchmark, use: ./run_benchmark.sh"
        echo "To analyze results, use: python3 analyze_results.py"
    fi
else
    echo "Benchmark failed with exit code: $EXIT_CODE"
fi