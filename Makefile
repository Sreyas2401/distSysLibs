CXX = g++
CXXFLAGS = -std=c++17 -Wall -O2
PKG_CONFIG_CFLAGS = $(shell pkg-config --cflags grpc++ protobuf)
PKG_CONFIG_LIBS = $(shell pkg-config --libs grpc++ protobuf)
INCLUDES = -I. -I./build $(PKG_CONFIG_CFLAGS)
LIBS = $(PKG_CONFIG_LIBS)

PROTO_SRCS = build/demo.pb.cc build/demo.grpc.pb.cc
PROTO_OBJS = $(PROTO_SRCS:.cc=.o)

all: build/headNode build/workerNode

build/headNode: build/headNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/workerNode: build/workerNode.o $(PROTO_OBJS)
	$(CXX) $(CXXFLAGS) -o $@ $^ $(LIBS)

build/%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

build/%.o: %.cc
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

%.o: %.cc
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f build/*.o build/headNode build/workerNode

proto: demo.proto
	protoc --cpp_out=build demo.proto
	protoc --grpc_out=build --plugin=protoc-gen-grpc=$$(which grpc_cpp_plugin) demo.proto

.PHONY: all clean proto
