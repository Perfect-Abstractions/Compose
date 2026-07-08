/**
 * Markdown actions dropdown (view/copy as .md).
 * Local override of docusaurus-markdown-source-plugin's dropdown so that
 * category index pages (e.g. /docs/foundations/) resolve to index.md instead
 * of intro.md (which only exists for the root /docs & /docs/ page).
 * When path has a trailing slash (e.g. /docs/contribution/code-style-guide/#hash),
 * we try single-doc URL first (code-style-guide.md), then category index (index.md).
 *
 * Also supports standalone MDX pages (e.g. /whitepaper) via
 * useResolvedMarkdownUrl which now handles non-/docs paths.
 */
import React, { useState, useRef, useCallback } from 'react';
import ChevronDownIcon from '@site/static/icons/chevron-down-filled.svg';
import ViewIcon from '@site/static/icons/view.svg';
import CopyIcon from '@site/static/icons/copy.svg';
import CheckmarkFilledIcon from '@site/static/icons/checkmark-filled.svg';
import { useLocation } from '@docusaurus/router';
import { useResolvedMarkdownUrl } from '../../../hooks/useResolvedMarkdownUrl';
import { useClickOutside } from '../../../hooks/useClickOutside';

export default function MarkdownActionsDropdown() {
  const [copied, setCopied] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef(null);

  const location = useLocation();
  const rawPath = location?.pathname ?? '';
  const { candidates, urlReady, markdownUrl, markdownContent } = useResolvedMarkdownUrl(rawPath);
  const closeDropdown = useCallback(() => setIsOpen(false), []);

  useClickOutside(dropdownRef, isOpen, closeDropdown);

  if (!candidates) {
    return null;
  }

  const handleOpenMarkdown = () => {
    if (!urlReady || !markdownUrl) return;
    if (markdownContent) {
      const blob = new Blob([markdownContent], { type: 'text/markdown' });
      window.open(URL.createObjectURL(blob), '_blank');
    } else {
      window.open(markdownUrl, '_blank');
    }
    setIsOpen(false);
  };

  const handleCopyMarkdown = async () => {
    if (!urlReady) return;
    try {
      if (markdownContent) {
        await navigator.clipboard.writeText(markdownContent);
      } else {
        const urlToFetch = markdownUrl;
        const fetchMarkdown = () =>
          fetch(urlToFetch).then((r) => {
            if (!r.ok) {
              if (candidates.fallback && urlToFetch === candidates.primary) {
                return fetch(candidates.fallback).then((r2) => {
                  if (!r2.ok) throw new Error('Failed to fetch markdown');
                  return r2.text();
                });
              }
              throw new Error('Failed to fetch markdown');
            }
            return r.text().then((text) => {
              if (text.trim().startsWith('<!DOCTYPE') || text.trim().startsWith('<html')) {
                throw new Error('Server returned HTML instead of markdown');
              }
              return text;
            });
          });
        if (typeof ClipboardItem !== 'undefined') {
          const item = new ClipboardItem({
            'text/plain': fetchMarkdown().then((text) => new Blob([text], { type: 'text/plain' })),
          });
          await navigator.clipboard.write([item]);
        } else {
          const text = await fetchMarkdown();
          await navigator.clipboard.writeText(text);
        }
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
