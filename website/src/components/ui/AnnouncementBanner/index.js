import React, { useState, useEffect } from 'react';
import clsx from 'clsx';
import Icon from '../Icon';
import styles from './styles.module.css';

const STORAGE_KEY_PREFIX = 'announcementBanner:';

/**
 * AnnouncementBanner - Site-wide top-of-page announcement bar
 *
 * @param {string} id - Stable identifier for this banner version (used for dismiss persistence)
 * @param {ReactNode|string} message - Main announcement text/content
 * @param {string} linkHref - Optional URL for primary call-to-action
 * @param {string} linkLabel - Label for the call-to-action link
 * @param {'local'|'session'|'none'} persistence - Where to persist dismissal; defaults to 'local'
 * @param {string} className - Optional extra className for container
 */
export default function AnnouncementBanner({
  id,
  message,
  linkHref,
  linkLabel,
  persistence = 'local',
  className,
}) {
  const [hidden, setHidden] = useState(true);

  useEffect(() => {
    if (!id) {
      setHidden(true);
      return;
    }
    if (typeof window === 'undefined') {
      setHidden(true);
      return;
    }
    try {
      const storageKey = `${STORAGE_KEY_PREFIX}${id}`;
      let dismissed = false;

      if (persistence === 'local') {
        const stored = window.localStorage.getItem(storageKey);
        dismissed = stored === 'dismissed';
      } else if (persistence === 'session') {
        const stored = window.sessionStorage.getItem(storageKey);
        dismissed = stored === 'dismissed';
      } else {
        // 'none' – do not restore a dismissed state between visits
        dismissed = false;
      }

      // Default to hidden; only show when banner has not been dismissed
      setHidden(dismissed);
    } catch {
      // localStorage can fail in some environments; keep banner hidden by default
      setHidden(true);
    }
  }, [id, persistence]);

  if (!id || !message || hidden) {
    return null;
  }

  const handleDismiss = () => {
    setHidden(true);
    if (typeof window === 'undefined') {
      return;
    }
    try {
      if (!id || persistence === 'none') {
        return;
      }
      const storageKey = `${STORAGE_KEY_PREFIX}${id}`;
      if (persistence === 'local') {
        window.localStorage.setItem(storageKey, 'dismissed');
      } else if (persistence === 'session') {
        window.sessionStorage.setItem(storageKey, 'dismissed');
      }
    } catch {
      // Ignore storage errors
    }
  };

  return (
    <div
      className={clsx(styles.banner, className)}
      role="status"
      aria-live="polite">
      <div className={styles.bannerInner}>
        <div className={styles.bannerMessage}>
          {message}
          {linkHref && linkLabel && (
            <a className={styles.bannerLink} href={linkHref}>
              {linkLabel}
            </a>
          )}
        </div>
        <button
          type="button"
          className={styles.closeButton}
          onClick={handleDismiss}
          aria-label="Dismiss announcement">
          <Icon name="close" size={18} decorative={false} alt="Close" />
        </button>
      </div>
    </div>
  );
}

