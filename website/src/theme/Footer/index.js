/**
 * Footer Component
 * Custom footer with Netlify badge and newsletter signup
 */

import React, { useEffect, useRef } from 'react';
import Footer from '@theme-original/Footer';
import FooterNewsletterSignup from '@site/src/components/newsletter/FooterNewsletterSignup';
import styles from './styles.module.css';

export default function FooterWrapper(props) {
  const footerRef = useRef(null);
  const newsletterRef = useRef(null);

  useEffect(() => {
    // Function to position newsletter based on viewport size
    const positionNewsletter = () => {
      if (!footerRef.current || !newsletterRef.current) return;
      
      const footerLinks = footerRef.current.querySelector('.footer__links');
      if (!footerLinks) return;
      
      // Check if newsletter is already in the container
      const isInContainer = footerLinks.contains(newsletterRef.current);
      
      // Determine if mobile or desktop (breakpoint: 996px)
      const isMobile = window.innerWidth <= 996;
      
      if (!isInContainer) {
        // Newsletter not yet in container, add it
        if (isMobile) {
          // Prepend on mobile (appears first)
          footerLinks.insertBefore(newsletterRef.current, footerLinks.firstChild);
        } else {
          // Append on desktop (appears on right side)
          footerLinks.appendChild(newsletterRef.current);
        }
      } else {
        // Newsletter already in container, reposition if needed
        const isFirst = footerLinks.firstChild === newsletterRef.current;
        const isLast = footerLinks.lastChild === newsletterRef.current;
        
        if (isMobile && !isFirst) {
          // Should be first on mobile
          footerLinks.insertBefore(newsletterRef.current, footerLinks.firstChild);
        } else if (!isMobile && !isLast) {
          // Should be last on desktop
          footerLinks.appendChild(newsletterRef.current);
        }
      }
    };

    // Position on mount
    positionNewsletter();

    // Handle window resize
    const handleResize = () => {
      positionNewsletter();
    };

    window.addEventListener('resize', handleResize);

    // Cleanup
    return () => {
      window.removeEventListener('resize', handleResize);
    };
  }, []);

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

