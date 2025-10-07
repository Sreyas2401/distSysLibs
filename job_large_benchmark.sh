#!/bin/bash
#SBATCH --job-name=benchmark-large
#SBATCH --output=benchmark_large_%j.out
#SBATCH --error=benchmark_large_%j.err
#SBATCH --partition=longq
#SBATCH --ntasks=1
#SBATCH --time=02:00:00
#SBATCH --mem-per-cpu=2048

# Set thread limits
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

cd /mnt/nfs/home/srajasekharu/work1/distSysLibs

echo "Starting large-scale benchmark job at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"

# Build first
make unified_benchmark

# Run comprehensive benchmarks with more samples
echo "Running direct pattern with 100 samples..."
./run_unified_benchmark.sh direct 100

echo "Running sequential pattern with 100 samples..."
./run_unified_benchmark.sh sequential 100

echo "Running two-hop pattern with 100 samples..."
./run_unified_benchmark.sh twohop 100

# Run analysis
echo "Analyzing results..."
python3 simple_analyze.py

echo "Large-scale benchmark completed at $(date)"
echo "All results saved and analyzed."