import { useCallback } from 'react';

/**
 * Custom hook for tracking documentation feedback with PostHog
 * 
 * @returns {Function} submitFeedback - Function to submit feedback
 */
export function useDocumentationFeedback() {
  /**
   * Submit feedback to PostHog analytics
   * 
   * @param {string} pageId - Unique identifier for the page
   * @param {string} feedback - 'yes' or 'no'
   * @param {string} comment - Optional comment text
   */
  const submitFeedback = useCallback((pageId, feedback, comment = null) => {
    const posthog = typeof window !== 'undefined' ? window.posthog : null;

    if (!posthog) {
      console.log('Feedback submitted:', { pageId, feedback, comment: comment || null });
      return;
    }

    posthog.capture('documentation_feedback', {
      page_id: pageId,
      feedback: feedback,
      comment: comment || null,
      timestamp: new Date().toISOString(),
      url: typeof window !== 'undefined' ? window.location.href : null,
    });
  }, []);

  return { submitFeedback };
}

