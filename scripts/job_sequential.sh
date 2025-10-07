#!/bin/bash
#SBATCH --job-name=benchmark-sequential
#SBATCH --output=benchmark_sequential_%j.out
#SBATCH --error=benchmark_sequential_%j.err
#SBATCH --partition=defq
#SBATCH --ntasks=1
#SBATCH --time=30:00
#SBATCH --mem-per-cpu=1024

# Set thread limits
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

cd /mnt/nfs/home/srajasekharu/work1/distSysLibs

echo "Starting sequential pattern benchmark at $(date)"
echo "Job ID: $SLURM_JOB_ID"

make run_sequential

echo "Sequential pattern benchmark completed at $(date)"