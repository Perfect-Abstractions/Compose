import csv
from collections import defaultdict

input_file = "benchmark.csv"
output_file = "BENCHMARK_REPORT.md"

# Data structure: data[function][(selectors, facets)][implementation] = gas
data = defaultdict(lambda: defaultdict(dict))

with open(input_file, newline="") as f:
    reader = csv.DictReader(f)
    for row in reader:
        impl = row["Implementation"]
        func = row["Function"]
        facets = int(row["Facets"])
        selectors = int(row["Selectors"])
        gas = int(row["GasUsed"])
        data[func][(selectors, facets)][impl] = gas

def format_table(func_name, rows, implementations):
    md = [f"## {func_name} Function Gas Costs\n"]
    md.append("| Selectors/Facets | " + " | ".join(implementations) + " |")
    md.append("|" + "|".join(["-" * len(h) for h in ["Selectors/Facets"] + implementations]) + "|")

    for (selectors, facets), impls in sorted(rows.items()):
        row = [f"{selectors}/{facets}"]
        for impl in implementations:
            val = impls.get(impl, "")
            if isinstance(val, int):
                val = f"{val:,}"
            row.append(str(val))
        md.append("| " + " | ".join(row) + " |")
    md.append("\n---\n")
    return "\n".join(md)

implementations = sorted(
    {impl for func_data in data.values() for pair in func_data.values() for impl in pair}
)

md = """

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
"""


md += format_table("facets()", data["facets()"], implementations)
md +=format_table("facetAddresses()", data["facetAddresses()"], implementations)


# Scrive su file
with open(output_file, "w") as f:
    f.write(md)

print(f"Markdown report generated: {output_file}")