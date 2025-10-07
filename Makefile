CXX = g++
CXXFLAGS = -std=c++17 -Wall -O2
PKG_CONFIG_CFLAGS = $(shell pkg-config --cflags grpc++ protobuf)
PKG_CONFIG_LIBS = $(shell pkg-config --libs grpc++ protobuf)
INCLUDES = -I. -I./build $(PKG_CONFIG_CFLAGS)
LIBS = $(PKG_CONFIG_LIBS)

# Demo components (original)
PROTO_SRCS = build/demo.pb.cc build/demo.grpc.pb.cc
PROTO_OBJS = $(PROTO_SRCS:.cc=.o)

# Unified benchmark components
BENCHMARK_PROTO_SRCS = build/benchmark.pb.cc build/benchmark.grpc.pb.cc
BENCHMARK_PROTO_OBJS = $(BENCHMARK_PROTO_SRCS:.cc=.o)

# Main targets - unified benchmark infrastructure (using CMAKE)
all: cmake_benchmark

# Demo targets (original components - using direct compilation)
demo: build/headNode build/workerNode

build/headNode: build/headNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/workerNode: build/workerNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

# CMake-based benchmark targets
cmake_benchmark: build/benchmark.pb.cc build/benchmark.grpc.pb.cc
	mkdir -p build
	cd build && cmake .. && make benchmarkHead benchmarkWorker

# Legacy direct compilation targets (kept for fallback)
build/benchmarkHead: build/benchmarkHead.o $(BENCHMARK_PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/benchmarkWorker: build/benchmarkWorker.o $(BENCHMARK_PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

build/%.o: %.cc
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.cc
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f build/*.o build/headNode build/workerNode benchmark_results*.csv
	rm -f build/benchmarkHead build/benchmarkWorker 
	cd build && make clean || true
	rm -rf build/CMakeFiles build/CMakeCache.txt build/_deps

proto: src/demo.proto
	protoc --cpp_out=build src/demo.proto
	protoc --grpc_out=build --plugin=protoc-gen-grpc=$$(which grpc_cpp_plugin) src/demo.proto

benchmark-proto: src/benchmark.proto
	protoc --cpp_out=build src/benchmark.proto
	protoc --grpc_out=build --plugin=protoc-gen-grpc=$$(which grpc_cpp_plugin) src/benchmark.proto

# Convenient targets for unified benchmark
benchmark_head: cmake_benchmark

benchmark_worker: cmake_benchmark

unified_benchmark: cmake_benchmark

run_unified: unified_benchmark
	./scripts/run_unified_benchmark.sh all 20

run_direct: unified_benchmark
	./scripts/run_unified_benchmark.sh direct 50

run_sequential: unified_benchmark
	./scripts/run_unified_benchmark.sh sequential 50

run_twohop: unified_benchmark
	./scripts/run_unified_benchmark.sh twohop 50

analyze: 
	python3 analysis/simple_analyze.py

# SLURM batch job shortcuts
submit-direct:
	./scripts/submit_benchmark.sh direct

submit-sequential:
	./scripts/submit_benchmark.sh sequential

submit-twohop:
	./scripts/submit_benchmark.sh twohop

submit-unified:
	./scripts/submit_benchmark.sh unified

submit-large:
	./scripts/submit_benchmark.sh large

job-status:
	./scripts/submit_benchmark.sh --status

.PHONY: all clean proto benchmark-proto benchmark_head benchmark_worker unified_benchmark run_unified run_direct run_sequential run_twohop analyze submit-direct submit-sequential submit-twohop submit-unified submit-large job-status
