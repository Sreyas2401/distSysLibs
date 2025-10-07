#!/bin/bash
#SBATCH --job-name=benchmark-twohop
#SBATCH --output=benchmark_twohop_%j.out
#SBATCH --error=benchmark_twohop_%j.err
#SBATCH --partition=defq
#SBATCH --ntasks=1
#SBATCH --time=30:00
#SBATCH --mem-per-cpu=1024

# Set thread limits
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

cd /mnt/nfs/home/srajasekharu/work1/distSysLibs

echo "Starting two-hop pattern benchmark at $(date)"
echo "Job ID: $SLURM_JOB_ID"

make run_twohop

echo "Two-hop pattern benchmark completed at $(date)"