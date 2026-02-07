import React, { useState } from 'react';
import { useColorMode } from '@docusaurus/theme-common';
import { useNewsletterSubscribe } from '@site/src/hooks/useNewsletterSubscribe';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * Footer Newsletter Signup Component
 * 
 * A compact newsletter signup form designed specifically for footer placement.
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
  const { subscribe, isSubmitting, isConfigured } = useNewsletterSubscribe();
  
  const [email, setEmail] = useState('');

  if (!isConfigured) {
    return null;
  }

  const handleSubmit = async (e) => {
    e.preventDefault();

    try {
      await subscribe({ email });
      setEmail('');
    } catch (error) {
      // Error is already handled by the hook
    }
  };


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
          <img
            src="/icons/shield-check.svg"
            alt=""
            className={styles.footerNewsletterTrustIcon}
            aria-hidden="true"
            width="14"
            height="14"
          />
          <span>No spam. Unsubscribe anytime.</span>
        </div>
      </form>
    </div>
  );
}
