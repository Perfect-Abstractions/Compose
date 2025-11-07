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
let currentResult = null;

rl.on('line', (line) => {
    const trimmed = line.trim();
    // Look for Implementation line to start a new result
    if (trimmed.includes('Implementation:')) {
        if (currentResult && currentResult.implementation) {
            results.push(currentResult);
        }
        currentResult = {};
        currentResult.implementation = trimmed.split(':')[1].trim();
    } else if (currentResult && trimmed.includes('Selectors:')) {
        currentResult.selectors = parseInt(trimmed.split(':')[1].trim());
    } else if (currentResult && trimmed.includes('Facets:')) {
        currentResult.facets = parseInt(trimmed.split(':')[1].trim());
    } else if (currentResult && trimmed.includes('facets() gas:')) {
        currentResult.facetsGas = parseInt(trimmed.split(':')[1].trim());
    } else if (currentResult && trimmed.includes('facetAddresses() gas:')) {
        currentResult.facetAddressesGas = parseInt(trimmed.split(':')[1].trim());
    }
});

rl.on('close', () => {
    if (currentResult) {
        results.push(currentResult);
    }
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

    // Group results by implementation
    const grouped = {
        Original: [],
        Current: [],
        TwoPass: [],
        CollisionMap: []
    };

    results.forEach(result => {
        if (grouped[result.implementation]) {
            grouped[result.implementation].push(result);
        }
    });

    // Sort by selectors, then facets
    Object.keys(grouped).forEach(impl => {
        grouped[impl].sort((a, b) => {
            if (a.selectors !== b.selectors) return a.selectors - b.selectors;
            return a.facets - b.facets;
        });
    });

    // Generate table for facets() function
    console.log('## facets() Function Gas Costs\n');
    console.log('| Selectors/Facets | Original | Current | TwoPass | CollisionMap |');
    console.log('|------------------|----------|---------|---------|--------------|');

    const configs = [
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
    ];

    configs.forEach(config => {
        const original = grouped.Original.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const current = grouped.Current.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const twoPass = grouped.TwoPass.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const collisionMap = grouped.CollisionMap.find(r => r.selectors === config.selectors && r.facets === config.facets);

        const originalStr = original ? formatNumber(original.facetsGas) : 'N/A';
        const currentStr = current ? formatNumber(current.facetsGas) : 'N/A';
        const twoPassStr = twoPass ? formatNumber(twoPass.facetsGas) : 'N/A';
        const collisionMapStr = collisionMap ? formatNumber(collisionMap.facetsGas) : 'N/A';

        console.log(`| ${config.selectors}/${config.facets} | ${originalStr} | ${currentStr} | ${twoPassStr} | ${collisionMapStr} |`);
    });

    console.log('\n---\n');
    console.log('## facetAddresses() Function Gas Costs\n');
    console.log('| Selectors/Facets | Original | Current | TwoPass | CollisionMap |');
    console.log('|------------------|----------|---------|---------|--------------|');

    configs.forEach(config => {
        const original = grouped.Original.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const current = grouped.Current.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const twoPass = grouped.TwoPass.find(r => r.selectors === config.selectors && r.facets === config.facets);
        const collisionMap = grouped.CollisionMap.find(r => r.selectors === config.selectors && r.facets === config.facets);

        const originalStr = original ? formatNumber(original.facetAddressesGas) : 'N/A';
        const currentStr = current ? formatNumber(current.facetAddressesGas) : 'N/A';
        const twoPassStr = twoPass ? formatNumber(twoPass.facetAddressesGas) : 'N/A';
        const collisionMapStr = collisionMap ? formatNumber(collisionMap.facetAddressesGas) : 'N/A';

        console.log(`| ${config.selectors}/${config.facets} | ${originalStr} | ${currentStr} | ${twoPassStr} | ${collisionMapStr} |`);
    });

    // Additional configurations
    const additionalConfigs = [
        { selectors: 20, facets: 7 },
        { selectors: 50, facets: 17 },
        { selectors: 100, facets: 34 },
        { selectors: 500, facets: 167 },
        { selectors: 1000, facets: 334 }
    ];

    if (grouped.Original.some(r => r.selectors >= 20)) {
        console.log('\n---\n');
        console.log('## Additional Configurations\n');
        console.log('### facets() Function\n');
        console.log('| Selectors/Facets | Original | Current | TwoPass | CollisionMap |');
        console.log('|------------------|----------|---------|---------|--------------|');

        additionalConfigs.forEach(config => {
            const original = grouped.Original.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const current = grouped.Current.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const twoPass = grouped.TwoPass.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const collisionMap = grouped.CollisionMap.find(r => r.selectors === config.selectors && r.facets === config.facets);

            const originalStr = original ? formatNumber(original.facetsGas) : 'N/A';
            const currentStr = current ? formatNumber(current.facetsGas) : 'N/A';
            const twoPassStr = twoPass ? formatNumber(twoPass.facetsGas) : 'N/A';
            const collisionMapStr = collisionMap ? formatNumber(collisionMap.facetsGas) : 'N/A';

            console.log(`| ${config.selectors}/${config.facets} | ${originalStr} | ${currentStr} | ${twoPassStr} | ${collisionMapStr} |`);
        });

        console.log('\n### facetAddresses() Function\n');
        console.log('| Selectors/Facets | Original | Current | TwoPass | CollisionMap |');
        console.log('|------------------|----------|---------|---------|--------------|');

        additionalConfigs.forEach(config => {
            const original = grouped.Original.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const current = grouped.Current.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const twoPass = grouped.TwoPass.find(r => r.selectors === config.selectors && r.facets === config.facets);
            const collisionMap = grouped.CollisionMap.find(r => r.selectors === config.selectors && r.facets === config.facets);

            const originalStr = original ? formatNumber(original.facetAddressesGas) : 'N/A';
            const currentStr = current ? formatNumber(current.facetAddressesGas) : 'N/A';
            const twoPassStr = twoPass ? formatNumber(twoPass.facetAddressesGas) : 'N/A';
            const collisionMapStr = collisionMap ? formatNumber(collisionMap.facetAddressesGas) : 'N/A';

            console.log(`| ${config.selectors}/${config.facets} | ${originalStr} | ${currentStr} | ${twoPassStr} | ${collisionMapStr} |`);
        });
    }
}
