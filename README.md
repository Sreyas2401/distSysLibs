# Distributed System Demo

A comprehensive distributed system implementation and communication latency benchmark suite using gRPC.

## Components

### 1. Basic Distributed System
- **Head Node**: Distributes tasks to available worker nodes and collects results
- **Worker Nodes**: Process incoming requests and return results
- **Communication**: gRPC with Protocol Buffers

### 2. Communication Latency Benchmark
- **Baseline Experiment**: Direct worker communication latency analysis
- **Variable Payload Sizes**: Configurable data sizes (16-byte increments)
- **Fixed Acknowledgement**: 512-byte responses
- **Comprehensive Analysis**: Statistical analysis and visualization tools

## Features

### Distributed System
- Multiple worker nodes running on different ports
- Asynchronous task distribution from head node
- Load balancing (round-robin) across workers
- Timeout handling for requests
- Dummy remote procedures with simulated processing time

### Benchmark Suite
- High-precision latency measurements (nanosecond resolution)
- Configurable payload sizes and sample counts
- Statistical analysis (mean, median, P95, P99)
- Automated experiment runner
- Data visualization and analysis tools
- CSV export for custom analysis

## Prerequisites

Make sure you have the following installed:
- g++ with C++17 support
- gRPC and Protocol Buffers libraries
- protoc compiler
- grpc_cpp_plugin

On macOS with Homebrew:
```bash
brew install grpc protobuf
```

## Building

### Option 1: Using Makefile (Recommended)
```bash
make
```

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
./run_demo.sh
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
