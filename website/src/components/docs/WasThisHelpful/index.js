import React, { useState } from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * WasThisHelpful Component - Feedback widget for documentation pages
 * 
 * @param {string} pageId - Unique identifier for the page
 * @param {Function} onSubmit - Callback function when feedback is submitted
 */
export default function WasThisHelpful({ 
  pageId,
  onSubmit
}) {
  const [feedback, setFeedback] = useState(null);
  const [comment, setComment] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleFeedback = (value) => {
    setFeedback(value);
  };

  const handleSubmit = () => {
    if (onSubmit) {
      onSubmit({ pageId, feedback, comment });
    } else {
      // Default behavior - could log to analytics
      console.log('Feedback submitted:', { pageId, feedback, comment });
    }
    setSubmitted(true);
  };

  if (submitted) {
    return (
      <div className={styles.feedbackSubmitted}>
        <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
          <path
            d="M16.667 5L7.5 14.167 3.333 10"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        <span>Thank you for your feedback!</span>
      </div>
    );
  }

  return (
    <div className={styles.wasThisHelpful}>
      <div className={styles.feedbackPrompt}>
        <span className={styles.promptText}>Was this helpful?</span>
        <div className={styles.feedbackButtons}>
          <button
            className={clsx(
              styles.feedbackButton,
              feedback === 'yes' && styles.feedbackButtonActive
            )}
            onClick={() => handleFeedback('yes')}
            aria-label="Yes, this was helpful"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path
                d="M5.833 8.333H4.167A1.667 1.667 0 002.5 10v5a1.667 1.667 0 001.667 1.667h1.666M5.833 8.333V6.667a1.667 1.667 0 011.667-1.667h1.666M5.833 8.333h8.334M10.833 5v3.333M10.833 5h1.667a1.667 1.667 0 011.667 1.667v1.666M10.833 8.333h2.5"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            Yes
          </button>
          <button
            className={clsx(
              styles.feedbackButton,
              feedback === 'no' && styles.feedbackButtonActive
            )}
            onClick={() => handleFeedback('no')}
            aria-label="No, this was not helpful"
          >
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
              <path
                d="M5.833 11.667H4.167A1.667 1.667 0 002.5 10V5a1.667 1.667 0 001.667-1.667h1.666M5.833 11.667V13.333a1.667 1.667 0 001.667 1.667h1.666M5.833 11.667h8.334M10.833 15v-3.333M10.833 15h1.667a1.667 1.667 0 001.667-1.667v-1.666M10.833 11.667h2.5"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            No
          </button>
        </div>
      </div>
      {feedback && (
        <div className={styles.feedbackForm}>
          <textarea
            className={styles.commentInput}
            placeholder="Tell us more (optional)..."
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            rows={3}
          />
          <button
            className={styles.submitButton}
            onClick={handleSubmit}
          >
            Submit Feedback
          </button>
        </div>
      )}
    </div>
  );
}





