/**
 * Animated Gradient Background for Navbar
 * Adds floating gradient orbs for visual interest
 */

import React from 'react';
import styles from './styles.module.css';

export default function NavbarGradient() {
  return (
    <div className={styles.gradientContainer}>
      <div className={styles.gradientOrb1}></div>
      <div className={styles.gradientOrb2}></div>
    </div>
  );
}
