import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * StepIndicator Component - Multi-step process visualization
 * 
 * @param {Array} steps - Array of step objects { title, description, status }
 * @param {number} currentStep - Current active step index (0-based)
 * @param {string} orientation - 'horizontal' or 'vertical' (default: 'vertical')
 */
export default function StepIndicator({ 
  steps = [], 
  currentStep = 0,
  orientation = 'vertical'
}) {
  const getStepStatus = (index) => {
    if (index < currentStep) return 'completed';
    if (index === currentStep) return 'active';
    return 'pending';
  };

  return (
    <div className={clsx(styles.stepIndicator, styles[`stepIndicator--${orientation}`])}>
      {steps.map((step, index) => {
        const status = step.status || getStepStatus(index);
        const isLast = index === steps.length - 1;

        return (
          <div key={index} className={styles.stepItem}>
            <div className={styles.stepConnector}>
              {!isLast && (
                <div className={clsx(
                  styles.stepLine,
                  status === 'completed' && styles.stepLineCompleted
                )} />
              )}
            </div>
            <div className={styles.stepContent}>
              <div className={clsx(
                styles.stepNumber,
                styles[`stepNumber--${status}`]
              )}>
                {status === 'completed' ? (
                  <svg width="16" height="16" viewBox="0 0 20 20" fill="none">
                    <path
                      d="M16.667 5L7.5 14.167 3.333 10"
                      stroke="currentColor"
                      strokeWidth="2"
                      strokeLinecap="round"
                      strokeLinejoin="round"
                    />
                  </svg>
                ) : (
                  <span>{index + 1}</span>
                )}
              </div>
              <div className={styles.stepText}>
                <div className={clsx(
                  styles.stepTitle,
                  status === 'active' && styles.stepTitleActive
                )}>
                  {step.title}
                </div>
                {step.description && (
                  <div className={styles.stepDescription}>
                    {step.description}
                  </div>
                )}
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}





