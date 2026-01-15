import React, { useState } from 'react';
import { useColorMode } from '@docusaurus/theme-common';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import { useNewsletterSubscribe } from '@site/src/hooks/useNewsletterSubscribe';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * Premium Newsletter Signup Component
 * 
 * A stunning newsletter subscription form with glass morphism, gradients,
 * and smooth animations. Uses the useNewsletterSubscribe hook directly.
 * 
 * Configuration is read from themeConfig.newsletter in docusaurus.config.js.
 * The component automatically adapts to the current Docusaurus theme (light/dark mode).
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
  const { siteConfig } = useDocusaurusContext();
  const newsletterConfig = siteConfig.themeConfig?.newsletter;
  
  const { subscribe, isSubmitting, message, isConfigured, clearMessage } = useNewsletterSubscribe();
  
  const [email, setEmail] = useState('');
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');

  // Don't render if not configured
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

      // Reset form on success
      setEmail('');
      setFirstName('');
      setLastName('');

      // Call success callback if provided
      if (onSuccess) {
        onSuccess({ email, firstName, lastName });
      }
    } catch (error) {
      // Error is already handled by the hook, but call error callback if provided
      if (onError) {
        onError(error);
      }
    }
  };

  // Envelope icon SVG
  const EnvelopeIcon = () => (
    <svg
      className={styles.newsletterIcon}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
      />
    </svg>
  );

  // Checkmark icon SVG
  const CheckmarkIcon = () => (
    <svg
      className={styles.newsletterMessageIcon}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M5 13l4 4L19 7"
      />
    </svg>
  );

  // Alert/Error icon SVG
  const AlertIcon = () => (
    <svg
      className={styles.newsletterMessageIcon}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
  );

  // Shield/Trust icon SVG
  const ShieldIcon = () => (
    <svg
      className={styles.newsletterTrustIcon}
      fill="none"
      viewBox="0 0 24 24"
      stroke="currentColor"
      aria-hidden="true"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        strokeWidth={2}
        d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
      />
    </svg>
  );

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
              <EnvelopeIcon />
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
            <ShieldIcon />
            <span>No spam. Unsubscribe anytime.</span>
          </div>
        </form>

        {/* Message States with Icons */}
        {message.text && (
          <div
            className={clsx(
              styles.newsletterMessage,
              styles[`newsletterMessage--${message.type}`]
            )}
            role={message.type === 'error' ? 'alert' : 'status'}
            aria-live="polite"
          >
            {message.type === 'success' ? <CheckmarkIcon /> : <AlertIcon />}
            <span>{message.text}</span>
          </div>
        )}
      </div>
    </div>
  );
}
