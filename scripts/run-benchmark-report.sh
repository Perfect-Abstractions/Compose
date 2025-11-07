#!/usr/bin/env bash

# Gas Benchmark Report Generator
# 
# Runs comprehensive benchmark tests and generates a formatted report
# showing gas costs for facets() and facetAddresses() functions across
# different implementations and configurations.
#
# Usage: ./scripts/run-benchmark-report.sh

set -e

echo "Running Diamond Loupe Gas Benchmarks..."
echo "========================================"
echo ""

cd "$(dirname "$0")/.."

# Run all benchmarks and generate report
echo "Running all benchmark tests..."
forge test --match-path test/benchmark/ComprehensiveBenchmark.t.sol --match-test "test_(Original|Current|TwoPass|CollisionMap|Additional)" -vv 2>&1 | grep -E "^\s+(Implementation|Selectors|Facets|facets\(\)|facetAddresses\(\))" | node scripts/generate-benchmark-report.js > BENCHMARK_REPORT.md

echo ""
echo "Report generated: BENCHMARK_REPORT.md"
echo ""
echo "To view the report:"
echo "  cat BENCHMARK_REPORT.md"

