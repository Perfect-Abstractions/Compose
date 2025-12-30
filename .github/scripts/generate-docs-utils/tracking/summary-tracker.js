/**
 * Summary Tracker
 * 
 * Tracks processing results and generates summary reports.
 * Replaces global processedFiles object with a class-based approach.
 */

const path = require('path');
const { writeFileSafe } = require('../../workflow-utils');

/**
 * Tracks processed files and generates summary reports
 */
class SummaryTracker {
  constructor() {
    this.facets = [];
    this.modules = [];
    this.skipped = [];
    this.errors = [];
    this.fallbackFiles = [];
  }

  /**
   * Record a successfully processed facet
   * @param {string} title - Facet title
   * @param {string} file - Output file path
   */
  recordFacet(title, file) {
    this.facets.push({ title, file });
  }

  /**
   * Record a successfully processed module
   * @param {string} title - Module title
   * @param {string} file - Output file path
   */
  recordModule(title, file) {
    this.modules.push({ title, file });
  }

  /**
   * Record a skipped file
   * @param {string} file - File path
   * @param {string} reason - Reason for skipping
   */
  recordSkipped(file, reason) {
    this.skipped.push({ file, reason });
  }

  /**
   * Record an error
   * @param {string} file - File path
   * @param {string} error - Error message
   */
  recordError(file, error) {
    this.errors.push({ file, error });
  }

  /**
   * Record a file that used fallback content
   * @param {string} title - Contract title
   * @param {string} file - Output file path
   * @param {string} error - Error message
   */
  recordFallback(title, file, error) {
    this.fallbackFiles.push({ title, file, error });
  }

  /**
   * Print processing summary to console
   */
  printSummary() {
    console.log('\n' + '='.repeat(50));
    console.log('Documentation Generation Summary');
    console.log('='.repeat(50));

    console.log(`\nFacets generated: ${this.facets.length}`);
    for (const f of this.facets) {
      console.log(`   - ${f.title}`);
    }

    console.log(`\nModules generated: ${this.modules.length}`);
    for (const m of this.modules) {
      console.log(`   - ${m.title}`);
    }

    if (this.skipped.length > 0) {
      console.log(`\nSkipped: ${this.skipped.length}`);
      for (const s of this.skipped) {
        console.log(`   - ${path.basename(s.file)}: ${s.reason}`);
      }
    }

    if (this.errors.length > 0) {
      console.log(`\nErrors: ${this.errors.length}`);
      for (const e of this.errors) {
        console.log(`   - ${path.basename(e.file)}: ${e.error}`);
      }
    }

    if (this.fallbackFiles.length > 0) {
      console.log(`\n⚠️  Files using fallback due to AI errors: ${this.fallbackFiles.length}`);
      for (const f of this.fallbackFiles) {
        console.log(`   - ${f.title}: ${f.error}`);
      }
    }

    const total = this.facets.length + this.modules.length;
    console.log(`\nTotal generated: ${total} documentation files`);
    console.log('='.repeat(50) + '\n');
  }

  /**
   * Write summary to file for GitHub Action
   */
  writeSummaryFile() {
    const summary = {
      timestamp: new Date().toISOString(),
      facets: this.facets,
      modules: this.modules,
      skipped: this.skipped,
      errors: this.errors,
      fallbackFiles: this.fallbackFiles,
      totalGenerated: this.facets.length + this.modules.length,
    };

    writeFileSafe('docgen-summary.json', JSON.stringify(summary, null, 2));
  }
}

module.exports = {
  SummaryTracker,
};

