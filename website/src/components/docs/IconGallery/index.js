import React from 'react';
import Icon from '../../ui/Icon';

/**
 * IconGallery Component - Displays all available icons in a grid layout
 * Automatically discovers icons from the static/icons directory
 */
export default function IconGallery() {
  // List of all available icons (without .svg extension)
  const icons = [
    'arrow-down-right',
    'arrow-right-small',
    'arrow-right',
    'arrow-up-right',
    'book',
    'books',
    'box-detailed',
    'chart',
    'chat',
    'checkmark',
    'chevron-down-small',
    'chevron-down',
    'chevron-up',
    'clipboard',
    'clock',
    'coin',
    'community',
    'compose',
    'composition',
    'cross',
    'cube-detailed',
    'cube',
    'cycle',
    'diamond-native',
    'diamond',
    'discord',
    'dot',
    'download',
    'eye',
    'geometric-diamond',
    'github',
    'globe',
    'graduation',
    'heart',
    'key',
    'layers-simple',
    'layers',
    'library',
    'lightbulb',
    'lightning',
    'lock',
    'memo',
    'mobile',
    'no-entry',
    'package',
    'padlock',
    'palette',
    'plug',
    'puzzle',
    'read-first',
    'rocket',
    'save',
    'scroll',
    'settings',
    'shield',
    'simplicity',
    'siren',
    'sparkles',
    'star',
    'target',
    'thumbs-down',
    'thumbs-up',
    'users',
    'warning',
    'wave',
    'wrench',
  ];

  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: 'repeat(auto-fill, minmax(120px, 1fr))',
      gap: '1.5rem',
      marginTop: '2rem',
      marginBottom: '2rem'
    }}>
      {icons.map((iconName) => (
        <div key={iconName} style={{ textAlign: 'center' }}>
          <div style={{ 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center', 
            height: '80px',
            marginBottom: '0.5rem',
            background: 'var(--ifm-background-surface-color)',
            borderRadius: '0.5rem',
            padding: '1rem'
          }}>
            <Icon name={iconName} size={32} />
          </div>
          <code style={{ fontSize: '0.75rem', color: 'var(--ifm-color-emphasis-600)' }}>
            {iconName}
          </code>
        </div>
      ))}
    </div>
  );
}

