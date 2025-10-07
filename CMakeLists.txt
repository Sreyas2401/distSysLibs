cmake_minimum_required(VERSION 3.10)
project(DistributedSystem)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages using the system versions
find_package(PkgConfig REQUIRED)
find_package(Protobuf REQUIRED)

# Use pkg-config to find gRPC
pkg_check_modules(GRPC REQUIRED grpc++)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/build)
include_directories(${Protobuf_INCLUDE_DIRS})

# Add gRPC include directories from pkg-config
include_directories(${GRPC_INCLUDE_DIRS})

# Generated protobuf and gRPC files for demo
set(DEMO_PROTO_SRCS
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.grpc.pb.cc
)

# Generated protobuf and gRPC files for benchmark  
set(BENCHMARK_PROTO_SRCS
    ${CMAKE_CURRENT_SOURCE_DIR}/build/benchmark.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/build/benchmark.grpc.pb.cc
)

# Demo executables (original)
add_executable(headNode
    headNode.cpp
    ${DEMO_PROTO_SRCS}
)

target_link_libraries(headNode
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    pthread
)

add_executable(workerNode
    workerNode.cpp
    ${DEMO_PROTO_SRCS}
)

target_link_libraries(workerNode
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    pthread
)

# Benchmark executables (unified infrastructure)
add_executable(benchmarkHead
    benchmarkHead.cpp
    ${BENCHMARK_PROTO_SRCS}
)

target_link_libraries(benchmarkHead
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    pthread
)

add_executable(benchmarkWorker
    benchmarkWorker.cpp
    ${BENCHMARK_PROTO_SRCS}
)

target_link_libraries(benchmarkWorker
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    pthread
)
