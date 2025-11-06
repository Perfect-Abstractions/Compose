import {useEffect, useState} from 'react';
import {useSessionStorage} from './useSessionStorage';

/**
 * Fetch the star count for a GitHub repository.
 * Uses the GitHub API /repos/{owner}/{repo} endpoint.
 * Caches result in sessionStorage to avoid refetching during the same session.
 */
export function useGithubStarsCount({
  owner,
  repo,
  defaultValue = '0',
}) {
  const cacheKey = `github_stars_${owner}_${repo}`;
  const [cachedValue, setCachedValue] = useSessionStorage(cacheKey, null);
  
  const [value, setValue] = useState(() => {
    return cachedValue ? String(cachedValue) : String(defaultValue);
  });
  const [count, setCount] = useState(cachedValue);
  const [isLoading, setIsLoading] = useState(!cachedValue);
  const [error, setError] = useState(null);

  useEffect(() => {
    // If we have a cached value, use it and skip fetch
    if (cachedValue !== null) {
      setValue(String(cachedValue));
      setCount(cachedValue);
      setIsLoading(false);
      return;
    }

    let isMounted = true;

    async function fetchStarsCount() {
      setIsLoading(true);
      setError(null);
      try {
        const url = `https://api.github.com/repos/${owner}/${repo}`;
        const response = await fetch(url);
        
        if (!response.ok) {
          throw new Error(`GitHub API ${response.status}`);
        }

        const data = await response.json();
        if (data && typeof data.stargazers_count === 'number' && isMounted) {
          const starsCount = data.stargazers_count;
          if (Number.isFinite(starsCount)) {
            setCount(starsCount);
            setValue(String(starsCount));
            setCachedValue(starsCount);
          }
        }
      } catch (e) {
        if (isMounted) setError(e);
      } finally {
        if (isMounted) setIsLoading(false);
      }
    }

    fetchStarsCount();
    return () => {
      isMounted = false;
    };
  }, [owner, repo, defaultValue, cachedValue, setCachedValue]);

  return {value, count, isLoading, error};
}


