# Building the Distributed Systems Benchmark

### Dependencies

#### Required Libraries
- **gRPC**: High-performance RPC framework
- **Protocol Buffers**: Google's data serialization library
- **pthread**: POSIX threads library (usually system-provided)

#### Optional Dependencies
- **Python 3.6+**: For analysis and visualization scripts
- **matplotlib**: For generating plots (pip install matplotlib)
- **pandas**: For data analysis (pip install pandas)

## Installation Methods

### Method 1: System Package Manager (Recommended for Clusters)

#### macOS (Homebrew)
```bash
brew install grpc protobuf cmake
```

## Building the Project

### Method 1: Makefile (Recommended)

The Makefile provides convenient targets for common build tasks:

```bash
# Build everything
make all

# Build specific components
make unified_benchmark    # Build benchmark system only
make demo                 # Build demo system only

# Generate protobuf files
make benchmark-proto     # Generate benchmark protocol files
make proto               # Generate demo protocol files

# Clean build artifacts
make clean
```

#### Makefile Targets Reference

| Target | Description |
|--------|-------------|
| `all` | Build benchmark system (default) |
| `demo` | Build demo system components |
| `unified_benchmark` | Build benchmark head and worker |
| `benchmark_head` | Build benchmark head only |
| `benchmark_worker` | Build benchmark worker only |
| `proto` | Generate demo protobuf files |
| `benchmark-proto` | Generate benchmark protobuf files |
| `clean` | Remove build artifacts |

### Method 2: CMake

```bash
# Create build directory
mkdir build && cd build

# Configure build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17

# Build
make -j$(nproc)
```

#### CMake Build Options

| Option | Default | Description |
|--------|---------|-------------|
| `CMAKE_BUILD_TYPE` | `Release` | Build type (Debug/Release) |
| `CMAKE_CXX_STANDARD` | `17` | C++ standard version |
| `CMAKE_INSTALL_PREFIX` | `/usr/local` | Installation directory |

## Verification

After building, verify everything works:

```bash
# Check executables exist
ls -la build/benchmark*

# Test basic functionality
./build/benchmarkHead --help
./build/benchmarkWorker --help

# Run quick test
make run_direct
```