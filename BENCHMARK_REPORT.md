

# Diamond Loupe Gas Benchmark Report
    
## Usage


Run the following command to execute the benchmark and generate the .csv results:
```bash
forge script script/LoupeBenchmark.s.sol --gas-limit 1000000000000000000
```

Use a very high gas limit to avoid out-of-gas errors during execution.


Then, convert the CSV results into a Markdown report (BENCHMARK_REPORT.md) with:

```bash
python3 gen_benchmark_report.py 
```
    **Compiler Settings in foundry.toml:**
    - Optimizer Runs: 20,000"
    - viaIR: Disabled
## facets() Function Gas Costs

| Selectors/Facets | CollisionMap | Current | Original | TwoPass |
|----------------|------------|-------|--------|-------|
| 0/0 | 1,872 | 14,905 | 1,704 | 1,868 |
| 2/1 | 7,113 | 18,521 | 5,141 | 7,044 |
| 4/2 | 23,766 | 26,574 | 15,399 | 22,898 |
| 6/3 | 53,690 | 40,377 | 34,322 | 52,281 |
| 40/10 | 1,502,735 | 592,890 | 992,654 | 1,465,933 |

---
## facetAddresses() Function Gas Costs

| Selectors/Facets | CollisionMap | Current | Original | TwoPass |
|----------------|------------|-------|--------|-------|
| 0/0 | 1,519 | 14,656 | 1,515 | 1,515 |
| 2/1 | 3,336 | 16,939 | 3,288 | 3,288 |
| 4/2 | 9,052 | 22,443 | 8,871 | 8,871 |
| 6/3 | 19,882 | 31,719 | 19,858 | 19,964 |
| 40/10 | 619,083 | 348,787 | 604,638 | 604,903 |

---
