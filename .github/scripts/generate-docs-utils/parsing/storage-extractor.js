/**
 * Storage Extractor
 * 
 * Functions for extracting storage information from parsed data.
 */

/**
 * Extract storage information from parsed data
 * @param {object} data - Parsed documentation data
 * @returns {string | null} Storage information or null
 */
function extractStorageInfo(data) {
  // Look for STORAGE_POSITION in state variables
  const storageVar = data.stateVariables.find(v => 
    v.name.includes('STORAGE') || v.name.includes('storage')
  );

  if (storageVar) {
    return `Storage position: \`${storageVar.name}\` - ${storageVar.description || 'Used for diamond storage pattern.'}`;
  }

  // Look for storage struct
  const storageStruct = data.structs.find(s => 
    s.name.includes('Storage')
  );

  if (storageStruct) {
    return `Uses the \`${storageStruct.name}\` struct following the ERC-8042 diamond storage pattern.`;
  }

  return null;
}

module.exports = {
  extractStorageInfo,
};

