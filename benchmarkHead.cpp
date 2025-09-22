#include <iostream>
#include <memory>
#include <string>
#include <vector>
#include <chrono>
#include <thread>
#include <fstream>
#include <iomanip>
#include <algorithm>
#include <numeric>

#include <grpcpp/grpcpp.h>
#include "build/benchmark.pb.h"
#include "build/benchmark.grpc.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
using benchmark::BenchmarkService;
using benchmark::BenchmarkRequest;
using benchmark::BenchmarkResponse;

struct LatencyMeasurement {
    int payloadSize;
    double latencyMs;
    bool success;
    int64_t requestTimestamp;
    int64_t responseTimestamp;
};

class BenchmarkClient {
public:
    BenchmarkClient(std::shared_ptr<Channel> channel)
        : stub_(BenchmarkService::NewStub(channel)) {}

    LatencyMeasurement RunBenchmark(int requestId, int payloadSize) {
        BenchmarkRequest request;
        request.set_requestid(requestId);
        
        // Generate payload of specified size
        std::string payload(payloadSize, 'X');
        request.set_payload(payload);
        
        auto requestTime = std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::high_resolution_clock::now().time_since_epoch()).count();
        request.set_timestamp(requestTime);

        BenchmarkResponse response;
        ClientContext context;

        // Set timeout for the request
        std::chrono::system_clock::time_point deadline =
            std::chrono::system_clock::now() + std::chrono::seconds(30);
        context.set_deadline(deadline);

        auto start = std::chrono::high_resolution_clock::now();
        Status status = stub_->ProcessBenchmark(&context, request, &response);
        auto end = std::chrono::high_resolution_clock::now();

        auto latencyNs = std::chrono::duration_cast<std::chrono::nanoseconds>(end - start).count();
        double latencyMs = latencyNs / 1000000.0;

        LatencyMeasurement measurement;
        measurement.payloadSize = payloadSize;
        measurement.latencyMs = latencyMs;
        measurement.success = status.ok() && response.success();
        measurement.requestTimestamp = requestTime;
        measurement.responseTimestamp = response.responsetimestamp();

        if (!measurement.success) {
            std::cout << "Request " << requestId << " failed: " << status.error_message() << std::endl;
        }

        return measurement;
    }

private:
    std::unique_ptr<BenchmarkService::Stub> stub_;
};

class BenchmarkHead {
public:
    BenchmarkHead(const std::string& workerAddress) {
        auto channel = grpc::CreateChannel(workerAddress, grpc::InsecureChannelCredentials());
        client_ = std::make_unique<BenchmarkClient>(channel);
        workerAddress_ = workerAddress;
        std::cout << "Connected to worker: " << workerAddress << std::endl;
    }

