import { useState, useEffect } from 'react';
import { usePluginData } from '@docusaurus/useGlobalData';

function normalizeDocsPath(path) {
  if (path === '/docs') return '/docs/';
  return path;
}

function isolateHash(pathname) {
  const idx = pathname.indexOf('#');
  return idx === -1 ? { path: pathname, hash: '' } : {
    path: pathname.slice(0, idx),
    hash: pathname.slice(idx),
  };
}

/**
 * Returns { primary, fallback } for markdown URL(s).
 * pathname must not include hash (use location.pathname).
 */
function getMarkdownUrlCandidates(currentPath) {
  const { path } = isolateHash(currentPath);
  const normalizedPath = normalizeDocsPath(path);

  if (normalizedPath === '/docs/' || normalizedPath.startsWith('/docs/')) {
    if (normalizedPath === '/docs/') {
      return { primary: '/docs/intro.md' };
    }
    if (normalizedPath.endsWith('/')) {
      return {
        primary: normalizedPath.slice(0, -1) + '.md',
        fallback: normalizedPath + 'index.md',
      };
    }
    return { primary: normalizedPath + '.md' };
  }

  const cleanPath = normalizedPath.replace(/\/$/, '');
  if (cleanPath) {
    return { primary: cleanPath + '.md' };
  }
  return null;
}

/**
 * Resolves the markdown URL for the current docs path. When path has a trailing
 * slash, performs a HEAD request to choose between single-doc (.md) and category
 * index (index.md).
 * @param {string} pathname - location.pathname (no hash)
 * @returns {{ candidates: object | null, resolvedUrl: string | null, urlReady: boolean, markdownUrl: string | null, markdownContent: string | null }}
 */
export function useResolvedMarkdownUrl(pathname) {
  const [resolvedUrl, setResolvedUrl] = useState(null);
  const candidates = pathname ? getMarkdownUrlCandidates(pathname) : null;
  const allMarkdownContent = usePluginData('markdown-source-plugin');

  useEffect(() => {
    if (!candidates) {
      setResolvedUrl(null);
      return;
    }
    if (!candidates.fallback) {
      setResolvedUrl(candidates.primary);
      return;
    }
    let cancelled = false;
    const { primary, fallback } = candidates;
    fetch(primary, { method: 'HEAD' })
      .then((r) => {
        if (cancelled) return;
        setResolvedUrl(r.ok ? primary : fallback);
      })
      .catch(() => {
        if (!cancelled) setResolvedUrl(fallback);
      });
    return () => { cancelled = true; };
  }, [pathname]);

  const markdownUrl = resolvedUrl ?? candidates?.primary ?? null;
  const urlReady = !candidates?.fallback || resolvedUrl != null;

  const markdownContent =
    candidates?.primary && allMarkdownContent?.[candidates.primary]
      ? allMarkdownContent[candidates.primary]
      : null;

  return { candidates, resolvedUrl, urlReady, markdownUrl, markdownContent };
}
