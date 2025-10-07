#!/bin/bash
# Helper script to submit benchmark jobs to SLURM

show_usage() {
    echo "Usage: $0 [OPTIONS] BENCHMARK_TYPE"
    echo ""
    echo "BENCHMARK_TYPE:"
    echo "  direct      - Run direct pattern benchmark"
    echo "  sequential  - Run sequential pattern benchmark"
    echo "  twohop      - Run two-hop pattern benchmark"
    echo "  unified     - Run all patterns (medium)"
    echo "  large       - Run comprehensive large-scale benchmarks"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help  - Show this help message"
    echo "  -s, --status - Show job status"
    echo "  -q, --queue  - Show queue status"
    echo ""
    echo "Examples:"
    echo "  $0 direct           # Submit direct pattern job"
    echo "  $0 unified          # Submit all patterns job"
    echo "  $0 large            # Submit large-scale benchmark"
    echo "  $0 --status         # Show your job status"
}

show_status() {
    echo "=== Your current jobs ==="
    squeue -u $USER
    echo ""
    echo "=== Recent job outputs ==="
    ls -lt benchmark_*.out benchmark_*.err 2>/dev/null | head -5
}

show_queue() {
    echo "=== Queue status ==="
    sinfo
    echo ""
    echo "=== Running jobs ==="
    squeue
}

case "$1" in
    "direct")
        echo "Submitting direct pattern benchmark job..."
        sbatch job_direct.sh
        ;;
    "sequential")
        echo "Submitting sequential pattern benchmark job..."
        sbatch job_sequential.sh
        ;;
    "twohop")
        echo "Submitting two-hop pattern benchmark job..."
        sbatch job_twohop.sh
        ;;
    "unified")
        echo "Submitting unified benchmark job (all patterns)..."
        sbatch run_benchmark_job.sh
        ;;
    "large")
        echo "Submitting large-scale benchmark job..."
        sbatch job_large_benchmark.sh
        ;;
    "-s"|"--status")
        show_status
        ;;
    "-q"|"--queue")
        show_queue
        ;;
    "-h"|"--help"|"")
        show_usage
        ;;
    *)
        echo "Error: Unknown benchmark type '$1'"
        echo ""
        show_usage
        exit 1
        ;;
esac