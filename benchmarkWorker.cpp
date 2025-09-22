#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <chrono>

#include <grpcpp/grpcpp.h>
#include "build/benchmark.pb.h"
#include "build/benchmark.grpc.pb.h"

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using benchmark::BenchmarkService;
using benchmark::BenchmarkRequest;
using benchmark::BenchmarkResponse;

class BenchmarkServiceImpl final : public BenchmarkService::Service {
public:
    BenchmarkServiceImpl() {
        // Pre-generate 512-byte acknowledgement data
        ackData_.resize(512);
        for (int i = 0; i < 512; ++i) {
            ackData_[i] = static_cast<char>('A' + (i % 26));
        }
    }

    Status ProcessBenchmark(ServerContext* context, const BenchmarkRequest* request,
                           BenchmarkResponse* response) override {
        
        auto responseTime = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::high_resolution_clock::now().time_since_epoch()).count();

        // Set response fields
        response->set_requestid(request->requestid());
        response->set_acknowledgement(ackData_);
        response->set_requesttimestamp(request->timestamp());
        response->set_responsetimestamp(responseTime);
        response->set_success(true);
        
        // Optional: Log for debugging
        if (request->requestid() % 100 == 0) {  // Log every 100th request to avoid spam
            std::cout << "Worker processed request " << request->requestid() 
                      << " with payload size: " << request->payload().size() 
                      << " bytes" << std::endl;
        }
        
        return Status::OK;
    }

private:
    std::string ackData_;
};

void RunServer(const std::string& port) {
    std::string server_address("localhost:" + port);
    BenchmarkServiceImpl service;

    ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);
    
    std::unique_ptr<Server> server(builder.BuildAndStart());
    if (!server) {
        std::cout << "Failed to start server on " << server_address << std::endl;
        return;
    }
    
    std::cout << "Benchmark worker server listening on " << server_address << std::endl;

    server->Wait();
}

int main(int argc, char** argv) {
    std::string port = "50051";
    
    if (argc > 1) {
        port = argv[1];
    }
    
    std::cout << "Starting benchmark worker node on port " << port << std::endl;
    RunServer(port);
    
    return 0;
}