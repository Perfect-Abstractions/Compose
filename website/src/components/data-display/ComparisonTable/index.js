import React from 'react';
import styles from './styles.module.css';

export default function ComparisonTable({ features, columns }) {
  return (
    <div className={styles.tableContainer}>
      <table className={styles.comparisonTable}>
        <thead>
          <tr>
            <th className={styles.featureColumn}>Feature</th>
            {columns.map((col, index) => (
              <th key={index} className={styles.productColumn}>
                <div className={styles.columnHeader}>
                  {col.highlight && <span className={styles.badge}>Popular</span>}
                  <div className={styles.columnTitle}>{col.name}</div>
                </div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {features.map((feature, index) => (
            <tr key={index}>
              <td className={styles.featureCell}>
                <div className={styles.featureName}>{feature.name}</div>
                {feature.description && (
                  <div className={styles.featureDescription}>{feature.description}</div>
                )}
              </td>
              {feature.values.map((value, colIndex) => (
                <td key={colIndex} className={styles.valueCell}>
                  {typeof value === 'boolean' ? (
                    <span className={value ? styles.checkmark : styles.cross}>
                      {value ? '✓' : '✗'}
                    </span>
                  ) : (
                    <span className={styles.value}>{value}</span>
                  )}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

