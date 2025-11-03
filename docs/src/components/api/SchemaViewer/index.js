import React, { useState } from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * SchemaViewer Component - JSON schema visualization with expandable properties
 * 
 * @param {Object} schema - JSON schema object
 * @param {boolean} collapsed - Start collapsed (default: false)
 * @param {number} depth - Initial depth for nesting (default: 0)
 */
export default function SchemaViewer({ 
  schema = {},
  collapsed = false,
  depth = 0
}) {
  const [isExpanded, setIsExpanded] = useState(!collapsed);

  const renderValue = (value, key, level = 0) => {
    if (value === null) return <span className={styles.nullValue}>null</span>;
    if (value === undefined) return <span className={styles.undefinedValue}>undefined</span>;
    
    const type = Array.isArray(value) ? 'array' : typeof value;

    if (type === 'object') {
      return <SchemaViewer schema={value} collapsed={collapsed} depth={level + 1} />;
    }

    if (type === 'array') {
      return (
        <div className={styles.arrayContainer}>
          [
          {value.length > 0 ? (
            <div className={styles.arrayItems}>
              {value.map((item, idx) => (
                <div key={idx} className={styles.arrayItem}>
                  {renderValue(item, null, level + 1)}
                  {idx < value.length - 1 && ','}
                </div>
              ))}
            </div>
          ) : (
            <span className={styles.emptyArray}>empty</span>
          )}
          ]
        </div>
      );
    }

    if (type === 'string') {
      return <span className={styles.stringValue}>"{value}"</span>;
    }

    if (type === 'number' || type === 'boolean') {
      return <span className={styles.primitiveValue}>{String(value)}</span>;
    }

    return <span>{String(value)}</span>;
  };

  const renderProperty = (key, value, level) => {
    const isObject = typeof value === 'object' && value !== null && !Array.isArray(value);
    const isArray = Array.isArray(value);
    const isComplex = isObject || isArray;

    return (
      <div key={key} className={clsx(styles.property, isComplex && styles.propertyComplex)}>
        <div className={styles.propertyHeader}>
          <span className={styles.propertyKey}>"{key}"</span>
          <span className={styles.propertySeparator}>:</span>
          {isComplex && (
            <button
              className={styles.expandButton}
              onClick={() => setIsExpanded(!isExpanded)}
              aria-label={isExpanded ? 'Collapse' : 'Expand'}
            >
              <svg
                width="12"
                height="12"
                viewBox="0 0 12 12"
                fill="none"
                className={clsx(styles.expandIcon, isExpanded && styles.expandIconOpen)}
              >
                <path
                  d="M3 4.5L6 7.5L9 4.5"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </button>
          )}
          {!isComplex && (
            <div className={styles.propertyValue}>
              {renderValue(value, key, level)}
            </div>
          )}
        </div>
        {isComplex && (
          <div className={clsx(styles.propertyValue, !isExpanded && styles.propertyValueCollapsed)}>
            {renderValue(value, key, level)}
          </div>
        )}
      </div>
    );
  };

  const entries = Object.entries(schema);
  const hasContent = entries.length > 0;

  return (
    <div className={styles.schemaViewer}>
      <div className={styles.schemaContainer}>
        {hasContent ? (
          <>
            {'{'}
            <div className={styles.schemaBody}>
              {entries.map(([key, value]) => renderProperty(key, value, depth))}
            </div>
            {'}'}
          </>
        ) : (
          <span className={styles.emptyObject}>{'{}'}</span>
        )}
      </div>
    </div>
  );
}

