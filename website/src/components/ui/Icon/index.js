import React from 'react';

/**
 * Icon Component - Renders SVG icons from static/icons folder
 * 
 * @param {string} name - Icon name (e.g., 'star', 'warning', 'lightbulb')
 * @param {string} className - Optional CSS class
 * @param {number} size - Icon size in pixels (default: 24)
 */
export default function Icon({ name, className, size = 24, decorative = true, alt = '' }) {
  return (
    <img
      src={`/icons/${name}.svg`}
      alt={decorative ? '' : alt || `${name} icon`}
      aria-hidden={decorative ? 'true' : undefined}
      loading="lazy"
      width={size}
      height={size}
      className={className}
      style={{ display: 'inline-block', verticalAlign: 'middle' }}
    />
  );
}

