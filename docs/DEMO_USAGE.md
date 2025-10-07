# Demo System Usage Guide

## Overview

The demo system consists of:
- **Head Node**: Distributes tasks to available workers and collects results
- **Worker Nodes**: Process incoming tasks and return results  
- **Communication**: Uses gRPC with Protocol Buffers

This is designed for educational purposes to demonstrate basic distributed system concepts.

## Quick Start

### Automated Demo

The easiest way to run the demo:

```bash
# Build and run complete demo
./run_demo.sh
```

This script will:
1. Build the demo components
2. Start 3 worker nodes in background
3. Run the head node with sample tasks
4. Clean up worker processes

### Manual Demo

For step-by-step understanding:

```bash
# 1. Build demo components
make demo

# 2. Start worker nodes (in separate terminals or background)
./build/workerNode 50051 &
./build/workerNode 50052 &  
./build/workerNode 50053 &

# 3. Run head node
./build/headNode localhost:50051 localhost:50052 localhost:50053

# 4. Clean up (if running in background)
killall workerNode
```

## 🔧 Component Details

### Head Node (`headNode.cpp`)

**Purpose**: Coordinates task distribution and result collection.

**Usage**:
```bash
./build/headNode [worker_addresses...]

# Examples:
./build/headNode                                    # Use default workers
./build/headNode localhost:50051                    # Single worker
./build/headNode localhost:50051 localhost:50052   # Multiple workers
```

**Default Configuration**:
- Uses ports 50051, 50052, 50053 if no addresses specified
- Distributes 8 sample tasks (template only prints message sent)
- Uses round-robin load balancing
- 5-second timeout per task

### Worker Node (`workerNode.cpp`)

**Purpose**: Processes incoming tasks and returns results.

**Usage**:
```bash
./build/workerNode <port>

# Examples:
./build/workerNode 50051    # Listen on port 50051
./build/workerNode 50055    # Listen on port 50055
```

**Behavior**:
- Starts gRPC server on specified port
- Simulates processing with random delay (100-500ms)
- Returns processed task description with timestamp

## Protocol Definition

The demo uses a simple protocol defined in `demo.proto`:

```protobuf
service TaskProcessor {
    rpc ProcessRequest(TaskRequest) returns (TaskResponse);
}

message TaskRequest {
    int32 task_id = 1;
    string task_description = 2;
}

message TaskResponse {
    int32 task_id = 1;
    string result = 2;
    bool success = 3;
}
```