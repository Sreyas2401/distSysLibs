cmake_minimum_required(VERSION 3.10)
project(DistributedSystem)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Protobuf REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(GRPC REQUIRED grpc++)

# Include directories
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${Protobuf_INCLUDE_DIRS})

# Generated protobuf and gRPC files
set(PROTO_SRCS
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.pb.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.grpc.pb.cc
)

set(PROTO_HDRS
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.pb.h
    ${CMAKE_CURRENT_SOURCE_DIR}/build/demo.grpc.pb.h
)

# Worker node executable
add_executable(build/workerNode
    workerNode.cpp
    ${PROTO_SRCS}
)

target_link_libraries(build/workerNode
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    grpc++
    grpc
    protobuf
    pthread
)

# Head node executable
add_executable(build/headNode
    headNode.cpp
    ${PROTO_SRCS}
)

target_link_libraries(build/headNode
    ${Protobuf_LIBRARIES}
    ${GRPC_LIBRARIES}
    grpc++
    grpc
    protobuf
    pthread
)
