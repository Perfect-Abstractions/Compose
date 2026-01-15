import React, { useState } from 'react';
import { useColorMode } from '@docusaurus/theme-common';
import { useNewsletterSubscribe } from '@site/src/hooks/useNewsletterSubscribe';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * Footer Newsletter Signup Component
 * 
 * A compact newsletter signup form designed specifically for footer placement.
 * Uses the useNewsletterSubscribe hook and integrates seamlessly with the footer design.
 * 
 * @param {Object} props - Component props
 * @param {string} props.title - Optional title/label for the newsletter section
 * @param {string} props.emailPlaceholder - Email input placeholder text
 * @param {string} props.buttonText - Submit button text
 * @param {string} props.className - Additional CSS classes
 */
export default function FooterNewsletterSignup({
  title = 'Newsletter',
  description = 'Get notified about releases, feature announcements, and technical deep-dives on building smart contracts with Compose.',
  emailPlaceholder = 'Enter your email',
  buttonText = 'Subscribe',
  className = '',
}) {
  const { colorMode } = useColorMode();
  const { subscribe, isSubmitting, message, isConfigured } = useNewsletterSubscribe();
  
  const [email, setEmail] = useState('');

  // Don't render if not configured
  if (!isConfigured) {
    return null;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      await subscribe({ email });

      // Reset form on success
      setEmail('');
    } catch (error) {
      // Error is already handled by the hook
    }
  };

  // Shield/Trust icon SVG
  const ShieldIcon = () => (
    <svg
      className={styles.footerNewsletterTrustIcon}
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
        styles.footerNewsletter,
        styles[`footerNewsletter--${colorMode}`],
        className
      )}
    >
      {title && <h3 className={styles.footerNewsletterTitle}>{title}</h3>}
      {description && <p className={styles.footerNewsletterDescription}>{description}</p>}
      
      <form onSubmit={handleSubmit} className={styles.footerNewsletterForm}>
        <div className={styles.footerNewsletterInputGroup}>
          <input
            type="email"
            placeholder={emailPlaceholder}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={styles.footerNewsletterInput}
            required
            disabled={isSubmitting}
            aria-label="Email address"
            aria-required="true"
          />
          <button
            type="submit"
            className={styles.footerNewsletterButton}
            disabled={isSubmitting || !email.trim()}
            aria-label="Subscribe to newsletter"
          >
            {isSubmitting ? (
              <span className={styles.footerNewsletterButtonSpinner} aria-hidden="true" />
            ) : (
              buttonText
            )}
          </button>
        </div>

        {/* Trust Signal */}
        <div className={styles.footerNewsletterTrustSignal}>
          <ShieldIcon />
          <span>No spam. Unsubscribe anytime.</span>
        </div>

        {message.text && (
          <div
            className={clsx(
              styles.footerNewsletterMessage,
              styles[`footerNewsletterMessage--${message.type}`]
            )}
            role={message.type === 'error' ? 'alert' : 'status'}
            aria-live="polite"
          >
            {message.text}
          </div>
        )}
      </form>
    </div>
  );
}
