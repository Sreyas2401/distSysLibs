#!/bin/bash

# Script to start the distributed system demo

echo "Building the distributed system..."
make clean && make

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Starting worker nodes..."

# Start worker nodes in background
./build/workerNode 50051 &
WORKER1_PID=$!
echo "Started worker 1 on port 50051 (PID: $WORKER1_PID)"

./build/workerNode 50052 &
WORKER2_PID=$!
echo "Started worker 2 on port 50052 (PID: $WORKER2_PID)"

./build/workerNode 50053 &
WORKER3_PID=$!
echo "Started worker 3 on port 50053 (PID: $WORKER3_PID)"

# Function to cleanup worker processes
cleanup() {
    echo "Shutting down workers..."
    kill $WORKER1_PID $WORKER2_PID $WORKER3_PID 2>/dev/null
    wait
    echo "All workers stopped."
}

# Set up trap to cleanup on script exit
trap cleanup EXIT

echo "Waiting for workers to initialize..."
sleep 3

echo "Starting head node..."
./build/headNode

echo "Demo completed!"
