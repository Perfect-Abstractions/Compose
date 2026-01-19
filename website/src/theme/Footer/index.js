/**
 * Footer Component
 * Custom footer with Netlify badge and newsletter signup
 */

import React, { useRef } from 'react';
import Footer from '@theme-original/Footer';
import FooterNewsletterSignup from '@site/src/components/newsletter/FooterNewsletterSignup';
import { useFooterNewsletterPosition } from '@site/src/hooks/useFooterNewsletterPosition';
import styles from './styles.module.css';

export default function FooterWrapper(props) {
  const footerRef = useRef(null);
  const newsletterRef = useRef(null);
  useFooterNewsletterPosition({ footerRef, newsletterRef });

  return (
    <div className={styles.footerWrapper} ref={footerRef}>
      <Footer {...props} />
      <div ref={newsletterRef} className={styles.footerNewsletterSection}>
        <FooterNewsletterSignup />
      </div>
      <div className="netlifyBadge">
        <a 
          href="https://www.netlify.com" 
          target="_blank" 
          rel="noopener noreferrer"
        >
          <span className="badgeDot"></span>
          <span className="badgeText">
            This site is powered by <span className="badgeTextNetlify">Netlify</span>
          </span>
        </a>
      </div>
    </div>
  );
}

