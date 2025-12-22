import React from 'react';
import styles from './styles.module.css';

/**
 * Parse description string and convert markdown-style code (backticks) to JSX code elements
 * @param {string|React.ReactNode} description - Description string or React element
 * @returns {React.ReactNode} Description with code elements rendered
 */
function parseDescription(description) {
  if (!description || typeof description !== 'string') {
    return description;
  }
  
  // Split by backticks and alternate between text and code
  const parts = description.split(/(`[^`]+`)/g);
  return parts.map((part, index) => {
    if (part.startsWith('`') && part.endsWith('`')) {
      // This is a code block
      const codeContent = part.slice(1, -1); // Remove backticks
      return (
        <code key={index} className={styles.inlineCode}>
          {codeContent}
        </code>
      );
    }
    return <React.Fragment key={index}>{part}</React.Fragment>;
  });
}

/**
 * PropertyTable Component - Modern API property documentation table
 * Inspired by Shadcn UI design patterns
 * 
 * @param {Array} properties - Array of property objects
 * @param {boolean} showRequired - Show required column (default: true)
 * @param {boolean} showTypes - Show type column (default: true)
 * @param {string} title - Optional table title
 */
export default function PropertyTable({ 
  properties = [],
  showRequired = true,
  showTypes = true,
  title
}) {
  return (
    <div className={styles.propertyTable}>
      {title && <h3 className={styles.tableTitle}>{title}</h3>}
      <div className={styles.tableWrapper}>
        <div className={styles.tableContainer}>
          <table className={styles.table}>
            <thead>
              <tr>
                <th className={styles.nameColumn}>Property</th>
                {showTypes && <th className={styles.typeColumn}>Type</th>}
                {showRequired && <th className={styles.requiredColumn}>Required</th>}
                <th className={styles.descriptionColumn}>Description</th>
              </tr>
            </thead>
            <tbody>
              {properties.map((prop, index) => (
                <tr key={index}>
                  <td className={styles.nameCell}>
                    <code className={styles.propertyName}>{prop.name}</code>
                  </td>
                  {showTypes && (
                    <td className={styles.typeCell}>
                      <code className={styles.typeValue}>{prop.type || 'any'}</code>
                    </td>
                  )}
                  {showRequired && (
                    <td className={styles.requiredCell}>
                      {prop.required ? (
                        <span className={styles.requiredBadge}>Yes</span>
                      ) : (
                        <span className={styles.optionalBadge}>No</span>
                      )}
                    </td>
                  )}
                  <td className={styles.descriptionCell}>
                    {prop.descriptionElement || parseDescription(prop.description || prop.desc) || '-'}
                    {prop.default !== undefined && (
                      <div className={styles.defaultValue}>
                        Default: <code>{String(prop.default)}</code>
                      </div>
                    )}
                    {prop.example && (
                      <div className={styles.exampleValue}>
                        Example: <code>{String(prop.example)}</code>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}