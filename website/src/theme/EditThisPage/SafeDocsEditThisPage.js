import React from 'react';
import DocsEditThisPage from './DocsEditThisPage';
import SimpleEditThisPage from './SimpleEditThisPage';

/**
 * Error boundary wrapper for DocsEditThisPage
 * Catches errors if useDoc hook is called outside DocProvider context
 * Falls back to SimpleEditThisPage if an error occurs
 * 
 * @param {string} editUrl - URL to edit the page
 */
export default class SafeDocsEditThisPage extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error) {
    // If useDoc fails, fall back to simple version
    return { hasError: true };
  }

  componentDidCatch(error, errorInfo) {
    // Error caught, will render fallback
    // Could log to error reporting service here if needed
  }

  render() {
    if (this.state.hasError) {
      return <SimpleEditThisPage editUrl={this.props.editUrl} />;
    }

    return <DocsEditThisPage editUrl={this.props.editUrl} />;
  }
}
