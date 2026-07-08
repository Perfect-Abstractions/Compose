import React, { useState, useEffect, useRef, useCallback } from 'react';
import { createPortal } from 'react-dom';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import CodeBlock from '@theme/CodeBlock';
import Heading from '@theme/Heading';
import Icon from '../ui/Icon';
import { useMatchMedia } from '../../hooks/useMatchMedia';
import styles from './codeShowcase.module.css';

const CODE_FILENAME = 'GameNFTFacet.sol';
const PANEL_TITLE_ID = 'code-showcase-panel-title';

const SHOWCASE_EXAMPLE_CODE = `// Your custom facet uses the ERC721 module
import { ERC721Mod } from "compose/ERC721Mod.sol";

contract GameNFTFacet {
    function mintWithGameLogic(
        address player,
        uint256 tokenId
    ) external {
        // Your custom game logic
        require(
            playerHasEnoughPoints(player),
            "Not enough points"
        );

        // Use ERC721Mod - same storage
        ERC721Mod.mint(player, tokenId);

        // Standard ERC721Facet functions work seamlessly
        updatePlayerStats(player);
    }
}`;

const FOCUSABLE_SELECTOR =
  'button:not([disabled]), [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';

function ShowcaseSolidityCode() {
  return (
    <div className={styles.codeShowcaseBlockRoot}>
      <CodeBlock language="solidity" showLineNumbers={false}>
        {SHOWCASE_EXAMPLE_CODE}
      </CodeBlock>
    </div>
  );
}

export default function CodeShowcase() {
  const isNarrow = useMatchMedia('(max-width: 1100px)');
  const [panelActive, setPanelActive] = useState(false);
  const [panelEntered, setPanelEntered] = useState(false);
  const triggerRef = useRef(null);
  const closeButtonRef = useRef(null);
  const panelRef = useRef(null);

  const finishClose = useCallback(() => {
    setPanelActive(false);
    setPanelEntered(false);
  }, []);

  const requestClose = useCallback(() => {
    setPanelEntered(false);
  }, []);

  const openPanel = useCallback(() => {
    setPanelActive(true);
    setPanelEntered(false);
  }, []);

  useEffect(() => {
    if (!panelActive) return;
    const id = requestAnimationFrame(() => {
      requestAnimationFrame(() => setPanelEntered(true));
    });
    return () => cancelAnimationFrame(id);
  }, [panelActive]);

  useEffect(() => {
    if (!isNarrow) {
      setPanelActive(false);
      setPanelEntered(false);
    }
  }, [isNarrow]);

  useEffect(() => {
    if (!panelActive) return;
    const prev = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prev;
    };
  }, [panelActive]);

  useEffect(() => {
    if (!panelActive || !panelEntered) return;
    const onKey = (e) => {
      if (e.key === 'Escape') requestClose();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [panelActive, panelEntered, requestClose]);

  useEffect(() => {
    if (!panelEntered) return;
    closeButtonRef.current?.focus();
  }, [panelEntered]);

  const onPanelTransitionEnd = useCallback(
    (e) => {
      if (e.target !== panelRef.current) return;
      if (e.propertyName !== 'transform') return;
      if (panelEntered) return;
      finishClose();
      triggerRef.current?.focus();
    },
    [panelEntered, finishClose]
  );

  const handlePanelKeyDown = useCallback((e) => {
    if (e.key !== 'Tab') return;
    const root = panelRef.current;
    if (!root) return;
    const list = Array.from(root.querySelectorAll(FOCUSABLE_SELECTOR)).filter(
      (el) => !el.hasAttribute('disabled')
    );
    if (list.length === 0) return;
    const first = list[0];
    const last = list[list.length - 1];
    const active = document.activeElement;
    if (e.shiftKey) {
      if (active === first || !root.contains(active)) {
        e.preventDefault();
        last.focus();
      }
    } else if (active === last) {
      e.preventDefault();
      first.focus();
    }
  }, []);

  const overlay =
    panelActive &&
    typeof document !== 'undefined' &&
    createPortal(
      <>
        <div
          role="presentation"
          className={clsx(
            styles.codePanelBackdrop,
            panelEntered && styles.codePanelBackdropVisible
          )}
          onClick={requestClose}
        />
        <div
          ref={panelRef}
          className={clsx(styles.codePanel, panelEntered && styles.codePanelVisible)}
          role="dialog"
          aria-modal="true"
          aria-labelledby={PANEL_TITLE_ID}
          onKeyDown={handlePanelKeyDown}
          onTransitionEnd={onPanelTransitionEnd}>
          <div className={styles.codePanelInner}>
            <div className={styles.codeWindow}>
              <div className={clsx(styles.codeWindowHeader, styles.codeWindowHeaderPanel)}>
                <span id={PANEL_TITLE_ID} className={styles.codeWindowTitle}>
                  {CODE_FILENAME}
                </span>
                <button
                  ref={closeButtonRef}
                  type="button"
                  className={styles.codePanelClose}
                  aria-label="Close"
                  onClick={requestClose}>
                  <span className={styles.codePanelCloseIcon} aria-hidden="true">
                    <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
                      <path
                        d="M5 5l10 10M15 5L5 15"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                      />
                    </svg>
                  </span>
                </button>
              </div>
              <ShowcaseSolidityCode />
            </div>
          </div>
        </div>
      </>,
      document.body
    );

  return (
    <section className={styles.showcaseSection}>
      <div className="container">
        <div className={styles.showcaseGrid}>
          <div className={styles.showcaseContent}>
            <Heading as="h2" className={styles.showcaseTitle}>
              {`Ship Extensions on Shared State`}
            </Heading>
            <p className={styles.showcaseDescription}>
              Both facets and modules access the same storage in your diamond.
              Your custom facets can extend Compose functionality without inheritance.
            </p>
            <div className={styles.showcaseFeatures}>
              <Link to="/docs/foundations/facets-and-modules" className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-facet" size={24} />
                </div>
                <div>
                  <h4>Facets</h4>
                  <p>Complete, reusable implementations</p>
                </div>
              </Link>
              <Link to="/docs/foundations/solidity-modules" className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-library" size={24} />
                </div>
                <div>
                  <h4>Modules</h4>
                  <p>Helper functions for custom facets</p>
                </div>
              </Link>
              <Link
                to="/docs/foundations/facets-and-modules#the-key-insight-shared-storage"
                className={styles.showcaseFeature}>
                <div className={styles.showcaseFeatureIcon}>
                  <Icon name="showcase-storage" size={24} />
                </div>
                <div>
                  <h4>Shared Storage</h4>
                  <p>Both work with the same data</p>
                </div>
              </Link>
            </div>
            {isNarrow && (
              <button
                ref={triggerRef}
                type="button"
                className={styles.codeExampleTrigger}
                onClick={openPanel}>
                View Code Example
              </button>
            )}
          </div>
          {!isNarrow && (
            <div className={styles.showcaseCode}>
              <div className={styles.codeWindow}>
                <div className={styles.codeWindowHeader}>
                  <span className={styles.codeWindowTitle}>{CODE_FILENAME}</span>
                </div>
                <ShowcaseSolidityCode />
              </div>
            </div>
          )}
        </div>
      </div>
      {overlay}
    </section>
  );
}
