# Distributed Systems Communication Latency Benchmark

A comprehensive distributed system implementation and communication latency benchmark suite using gRPC, designed for distributed systems research and performance analysis.

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Components](#components)
- [Building](#building)
- [Usage](#usage)
- [SLURM Cluster Usage](#slurm-cluster-usage)
- [Documentation](#documentation)
- [Contributing](#contributing)

## Overview

This project provides two main components:

1. **Unified Communication Latency Benchmark**: Measures and compares latency across three communication patterns:
   - **Direct**: `head → worker → ack → head`
   - **Sequential**: `head → worker1 → ack → head → worker2 → ack → head`  
   - **Two-hop**: `head → worker1 → worker2 → ack → head`

2. **Basic Distributed System Demo**: Simple task distribution system for educational purposes

## Project Structure

```
distSysLibs/
├── README.md                    # This file
├── docs/                       # Detailed documentation
│   ├── BUILDING.md                 # Build instructions
│   ├── CLUSTER_USAGE.md            # SLURM cluster guide
│   ├── DEMO_USAGE.md               # Demo system guide
│   └── BENCHMARK_USAGE.md          # Benchmark guide
├── scripts/                    # Job submission scripts
│   ├── submit_benchmark.sh         # Main submission script
│   ├── job_*.sh                   # Individual job scripts
│   └── run_*.sh                   # Execution scripts
├── src/                        # Source code
│   ├── benchmark*.cpp             # Benchmark components
│   ├── headNode.cpp               # Demo head node
│   ├── workerNode.cpp             # Demo worker
│   └── *.proto                    # Protocol definitions
├── analysis/                   # Analysis tools
│   └── simple_analyze.py          # Results analysis
├── CMakeLists.txt
├── Makefile
└── build/                      # Build artifacts

```

## Quick Start

### Prerequisites

- **C++17** compatible compiler (g++ 7.0+)
- **CMake** 3.10+
- **gRPC** and **Protocol Buffers** (system-installed or via package manager)
- **Python 3** (for analysis scripts)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Sreyas2401/distSysLibs.git
   cd distSysLibs
   ```

2. **Build the project:**
   ```bash
   make unified_benchmark    # Build benchmark components
   make demo                # Build demo components  
   ```

3. **Run a quick test:**
   ```bash
   make run_direct          # Test direct pattern
   ```

## Components

### Unified Benchmark Infrastructure
- **`benchmarkHead.cpp`**: Unified head node supporting all communication patterns
- **`benchmarkWorker.cpp`**: Enhanced worker node with optional forwarding capability
- **`benchmark.proto`**: Protocol definition for variable payloads and fixed acknowledgments

### Demo System (Educational)
- **`headNode.cpp`**: Simple task distribution head node
- **`workerNode.cpp`**: Basic worker node for task processing
- **`demo.proto`**: Protocol definition for demo tasks

## Building

The project supports both **Makefile** and **CMake** build systems:

### Using Makefile (Recommended)
```bash
# Build everything
make all

# Build specific components
make unified_benchmark      # Benchmark system
make demo                  # Demo system
make benchmark-proto       # Generate benchmark protobuf files
make proto                 # Generate demo protobuf files
```

### Using CMake
```bash
mkdir build && cd build
cmake ..
make
```

For detailed build instructions, see [📄 docs/BUILDING.md](docs/BUILDING.md)

## Usage

### Benchmark System

#### Interactive Usage
```bash
# Individual patterns
make run_direct            # Direct pattern
make run_sequential        # Sequential pattern
make run_twohop           # Two-hop pattern
make run_unified          # All patterns

# Analysis
make analyze              # Generate comparison plots
```

#### Manual Usage
```bash
# Start workers
./build/benchmarkWorker --port 50060 &
./build/benchmarkWorker --port 50061 &

# Run benchmark
./build/benchmarkHead --pattern direct --workers localhost:50060 --samples 100
```

### Demo System
```bash
# Automated demo
./run_demo.sh

# Manual demo
./build/workerNode 50051 &
./build/headNode localhost:50051
```

For detailed usage instructions, see:
- [docs/BENCHMARK_USAGE.md](docs/BENCHMARK_USAGE.md)
- [docs/DEMO_USAGE.md](docs/DEMO_USAGE.md)

## SLURM Cluster Usage

### Quick Submission
```bash
# Submit individual jobs
./scripts/submit_benchmark.sh direct
./scripts/submit_benchmark.sh unified

# Check status
./scripts/submit_benchmark.sh --status
```

### Makefile Shortcuts
```bash
make submit-direct         # Submit direct pattern job
make submit-unified        # Submit all patterns job
make job-status           # Check job status
```

For detailed cluster usage, see [docs/CLUSTER_USAGE.md](docs/CLUSTER_USAGE.md)

### Option 2: Using CMake
```bash
mkdir cmake-build && cd cmake-build
cmake ..
make
```

## Running the System

### Original Distributed System Demo
Run the automated demo script:
```bash
./scripts/run_demo.sh
```

Or manually:
```bash
# Terminal 1-3: Start workers
./build/workerNode 50051
./build/workerNode 50052  
./build/workerNode 50053

# Terminal 4: Run head node
./build/headNode
```

### Communication Latency Benchmark

#### Quick Demo (30 seconds)
```bash
./quick_demo.sh
```

#### Full Benchmark (5-15 minutes)
```bash
./run_benchmark.sh
```

#### Custom Configuration
```bash
./run_benchmark.sh --min-size 32 --max-size 16384 --increment 32 --samples 200
```

#### Analysis
```bash
python3 analyze_results.py
```

For detailed benchmark documentation, see [`BENCHMARK_README.md`](BENCHMARK_README.md).
./run_demo.sh
```

This will:
1. Build the project
2. Start 3 worker nodes on ports 50051, 50052, 50053
3. Run the head node to distribute tasks
4. Clean up worker processes when done

### Manual Operation

Start worker nodes manually:
```bash
# Terminal 1
./build/workerNode 50051

# Terminal 2
./build/workerNode 50052

# Terminal 3
./build/workerNode 50053
```

Start head node:
```bash
# Terminal 4
./build/headNode localhost:50051 localhost:50052 localhost:50053
```

Or use default addresses:
```bash
./build/headNode
```

## How It Works

1. **Worker Nodes**: Each worker starts a gRPC server listening on a specified port
2. **Head Node**: 
   - Connects to specified worker addresses
   - Creates a list of dummy tasks
   - Distributes tasks to workers using round-robin
   - Collects and displays results asynchronously
3. **Communication**: Uses the `ProcessRequest` RPC defined in `demo.proto`

## Example Output

```
Head Node starting demo with 3 workers

=== Distributing 8 tasks to 3 workers ===
Sending job 1 to worker localhost:50051: Calculate fibonacci(20)
Sending job 2 to worker localhost:50052: Sort array [5,2,8,1,9]
Sending job 3 to worker localhost:50053: Find prime numbers up to 100
...
✓ Job 1 completed in 234ms: Processed: Calculate fibonacci(20) [Worker Response]
✓ Job 2 completed in 156ms: Processed: Sort array [5,2,8,1,9] [Worker Response]
...
=== All tasks completed ===
```

## File Structure

```
├── demo.proto              # Protocol buffer definition
├── headNode.cpp            # Head node implementation
├── workerNode.cpp          # Worker node implementation
├── CMakeLists.txt          # CMake build configuration
├── Makefile                # Make build configuration
├── run_demo.sh             # Demo startup script
└── build/                  # Build directory (contains all compiled files)
    ├── demo.pb.h
    ├── demo.pb.cc
    ├── demo.grpc.pb.h
    ├── demo.grpc.pb.cc
    ├── *.o                 # Object files
    ├── headNode            # Head node executable
    └── workerNode          # Worker node executable
```

## Customization

- Modify `demo.proto` to add new RPC methods or message fields
- Adjust worker processing logic in `workerNode.cpp`
- Change task distribution strategy in `headNode.cpp`
- Add more sophisticated error handling and retry logic
