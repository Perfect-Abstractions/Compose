import React, { useState } from 'react';
import clsx from 'clsx';
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
                <svg width="16" height="16" viewBox="0 0 20 20" fill="none">
                  <path
                    d="M16.667 5L7.5 14.167 3.333 10"
                    stroke="currentColor"
                    strokeWidth="2"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
                Copied!
              </>
            ) : (
              <>
                <svg width="16" height="16" viewBox="0 0 20 20" fill="none">
                  <path
                    d="M13.333 8.333H15A1.667 1.667 0 0116.667 10v6.667A1.667 1.667 0 0115 18.333H5A1.667 1.667 0 013.333 16.667V10A1.667 1.667 0 015 8.333h1.667m0-3.333h5m-5 0v5m0-5h5m-5 0v5m5-5v5"
                    stroke="currentColor"
                    strokeWidth="1.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                </svg>
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





