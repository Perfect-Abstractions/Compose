import React from 'react';
import clsx from 'clsx';
import styles from './styles.module.css';

export default function IconNavbarItem({
  mobile = false,
  position: _position,
  href,
  iconSrc,
  label,
  className,
}) {
  const icon = (
    <img
      src={iconSrc}
      alt=""
      width={24}
      height={24}
      className={styles.icon}
      loading="lazy"
    />
  );

  const link = (
    <a
      className={clsx(
        mobile ? 'menu__link' : 'navbar__item navbar__link',
        styles.link,
        className,
      )}
      href={href}
      aria-label={label}
      target="_blank"
      rel="noopener noreferrer">
      {icon}
    </a>
  );

  if (mobile) {
    return <li className="menu__list-item">{link}</li>;
  }

  return link;
}
