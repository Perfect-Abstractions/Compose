import React, { useState } from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';
import { useDocumentationFeedback } from '../../../hooks/useDocumentationFeedback';

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
  const { submitFeedback } = useDocumentationFeedback();
  const [feedback, setFeedback] = useState(null);
  const [comment, setComment] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const handleFeedback = (value) => {
    setFeedback(value);
  };

  const handleSubmit = () => {
    submitFeedback(pageId, feedback, comment.trim() || null);
    if (onSubmit) {
      onSubmit({ pageId, feedback, comment });
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
            <img 
              src={feedback === 'yes' ? "/icons/thumbs-up-white.svg" : "/icons/thumbs-up.svg"}
              alt="" 
              width="20" 
              height="20"
              className={styles.feedbackIcon}
              aria-hidden="true"
            />
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
            <img 
              src={feedback === 'no' ? "/icons/thumbs-down-white.svg" : "/icons/thumbs-down.svg"}
              alt="" 
              width="20" 
              height="20"
              className={styles.feedbackIcon}
              aria-hidden="true"
            />
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





