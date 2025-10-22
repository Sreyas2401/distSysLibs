#!/bin/bash
# Submit a sweep of experiments for direct and sequential patterns across N workers
# Usage: ./scripts/submit_sweep.sh [--start S] [--end E] [--samples SAMPLES] [--min-size MIN] [--max-size MAX] [--increment INC]

set -euo pipefail

START=${START:-2}
END=${END:-10}
SAMPLES=${SAMPLES:-100}
MIN_SIZE=${MIN_SIZE:-16}
MAX_SIZE=${MAX_SIZE:-8192}
INCREMENT=${INCREMENT:-16}
CPUS_PER_TASK=${CPUS_PER_TASK:-72}
NODES_PER_JOB_EXTRA=${NODES_PER_JOB_EXTRA:-0} # additional nodes if needed

PROJECT_ROOT=$(pwd)
SWEEP_RESULTS_DIR="${PROJECT_ROOT}/results_sweep"
mkdir -p "${SWEEP_RESULTS_DIR}"

submit_and_wait() {
    local pattern=$1
    local N=$2

    local nodes=$((N + 1))
    echo "Submitting ${pattern} with N=${N} (nodes=${nodes})"

    # Submit
    jid=$(sbatch --nodes=${nodes} --export=PATTERN=${pattern},SAMPLES=${SAMPLES},MIN_SIZE=${MIN_SIZE},MAX_SIZE=${MAX_SIZE},INCREMENT=${INCREMENT} scripts/run_distributed_benchmark.sh | awk '{print $4}')
    echo "  submitted job ${jid}, waiting..."

    # Wait for completion
    while squeue -j ${jid} -h >/dev/null 2>&1; do
        sleep 5
    done

    # Move results into structured folder (job may have produced file in csvfiles/)
    dest_dir="${SWEEP_RESULTS_DIR}/${pattern}/N${N}"
    mkdir -p "${dest_dir}"

    # Move CSVs and logs; use SLURM_JOB_ID in filename if present
    if compgen -G "csvfiles/benchmark_results_${pattern}.csv" >/dev/null; then
        mv csvfiles/benchmark_results_${pattern}.csv "${dest_dir}/benchmark_results_${pattern}_job${jid}.csv" || true
    fi

    # move logs if created
    if compgen -G "logs/worker-*" >/dev/null; then
        mkdir -p "${dest_dir}/logs"
        mv logs/worker-* "${dest_dir}/logs/" || true
    fi

    # save batch stdout/err if present
    if compgen -G "benchmark_distributed_${jid}.out" >/dev/null; then
        mv benchmark_distributed_${jid}.out "${dest_dir}/"
    fi
    if compgen -G "benchmark_distributed_${jid}.err" >/dev/null; then
        mv benchmark_distributed_${jid}.err "${dest_dir}/"
    fi

    echo "  results moved to ${dest_dir}"
}

# Run sweep for direct and sequential
for pattern in direct sequential; do
    for N in $(seq ${START} ${END}); do
        # skip invalid N for direct (direct can use N>=1 but we start at START)
        submit_and_wait ${pattern} ${N}
    done
done

echo "Sweep complete. Results under ${SWEEP_RESULTS_DIR}/" 
