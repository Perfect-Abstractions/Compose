import React, { useState } from 'react';
import CodeBlock from '@theme/CodeBlock';
import styles from './styles.module.css';

export default function CodeShowcase({ examples }) {
  const [activeTab, setActiveTab] = useState(0);

  return (
    <div className={styles.showcase}>
      {/* Tab Bar */}
      <div className={styles.tabBar}>
        {examples.map((example, index) => (
          <button
            key={index}
            className={`${styles.tab} ${activeTab === index ? styles.tabActive : ''}`}
            onClick={() => setActiveTab(index)}
            type="button"
          >
            {example.label}
          </button>
        ))}
      </div>
      
      {/* Code Content */}
      <div className={styles.codeWrapper}>
        <CodeBlock 
          language={examples[activeTab].language || 'javascript'}
          showLineNumbers={false}
        >
          {examples[activeTab].code}
        </CodeBlock>
      </div>
    </div>
  );
}
