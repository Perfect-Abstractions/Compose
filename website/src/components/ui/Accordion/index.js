import React, { useState } from 'react';
import clsx from 'clsx';
import Icon from '../Icon';
import styles from './styles.module.css';

/**
 * Accordion Component - Collapsible sections for FAQs and details
 * 
 * @param {string} title - Accordion title/header
 * @param {boolean} defaultOpen - Whether accordion is open by default
 * @param {ReactNode} children - Content to display when expanded
 * @param {string} variant - Style variant ('default', 'bordered')
 */
export default function Accordion({ 
  title, 
  defaultOpen = false,
  children,
  variant = 'default'
}) {
  const [isOpen, setIsOpen] = useState(defaultOpen);

  const toggle = () => {
    setIsOpen(!isOpen);
  };

  return (
    <div className={clsx(styles.accordion, styles[`accordion--${variant}`])}>
      <button
        className={clsx(styles.accordionHeader, isOpen && styles.accordionHeaderOpen)}
        onClick={toggle}
        aria-expanded={isOpen}
        aria-controls={`accordion-content-${title?.replace(/\s+/g, '-').toLowerCase()}`}
      >
        <span className={styles.accordionTitle}>{title}</span>
        <Icon
          name="accordion-chevron"
          size={20}
          className={clsx(styles.accordionIcon, isOpen && styles.accordionIconOpen)}
        />
      </button>
      <div
        id={`accordion-content-${title?.replace(/\s+/g, '-').toLowerCase()}`}
        className={clsx(styles.accordionContent, isOpen && styles.accordionContentOpen)}
        aria-hidden={!isOpen}
      >
        <div className={styles.accordionBody}>
          {children}
        </div>
      </div>
    </div>
  );
}

/**
 * AccordionGroup - Container for multiple accordions
 */
export function AccordionGroup({ children, className }) {
  return (
    <div className={clsx(styles.accordionGroup, className)}>
      {children}
    </div>
  );
}





