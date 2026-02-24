import React, { useState } from 'react';
import clsx from 'clsx';
import Icon from '../../ui/Icon';
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
        <Icon name="checkmark-stroke" size={20} />
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
            <Icon name="thumbs-up-outline" size={20} />
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
            <Icon name="thumbs-down-outline" size={20} />
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





