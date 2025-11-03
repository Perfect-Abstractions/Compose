import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * ApiEndpoint Component - REST API endpoint display
 * 
 * @param {string} method - HTTP method (GET, POST, PUT, DELETE, PATCH)
 * @param {string} path - API endpoint path
 * @param {string} description - Optional description
 * @param {Array} params - Optional query parameters
 */
export default function ApiEndpoint({ 
  method = 'GET',
  path,
  description,
  params = []
}) {
  const methodColors = {
    GET: '#10b981',
    POST: '#3b82f6',
    PUT: '#f59e0b',
    PATCH: '#8b5cf6',
    DELETE: '#ef4444',
  };

  const methodStyle = {
    backgroundColor: methodColors[method.toUpperCase()] || methodColors.GET,
    color: 'white'
  };

  return (
    <div className={styles.apiEndpoint}>
      <div className={styles.endpointHeader}>
        <span className={styles.methodBadge} style={methodStyle}>
          {method.toUpperCase()}
        </span>
        <code className={styles.path}>{path}</code>
      </div>
      {description && (
        <p className={styles.description}>{description}</p>
      )}
      {params.length > 0 && (
        <div className={styles.params}>
          <div className={styles.paramsTitle}>Query Parameters:</div>
          <ul className={styles.paramsList}>
            {params.map((param, index) => (
              <li key={index} className={styles.paramItem}>
                <code className={styles.paramName}>{param.name}</code>
                {param.required && (
                  <span className={styles.requiredBadge}>required</span>
                )}
                {param.description && (
                  <span className={styles.paramDesc}> - {param.description}</span>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}





