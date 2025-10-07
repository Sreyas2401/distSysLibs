#!/bin/bash
#SBATCH --job-name=benchmark-direct
#SBATCH --output=benchmark_direct_%j.out
#SBATCH --error=benchmark_direct_%j.err
#SBATCH --partition=defq
#SBATCH --ntasks=1
#SBATCH --time=30:00
#SBATCH --mem-per-cpu=1024

# Set thread limits
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

cd /mnt/nfs/home/srajasekharu/work1/distSysLibs

echo "Starting direct pattern benchmark at $(date)"
echo "Job ID: $SLURM_JOB_ID"

make run_direct

echo "Direct pattern benchmark completed at $(date)"