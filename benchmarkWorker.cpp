#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <chrono>

#include <grpcpp/grpcpp.h>
#include "build/benchmark.pb.h"
#include "build/benchmark.grpc.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using benchmark::BenchmarkService;
using benchmark::BenchmarkRequest;
using benchmark::BenchmarkResponse;

class ForwardingClient {
public:
    ForwardingClient(std::shared_ptr<Channel> channel)
        : stub_(BenchmarkService::NewStub(channel)) {}

    BenchmarkResponse ForwardRequest(const BenchmarkRequest& request) {
        BenchmarkResponse response;
        ClientContext context;

        // Set timeout for the request
        std::chrono::system_clock::time_point deadline =
            std::chrono::system_clock::now() + std::chrono::seconds(30);
        context.set_deadline(deadline);

        Status status = stub_->ProcessBenchmark(&context, request, &response);

        if (!status.ok()) {
            response.set_success(false);
        }

        return response;
    }

private:
    std::unique_ptr<BenchmarkService::Stub> stub_;
};

class BenchmarkServiceImpl final : public BenchmarkService::Service {
public:
    BenchmarkServiceImpl(const std::string& nextWorkerAddress = "") 
        : nextWorkerAddress_(nextWorkerAddress) {
        // Pre-generate 512-byte acknowledgement data
        ackData_.resize(512);
        for (int i = 0; i < 512; ++i) {
            ackData_[i] = static_cast<char>('A' + (i % 26));
        }

        // If we have a next worker, create a client for forwarding
        if (!nextWorkerAddress_.empty()) {
            auto channel = grpc::CreateChannel(nextWorkerAddress_, grpc::InsecureChannelCredentials());
            forwardingClient_ = std::make_unique<ForwardingClient>(channel);
            std::cout << "Worker configured to forward to: " << nextWorkerAddress_ << std::endl;
        }
    }

    Status ProcessBenchmark(ServerContext* context, const BenchmarkRequest* request,
                           BenchmarkResponse* response) override {
        
        auto responseTime = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::high_resolution_clock::now().time_since_epoch()).count();

        // If this worker should forward to another worker (two-hop pattern)
        if (forwardingClient_) {
            // Forward the request to the next worker
            BenchmarkRequest forwardRequest = *request;
            BenchmarkResponse forwardResponse = forwardingClient_->ForwardRequest(forwardRequest);
            
            // Return the response from the final worker
            *response = forwardResponse;
            
            if (request->requestid() % 100 == 0) {
                std::cout << "Worker forwarded request " << request->requestid() 
                          << " to " << nextWorkerAddress_ << std::endl;
            }
        } else {
            // Normal processing - this is the final worker
            response->set_requestid(request->requestid());
            response->set_acknowledgement(ackData_);
            response->set_requesttimestamp(request->timestamp());
            response->set_responsetimestamp(responseTime);
            response->set_success(true);
            
            if (request->requestid() % 100 == 0) {
                std::cout << "Worker processed request " << request->requestid() 
                          << " with payload size: " << request->payload().size() 
                          << " bytes" << std::endl;
            }
        }
        
        return Status::OK;
    }

private:
    std::string ackData_;
    std::string nextWorkerAddress_;
    std::unique_ptr<ForwardingClient> forwardingClient_;
};

void RunServer(const std::string& port, const std::string& nextWorkerAddress = "") {
    std::string server_address("0.0.0.0:" + port);
    BenchmarkServiceImpl service(nextWorkerAddress);

    ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);
    
    std::unique_ptr<Server> server(builder.BuildAndStart());
    if (!server) {
        std::cout << "Failed to start server on " << server_address << std::endl;
        return;
    }
    
    std::cout << "Benchmark worker server listening on " << server_address;
    if (!nextWorkerAddress.empty()) {
        std::cout << " (forwarding to " << nextWorkerAddress << ")";
    }
    std::cout << std::endl;

    server->Wait();
}

int main(int argc, char** argv) {
    std::string port = "50051";
    std::string nextWorkerAddress = "";
    
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--port" && i + 1 < argc) {
            port = argv[++i];
        } else if (arg == "--forward-to" && i + 1 < argc) {
            nextWorkerAddress = argv[++i];
        } else if (arg == "--help") {
            std::cout << "Usage: " << argv[0] << " [options]\n"
                      << "Options:\n"
                      << "  --port PORT           Port to listen on (default: 50051)\n"
                      << "  --forward-to ADDRESS  Forward requests to this worker (for two-hop pattern)\n"
                      << "  --help                Show this help message\n";
            return 0;
        } else if (i == 1 && arg.find("--") != 0) {
            // Backward compatibility: first argument is port
            port = arg;
        }
    }
    
    std::cout << "Starting benchmark worker node on port " << port;
    if (!nextWorkerAddress.empty()) {
        std::cout << " with forwarding to " << nextWorkerAddress;
    }
    std::cout << std::endl;
    
    RunServer(port, nextWorkerAddress);
    
    return 0;
}