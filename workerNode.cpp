#include <iostream>
#include <memory>
#include <string>
#include <thread>
#include <chrono>

#include <grpcpp/grpcpp.h>
#include "build/demo.pb.h"
#include "build/demo.grpc.pb.h"

using grpc::Server;
using grpc::ServerBuilder;
using grpc::ServerContext;
using grpc::Status;
using demo::DemoService;
using demo::Request;
using demo::Response;

class DemoServiceImpl final : public DemoService::Service {
    Status ProcessRequest(ServerContext* context, const Request* request,
                         Response* response) override {
        
        std::cout << "Worker received job " << request->jobid() 
                  << " with query: " << request->query() << std::endl;

        response->set_jobid(request->jobid());
        response->set_result("Processed: " + request->query() + " [Worker Response]");
        response->set_success(true);
        
        std::cout << "Worker completed job " << request->jobid() << std::endl;
        
        return Status::OK;
    }
};

void RunServer(const std::string& port) {
    std::string server_address("0.0.0.0:" + port);
    DemoServiceImpl service;

    ServerBuilder builder;
    builder.AddListeningPort(server_address, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);
    
    std::unique_ptr<Server> server(builder.BuildAndStart());
    std::cout << "Worker server listening on " << server_address << std::endl;

    server->Wait();
}

int main(int argc, char** argv) {
    std::string port = "50051";
    
    if (argc > 1) {
        port = argv[1];
    }
    
    std::cout << "Starting worker node on port " << port << std::endl;
    RunServer(port);
    
    return 0;
}
