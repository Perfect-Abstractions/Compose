/**
 * Shared sidebar toggle button for breadcrumb rows (docs and blog).
 * Desktop-only; uses same breakpoint (997px) as sidebars. Accessible and keyboard-friendly.
 */
import React, { useCallback } from 'react';
import styles from './SidebarToggleButton.module.css';

export default function SidebarToggleButton({
  isHidden,
  onToggle,
  ariaLabel,
  ...rest
}) {
  const handleKeyDown = useCallback(
    (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        onToggle();
      }
    },
    [onToggle]
  );

  return (
    <button
      type="button"
      className={styles.sidebarToggleButton}
      onClick={onToggle}
      onKeyDown={handleKeyDown}
      aria-label={ariaLabel}
      aria-pressed={isHidden}
      title={ariaLabel}
      {...rest}>
      <span className={styles.sidebarToggleIcon} aria-hidden="true" />
    </button>
  );
}
