#!/usr/bin/env node

/**
 * Gas Benchmark Report Generator
 * 
 * Parses forge test output with console logs and generates a formatted markdown report
 * 
 * Usage:
 *   forge test --match-path test/benchmark/ComprehensiveBenchmark.t.sol -vv 2>&1 | node scripts/generate-benchmark-report.js > BENCHMARK_REPORT.md
 */

const readline = require('readline');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
});

const results = [];

rl.on('line', (line) => {
    const trimmed = line.trim();
    if (trimmed.startsWith('BENCHMARK_RESULT')) {
        const parts = trimmed.split(',');
        if (parts.length >= 8) {
            results.push({
                implementation: parts[1],
                selectors: parseInt(parts[2], 10),
                facets: parseInt(parts[3], 10),
                facetsSuccess: parts[4] === '1',
                facetsGas: parseInt(parts[5], 10),
                facetAddressesSuccess: parts[6] === '1',
                facetAddressesGas: parseInt(parts[7], 10)
            });
        }
    }
});

rl.on('close', () => {
    generateReport();
});

function formatNumber(num) {
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function generateReport() {
    console.log('# Diamond Loupe Gas Benchmark Report\n');
    console.log('Generated from comprehensive benchmark tests.\n');
    console.log('**Compiler Settings:**');
    console.log('- Optimizer Runs: 20,000');
    console.log('- viaIR: Disabled\n');
    console.log('---\n');

    const implementationMeta = [
        {
            key: 'Original',
            label: 'Original (Mudgen, 2018)',
            link: 'https://github.com/Perfect-Abstractions/Compose/blob/bea3dfb6d2e48d88bed1b9f1c34104a16b7ebc84/src/diamond/DiamondLoupeFacet.sol'
        },
        {
            key: 'ComposeReference',
            label: 'Compose Reference (Mudgen, 2025)',
            link: 'https://github.com/Perfect-Abstractions/Compose/blob/main/src/diamond/DiamondLoupeFacet.sol'
        },
        {
            key: 'TwoPassBaseline',
            label: 'Two-Pass Benchmark (Compose)',
            link: 'test/benchmark/implementations/TwoPassDiamondLoupeFacet.sol'
        },
        {
            key: 'CollisionMap',
            label: 'Collision Map Benchmark (Compose)',
            link: 'test/benchmark/implementations/CollisionMapDiamondLoupeFacet.sol'
        },
        {
            key: 'JackieXu',
            label: 'Jackie Xu Optimised Loupe',
            link: 'https://github.com/JackieXu/Compose/blob/fa4103dc76a73fbab4e9c3cebcd98dcac1783295/src/diamond/DiamondLoupeFacet.sol'
        },
        {
            key: 'KitetsuDinesh',
            label: '0xkitetsu-dinesh Bucketed Loupe',
            link: 'https://github.com/mudgen/diamond-2/pull/155'
        },
        {
            key: 'Dawid919',
            label: 'Dawid919 Registry Loupe',
            link: 'https://github.com/mudgen/diamond-2/pull/155'
        }
    ];

    const configGroups = {
        issue155: [
            { selectors: 0, facets: 0 },
            { selectors: 2, facets: 1 },
            { selectors: 4, facets: 2 },
            { selectors: 6, facets: 3 },
            { selectors: 40, facets: 10 },
            { selectors: 40, facets: 20 },
            { selectors: 64, facets: 16 },
            { selectors: 64, facets: 32 },
            { selectors: 64, facets: 64 },
            { selectors: 504, facets: 42 }
        ],
        extended: [
            { selectors: 1000, facets: 84 },
            { selectors: 10000, facets: 834 },
            { selectors: 12000, facets: 1200 }
        ],
        additional: [
            { selectors: 20, facets: 7 },
            { selectors: 50, facets: 17 },
            { selectors: 100, facets: 34 },
            { selectors: 500, facets: 167 },
            { selectors: 1000, facets: 334 }
        ]
    };

    const resultIndex = new Map();
    results.forEach(result => {
        const key = `${result.selectors}:${result.facets}:${result.implementation}`;
        resultIndex.set(key, result);
    });

    console.log('---\n');
    console.log('## Implementations Covered\n');
    implementationMeta.forEach(meta => {
        console.log(`- [${meta.label}](${meta.link}) \`(${meta.key})\``);
    });

    console.log('\n---\n');
    console.log('## facets() Function Gas Costs\n');
    renderTable(configGroups.issue155, implementationMeta, resultIndex, 'facets');

    console.log('\n---\n');
    console.log('## facetAddresses() Function Gas Costs\n');
    renderTable(configGroups.issue155, implementationMeta, resultIndex, 'facetAddresses');

    if (configGroups.extended.length) {
        console.log('\n---\n');
        console.log('## Extended Configurations (Large Diamonds)\n');
        console.log('### facets() Function\n');
        renderTable(configGroups.extended, implementationMeta, resultIndex, 'facets');
        console.log('\n### facetAddresses() Function\n');
        renderTable(configGroups.extended, implementationMeta, resultIndex, 'facetAddresses');
    }

    if (configGroups.additional.length) {
        console.log('\n---\n');
        console.log('## Additional Configurations (Issue #155 follow-up)\n');
        console.log('### facets() Function\n');
        renderTable(configGroups.additional, implementationMeta, resultIndex, 'facets');
        console.log('\n### facetAddresses() Function\n');
        renderTable(configGroups.additional, implementationMeta, resultIndex, 'facetAddresses');
    }
}

function renderTable(configs, implementationMeta, index, metric) {
    const headerCells = implementationMeta.map(meta => meta.key);
    console.log(`| Selectors/Facets | ${headerCells.join(' | ')} |`);
    console.log(`|------------------|${implementationMeta.map(() => '----------').join('|')}|`);

    configs.forEach(config => {
        const rowValues = implementationMeta.map(meta => {
            const entry = index.get(`${config.selectors}:${config.facets}:${meta.key}`);
            if (!entry) return 'N/A';
            if (metric === 'facets') {
                if (!entry.facetsSuccess && entry.facetsGas === 0) return 'SKIP';
                if (!entry.facetsSuccess) return 'FAIL';
                return formatNumber(entry.facetsGas);
            } else {
                if (!entry.facetAddressesSuccess && entry.facetAddressesGas === 0) return 'SKIP';
                if (!entry.facetAddressesSuccess) return 'FAIL';
                return formatNumber(entry.facetAddressesGas);
            }
        });
        console.log(`| ${config.selectors}/${config.facets} | ${rowValues.join(' | ')} |`);
    });
}
