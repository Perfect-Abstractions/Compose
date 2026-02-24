import React, { useState } from 'react';
import Icon from '../../ui/Icon';
import styles from './styles.module.css';

/**
 * TerminalCommand Component - Styled terminal/shell commands
 * 
 * @param {string} command - Command to display
 * @param {boolean} copyable - Show copy button (default: true)
 * @param {string} prompt - Command prompt (default: '$')
 * @param {string} language - Syntax highlighting language (default: 'bash')
 */
export default function TerminalCommand({ 
  command,
  copyable = true,
  prompt = '$',
  language = 'bash'
}) {
  const [copied, setCopied] = useState(false);

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(command);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  return (
    <div className={styles.terminalCommand}>
      <div className={styles.terminalHeader}>
        <div className={styles.terminalDots}>
          <span className={styles.dot}></span>
          <span className={styles.dot}></span>
          <span className={styles.dot}></span>
        </div>
        <span className={styles.terminalTitle}>Terminal</span>
        {copyable && (
          <button
            className={styles.copyButton}
            onClick={handleCopy}
            aria-label="Copy command"
            title="Copy command"
          >
            {copied ? (
              <>
                <Icon name="checkmark-stroke" size={16} />
                Copied!
              </>
            ) : (
              <>
                <Icon name="clipboard-outline" size={16} />
                Copy
              </>
            )}
          </button>
        )}
      </div>
      <div className={styles.terminalBody}>
        <pre className={styles.commandLine}>
          <span className={styles.prompt}>{prompt}</span>
          <code className={`language-${language}`}>{command}</code>
        </pre>
      </div>
    </div>
  );
}





