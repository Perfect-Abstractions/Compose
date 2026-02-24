/**
 * Markdown actions dropdown (view/copy as .md).
 * Local override of docusaurus-markdown-source-plugin's dropdown so that
 * category index pages (e.g. /docs/foundations/) resolve to index.md instead
 * of intro.md (which only exists for the root /docs & /docs/ page).
 * When path has a trailing slash (e.g. /docs/contribution/code-style-guide/#hash),
 * we try single-doc URL first (code-style-guide.md), then category index (index.md).
 */
import React, { useState, useRef, useCallback } from 'react';
import ChevronDownIcon from '@site/static/icons/chevron-down-filled.svg';
import ViewIcon from '@site/static/icons/view.svg';
import CopyIcon from '@site/static/icons/copy.svg';
import CheckmarkFilledIcon from '@site/static/icons/checkmark-filled.svg';
import { useResolvedMarkdownUrl } from '../../../hooks/useResolvedMarkdownUrl';
import { useClickOutside } from '../../../hooks/useClickOutside';

export default function MarkdownActionsDropdown() {
  const [copied, setCopied] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef(null);

  const rawPath = typeof window !== 'undefined' ? window.location.pathname : '';
  const isDocsPage = rawPath === '/docs' || rawPath.startsWith('/docs/');
  const { candidates, urlReady, markdownUrl } = useResolvedMarkdownUrl(rawPath);
  const closeDropdown = useCallback(() => setIsOpen(false), []);

  useClickOutside(dropdownRef, isOpen, closeDropdown);

  if (!isDocsPage || !candidates) {
    return null;
  }

  const handleOpenMarkdown = () => {
    if (!urlReady || !markdownUrl) return;
    window.open(markdownUrl, '_blank');
    setIsOpen(false);
  };

  const handleCopyMarkdown = async () => {
    if (!urlReady || !markdownUrl) return;
    try {
      const urlToFetch = markdownUrl;
      const fetchMarkdown = () =>
        fetch(urlToFetch).then((r) => {
          if (r.ok) return r.text();
          if (candidates.fallback && urlToFetch === candidates.primary) {
            return fetch(candidates.fallback).then((r2) => {
              if (!r2.ok) throw new Error('Failed to fetch markdown');
              return r2.text();
            });
          }
          throw new Error('Failed to fetch markdown');
        });
      // iOS Safari: clipboard.write() must run in the same user gesture as the click;
      // ClipboardItem + Promise keeps the gesture context after fetch().
      if (typeof ClipboardItem !== 'undefined') {
        const item = new ClipboardItem({
          'text/plain': fetchMarkdown().then((text) => new Blob([text], { type: 'text/plain' })),
        });
        await navigator.clipboard.write([item]);
      } else {
        const text = await fetchMarkdown();
        await navigator.clipboard.writeText(text);
      }

      setCopied(true);
      setTimeout(() => {
        setCopied(false);
        setIsOpen(false);
      }, 2000);
    } catch (error) {
      console.error('Failed to copy markdown:', error);
      alert('Failed to copy markdown. Please try again.');
    }
  };

  return (
    <div
      ref={dropdownRef}
      className={`dropdown ${isOpen ? 'dropdown--show' : ''}`}
    >
      <button
        className="button button--outline button--secondary button--sm"
        onClick={() => setIsOpen(!isOpen)}
        aria-haspopup="true"
        aria-expanded={isOpen}
      >
        Open Markdown
        <ChevronDownIcon width={16} height={16} style={{ marginLeft: '4px', verticalAlign: 'middle' }} />
      </button>

      <ul className="dropdown__menu">
        <li>
          <button
            className="dropdown__link"
            onClick={handleOpenMarkdown}
            disabled={!urlReady}
            style={{ cursor: urlReady ? 'pointer' : 'not-allowed', border: 'none', background: 'none', width: '100%', textAlign: 'left', opacity: urlReady ? 1 : 0.7 }}
          >
            <ViewIcon width={16} height={16} style={{ marginRight: '8px', verticalAlign: 'middle' }} />
            View
          </button>
        </li>
        <li>
          <button
            className="dropdown__link"
            onClick={handleCopyMarkdown}
            disabled={copied || !urlReady}
            style={{ cursor: 'pointer', border: 'none', background: 'none', width: '100%', textAlign: 'left' }}
          >
            {copied ? (
              <>
                <CheckmarkFilledIcon width={16} height={16} style={{ marginRight: '8px', verticalAlign: 'middle' }} />
                Copied!
              </>
            ) : (
              <>
                <CopyIcon width={16} height={16} style={{ marginRight: '8px', verticalAlign: 'middle' }} />
                Copy
              </>
            )}
          </button>
        </li>
      </ul>
    </div>
  );
}
