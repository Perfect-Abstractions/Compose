/**
 * Footer Component
 * Custom footer with Netlify badge
 */

import React from 'react';
import Footer from '@theme-original/Footer';
import styles from './styles.module.css';

export default function FooterWrapper(props) {
  return (
    <div className={styles.footerWrapper}>
      <Footer {...props} />
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

