import React, { useState } from 'react';
import Icon from '../../ui/Icon';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * ExpandableCode Component - Collapsible long code blocks
 * 
 * @param {string} language - Code language
 * @param {number} maxLines - Maximum lines before collapsing (default: 10)
 * @param {string} title - Optional title
 * @param {ReactNode} children - Code content
 */
export default function ExpandableCode({ 
  language = 'javascript',
  maxLines = 10,
  title,
  children
}) {
  const [isExpanded, setIsExpanded] = useState(false);
  const codeRef = React.useRef(null);
  const [needsExpansion, setNeedsExpansion] = React.useState(false);

  React.useEffect(() => {
    if (codeRef.current) {
      const lines = codeRef.current.textContent.split('\n').length;
      setNeedsExpansion(lines > maxLines);
    }
  }, [children, maxLines]);

  const codeContent = typeof children === 'string' ? children : children?.props?.children || '';

  return (
    <div className={styles.expandableCode}>
      {title && <div className={styles.codeTitle}>{title}</div>}
      <div className={styles.codeWrapper}>
        <pre
          ref={codeRef}
          className={clsx(
            styles.codeBlock,
            !isExpanded && needsExpansion && styles.codeBlockCollapsed
          )}
          style={{
            '--max-lines': maxLines,
          }}
        >
          <code className={`language-${language}`}>{codeContent}</code>
        </pre>
        {needsExpansion && (
          <button
            className={clsx(
              styles.expandButton,
              isExpanded && styles.expandButtonExpanded
            )}
            onClick={() => setIsExpanded(!isExpanded)}
            aria-label={isExpanded ? 'Collapse code' : 'Expand code'}
          >
            {isExpanded ? (
              <>
                <Icon name="chevron-up" size={16} />
                Show Less
              </>
            ) : (
              <>
                <Icon name="chevron-down" size={16} />
                Show More ({codeRef.current?.textContent.split('\n').length - maxLines} more lines)
              </>
            )}
          </button>
        )}
      </div>
    </div>
  );
}





