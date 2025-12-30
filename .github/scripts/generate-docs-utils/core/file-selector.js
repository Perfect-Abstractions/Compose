/**
 * File Selector
 * 
 * Determines which Solidity files to process based on command line arguments.
 */

const { getAllSolFiles, readChangedFilesFromFile, getChangedSolFiles } = require('../utils/git-utils');

/**
 * Get files to process based on command line arguments
 * @param {string[]} args - Command line arguments
 * @returns {string[]} Array of Solidity file paths to process
 */
function getFilesToProcess(args) {
  if (args.includes('--all')) {
    console.log('Processing all Solidity files...');
    return getAllSolFiles();
  }

  if (args.length > 0 && !args[0].startsWith('--')) {
    const changedFilesPath = args[0];
    console.log(`Reading changed files from: ${changedFilesPath}`);
    const solFiles = readChangedFilesFromFile(changedFilesPath);

    if (solFiles.length === 0) {
      console.log('No files in list, checking git diff...');
      return getChangedSolFiles();
    }

    return solFiles;
  }

  console.log('Getting changed Solidity files from git...');
  return getChangedSolFiles();
}

module.exports = {
  getFilesToProcess,
};

