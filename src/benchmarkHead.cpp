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
#include <sstream>
#include <filesystem>

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
    std::string pattern;  // Track which pattern was used
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
        
        // Set timestamp (still used by protocol, just not stored in CSV)
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
    BenchmarkHead(const std::vector<std::string>& workerAddresses, const std::string& pattern = "direct") 
        : pattern_(pattern) {
        for (const auto& address : workerAddresses) {
            auto channel = grpc::CreateChannel(address, grpc::InsecureChannelCredentials());
            clients_.push_back(std::make_unique<BenchmarkClient>(channel));
            workerAddresses_.push_back(address);
        }
        std::cout << "Connected to " << clients_.size() << " workers using " << pattern_ << " pattern" << std::endl;
        for (const auto& addr : workerAddresses_) {
            std::cout << "  Worker: " << addr << std::endl;
        }
    }

    void RunLatencyBenchmark(int minSize = 16, int maxSize = 8192, int increment = 16, int samplesPerSize = 100) {
        std::cout << "\n=== Starting Communication Latency Benchmark ===" << std::endl;
        std::cout << "Pattern: " << GetPatternDescription() << std::endl;
        std::cout << "Payload size range: " << minSize << " to " << maxSize << " bytes" << std::endl;
        std::cout << "Increment: " << increment << " bytes" << std::endl;
        std::cout << "Samples per size: " << samplesPerSize << std::endl;
        std::cout << "Fixed acknowledgement size: 512 bytes\n" << std::endl;

        // Validate pattern requirements
        if (!ValidatePattern()) {
            return;
        }

        std::vector<LatencyMeasurement> allMeasurements;
        int requestId = 1;

        // Warmup phase
        std::cout << "Warmup phase..." << std::endl;
        for (int i = 0; i < 10; ++i) {
            RunPatternRequest(requestId++, 1024);
        }
        std::cout << "Warmup complete.\n" << std::endl;

        // Main benchmark
        for (int payloadSize = minSize; payloadSize <= maxSize; payloadSize += increment) {
            std::cout << "Testing payload size: " << payloadSize << " bytes... ";
            std::cout.flush();

            std::vector<double> latencies;
            int successCount = 0;

            for (int sample = 0; sample < samplesPerSize; ++sample) {
                auto measurement = RunPatternRequest(requestId++, payloadSize);
                allMeasurements.push_back(measurement);
                
                if (measurement.success) {
                    latencies.push_back(measurement.latencyMs);
                    successCount++;
                }
            }

            if (!latencies.empty()) {
                double mean = std::accumulate(latencies.begin(), latencies.end(), 0.0) / latencies.size();
                std::cout << "Mean: " << std::fixed << std::setprecision(3) << mean << "ms, "
                          << "Success: " << successCount << "/" << samplesPerSize << std::endl;
            } else {
                std::cout << "All requests failed!" << std::endl;
            }
        }

        // Save detailed results
        SaveResults(allMeasurements);
        
        std::cout << "\n=== Benchmark Complete ===" << std::endl;
        std::cout << "Total measurements: " << allMeasurements.size() << std::endl;
        std::cout << "Results saved to csvfiles/benchmark_results_" << pattern_ << ".csv" << std::endl;
    }

private:
    std::string GetPatternDescription() {
        if (pattern_ == "direct") {
            return "head -> worker (round-robin across " + std::to_string(clients_.size()) + " workers)";
        } else if (pattern_ == "sequential") {
            return "head -> worker1 -> ack -> head -> worker2 -> ack -> head ... (" + std::to_string(clients_.size()) + " workers)";
        } else if (pattern_ == "twohop") {
            return "head -> worker1 -> worker2 -> ... -> worker" + std::to_string(clients_.size()) + " -> ack -> head";
        }
        return "unknown pattern";
    }

    bool ValidatePattern() {
        if (clients_.empty()) {
            std::cout << "Error: No workers available!" << std::endl;
            return false;
        }
        
        if (pattern_ == "direct") {
            std::cout << "Direct pattern: Using " << clients_.size() << " worker(s) in round-robin" << std::endl;
        } else if (pattern_ == "sequential") {
            std::cout << "Sequential pattern: Contacting all " << clients_.size() << " worker(s) in sequence" << std::endl;
        } else if (pattern_ == "twohop") {
            std::cout << "Two-hop pattern: Using " << clients_.size() << "-worker forwarding chain" << std::endl;
        }
        
        return true;
    }

    LatencyMeasurement RunPatternRequest(int requestId, int payloadSize) {
        if (pattern_ == "direct") {
            return RunDirectRequest(requestId, payloadSize);
        } else if (pattern_ == "sequential") {
            return RunSequentialRequest(requestId, payloadSize);
        } else if (pattern_ == "twohop") {
            return RunTwoHopRequest(requestId, payloadSize);
        }
        
        LatencyMeasurement failed;
        failed.success = false;
        failed.pattern = pattern_;
        return failed;
    }

    LatencyMeasurement RunDirectRequest(int requestId, int payloadSize) {
        // Round-robin across all available workers
        int workerIndex = (requestId - 1) % clients_.size();
        auto measurement = clients_[workerIndex]->RunBenchmark(requestId, payloadSize);
        
        LatencyMeasurement result;
        result.payloadSize = measurement.payloadSize;
        result.latencyMs = measurement.latencyMs;
        result.success = measurement.success;
        result.pattern = "direct";
        
        return result;
    }

    LatencyMeasurement RunSequentialRequest(int requestId, int payloadSize) {
        LatencyMeasurement result;
        result.payloadSize = payloadSize;
        result.pattern = "sequential";
        result.success = true;  // Start optimistic

        auto overallStart = std::chrono::high_resolution_clock::now();

        // Send requests to ALL workers sequentially
        for (size_t i = 0; i < clients_.size(); ++i) {
            auto measurement = clients_[i]->RunBenchmark(requestId + i * 1000000, payloadSize);
            if (!measurement.success) {
                result.success = false;
                // Continue to other workers even if one fails
            }
        }
        
        auto overallEnd = std::chrono::high_resolution_clock::now();
        result.latencyMs = std::chrono::duration_cast<std::chrono::nanoseconds>(
            overallEnd - overallStart).count() / 1000000.0;

        return result;
    }

    LatencyMeasurement RunTwoHopRequest(int requestId, int payloadSize) {
        // For two-hop, we just send to the first worker, which forwards automatically
        auto measurement = clients_[0]->RunBenchmark(requestId, payloadSize);
        
        LatencyMeasurement result;
        result.payloadSize = measurement.payloadSize;
        result.latencyMs = measurement.latencyMs;
        result.success = measurement.success;
        result.pattern = "twohop";
        
        return result;
    }

    void SaveResults(const std::vector<LatencyMeasurement>& measurements) {
        // Create csvfiles directory if it doesn't exist
        std::filesystem::create_directories("csvfiles");
        
        std::string filename = "csvfiles/benchmark_results_" + pattern_ + ".csv";
        std::ofstream file(filename);
        file << "PayloadSize,LatencyMs,Success,Pattern\n";
        
        for (const auto& m : measurements) {
            file << m.payloadSize << "," 
                 << std::fixed << std::setprecision(6) << m.latencyMs << ","
                 << (m.success ? "1" : "0") << ","
                 << m.pattern << "\n";
        }
        
        file.close();
    }

    std::vector<std::unique_ptr<BenchmarkClient>> clients_;
    std::vector<std::string> workerAddresses_;
    std::string pattern_;
};

