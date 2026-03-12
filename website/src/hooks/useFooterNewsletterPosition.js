import { useEffect } from 'react';

/**
 * Hook for positioning newsletter in footer based on viewport size
 * 
 * Handles dynamic positioning of newsletter component in footer:
 * - First position on mobile (≤996px)
 * - Last position on desktop (>996px)
 * 
 * Uses MutationObserver to handle async footer rendering and debounced
 * resize handler for performance.
 * 
 * @param {Object} refs - React refs for footer and newsletter elements
 * @param {React.RefObject} refs.footerRef - Ref to footer wrapper element
 * @param {React.RefObject} refs.newsletterRef - Ref to newsletter section element
 * @param {Object} options - Configuration options
 * @param {number} options.mobileBreakpoint - Breakpoint for mobile/desktop (default: 996)
 * @param {number} options.debounceMs - Debounce delay for resize handler (default: 150)
 */
export function useFooterNewsletterPosition(
  { footerRef, newsletterRef },
  { mobileBreakpoint = 996, debounceMs = 150 } = {}
) {
  useEffect(() => {
    if (!footerRef?.current || !newsletterRef?.current) return;

    // Debounce utility function
    const debounce = (func, wait) => {
      let timeout;
      return (...args) => {
        clearTimeout(timeout);
        timeout = setTimeout(() => func(...args), wait);
      };
    };

    // Ensure newsletter is in footer__links container
    // Position based on viewport: first on mobile, last on desktop
    const insertNewsletter = () => {
      if (!footerRef.current || !newsletterRef.current) return;
      
      const footerLinks = footerRef.current.querySelector('.footer__links');
      if (!footerLinks) return;
      
      const isMobile = window.innerWidth <= mobileBreakpoint;
      const isInContainer = footerLinks.contains(newsletterRef.current);
      const isFirst = footerLinks.firstChild === newsletterRef.current;
      const isLast = footerLinks.lastChild === newsletterRef.current;
      
      if (!isInContainer) {
        // Not in container yet, add it
        if (isMobile) {
          footerLinks.insertBefore(newsletterRef.current, footerLinks.firstChild);
        } else {
          footerLinks.appendChild(newsletterRef.current);
        }
      } else if (isMobile && !isFirst) {
        // In container but should be first on mobile
        footerLinks.insertBefore(newsletterRef.current, footerLinks.firstChild);
      } else if (!isMobile && !isLast) {
        // In container but should be last on desktop
        footerLinks.appendChild(newsletterRef.current);
      }
    };

    // Initial insertion
    insertNewsletter();

    // Use MutationObserver to handle cases where footer renders asynchronously
    const observer = new MutationObserver(() => {
      insertNewsletter();
    });

    if (footerRef.current) {
      observer.observe(footerRef.current, {
        childList: true,
        subtree: true,
      });
    }

    // Debounced resize handler
    const handleResize = debounce(insertNewsletter, debounceMs);

    window.addEventListener('resize', handleResize);

    // Cleanup
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', handleResize);
    };
  }, [footerRef, newsletterRef, mobileBreakpoint, debounceMs]);
}
