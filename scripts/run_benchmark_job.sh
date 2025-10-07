#!/bin/bash
#SBATCH --job-name=benchmark-unified
#SBATCH --output=benchmark_results_%j.out
#SBATCH --error=benchmark_results_%j.err
#SBATCH --partition=defq
#SBATCH --ntasks=1
#SBATCH --time=01:00:00
#SBATCH --mem-per-cpu=2048

# Set thread limits to avoid resource conflicts
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

# Change to the project directory
cd /mnt/nfs/home/srajasekharu/work1/distSysLibs

echo "Starting unified benchmark job at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"

# Build the benchmark components
echo "Building benchmark components..."
make unified_benchmark

if [ $? -ne 0 ]; then
    echo "Build failed! Exiting."
    exit 1
fi

echo "Build successful. Starting benchmark tests..."

# Run all benchmark patterns
echo "Running all benchmark patterns..."
make run_unified

echo "Benchmark job completed at $(date)"
echo "Results are available in benchmark_results_*.csv files"

# List the generated result files
echo "Generated result files:"
ls -la benchmark_results_*.csv 2>/dev/null || echo "No CSV files found"