#!/bin/bash

# Unified benchmark script for all communication patterns
# Usage: ./run_unified_benchmark.sh [pattern] [samples] [workers]
# pattern: direct, sequential, twohop, or all (default: all)
# samples: number of samples per payload size (default: 50)
# workers: number of workers to use (default: depends on pattern)

# Check for help first
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "=== Unified Communication Latency Benchmark ==="
    echo "Usage: $0 [pattern] [samples] [workers]"
    echo
    echo "Arguments:"
    echo "  pattern   Communication pattern: direct, sequential, twohop, or all (default: all)"
    echo "  samples   Number of samples per payload size (default: 50)"
    echo "  workers   Number of workers to use (default: depends on pattern)"
    echo
    echo "Pattern Descriptions:"
    echo "  direct:     head -> worker (round-robin across N workers)"
    echo "  sequential: head -> worker1 -> head -> worker2 -> head ... (all N workers)"
    echo "  twohop:     head -> worker1 -> worker2 -> ... -> workerN -> head (chain)"
    echo
    echo "Default Worker Counts:"
    echo "  direct:     1 worker"
    echo "  sequential: 2 workers"
    echo "  twohop:     2 workers"
    echo
    echo "Examples:"
    echo "  $0 direct 50 3        # Direct pattern, 50 samples, 3 workers"
    echo "  $0 sequential 25 4    # Sequential pattern, 25 samples, 4 workers"
    echo "  $0 twohop 100 5       # Two-hop pattern, 100 samples, 5-worker chain"
    echo "  $0 all 50 3           # All patterns, 50 samples, 3 workers each"
    echo
    exit 0
fi

PATTERN=${1:-all}
SAMPLES=${2:-50}
NUM_WORKERS=${3:-0}  # 0 means use pattern default
MIN_SIZE=16
MAX_SIZE=1024
INCREMENT=16

echo "=== Unified Communication Latency Benchmark ==="
echo "Pattern: $PATTERN"
echo "Samples per size: $SAMPLES"

# Set default workers based on pattern if not specified
if [ $NUM_WORKERS -eq 0 ]; then
    case $PATTERN in
        "direct") NUM_WORKERS=1 ;;
        "sequential") NUM_WORKERS=2 ;;
        "twohop") NUM_WORKERS=2 ;;
        "all") NUM_WORKERS=0 ;; # Will be set per pattern
    esac
fi

if [ $NUM_WORKERS -gt 0 ]; then
    echo "Number of workers: $NUM_WORKERS"
fi

echo "Payload range: ${MIN_SIZE}-${MAX_SIZE} bytes (increment: $INCREMENT)"
echo

# Function to start workers
start_workers() {
    local num_workers=$1
    local pattern=$2
    local base_port=50060
    
    WORKER_PIDS=()
    WORKER_ADDRESSES=()
    
    echo "Starting $num_workers workers for $pattern pattern..."
    
    # For twohop pattern, we need to set up forwarding chain
    if [ "$pattern" = "twohop" ]; then
        # Start workers in reverse order for forwarding chain
        for ((i=$num_workers; i>=1; i--)); do
            port=$((base_port + i - 1))
            if [ $i -eq $num_workers ]; then
                # Last worker in chain (no forwarding)
                ./build/benchmarkWorker --port $port > worker$i.log 2>&1 &
            else
                # Forward to next worker in chain
                next_port=$((base_port + i))
                ./build/benchmarkWorker --port $port --forward-to localhost:$next_port > worker$i.log 2>&1 &
            fi
            WORKER_PIDS[$i]=$!
            WORKER_ADDRESSES+=("localhost:$port")
            sleep 0.5  # Small delay between worker starts
        done
    else
        # For direct and sequential patterns, start workers normally
        for ((i=1; i<=num_workers; i++)); do
            port=$((base_port + i - 1))
            ./build/benchmarkWorker --port $port > worker$i.log 2>&1 &
            WORKER_PIDS[$i]=$!
            WORKER_ADDRESSES+=("localhost:$port")
            sleep 0.5
        done
    fi
    
    # Wait for all workers to initialize
    echo "Waiting for workers to initialize..."
    sleep 2
}

# Function to stop workers
stop_workers() {
    echo "Stopping workers..."
    for pid in "${WORKER_PIDS[@]}"; do
        if [ ! -z "$pid" ]; then
            kill $pid 2>/dev/null
            wait $pid 2>/dev/null
        fi
    done
    
    # Clean up log files
    rm -f worker*.log
}

# Function to run a single pattern
run_pattern() {
    local pattern=$1
    local num_workers=$2
    
    if [ $num_workers -eq 0 ]; then
        # Set pattern defaults
        case $pattern in
            "direct") num_workers=1 ;;
            "sequential") num_workers=2 ;;
            "twohop") num_workers=2 ;;
        esac
    fi
    
    echo "Running $pattern pattern with $num_workers workers..."
    
    # Start workers
    start_workers $num_workers $pattern
    
    # Build worker addresses string
    worker_list=$(IFS=','; echo "${WORKER_ADDRESSES[*]}")
    
    # For twohop pattern, only use the first worker (entry point)
    if [ "$pattern" = "twohop" ]; then
        worker_list="${WORKER_ADDRESSES[0]}"
    fi
    
    # Run benchmark
    echo "Starting benchmark..."
    ./build/benchmarkHead --pattern $pattern --workers "$worker_list" \
                          --min-size $MIN_SIZE --max-size $MAX_SIZE \
                          --increment $INCREMENT --samples $SAMPLES
    
    # Clean up workers
    stop_workers
    
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
    "direct"|"sequential"|"twohop")
        run_pattern $PATTERN $NUM_WORKERS
        ;;
    "all")
        echo "Running all patterns..."
        echo
        # Use specified number of workers or pattern defaults
        direct_workers=$([[ $NUM_WORKERS -gt 0 ]] && echo $NUM_WORKERS || echo 1)
        sequential_workers=$([[ $NUM_WORKERS -gt 0 ]] && echo $NUM_WORKERS || echo 2)
        twohop_workers=$([[ $NUM_WORKERS -gt 0 ]] && echo $NUM_WORKERS || echo 2)
        
        run_pattern "direct" $direct_workers
        run_pattern "sequential" $sequential_workers
        run_pattern "twohop" $twohop_workers
        
        echo "=== All Patterns Complete ==="
        echo "Results saved to csvfiles/:"
        echo "  benchmark_results_direct.csv"
        echo "  benchmark_results_sequential.csv"
        echo "  benchmark_results_twohop.csv"
        echo
        echo "To analyze results, run: python3 simple_analyze.py"
        ;;
    *)
        echo "Error: Invalid pattern '$PATTERN'"
        echo "Valid patterns: direct, sequential, twohop, all"
        echo "Usage: ./run_unified_benchmark.sh [pattern] [samples] [workers]"
        echo "Examples:"
        echo "  ./run_unified_benchmark.sh direct 50 3      # Direct pattern with 3 workers"
        echo "  ./run_unified_benchmark.sh sequential 25 4  # Sequential pattern with 4 workers"
        echo "  ./run_unified_benchmark.sh all 50 5         # All patterns with 5 workers each"
        exit 1
        ;;
esac

echo "Benchmark complete!"