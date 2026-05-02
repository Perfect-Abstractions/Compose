import React, { useState } from 'react';
import clsx from 'clsx';
import { useColorMode } from '@docusaurus/theme-common';
import Icon from '../../ui/Icon';
import {
  captureDocsHelpfulSubmit,
  captureDocsHelpfulVote,
} from '@site/src/utils/captureDocsFeedback';
import styles from './styles.module.css';

/** Same path as static/icons/checkmark-stroke.svg; inline so currentColor matches success text (img ignores it). */
function FeedbackCheckIcon({ size = 20, className }) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 20 20"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-hidden
    >
      <path
        d="M16.667 5L7.5 14.167 3.333 10"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/**
 * @param {string} [pageId]
 * @param {string} [permalink]
 * @param {string} [title]
 * @param {'card'|'aside'} [variant]
 * @param {Function} [onSubmit]
 * @param {import('react').ReactNode} [asideEndSlot] — e.g. Report issue; beside Yes/No on mobile; desktop: below buttons, or below textarea+Submit when “No”
 */
export default function WasThisHelpful({
  pageId,
  permalink,
  title,
  onSubmit,
  variant = 'card',
  asideEndSlot,
}) {
  const { colorMode } = useColorMode();
  const [feedback, setFeedback] = useState(null);
  const [comment, setComment] = useState('');
  const [submitted, setSubmitted] = useState(false);

  const thumbUpName = colorMode === 'dark' ? 'thumbs-up-dark' : 'thumbs-up';
  const thumbDownName = colorMode === 'dark' ? 'thumbs-down-dark' : 'thumbs-down';

  const analyticsContext = { pageId, permalink, title, variant };

  const handleCardFeedback = (value) => {
    setFeedback(value);
    captureDocsHelpfulVote({ helpful: value, ...analyticsContext });
  };

  const handleCardSubmit = () => {
    if (onSubmit) {
      onSubmit({ pageId, feedback, comment });
    }
    if (feedback) {
      captureDocsHelpfulSubmit({
        helpful: feedback,
        comment: comment.trim(),
        ...analyticsContext,
      });
    }
    setSubmitted(true);
  };

  const handleAsideYes = () => {
    captureDocsHelpfulSubmit({
      helpful: 'yes',
      comment: '',
      ...analyticsContext,
    });
    if (onSubmit) {
      onSubmit({ pageId, feedback: 'yes', comment: '' });
    }
    setSubmitted(true);
  };

  const handleAsideNo = () => {
    setFeedback('no');
    captureDocsHelpfulVote({ helpful: 'no', ...analyticsContext });
  };

  const handleAsideSubmit = () => {
    captureDocsHelpfulSubmit({
      helpful: 'no',
      comment: comment.trim(),
      ...analyticsContext,
    });
    if (onSubmit) {
      onSubmit({ pageId, feedback: 'no', comment: comment.trim() });
    }
    
    setSubmitted(true);
  };

  if (submitted) {
    const submittedBody = (
      <>
        <FeedbackCheckIcon
          size={variant === 'aside' ? 18 : 20}
          className={styles.feedbackSubmittedCheck}
        />
        <span>Thank you for your feedback!</span>
      </>
    );

    if (variant === 'aside' && asideEndSlot) {
      return (
        <div
          className={clsx(
            styles.asideRoot,
            styles.asideRootWithEndSlot,
            styles.asideRootSubmittedAside
          )}
        >
          <div
            className={clsx(
              styles.feedbackSubmitted,
              styles.feedbackSubmittedAside,
              styles.asideSubmittedMain
            )}
          >
            {submittedBody}
          </div>
          <div className={styles.asideEndSlot}>{asideEndSlot}</div>
        </div>
      );
    }

    return (
      <div
        className={clsx(
          styles.feedbackSubmitted,
          variant === 'aside' && styles.feedbackSubmittedAside
        )}
      >
        {submittedBody}
      </div>
    );
  }

  if (variant === 'aside') {
    const buttonsRow = (
      <div className={styles.asideButtons}>
        <button
          type="button"
          className={styles.asideBtn}
          onClick={handleAsideYes}
          aria-label="Yes, this was helpful"
        >
          <Icon name={thumbUpName} size={18} className={styles.thumbIcon} />
          Yes
        </button>
        <button
          type="button"
          className={styles.asideBtn}
          onClick={handleAsideNo}
          aria-label="No, this was not helpful"
        >
          <Icon name={thumbDownName} size={18} className={styles.thumbIcon} />
          No
        </button>
      </div>
    );

    return (
      <div
        className={clsx(
          styles.asideRoot,
          asideEndSlot && styles.asideRootWithEndSlot,
          feedback === 'no' && styles.asideRootWithFollowup
        )}
      >
        <p className={styles.asideLabel}>Was this helpful?</p>
        {buttonsRow}
        {feedback === 'no' && (
          <div className={styles.asideFollowup}>
            <textarea
              className={styles.asideTextarea}
              placeholder="Tell us more (optional)..."
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              rows={2}
            />
            <button
              type="button"
              className={clsx(styles.asideSubmit, styles.feedbackSubmitNo)}
              onClick={handleAsideSubmit}
            >
              Submit
            </button>
          </div>
        )}
        {asideEndSlot ? (
          <div className={styles.asideEndSlot}>{asideEndSlot}</div>
        ) : null}
      </div>
    );
  }

  return (
    <div className={styles.wasThisHelpful}>
      <div className={styles.feedbackPrompt}>
        <span className={styles.promptText}>Was this helpful?</span>
        <div className={styles.feedbackButtons}>
          <button
            type="button"
            className={clsx(
              styles.feedbackButton,
              feedback === 'yes' && styles.feedbackButtonActive
            )}
            onClick={() => handleCardFeedback('yes')}
            aria-label="Yes, this was helpful"
          >
            <Icon
              name={thumbUpName}
              size={20}
              className={clsx(
                styles.thumbIcon,
                feedback === 'yes' && styles.thumbIconOnPrimary
              )}
            />
            Yes
          </button>
          <button
            type="button"
            className={clsx(
              styles.feedbackButton,
              feedback === 'no' && styles.feedbackButtonActive
            )}
            onClick={() => handleCardFeedback('no')}
            aria-label="No, this was not helpful"
          >
            <Icon
              name={thumbDownName}
              size={20}
              className={clsx(
                styles.thumbIcon,
                feedback === 'no' && styles.thumbIconOnPrimary
              )}
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
            type="button"
            className={clsx(
              styles.submitButton,
              feedback === 'no' && styles.feedbackSubmitNo
            )}
            onClick={handleCardSubmit}
          >
            Submit Feedback
          </button>
        </div>
      )}
    </div>
  );
}
