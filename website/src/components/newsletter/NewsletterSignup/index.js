import React, { useState } from 'react';
import { useColorMode } from '@docusaurus/theme-common';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import { useNewsletterSubscribe } from '@site/src/hooks/useNewsletterSubscribe';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 *  Newsletter Signup Component
 * 
 * @param {Object} props - Component props
 * @param {boolean} props.showNameFields - Whether to show first/last name fields
 * @param {string} props.title - Form title
 * @param {string} props.description - Form description
 * @param {string} props.buttonText - Submit button text
 * @param {string} props.emailPlaceholder - Email input placeholder
 * @param {string} props.firstNamePlaceholder - First name input placeholder
 * @param {string} props.lastNamePlaceholder - Last name input placeholder
 * @param {string} props.className - Additional CSS classes
 * @param {Function} props.onSuccess - Callback fired on successful subscription
 * @param {Function} props.onError - Callback fired on subscription error
 */
export default function NewsletterSignup({
  showNameFields = false,
  title = 'Stay Updated',
  description = 'Get notified about new features and updates.',
  buttonText = 'Subscribe',
  emailPlaceholder = 'Enter your email',
  firstNamePlaceholder = 'First Name',
  lastNamePlaceholder = 'Last Name',
  className = '',
  onSuccess,
  onError,
}) {
  const { colorMode } = useColorMode();
  
  const { subscribe, isSubmitting, isConfigured } = useNewsletterSubscribe();
  
  const [email, setEmail] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');

  if (!isConfigured) {
    return null;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      await subscribe({
        email,
        ...(showNameFields && firstName && { firstName }),
        ...(showNameFields && lastName && { lastName }),
      });

      setEmail('');
      setFirstName('');
      setLastName('');

      if (onSuccess) {
        onSuccess({ email, firstName, lastName });
      }
    } catch (error) {
      if (onError) {
        onError(error);
      }
    }
  };


  return (
    <div 
      className={clsx(
        styles.newsletterContainer,
        styles[`newsletterContainer--${colorMode}`],
        className
      )}
    >
      <div className={styles.newsletterContent}>
        {/* Header Section with Icon */}
        <div className={styles.newsletterHeader}>
          <div className={styles.newsletterTitleRow}>
            <div className={styles.newsletterIconWrapper}>
              <img
                src="/icons/envelope.svg"
                alt=""
                className={styles.newsletterIcon}
                aria-hidden="true"
                width="24"
                height="24"
              />
            </div>
            {title && <h3 className={styles.newsletterTitle}>{title}</h3>}
          </div>
          {description && (
            <p className={styles.newsletterDescription}>{description}</p>
          )}
        </div>
        
        {/* Form Section */}
        <form onSubmit={handleSubmit} className={styles.newsletterForm}>
          {showNameFields && (
            <div className={styles.newsletterRow}>
              <div className={styles.newsletterInputWrapper}>
                <input
                  type="text"
                  placeholder={firstNamePlaceholder}
                  value={firstName}
                  onChange={(e) => setFirstName(e.target.value)}
                  className={styles.newsletterInput}
                  disabled={isSubmitting}
                  aria-label="First name"
                />
              </div>
              <div className={styles.newsletterInputWrapper}>
                <input
                  type="text"
                  placeholder={lastNamePlaceholder}
                  value={lastName}
                  onChange={(e) => setLastName(e.target.value)}
                  className={styles.newsletterInput}
                  disabled={isSubmitting}
                  aria-label="Last name"
                />
              </div>
            </div>
          )}
          
          {/* Email Input and Button Row - Side by side on desktop */}
          <div className={styles.newsletterRow}>
            <div className={styles.newsletterInputWrapper}>
              <input
                type="email"
                placeholder={emailPlaceholder}
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={styles.newsletterInput}
                required
                disabled={isSubmitting}
                aria-label="Email address"
                aria-required="true"
              />
            </div>
            <button
              type="submit"
              className={styles.newsletterButton}
              disabled={isSubmitting || !email.trim()}
              aria-label="Subscribe to newsletter"
            >
              <span className={styles.newsletterButtonContent}>
                {isSubmitting ? (
                  <>
                    <span className={styles.newsletterButtonSpinner} aria-hidden="true" />
                    <span>Subscribing...</span>
                  </>
                ) : (
                  buttonText
                )}
              </span>
            </button>
          </div>

          {/* Trust Signal */}
          <div className={styles.newsletterTrustSignal}>
            <img
              src="/icons/shield-check.svg"
              alt=""
              className={styles.newsletterTrustIcon}
              aria-hidden="true"
              width="14"
              height="14"
            />
            <span>No spam. Unsubscribe anytime.</span>
          </div>
        </form>
      </div>
    </div>
  );
}
