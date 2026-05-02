import React, { useState, useMemo, useEffect } from 'react';
import CodeBlock from '@theme/CodeBlock';
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
  const [needsExpansion, setNeedsExpansion] = useState(false);

  const codeContent = typeof children === 'string' ? children : children?.props?.children || '';
  const lineCount = useMemo(() => codeContent.split('\n').length, [codeContent]);

  useEffect(() => {
    setNeedsExpansion(lineCount > maxLines);
  }, [lineCount, maxLines]);

  return (
    <div className={styles.expandableCode}>
      {title && <div className={styles.codeTitle}>{title}</div>}
      <div className={styles.codeWrapper}>
        <CodeBlock
          language={language}
          className={clsx(
            styles.codeBlock,
            !isExpanded && needsExpansion && styles.codeBlockCollapsed
          )}
          style={{ '--max-lines': maxLines }}
        >
          {codeContent}
        </CodeBlock>
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
                Show More ({lineCount - maxLines} more lines)
              </>
            )}
          </button>
        )}
      </div>
    </div>
  );
}





