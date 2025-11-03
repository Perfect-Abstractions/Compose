import React, { useState } from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * APIReference Component - Display API endpoint information
 * 
 * @param {string} method - HTTP method (GET, POST, PUT, DELETE, etc.)
 * @param {string} endpoint - API endpoint path
 * @param {string} description - Endpoint description
 * @param {Array} parameters - Array of parameter objects
 * @param {Object} response - Example response
 */
export default function APIReference({
  method = 'GET',
  endpoint,
  description,
  parameters = [],
  response
}) {
  const [activeTab, setActiveTab] = useState('parameters');

  const methodColors = {
    GET: '#10b981',
    POST: '#3b82f6',
    PUT: '#f59e0b',
    DELETE: '#ef4444',
    PATCH: '#3b82f6'
  };

  return (
    <div className={styles.apiReference}>
      <div className={styles.apiHeader}>
        <div className={styles.apiMethodContainer}>
          <span 
            className={styles.apiMethod}
            style={{ backgroundColor: methodColors[method] || '#64748b' }}
          >
            {method}
          </span>
          <code className={styles.apiEndpoint}>{endpoint}</code>
        </div>
        {description && (
          <p className={styles.apiDescription}>{description}</p>
        )}
      </div>

      {(parameters.length > 0 || response) && (
        <div className={styles.apiTabs}>
          <div className={styles.apiTabButtons}>
            {parameters.length > 0 && (
              <button
                className={clsx(
                  styles.apiTabButton,
                  activeTab === 'parameters' && styles.apiTabButtonActive
                )}
                onClick={() => setActiveTab('parameters')}
              >
                Parameters
              </button>
            )}
            {response && (
              <button
                className={clsx(
                  styles.apiTabButton,
                  activeTab === 'response' && styles.apiTabButtonActive
                )}
                onClick={() => setActiveTab('response')}
              >
                Response
              </button>
            )}
          </div>

          <div className={styles.apiTabContent}>
            {activeTab === 'parameters' && parameters.length > 0 && (
              <div className={styles.apiParameters}>
                {parameters.map((param, index) => (
                  <div key={index} className={styles.apiParameter}>
                    <div className={styles.apiParameterHeader}>
                      <code className={styles.apiParameterName}>{param.name}</code>
                      <span className={styles.apiParameterType}>{param.type}</span>
                      {param.required && (
                        <span className={styles.apiParameterRequired}>required</span>
                      )}
                    </div>
                    {param.description && (
                      <p className={styles.apiParameterDescription}>
                        {param.description}
                      </p>
                    )}
                  </div>
                ))}
              </div>
            )}

            {activeTab === 'response' && response && (
              <pre className={styles.apiResponse}>
                <code>{JSON.stringify(response, null, 2)}</code>
              </pre>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