int main(int argc, char** argv) {
    std::string pattern = "direct";
    std::vector<std::string> workerAddresses;
    int minSize = 16;
    int maxSize = 8192;
    int increment = 16;
    int samplesPerSize = 100;
    
    // Parse command line arguments
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--pattern" && i + 1 < argc) {
            pattern = argv[++i];
        } else if (arg == "--workers" && i + 1 < argc) {
            // Parse comma-separated worker addresses
            std::string workersStr = argv[++i];
            std::stringstream ss(workersStr);
            std::string address;
            while (std::getline(ss, address, ',')) {
                if (!address.empty()) {
                    workerAddresses.push_back(address);
                }
            }
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
                      << "  --pattern <direct|sequential|twohop>  Communication pattern (default: direct)\n"
                      << "  --workers <addr1,addr2,...>           Comma-separated worker addresses\n"
                      << "  --min-size SIZE                       Minimum payload size in bytes (default: 16)\n"
                      << "  --max-size SIZE                       Maximum payload size in bytes (default: 8192)\n"
                      << "  --increment SIZE                      Payload size increment in bytes (default: 16)\n"
                      << "  --samples COUNT                       Number of samples per payload size (default: 100)\n"
                      << "  --help                                Show this help\n"
                      << "\nPatterns:\n"
                      << "  direct:     head -> worker -> ack -> head\n"
                      << "  sequential: head -> worker1 -> ack -> head -> worker2 -> ack -> head\n"
                      << "  twohop:     head -> worker1 -> worker2 -> ack -> head\n"
                      << "\nExamples:\n"
                      << "  Direct:     " << argv[0] << " --pattern direct --workers localhost:50051\n"
                      << "  Sequential: " << argv[0] << " --pattern sequential --workers localhost:50051,localhost:50052\n"
                      << "  Two-hop:    " << argv[0] << " --pattern twohop --workers localhost:50051\n"
                      << std::endl;
            return 0;
        }
    }
    
    // Default worker if none provided
    if (workerAddresses.empty()) {
        workerAddresses.push_back("localhost:50051");
    }
    
    // Validate pattern
    if (pattern != "direct" && pattern != "sequential" && pattern != "twohop") {
        std::cout << "Error: Invalid pattern. Must be 'direct', 'sequential', or 'twohop'" << std::endl;
        return 1;
    }
    
    std::cout << "Benchmark Head Node Starting..." << std::endl;
    std::cout << "Pattern: " << pattern << std::endl;
    std::cout << "Workers: ";
    for (size_t i = 0; i < workerAddresses.size(); ++i) {
        std::cout << workerAddresses[i];
        if (i < workerAddresses.size() - 1) std::cout << ", ";
    }
    std::cout << std::endl;
    std::cout << "Payload size range: " << minSize << " - " << maxSize << " bytes" << std::endl;
    std::cout << "Increment: " << increment << " bytes" << std::endl;
    std::cout << "Samples per size: " << samplesPerSize << std::endl;

    try {
        BenchmarkHead head(workerAddresses, pattern);
        
        // Wait a moment for connections to establish
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        
        head.RunLatencyBenchmark(minSize, maxSize, increment, samplesPerSize);
        
        std::cout << "\nBenchmark completed successfully!" << std::endl;
        return 0;
    } catch (const std::exception& e) {
        std::cout << "Error: " << e.what() << std::endl;
        return 1;
    }
}