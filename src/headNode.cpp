#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <thread>
#include <future>
#include <chrono>

#include <grpcpp/grpcpp.h>
#include "build/demo.pb.h"
#include "build/demo.grpc.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
using demo::DemoService;
using demo::Request;
using demo::Response;

class WorkerClient {
public:
    WorkerClient(std::shared_ptr<Channel> channel)
        : stub_(DemoService::NewStub(channel)) {}

    std::pair<bool, std::string> ProcessRequest(int jobId, const std::string& query) {
        Request request;
        request.set_jobid(jobId);
        request.set_query(query);

        Response response;
        ClientContext context;

        // Set timeout for the request
        std::chrono::system_clock::time_point deadline =
            std::chrono::system_clock::now() + std::chrono::seconds(10);
        context.set_deadline(deadline);

        Status status = stub_->ProcessRequest(&context, request, &response);

        if (status.ok()) {
            return {response.success(), response.result()};
        } else {
            return {false, "RPC failed: " + status.error_message()};
        }
    }

private:
    std::unique_ptr<DemoService::Stub> stub_;
};

class HeadNode {
public:
    HeadNode() : jobCounter_(0) {}

    void AddWorker(const std::string& address) {
        auto channel = grpc::CreateChannel(address, grpc::InsecureChannelCredentials());
        workers_.push_back(std::make_unique<WorkerClient>(channel));
        workerAddresses_.push_back(address);
        std::cout << "Added worker: " << address << std::endl;
    }

    void DistributeWork(const std::vector<std::string>& tasks) {
        if (workers_.empty()) {
            std::cout << "No workers available!" << std::endl;
            return;
        }

        std::cout << "\n=== Distributing " << tasks.size() << " tasks to " 
                  << workers_.size() << " workers ===" << std::endl;

        std::vector<std::future<void>> futures;

        for (size_t i = 0; i < tasks.size(); ++i) {
            int workerIndex = i % workers_.size();
            int jobId = ++jobCounter_;
            
            auto future = std::async(std::launch::async, [this, workerIndex, jobId, &tasks, i]() {
                auto start = std::chrono::high_resolution_clock::now();
                
                std::cout << "Sending job " << jobId << " to worker " 
                          << workerAddresses_[workerIndex] << ": " << tasks[i] << std::endl;
                
                auto result = workers_[workerIndex]->ProcessRequest(jobId, tasks[i]);
                
                auto end = std::chrono::high_resolution_clock::now();
                auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
                
                if (result.first) {
                    std::cout << "✓ Job " << jobId << " completed in " << duration.count() 
                              << "ms: " << result.second << std::endl;
                } else {
                    std::cout << "✗ Job " << jobId << " failed: " << result.second << std::endl;
                }
            });
            
            futures.push_back(std::move(future));
        }

        // Wait for all tasks to complete
        for (auto& future : futures) {
            future.wait();
        }

        std::cout << "\n=== All tasks completed ===" << std::endl;
    }

    void RunDemo() {
        std::vector<std::string> tasks = {
            "Calculate fibonacci(20)",
            "Sort array [5,2,8,1,9]",
            "Find prime numbers up to 100",
            "Reverse string 'hello world'",
            "Compute square root of 1024",
            "Parse JSON data",
            "Validate email addresses",
            "Compress text data"
        };

        std::cout << "Head Node starting demo with " << workers_.size() << " workers" << std::endl;
        
        // Run multiple rounds of work distribution
        for (int round = 1; round <= 3; ++round) {
            std::cout << "\n--- Round " << round << " ---" << std::endl;
            DistributeWork(tasks);
            
            if (round < 3) {
                std::cout << "Waiting 2 seconds before next round...\n" << std::endl;
                std::this_thread::sleep_for(std::chrono::seconds(2));
            }
        }
    }

private:
    std::vector<std::unique_ptr<WorkerClient>> workers_;
    std::vector<std::string> workerAddresses_;
    std::atomic<int> jobCounter_;
};

int main(int argc, char** argv) {
    HeadNode headNode;

    std::vector<std::string> defaultWorkers = {
        "localhost:50051",
        "localhost:50052", 
        "localhost:50053"
    };

    if (argc > 1) {
        for (int i = 1; i < argc; ++i) {
            headNode.AddWorker(argv[i]);
        }
    } else {
        std::cout << "Using default worker addresses:" << std::endl;
        for (const auto& worker : defaultWorkers) {
            headNode.AddWorker(worker);
        }
    }

    std::cout << "\nWaiting 2 seconds for workers to start..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(2));

    headNode.RunDemo();

    return 0;
}
