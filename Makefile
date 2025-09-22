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

# Main targets - unified benchmark infrastructure
all: build/benchmarkHead build/benchmarkWorker

# Demo targets (original components)
demo: build/headNode build/workerNode

build/headNode: build/headNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/workerNode: build/workerNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

# Unified benchmark targets
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
	rm -f build/*.o build/headNode build/workerNode build/benchmarkHead build/benchmarkWorker benchmark_results*.csv

proto: demo.proto
	protoc --cpp_out=build demo.proto
	protoc --grpc_out=build --plugin=protoc-gen-grpc=$$(which grpc_cpp_plugin) demo.proto

benchmark-proto: benchmark.proto
	protoc --cpp_out=build benchmark.proto
	protoc --grpc_out=build --plugin=protoc-gen-grpc=$$(which grpc_cpp_plugin) benchmark.proto

# Convenient targets for unified benchmark
benchmark_head: build/benchmarkHead

benchmark_worker: build/benchmarkWorker

unified_benchmark: build/benchmarkHead build/benchmarkWorker

run_unified: unified_benchmark
	./run_unified_benchmark.sh all 20

run_direct: unified_benchmark
	./run_unified_benchmark.sh direct 50

run_sequential: unified_benchmark
	./run_unified_benchmark.sh sequential 50

run_twohop: unified_benchmark
	./run_unified_benchmark.sh twohop 50

analyze: 
	python3 simple_analyze.py

.PHONY: all clean proto benchmark-proto benchmark_head benchmark_worker unified_benchmark run_unified run_direct run_sequential run_twohop analyze
