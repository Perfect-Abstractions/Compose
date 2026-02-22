import { useState, useEffect } from 'react';

/** Normalize path so /docs is treated as /docs/ for URL building. */
function normalizeDocsPath(path) {
  if (path === '/docs') return '/docs/';
  return path;
}

/**
 * Returns { primary, fallback } for markdown URL(s).
 * pathname must not include hash (use location.pathname).
 */
function getMarkdownUrlCandidates(currentPath) {
  const path = normalizeDocsPath(currentPath);
  if (path !== '/docs/' && !path.startsWith('/docs/')) return null;
  if (path === '/docs/') {
    return { primary: `${path}intro.md` };
  }
  if (path.endsWith('/')) {
    return {
      primary: path.slice(0, -1) + '.md',
      fallback: path + 'index.md',
    };
  }
  return { primary: path + '.md' };
}

/**
 * Resolves the markdown URL for the current docs path. When path has a trailing
 * slash, performs a HEAD request to choose between single-doc (.md) and category
 * index (index.md).
 * @param {string} pathname - location.pathname (no hash)
 * @returns {{ candidates: object | null, resolvedUrl: string | null, urlReady: boolean, markdownUrl: string | null }}
 */
export function useResolvedMarkdownUrl(pathname) {
  const [resolvedUrl, setResolvedUrl] = useState(null);
  const candidates = pathname ? getMarkdownUrlCandidates(pathname) : null;

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

  return { candidates, resolvedUrl, urlReady, markdownUrl };
}
