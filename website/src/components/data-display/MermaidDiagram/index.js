import React, { useEffect, useRef, useState } from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

/**
 * MermaidDiagram Component - Mermaid diagram support
 * 
 * @param {string} diagram - Mermaid diagram code
 * @param {string} theme - Mermaid theme ('default', 'dark', 'neutral', default: 'default')
 */
export default function MermaidDiagram({ 
  diagram,
  theme = 'default'
}) {
  const mermaidRef = useRef(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    if (!diagram || !mermaidRef.current) return;

    const renderMermaid = async () => {
      try {
        // Dynamically import mermaid if available
        const mermaid = await import('mermaid').catch(() => null);
        
        if (!mermaid) {
          setError('Mermaid library not available. Please install mermaid package.');
          return;
        }

        mermaid.default.initialize({
          startOnLoad: false,
          theme: theme === 'dark' ? 'dark' : theme === 'neutral' ? 'neutral' : 'default',
          themeVariables: {
            primaryColor: '#3b82f6',
            primaryTextColor: '#ffffff',
            primaryBorderColor: '#2563eb',
            lineColor: '#60a5fa',
            secondaryColor: '#93c5fd',
            tertiaryColor: '#bfdbfe',
          }
        });

        const id = `mermaid-${Math.random().toString(36).substr(2, 9)}`;
        mermaidRef.current.id = id;
        
        await mermaid.default.render(id, diagram);
        mermaidRef.current.innerHTML = '';
        mermaidRef.current.innerHTML = `<div class="mermaid">${diagram}</div>`;
        await mermaid.default.init(undefined, mermaidRef.current);
      } catch (err) {
        console.error('Mermaid rendering error:', err);
        setError('Failed to render diagram. Please check your Mermaid syntax.');
      }
    };

    renderMermaid();
  }, [diagram, theme]);

  if (error) {
    return (
      <div className={styles.error}>
        <p>{error}</p>
        <pre className={styles.errorCode}>{diagram}</pre>
      </div>
    );
  }

  return (
    <div className={styles.mermaidDiagram}>
      <div ref={mermaidRef} className={styles.mermaidContainer}></div>
    </div>
  );
}

