import React, {useState, useEffect} from 'react';
import Icon from '@site/src/components/ui/Icon';
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
      <Icon
        name="star-outline"
        size={20}
        className={`${styles.starIcon} ${isStarred ? styles.starIconStarred : ''}`}
      />
      <span>{displayText}</span>
    </a>
  );
}

