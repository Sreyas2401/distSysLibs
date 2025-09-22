# Communication Latency Benchmark

This benchmark experiment analyzes communication latency in distributed systems with a focus on the baseline direct worker communication pattern.

## Experiment Design

### Baseline: Direct Worker Communication

**Communication Pattern:**
```
head -> data -> worker -> ack -> head
```

**Key Parameters:**
- **Variable Data Size**: Payload varies in increments of 16 bytes (configurable)
- **Fixed Acknowledgement**: Always 512 bytes
- **Measurement**: Round-trip latency profiled on the head node

## Components

### 1. Protocol Definition (`benchmark.proto`)
- Defines `BenchmarkService` with variable payload and fixed acknowledgement
- Includes timing information for precise latency measurement

### 2. Benchmark Worker (`benchmarkWorker.cpp`)
- Receives variable-size payloads
- Returns fixed 512-byte acknowledgements
- Minimal processing to isolate communication overhead

### 3. Benchmark Head (`benchmarkHead.cpp`)
- Generates payloads of varying sizes
- Measures round-trip latency with high precision
- Collects comprehensive statistics (mean, median, P95, P99)
- Exports results to CSV format

### 4. Benchmark Runner (`run_benchmark.sh`)
- Automated script to run complete experiments
- Handles process management and cleanup
- Configurable parameters

### 5. Results Analysis (`analyze_results.py`)
- Generates visualizations and statistical analysis
- Calculates throughput estimates
- Provides insights into scaling behavior

## Usage

### Quick Start

1. **Build the benchmark components:**
   ```bash
   make benchmark-proto
   make all
   ```

2. **Run the benchmark with default settings:**
   ```bash
   ./run_benchmark.sh
   ```

3. **Analyze the results:**
   ```bash
   python3 analyze_results.py
   ```

### Advanced Configuration

**Custom payload size range:**
```bash
./run_benchmark.sh --min-size 32 --max-size 16384 --increment 32 --samples 200
```

**Custom worker port:**
```bash
./run_benchmark.sh --port 50052
```

**Run head and worker separately:**
```bash
# Terminal 1: Start worker
./build/benchmarkWorker 50051

# Terminal 2: Run benchmark
./build/benchmarkHead --worker localhost:50051 --min-size 16 --max-size 8192
```

## Configuration Options

### Benchmark Runner (`run_benchmark.sh`)
- `--port PORT`: Worker port (default: 50051)
- `--min-size SIZE`: Minimum payload size in bytes (default: 16)
- `--max-size SIZE`: Maximum payload size in bytes (default: 8192)
- `--increment SIZE`: Payload size increment in bytes (default: 16)
- `--samples COUNT`: Number of samples per payload size (default: 100)
- `--no-cleanup`: Don't stop worker process on exit

### Benchmark Head (`benchmarkHead`)
- `--worker ADDRESS`: Worker address (default: localhost:50051)
- `--min-size SIZE`: Minimum payload size
- `--max-size SIZE`: Maximum payload size
- `--increment SIZE`: Payload size increment
- `--samples COUNT`: Number of samples per payload size

## Output and Analysis

### Results File (`benchmark_results.csv`)
Contains detailed measurements with columns:
- `PayloadSize`: Size of the data payload in bytes
- `LatencyMs`: Round-trip latency in milliseconds
- `Success`: Whether the request succeeded (1) or failed (0)
- `RequestTimestamp`: Timestamp when request was sent (nanoseconds)
- `ResponseTimestamp`: Timestamp when response was generated (nanoseconds)

### Analysis Script Output
- Statistical summary by payload size
- Latency visualizations (mean, percentiles, distributions)
- Throughput estimates
- Correlation analysis between payload size and latency

### Generated Plots
- `benchmark_plots/latency_analysis.png`: Comprehensive 4-panel analysis
- `benchmark_plots/latency_scatter.png`: Individual measurements with trends

## Expected Results

### Typical Observations
1. **Linear Scaling**: Latency generally increases with payload size
2. **Base Overhead**: Minimum latency represents protocol/network overhead
3. **Throughput Saturation**: Data throughput may plateau at larger payload sizes
4. **Variability**: Higher latency variability with larger payloads

### Key Metrics
- **Base Latency**: Minimum observed latency (16-byte payload)
- **Scaling Factor**: Ratio of latency increase to payload size increase
- **Throughput Ceiling**: Maximum sustained data throughput
- **Efficiency**: Scaling factor relative to theoretical linear scaling

## System Requirements

### Build Dependencies
- C++17 compiler (g++ or clang++)
- gRPC and Protocol Buffers development libraries
- pkg-config

### Analysis Dependencies
- Python 3.x
- matplotlib
- pandas
- numpy

### Installation (Ubuntu/Debian)
```bash
# Build dependencies
sudo apt update
sudo apt install build-essential pkg-config
sudo apt install libgrpc++-dev libprotobuf-dev protobuf-compiler-grpc

# Python dependencies
pip3 install matplotlib pandas numpy
```

### Installation (macOS)
```bash
# Build dependencies
brew install grpc protobuf pkg-config

# Python dependencies
pip3 install matplotlib pandas numpy
```

## Extending the Benchmark

### Adding New Communication Patterns
1. Create new protocol definitions (e.g., `multicast.proto`)
2. Implement corresponding head and worker nodes
3. Add build targets to Makefile
4. Create specialized runner scripts

### Custom Analysis
The CSV output format enables custom analysis with any data analysis tool:
- Excel/Google Sheets for basic analysis
- R for statistical modeling
- Python/Jupyter for advanced visualization
- MATLAB for signal processing analysis

## Troubleshooting

### Common Issues
1. **Build Failures**: Ensure gRPC and protobuf development libraries are installed
2. **Port Conflicts**: Use `--port` to specify alternative ports
3. **High Latency**: Check network conditions and system load
4. **Failed Requests**: Increase timeout values or reduce concurrency

### Debug Mode
Run components individually to isolate issues:
```bash
# Start worker with verbose output
./build/benchmarkWorker 50051

# Run head with minimal configuration
./build/benchmarkHead --worker localhost:50051 --samples 10
```

## Performance Notes

### Optimization for Accuracy
- **Warmup Phase**: Initial requests warm up the connection
- **High-Resolution Timing**: Nanosecond precision timestamps
- **Statistical Sampling**: Multiple samples per payload size for reliability
- **Isolated Measurement**: Minimal processing in worker to isolate communication overhead

### Scaling Considerations
- Default configuration tests ~500 different payload sizes
- With 100 samples each, total of ~50,000 measurements
- Typical runtime: 5-15 minutes depending on system performance
- Memory usage scales with result storage (~10MB for default configuration)