    void RunLatencyBenchmark(int minSize = 16, int maxSize = 8192, int increment = 16, int samplesPerSize = 100) {
        std::cout << "\n=== Starting Latency Benchmark ===" << std::endl;
        std::cout << "Payload size range: " << minSize << " to " << maxSize << " bytes" << std::endl;
        std::cout << "Increment: " << increment << " bytes" << std::endl;
        std::cout << "Samples per size: " << samplesPerSize << std::endl;
        std::cout << "Worker: " << workerAddress_ << std::endl;
        std::cout << "Fixed acknowledgement size: 512 bytes\n" << std::endl;

        std::vector<LatencyMeasurement> allMeasurements;
        int requestId = 1;

        // Warmup phase
        std::cout << "Warmup phase..." << std::endl;
        for (int i = 0; i < 10; ++i) {
            client_->RunBenchmark(requestId++, 1024);
        }
        std::cout << "Warmup complete.\n" << std::endl;

        // Main benchmark
        for (int payloadSize = minSize; payloadSize <= maxSize; payloadSize += increment) {
            std::cout << "Testing payload size: " << payloadSize << " bytes... ";
            std::cout.flush();

            std::vector<double> latencies;
            int successCount = 0;

            for (int sample = 0; sample < samplesPerSize; ++sample) {
                auto measurement = client_->RunBenchmark(requestId++, payloadSize);
                allMeasurements.push_back(measurement);
                
                if (measurement.success) {
                    latencies.push_back(measurement.latencyMs);
                    successCount++;
                }
            }

            if (!latencies.empty()) {
                std::sort(latencies.begin(), latencies.end());
                double mean = std::accumulate(latencies.begin(), latencies.end(), 0.0) / latencies.size();
                double median = latencies[latencies.size() / 2];
                double p95 = latencies[static_cast<size_t>(latencies.size() * 0.95)];
                double p99 = latencies[static_cast<size_t>(latencies.size() * 0.99)];

                std::cout << "Mean: " << std::fixed << std::setprecision(3) << mean << "ms, "
                          << "Median: " << median << "ms, "
                          << "P95: " << p95 << "ms, "
                          << "P99: " << p99 << "ms, "
                          << "Success: " << successCount << "/" << samplesPerSize << std::endl;
            } else {
                std::cout << "All requests failed!" << std::endl;
            }
        }

        // Save detailed results
        SaveResults(allMeasurements);
        
        std::cout << "\n=== Benchmark Complete ===" << std::endl;
        std::cout << "Total measurements: " << allMeasurements.size() << std::endl;
        std::cout << "Results saved to benchmark_results.csv" << std::endl;
    }

private:
    void SaveResults(const std::vector<LatencyMeasurement>& measurements) {
        std::ofstream file("benchmark_results.csv");
        file << "PayloadSize,LatencyMs,Success,RequestTimestamp,ResponseTimestamp\n";
        
        for (const auto& m : measurements) {
            file << m.payloadSize << "," 
                 << std::fixed << std::setprecision(6) << m.latencyMs << ","
                 << (m.success ? "1" : "0") << ","
                 << m.requestTimestamp << ","
                 << m.responseTimestamp << "\n";
        }
        
        file.close();
    }

    std::unique_ptr<BenchmarkClient> client_;
    std::string workerAddress_;
};

int main(int argc, char** argv) {
    std::string workerAddress = "localhost:50051";
    int minSize = 16;
    int maxSize = 8192;
    int increment = 16;
    int samplesPerSize = 100;

    // Parse command line arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--worker" && i + 1 < argc) {
            workerAddress = argv[++i];
        } else if (arg == "--min-size" && i + 1 < argc) {
            minSize = std::stoi(argv[++i]);
        } else if (arg == "--max-size" && i + 1 < argc) {
            maxSize = std::stoi(argv[++i]);
        } else if (arg == "--increment" && i + 1 < argc) {
            increment = std::stoi(argv[++i]);
        } else if (arg == "--samples" && i + 1 < argc) {
            samplesPerSize = std::stoi(argv[++i]);
        } else if (arg == "--help") {
            std::cout << "Usage: " << argv[0] << " [options]\n"
                      << "Options:\n"
                      << "  --worker ADDRESS     Worker address (default: localhost:50051)\n"
                      << "  --min-size SIZE      Minimum payload size in bytes (default: 16)\n"
                      << "  --max-size SIZE      Maximum payload size in bytes (default: 8192)\n"
                      << "  --increment SIZE     Payload size increment in bytes (default: 16)\n"
                      << "  --samples COUNT      Number of samples per payload size (default: 100)\n"
                      << "  --help               Show this help message\n";
            return 0;
        }
    }

    std::cout << "Benchmark Head Node - Direct Worker Communication" << std::endl;
    std::cout << "Configuration:" << std::endl;
    std::cout << "  Worker: " << workerAddress << std::endl;
    std::cout << "  Payload size range: " << minSize << " - " << maxSize << " bytes" << std::endl;
    std::cout << "  Increment: " << increment << " bytes" << std::endl;
    std::cout << "  Samples per size: " << samplesPerSize << std::endl;

    BenchmarkHead head(workerAddress);
    
    // Wait a moment for connection to establish
    std::this_thread::sleep_for(std::chrono::milliseconds(500));
    
    head.RunLatencyBenchmark(minSize, maxSize, increment, samplesPerSize);

    return 0;
}