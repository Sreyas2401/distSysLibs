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
| `run_distributed_benchmark.sh` | Multi-node head + workers | ~1hr | 3 nodes, 1 CPU/node |

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

## Multi-node Distributed Runs

The benchmark binaries communicate over gRPC, so the head and workers can run on separate compute nodes. The `scripts/run_distributed_benchmark.sh` submission script automates this setup:

1. Requests multiple nodes in a single job (default `#SBATCH --nodes=3`).
2. Uses `SLURM_NODELIST` to discover the allocated hostnames and launches one worker per node with `srun`.
3. Starts the benchmark head after the workers are ready and wires the correct `--workers host:port` list automatically.

### Usage

```bash
sbatch scripts/run_distributed_benchmark.sh
sbatch --nodes=4 --export=PATTERN=sequential,SAMPLES=50 scripts/run_distributed_benchmark.sh
```

The script honours the following environment overrides (pass via `--export`):

- `PATTERN` – `direct`, `sequential`, or `twohop`
- `MIN_SIZE`, `MAX_SIZE`, `INCREMENT` – payload sweep configuration
- `SAMPLES` – samples per payload size
- `WORKER_PORT`, `FORWARD_PORT` – gRPC listener ports
- `HEAD_START_DELAY` – seconds to wait before starting the head node

### Inspecting Node Assignments

SLURM exposes the allocated hostnames via `SLURM_NODELIST`. Expand the list inside your job with:

```bash
scontrol show hostnames "$SLURM_NODELIST"
```

These hostnames (e.g., `swarm042`) are resolvable within the cluster, so you can reference workers as `swarm042:50060` without needing raw IP addresses.

### Custom Tweaks

- Increase `#SBATCH --nodes` to add more worker nodes. The script launches one worker per extra node.
- Two-hop runs automatically forward the primary worker to the secondary via `--forward-to`.
- For manual experiments, allocate nodes interactively via `salloc --nodes=3 --ntasks-per-node=1` and run the script with `bash` once inside the allocation.
