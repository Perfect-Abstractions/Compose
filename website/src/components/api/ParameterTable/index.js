import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * ParameterTable Component - API parameter documentation table
 * Similar to PropertyTable but optimized for function/API parameters
 * 
 * @param {Array} parameters - Array of parameter objects
 * @param {boolean} showRequired - Show required column (default: true)
 * @param {boolean} showTypes - Show type column (default: true)
 * @param {string} title - Optional table title
 */
export default function ParameterTable({ 
  parameters = [],
  showRequired = true,
  showTypes = true,
  title
}) {
  return (
    <div className={styles.parameterTable}>
      {title && <h3 className={styles.tableTitle}>{title}</h3>}
      <div className={styles.tableWrapper}>
        <table className={styles.table}>
          <thead>
            <tr>
              <th className={styles.nameColumn}>Parameter</th>
              {showTypes && <th className={styles.typeColumn}>Type</th>}
              {showRequired && <th className={styles.requiredColumn}>Required</th>}
              <th className={styles.descriptionColumn}>Description</th>
            </tr>
          </thead>
          <tbody>
            {parameters.map((param, index) => (
              <tr key={index}>
                <td className={styles.nameCell}>
                  <code className={styles.parameterName}>{param.name}</code>
                </td>
                {showTypes && (
                  <td className={styles.typeCell}>
                    <code className={styles.typeValue}>{param.type || 'any'}</code>
                  </td>
                )}
                {showRequired && (
                  <td className={styles.requiredCell}>
                    {param.required ? (
                      <span className={styles.requiredBadge}>Yes</span>
                    ) : (
                      <span className={styles.optionalBadge}>No</span>
                    )}
                  </td>
                )}
                <td className={styles.descriptionCell}>
                  {param.description || param.desc || '-'}
                  {param.default !== undefined && (
                    <div className={styles.defaultValue}>
                      Default: <code>{String(param.default)}</code>
                    </div>
                  )}
                  {param.example && (
                    <div className={styles.exampleValue}>
                      Example: <code>{String(param.example)}</code>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}





