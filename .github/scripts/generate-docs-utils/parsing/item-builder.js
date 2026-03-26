/**
 * Item Builder
 * 
 * Functions for creating and saving parsed items.
 */

/**
 * Create a new item object based on section type
 * @param {string} name - Item name
 * @param {string} section - Section type
 * @returns {object} New item object
 */
function createNewItem(name, section) {
  const base = {
    name,
    description: '',
    notice: '',
  };

  switch (section) {
    case 'functions':
      return {
        ...base,
        signature: '',
        params: [],
        returns: [],
        mutability: 'nonpayable',
      };
    case 'events':
      return {
        ...base,
        signature: '',
        params: [],
      };
    case 'errors':
      return {
        ...base,
        signature: '',
        params: [],
      };
    case 'structs':
      return {
        ...base,
        definition: '',
        fields: [],
      };
    case 'stateVariables':
      return {
        ...base,
        type: '',
        value: '',
      };
    default:
      return base;
  }
}

/**
 * Save current item to data object
 * @param {object} data - Data object to save to
 * @param {object} item - Item to save
 * @param {string} type - Item type
 */
function saveCurrentItem(data, item, type) {
  if (!type || !item) return;

  switch (type) {
    case 'functions':
      data.functions.push(item);
      break;
    case 'events':
      data.events.push(item);
      break;
    case 'errors':
      data.errors.push(item);
      break;
    case 'structs':
      data.structs.push(item);
      break;
    case 'stateVariables':
      data.stateVariables.push(item);
      break;
  }
}

module.exports = {
  createNewItem,
  saveCurrentItem,
};

