/**
 * Root component wrapper
 * Adds global enhancements and effects
 */
import React from 'react';
import { Toaster } from 'react-hot-toast';
import NavbarEnhancements from '@site/src/components/navigation/NavbarEnhancements';
import useInjectMarkdownActionsDropdown from '@site/src/hooks/useInjectMarkdownActionsDropdown';

export default function Root({children}) {
  useInjectMarkdownActionsDropdown();

  return (
    <>
      <NavbarEnhancements />
      <Toaster 
        position="bottom-right"
        reverseOrder={false}
        gutter={12}
        containerClassName=""
        containerStyle={{}}
        toastOptions={{
          // Base styles - CSS will handle most styling
          duration: 4000,
          style: {
            // Use CSS variables for theme adaptation
            fontFamily: 'var(--ifm-font-family-base)',
            background: 'var(--ifm-background-surface-color)',
            color: 'var(--ifm-font-color-base)',
            border: '1px solid var(--ifm-color-emphasis-200)',
          },
          // Success toast styling
          success: {
            duration: 4000,
            iconTheme: {
              primary: '#10b981',
              secondary: '#ffffff',
            },
            style: {
              background: 'var(--ifm-background-surface-color)',
              color: 'var(--ifm-font-color-base)',
              border: '1px solid var(--ifm-color-emphasis-200)',
              borderLeft: '3px solid #10b981',
            },
          },
          // Error toast styling
          error: {
            duration: 5000,
            iconTheme: {
              primary: '#ef4444',
              secondary: '#ffffff',
            },
            style: {
              background: 'var(--ifm-background-surface-color)',
              color: 'var(--ifm-font-color-base)',
              border: '1px solid var(--ifm-color-emphasis-200)',
              borderLeft: '3px solid #ef4444',
            },
          },
          // Loading toast styling
          loading: {
            iconTheme: {
              primary: 'var(--ifm-color-primary)',
              secondary: 'var(--ifm-background-color)',
            },
            style: {
              background: 'var(--ifm-background-surface-color)',
              color: 'var(--ifm-font-color-base)',
              border: '1px solid var(--ifm-color-emphasis-200)',
              borderLeft: '3px solid var(--ifm-color-primary)',
            },
          },
          // Default toast styling
          blank: {
            style: {
              background: 'var(--ifm-background-surface-color)',
              color: 'var(--ifm-font-color-base)',
              border: '1px solid var(--ifm-color-emphasis-200)',
              borderLeft: '3px solid var(--ifm-color-emphasis-300)',
            },
          },
        }}
      />
      {children}
    </>
  );
}


