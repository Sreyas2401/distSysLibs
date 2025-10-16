#!/bin/bash
#SBATCH --job-name=benchmark-distributed
#SBATCH --output=benchmark_distributed_%j.out
#SBATCH --error=benchmark_distributed_%j.err
#SBATCH --partition=defq
#SBATCH --nodes=3
#SBATCH --ntasks-per-node=1
#SBATCH --time=01:30:00
#SBATCH --mem-per-cpu=2048

set -euo pipefail

# ============================================================================
# Configuration knobs (override via SBATCH --export or env vars)
# ============================================================================
PATTERN=${PATTERN:-direct}                      # direct | sequential | twohop
SAMPLES=${SAMPLES:-100}
MIN_SIZE=${MIN_SIZE:-16}
MAX_SIZE=${MAX_SIZE:-8192}
INCREMENT=${INCREMENT:-16}
WORKER_PORT=${WORKER_PORT:-50060}
FORWARD_PORT=${FORWARD_PORT:-50061}             # Two-hop forwarding port
PROJECT_ROOT=${PROJECT_ROOT:-/mnt/nfs/home/srajasekharu/work1/distSysLibs}
HEAD_START_DELAY=${HEAD_START_DELAY:-8}         # Seconds to wait for workers

# Limit threaded libraries to requested CPUs
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export MKL_NUM_THREADS=${MKL_NUM_THREADS:-1}
export OPENBLAS_NUM_THREADS=${OPENBLAS_NUM_THREADS:-1}

SHELL_BIN=$(command -v bash || command -v sh)
if [[ -z "${SHELL_BIN}" ]]; then
    echo "Error: Unable to locate a usable shell (bash or sh)." >&2
    exit 1
fi

cleanup_done=0
worker_nodes=()
active_worker_nodes=()

cleanup() {
    if [[ ${cleanup_done} -eq 1 ]]; then
        return
    fi
    cleanup_done=1

    if [[ ${#active_worker_nodes[@]} -gt 0 ]]; then
        echo "Stopping worker processes..."
        for node in "${active_worker_nodes[@]}"; do
            srun --nodes=1 --ntasks=1 --exclusive -w "${node}" \
                "${SHELL_BIN}" -lc "pkill -f benchmarkWorker || true" >/dev/null 2>&1 || true
        done
    fi

    wait || true
    echo "Cleanup complete."
}
trap cleanup EXIT

cd "${PROJECT_ROOT}"

echo "=== Distributed benchmark job starting at $(date) ==="
echo "SLURM job ID: ${SLURM_JOB_ID:-unknown}"
echo "Allocated nodes: ${SLURM_JOB_NODELIST:-$(hostname)}"

echo "Building benchmark binaries..."
make unified_benchmark

if [[ -z "${SLURM_JOB_NODELIST:-}" ]]; then
    echo "Error: SLURM_NODELIST is empty. Submit this script with sbatch/srun requesting multiple nodes."
    exit 1
fi

mapfile -t nodes < <(scontrol show hostnames "${SLURM_JOB_NODELIST}")
if [[ ${#nodes[@]} -lt 2 ]]; then
    echo "This script needs at least 2 nodes (1 head + 1 worker)."
    exit 1
fi

head_node=${nodes[0]}
worker_nodes=("${nodes[@]:1}")
required_workers=1

case "${PATTERN}" in
    direct)
        required_workers=1
        ;;
    sequential)
        required_workers=2
        ;;
    twohop)
        required_workers=2
        ;;
    *)
        echo "Unsupported pattern '${PATTERN}'. Use direct | sequential | twohop."
        exit 1
        ;;
esac

if [[ ${#worker_nodes[@]} -lt ${required_workers} ]]; then
    echo "Pattern '${PATTERN}' requires at least ${required_workers} worker node(s), but only ${#worker_nodes[@]} were allocated."
    exit 1
fi

echo "Head node: ${head_node}"
echo "Worker nodes: ${worker_nodes[*]}"
echo "Pattern: ${PATTERN}"

declare -a worker_addresses=()
primary_node=""
secondary_node=""
mkdir -p logs

launch_worker() {
    local node=$1
    local port=$2
    local forward_target=${3:-}

    echo "Starting worker on ${node}:${port} ${forward_target:+(forward -> ${forward_target})}" >&2
    active_worker_nodes+=("${node}")
    # Use resolved shell binary and exec the worker so the srun step is the worker process.
    srun --nodes=1 --ntasks=1 --exclusive -w "${node}" \
        "${SHELL_BIN}" -lc "cd '${PROJECT_ROOT}'; exec ./build/benchmarkWorker --port ${port} ${forward_target}" \
        > "logs/worker-${node}.out" 2> "logs/worker-${node}.err" &
}

case "${PATTERN}" in
    direct)
        for node in "${worker_nodes[@]}"; do
            launch_worker "${node}" "${WORKER_PORT}"
            worker_addresses+=("${node}:${WORKER_PORT}")
        done
        ;;
    sequential)
        for node in "${worker_nodes[@]}"; do
            launch_worker "${node}" "${WORKER_PORT}"
            worker_addresses+=("${node}:${WORKER_PORT}")
        done
        ;;
    twohop)
        primary_node=${worker_nodes[0]}
        secondary_node=${worker_nodes[1]}
        launch_worker "${secondary_node}" "${FORWARD_PORT}"
        launch_worker "${primary_node}" "${WORKER_PORT}" "--forward-to ${secondary_node}:${FORWARD_PORT}"
        worker_addresses+=("${primary_node}:${WORKER_PORT}")
        ;;
esac

echo "Waiting ${HEAD_START_DELAY}s for workers to start..."
sleep "${HEAD_START_DELAY}"

workers_arg=$(IFS=, ; echo "${worker_addresses[*]}")

head_command=(
    "${SHELL_BIN}" -lc "cd '${PROJECT_ROOT}'; \
    exec ./build/benchmarkHead --pattern ${PATTERN} --workers '${workers_arg}' \
        --min-size ${MIN_SIZE} --max-size ${MAX_SIZE} \
        --increment ${INCREMENT} --samples ${SAMPLES}"
)

echo "Launching benchmark head on ${head_node} with workers: ${workers_arg}"
srun --nodes=1 --ntasks=1 --exclusive -w "${head_node}" "${head_command[@]}"

echo "Benchmark run finished, collected CSV files:"
ls -1 csvfiles/benchmark_results_* 2>/dev/null || echo "No CSV files generated."

echo "=== Distributed benchmark job complete at $(date) ==="
