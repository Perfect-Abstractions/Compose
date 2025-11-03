/**
 * Root component wrapper
 * Adds global enhancements and effects
 */

import React from 'react';
import NavbarEnhancements from '@site/src/components/navigation/NavbarEnhancements';

export default function Root({children}) {
  return (
    <>
      <NavbarEnhancements />
      {children}
    </>
  );
}


