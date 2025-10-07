# SLURM Cluster Usage Guide

This guide covers running the distributed systems benchmark on SLURM-managed clusters.

## Quick Start

### Basic Job Submission

```bash
# Submit individual pattern benchmarks
./submit_benchmark.sh direct      # Direct pattern
./submit_benchmark.sh sequential  # Sequential pattern  
./submit_benchmark.sh twohop      # Two-hop pattern

# Submit comprehensive benchmarks
./submit_benchmark.sh unified     # All patterns (medium scale)
./submit_benchmark.sh large       # Large-scale benchmarks

# Check job status
./submit_benchmark.sh --status
./submit_benchmark.sh --queue
```

### Makefile Integration

```bash
# Submit jobs via Makefile
make submit-direct
make submit-unified  
make submit-large

# Check status
make job-status
```

## Available Job Scripts

| Script | Description | Runtime | Resources |
|--------|-------------|---------|-----------|
| `job_direct.sh` | Direct pattern only | ~30min | 1 CPU, 1GB RAM |
| `job_sequential.sh` | Sequential pattern only | ~30min | 1 CPU, 1GB RAM |
| `job_twohop.sh` | Two-hop pattern only | ~30min | 1 CPU, 1GB RAM |
| `run_benchmark_job.sh` | All patterns (medium) | ~1hr | 1 CPU, 2GB RAM |
| `job_large_benchmark.sh` | Comprehensive analysis | ~2hr | 1 CPU, 2GB RAM |

## Job Configuration

### Resource Allocation

All jobs are configured with conservative resource requests suitable for shared clusters:

```bash
#SBATCH --partition=defq          # Default queue (12hr limit)
#SBATCH --ntasks=1               # Single task
#SBATCH --time=30:00             # 30 minutes (adjust as needed)
#SBATCH --mem-per-cpu=1024       # 1GB RAM per CPU
```

### Environment Setup

Jobs automatically configure thread limits to avoid cluster policy violations:

```bash
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1  
export OPENBLAS_NUM_THREADS=1
```

## Job Management

### Monitoring Jobs

```bash
# Check your jobs
squeue -u $USER

# Check specific job
squeue -j <job_id>

# Show job details
scontrol show job <job_id>

# Check cluster status
sinfo
```

### Job Output

Jobs create separate output files:
- `benchmark_<pattern>_<jobid>.out` - Standard output
- `benchmark_<pattern>_<jobid>.err` - Error output

```bash
# View recent outputs
ls -lt benchmark_*.out | head -5

# Check job completion
tail benchmark_direct_12345.out

# Check for errors
cat benchmark_direct_12345.err
```

### Managing Jobs

```bash
# Cancel a job
scancel <job_id>

# Cancel all your jobs
scancel -u $USER

# Job dependencies (run job B after job A completes)
sbatch --dependency=afterok:<job_A_id> job_sequential.sh
```
