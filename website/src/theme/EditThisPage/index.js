import React from 'react';
import {useLocation} from '@docusaurus/router';
import SimpleEditThisPage from './SimpleEditThisPage';
import SafeDocsEditThisPage from './SafeDocsEditThisPage';

/**
 * Main EditThisPage component
 * 
 * Intelligently renders the appropriate EditThisPage variant based on the current route:
 * - Docs pages (/docs/*): Uses SafeDocsEditThisPage (with useDoc hook, wrapped in error boundary)
 * - Other pages: Uses SimpleEditThisPage
 * 
 * Route checking is necessary because error boundaries don't work reliably during SSR/build.
 * 
 * @param {string} editUrl - URL to edit the page
 */
export default function EditThisPage({editUrl}) {
  let isDocsPage = false;
  
  try {
    const location = useLocation();
    const pathname = location?.pathname || '';
    
    isDocsPage = pathname.startsWith('/docs/');
  } catch (error) {
    isDocsPage = false;
  }

  if (isDocsPage) {
    return <SafeDocsEditThisPage editUrl={editUrl} />;
  }

  return <SimpleEditThisPage editUrl={editUrl} />;
}
