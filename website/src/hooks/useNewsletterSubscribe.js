import { useState, useCallback } from 'react';
import toast from 'react-hot-toast';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

/**
 * Hook for subscribing to newsletter via Netlify serverless function
 * 
 * Handles form submission, state management, and error handling
 * for newsletter email subscriptions through Netlify serverless function.
 * 
 * @param {Object} options - Configuration options
 * @param {string} options.formId - Newsletter form ID (optional, falls back to config)
 * @param {string} options.endpoint - Custom endpoint URL (defaults to Netlify function)
 * @returns {Object} Subscribe function and state
 * @returns {Function} returns.subscribe - Subscribe function
 * @returns {boolean} returns.isSubmitting - Loading state
 * @returns {boolean} returns.isConfigured - Whether newsletter is configured
 */
export function useNewsletterSubscribe({ 
  formId = null,
  endpoint = '/.netlify/functions/newsletter-subscribe'
} = {}) {
  const { siteConfig } = useDocusaurusContext();
  const newsletterConfig = siteConfig.themeConfig?.newsletter;
  
  const [isSubmitting, setIsSubmitting] = useState(false);

  const isConfigured = newsletterConfig?.isEnabled;

  /**
   * Subscribe function - handles the API call to newsletter service
   * 
   * @param {Object} subscriberData - Subscriber information
   * @param {string} subscriberData.email - Email address (required)
   * @param {string} [subscriberData.firstName] - First name (optional)
   * @param {string} [subscriberData.lastName] - Last name (optional)
   * @param {Object} [subscriberData.customFields] - Additional custom fields
   * @returns {Promise<Object>} Response data or throws error
   */
  const subscribe = useCallback(async (subscriberData) => {
    if (!isConfigured) {
      const error = new Error('Newsletter is not configured');
      toast.error('Newsletter subscription is not available.');
      throw error;
    }

    if (!subscriberData.email) {
      const error = new Error('Email is required');
      toast.error('Email address is required.');
      throw error;
    }

    setIsSubmitting(true);

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: subscriberData.email.trim().toLowerCase(),
          ...(subscriberData.firstName && { firstName: subscriberData.firstName.trim() }),
          ...(subscriberData.lastName && { lastName: subscriberData.lastName.trim() }),
          ...(subscriberData.customFields || {}),
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Subscription failed');
      }

      // Success
      toast.success(data.message || 'Thank you for subscribing!');

      return data;

    } catch (error) {
      // Handle network errors
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        const errorMessage = 'Network error. Please check your connection and try again.';
        toast.error(errorMessage);
        throw new Error(errorMessage);
      }

      // Handle other errors
      const errorMessage = error.message || 'Something went wrong. Please try again.';
      toast.error(errorMessage);
      throw error;
    } finally {
      setIsSubmitting(false);
    }
  }, [isConfigured, endpoint]);

  // Warn in development if not configured
  if (!isConfigured && process.env.NODE_ENV === 'development') {
    console.warn(
      'Newsletter is not configured. Please add newsletter configuration to themeConfig in docusaurus.config.js'
    );
  }

  return {
    subscribe,
    isSubmitting,
    isConfigured,
  };
}
