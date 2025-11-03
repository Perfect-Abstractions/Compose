import React, {useState, useEffect} from 'react';
import {useGithubStarsCount} from '@site/src/hooks/useGithubStarsCount';
import styles from './styles.module.css';

export default function GitHubStarButton({
  owner = 'Perfect-Abstractions',
  repo = 'Compose',
  href,
  className,
}) {
  const {value, count, isLoading} = useGithubStarsCount({
    owner,
    repo,
    defaultValue: '0',
  });

  const githubUrl = href || `https://github.com/${owner}/${repo}`;
  const storageKey = `github-star-${owner}-${repo}`;

  const [isStarred, setIsStarred] = useState(false);

  useEffect(() => {
    // Check if user has already starred (stored in localStorage)
    const starred = localStorage.getItem(storageKey) === 'true';
    setIsStarred(starred);
  }, [storageKey]);

  const handleClick = () => {
    // Toggle starred state and save to localStorage
    const newState = !isStarred;
    setIsStarred(newState);
    localStorage.setItem(storageKey, String(newState));
  };

  const displayText = isLoading 
    ? 'stars on GitHub' 
    : count !== null 
      ? `${value} stars on GitHub` 
      : 'stars on GitHub';

  return (
    <a
      href={githubUrl}
      target="_blank"
      rel="noopener noreferrer"
      className={`${styles.starButton} ${className || ''} ${isStarred ? styles.starred : ''}`}
      onClick={handleClick}
    >
      <svg
        className={`${styles.starIcon} ${isStarred ? styles.starIconStarred : ''}`}
        width="20"
        height="20"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden="true"
      >
        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
      </svg>
      <span>{displayText}</span>
    </a>
  );
}

