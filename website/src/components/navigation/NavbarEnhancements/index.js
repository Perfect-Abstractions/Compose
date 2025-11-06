/**
 * Navbar Enhancements
 * Adds dynamic effects like scroll detection and animations
 */

import { useEffect } from 'react';
import ExecutionEnvironment from '@docusaurus/ExecutionEnvironment';

export function useNavbarScrollEffect() {
  useEffect(() => {
    if (!ExecutionEnvironment.canUseDOM) {
      return;
    }

    let lastScrollY = window.scrollY;
    let ticking = false;

    const updateNavbar = () => {
      const navbar = document.querySelector('.navbar');
      if (!navbar) return;

      const scrollY = window.scrollY;

      // Add scrolled class when scrolled down
      if (scrollY > 20) {
        navbar.classList.add('navbar--scrolled');
      } else {
        navbar.classList.remove('navbar--scrolled');
      }

      // Auto-hide on scroll down, show on scroll up (optional)
      // Uncomment the following if you want auto-hide behavior:
      /*
      if (scrollY > lastScrollY && scrollY > 100) {
        navbar.style.transform = 'translateY(-100%)';
      } else {
        navbar.style.transform = 'translateY(0)';
      }
      */

      lastScrollY = scrollY;
      ticking = false;
    };

    const requestTick = () => {
      if (!ticking) {
        window.requestAnimationFrame(updateNavbar);
        ticking = true;
      }
    };

    const handleScroll = () => {
      requestTick();
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    updateNavbar(); // Initial call

    return () => {
      window.removeEventListener('scroll', handleScroll);
    };
  }, []);
}

export function useNavbarLinkAnimations() {
  useEffect(() => {
    if (!ExecutionEnvironment.canUseDOM) {
      return;
    }

    // Add ripple effect on click
    const handleLinkClick = (e) => {
      const link = e.currentTarget;
      const ripple = document.createElement('span');
      const rect = link.getBoundingClientRect();
      const size = Math.max(rect.width, rect.height);
      const x = e.clientX - rect.left - size / 2;
      const y = e.clientY - rect.top - size / 2;

      ripple.style.width = ripple.style.height = `${size}px`;
      ripple.style.left = `${x}px`;
      ripple.style.top = `${y}px`;
      ripple.classList.add('navbar-ripple');

      link.style.position = 'relative';
      link.style.overflow = 'hidden';
      link.appendChild(ripple);

      setTimeout(() => {
        ripple.remove();
      }, 600);
    };

    const links = document.querySelectorAll('.navbar__link, .navbar__brand');
    links.forEach((link) => {
      link.addEventListener('click', handleLinkClick);
    });

    // Add ripple CSS
    const style = document.createElement('style');
    style.textContent = `
      .navbar-ripple {
        position: absolute;
        border-radius: 50%;
        background: rgba(59, 130, 246, 0.3);
        animation: navbar-ripple-animation 0.6s ease-out;
        pointer-events: none;
      }
      
      [data-theme='dark'] .navbar-ripple {
        background: rgba(96, 165, 250, 0.3);
      }
      
      @keyframes navbar-ripple-animation {
        from {
          transform: scale(0);
          opacity: 1;
        }
        to {
          transform: scale(4);
          opacity: 0;
        }
      }
    `;
    document.head.appendChild(style);

    return () => {
      links.forEach((link) => {
        link.removeEventListener('click', handleLinkClick);
      });
      style.remove();
    };
  }, []);
}

/**
 * Hook to initialize all navbar enhancements
 */
export function useNavbarEnhancements() {
  useNavbarScrollEffect();
  useNavbarLinkAnimations();
}

export default function NavbarEnhancements() {
  useNavbarEnhancements();
  return null;
}


