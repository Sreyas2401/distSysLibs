#!/bin/bash

# Unified benchmark script for all communication patterns
# Usage: ./run_unified_benchmark.sh [pattern] [samples]
# pattern: direct, sequential, twohop, or all (default: all)
# samples: number of samples per payload size (default: 50)

PATTERN=${1:-all}
SAMPLES=${2:-50}
MIN_SIZE=16
MAX_SIZE=1024
INCREMENT=16

echo "=== Unified Communication Latency Benchmark ==="
echo "Pattern: $PATTERN"
echo "Samples per size: $SAMPLES"
echo "Payload range: ${MIN_SIZE}-${MAX_SIZE} bytes (increment: $INCREMENT)"
echo

# Function to run a single pattern
run_pattern() {
    local pattern=$1
    local worker_args=$2
    
    echo "Running $pattern pattern..."
    
    # Start workers based on pattern
    case $pattern in
        "direct")
            echo "Starting 1 worker for direct pattern..."
            ./build/benchmarkWorker --port 50060 > worker1.log 2>&1 &
            WORKER1_PID=$!
            ;;
        "sequential")
            echo "Starting 2 workers for sequential pattern..."
            ./build/benchmarkWorker --port 50060 > worker1.log 2>&1 &
            WORKER1_PID=$!
            ./build/benchmarkWorker --port 50061 > worker2.log 2>&1 &
            WORKER2_PID=$!
            worker_args="localhost:50060,localhost:50061"
            ;;
        "twohop")
            echo "Starting workers for two-hop pattern (worker1 forwards to worker2)..."
            ./build/benchmarkWorker --port 50061 > worker2.log 2>&1 &
            WORKER2_PID=$!
            sleep 1  # Let second worker start first
            ./build/benchmarkWorker --port 50060 --forward-to localhost:50061 > worker1.log 2>&1 &
            WORKER1_PID=$!
            worker_args="localhost:50060"
            ;;
    esac
    
    # Wait for workers to start
    echo "Waiting for workers to initialize..."
    sleep 2
    
    # Run benchmark
    echo "Starting benchmark..."
    ./build/benchmarkHead --pattern $pattern --workers $worker_args \
                          --min-size $MIN_SIZE --max-size $MAX_SIZE \
                          --increment $INCREMENT --samples $SAMPLES
    
    # Clean up workers
    echo "Stopping workers..."
    if [ ! -z "$WORKER1_PID" ]; then
        kill $WORKER1_PID 2>/dev/null
        wait $WORKER1_PID 2>/dev/null
    fi
    if [ ! -z "$WORKER2_PID" ]; then
        kill $WORKER2_PID 2>/dev/null
        wait $WORKER2_PID 2>/dev/null
    fi
    
    # Clean up log files
    rm -f worker1.log worker2.log
    
    echo "$pattern pattern completed."
    echo
}

# Build the project first
echo "Building benchmark components..."
make -s benchmark_head benchmark_worker

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Run the requested pattern(s)
case $PATTERN in
    "direct")
        run_pattern "direct" "localhost:50060"
        ;;
    "sequential")
        run_pattern "sequential" "localhost:50060,localhost:50061"
        ;;
    "twohop")
        run_pattern "twohop" "localhost:50060"
        ;;
    "all")
        echo "Running all patterns..."
        echo
        run_pattern "direct" "localhost:50060"
        run_pattern "sequential" "localhost:50060,localhost:50061"
        run_pattern "twohop" "localhost:50060"
        
        echo "=== All Patterns Complete ==="
        echo "Results saved to:"
        echo "  benchmark_results_direct.csv"
        echo "  benchmark_results_sequential.csv"
        echo "  benchmark_results_twohop.csv"
        echo
        echo "To analyze results, run: python3 analyze_unified_results.py"
        ;;
    *)
        echo "Error: Invalid pattern '$PATTERN'"
        echo "Valid patterns: direct, sequential, twohop, all"
        exit 1
        ;;
esac

echo "Benchmark complete!"