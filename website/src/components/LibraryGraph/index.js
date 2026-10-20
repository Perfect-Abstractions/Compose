import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAllDocsData } from '@docusaurus/plugin-content-docs/client';
import { useColorMode } from '@docusaurus/theme-common';
import catalog from '@site/src/data/libraryCatalog.json';
import Icon from '../ui/Icon';
import { libraryGraph, constellationView } from './model.mjs';
import styles from './styles.module.css';

function FlatGraph({ data, onNode, selected }) {
  const svg = useRef(null);
  const [size, setSize] = useState({ width: 1000, height: 500 });
  useEffect(() => {
    const observer = new ResizeObserver(([entry]) => {
      if (entry.contentRect.width && entry.contentRect.height) setSize({ width: entry.contentRect.width, height: entry.contentRect.height });
    });
    observer.observe(svg.current);
    return () => observer.disconnect();
  }, []);
  const byId = new Map(data.nodes.map((node) => [node.id, node]));
  const view = constellationView(data.nodes, size.width / size.height);
  const point = (node) => {
    const [x, y] = view.projected.get(node.id);
    return [(x + 1) / 2 * size.width, (1 - y) / 2 * size.height];
  };
  const labelPositions = new Map();
  const placed = [];
  for (const node of data.nodes.filter((item) => item.kind === 'group')) {
    const [anchorX, anchorY] = point(node);
    const width = node.name.length * (node.level === 'category' ? 6.3 : 7.5) + 10;
    const x = Math.max(width / 2 + 6, Math.min(size.width - width / 2 - 6, anchorX));
    for (const offset of [node.level === 'category' ? 22 : -13, -30, 35, -48, 53]) {
      const y = anchorY + offset;
      if (y < 20 || y > size.height - 6 || placed.some((rect) => x + width / 2 > rect.left && x - width / 2 < rect.right && y > rect.top && y - 18 < rect.bottom)) continue;
      labelPositions.set(node.id, [x, y]);
      placed.push({ left: x - width / 2 - 3, right: x + width / 2 + 3, top: y - 21, bottom: y + 3 });
      break;
    }
  }
  return <svg ref={svg} className={styles.flat} viewBox={`0 0 ${size.width} ${size.height}`} role="group" aria-label="Compose library 2D graph">
    {Array.from({ length: 130 }, (_, i) => <circle key={`sky-${i}`} cx={(i * 193 % 997) / 997 * size.width} cy={(i * 127 % 991) / 991 * size.height} r={i % 5 === 0 ? 0.8 : 0.5} fill="#a6bad4" opacity="0.35" />)}
    {data.links.map((edge) => {
      const [x1, y1] = point(byId.get(edge.source)), [x2, y2] = point(byId.get(edge.target));
      const node = byId.get(edge.target);
      return <line key={`${edge.source}:${edge.target}`} x1={x1} y1={y1} x2={x2} y2={y2} stroke={node.color} opacity={node.matches ? 0.3 : 0.06} />;
    })}
    {data.nodes.map((node) => {
      const [x, y] = point(node);
      const content = <>
        <circle cx={x} cy={y} r="7" fill={node.color} opacity="0.09" />
        <circle cx={x} cy={y} r={node.kind === 'group' ? 2.8 : 2.1} fill={node.color} stroke={selected?.id === node.id ? 'currentColor' : 'none'} strokeWidth="2" />
        <circle cx={x} cy={y} r="13" fill="transparent" />
        {labelPositions.has(node.id) && <text x={labelPositions.get(node.id)[0]} y={labelPositions.get(node.id)[1]} textAnchor="middle" fill={node.color} fontSize={node.level === 'category' ? 11 : 13}>{node.name}</text>}
        <title>{node.name}</title>
      </>;
      return <g key={node.id} opacity={node.matches ? 1 : 0.25} role="button" tabIndex={0}
        aria-label={node.href ? `Open ${node.name} documentation in a new tab` : node.name}
        onClick={() => onNode(node)} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onNode(node); } }}>{content}</g>;
    })}
  </svg>;
}

export default function LibraryGraph() {
  const allDocs = useAllDocsData();
  const { colorMode } = useColorMode();
  const docs = allDocs.default?.versions[0]?.docs ?? [];
  const [query, setQuery] = useState('');
  const [preset, setPreset] = useState('');
  const [failed, setFailed] = useState(false);
  const [selected, setSelected] = useState();
  const [hovered, setHovered] = useState();
  const [browse, setBrowse] = useState(false);
  const data = useMemo(() => libraryGraph(catalog, docs, { query, preset }), [docs, query, preset]);
  const facets = data.nodes.filter((node) => node.kind === 'facet');
  const matching = facets.filter((node) => node.matches);
  const host = useRef(null);
  const scene = useRef(null);
  const onNode = useCallback((node) => {
    if (node.kind === 'group') { setQuery(node.level === 'category' || node.category === 'diamond' ? node.category : node.name); return; }
    setSelected(node);
    if (node.href) window.open(node.href, '_blank', 'noopener,noreferrer');
  }, []);
  const flat = failed;
  useEffect(() => {
    if (flat) return undefined;
    let cancelled = false;
    import('./scene').then(({ createLibraryScene }) => {
      if (cancelled || !host.current) return;
      try {
        scene.current = createLibraryScene(host.current, data, { onNode, onHover: setHovered, onError: () => setFailed(true), dark: colorMode === 'dark' });
      } catch { setFailed(true); }
    }).catch(() => { if (!cancelled) setFailed(true); });
    return () => { cancelled = true; scene.current?.dispose(); scene.current = null; };
  }, [flat, data, colorMode, onNode]);
  useEffect(() => { scene.current?.select(selected?.id); }, [selected]);
  const reset = () => { setQuery(''); setPreset(''); setSelected(undefined); setHovered(undefined); scene.current?.reset(); };
  const detail = hovered?.kind === 'facet' ? hovered : selected;
  return <section className={styles.explorer} aria-label="Library explorer">
    <div className={styles.heading}><h2>Library map</h2><span>{facets.length} facets</span></div>
    <div className={styles.toolbar}>
      <input type="search" aria-label="Search facets" placeholder="Search facets" value={query} onChange={(event) => setQuery(event.target.value)} />
      <select aria-label="CLI preset" value={preset} onChange={(event) => setPreset(event.target.value)}><option value="">All presets</option>{catalog.presets.map((item) => <option key={item.id} value={item.id}>{item.definition.label}</option>)}</select>
      <button type="button" className={styles.iconButton} title="Reset graph" aria-label="Reset graph" onClick={reset}><Icon name="cycle" size={18} /></button>
    </div>
    <div className={styles.viewport}>
      {flat ? <FlatGraph data={data} onNode={onNode} selected={selected} /> : <div ref={host} className={styles.scene} />}
      <div className={styles.detail} aria-live="polite">{detail ? <><strong>{detail.name}</strong>{detail.href ? <a href={detail.href} target="_blank" rel="noopener noreferrer">Documentation <Icon name="arrow-up-right" size={14} /></a> : <span>Documentation pending</span>}</> : <span>{matching.length} matching facets · {facets.filter((node) => node.href).length} documented</span>}</div>
    </div>
    <div className={styles.footer}><span>Family / facet</span><button type="button" aria-expanded={browse} onClick={() => setBrowse(!browse)}>Facet list ({matching.length}) <Icon name="chevron-down" size={12} /></button></div>
    {browse && <ul className={styles.list}>{matching.map((node) => <li key={node.id}><span className={styles.dot} style={{ background: node.color }} />{node.href ? <a href={node.href} target="_blank" rel="noopener noreferrer"><span className={styles.facetName}>{node.name}</span><Icon name="arrow-up-right" size={13} /></a> : <button type="button" onClick={() => setSelected(node)}><span className={styles.facetName}>{node.name}</span><span className={styles.facetStatus}>Docs pending</span></button>}</li>)}{matching.length === 0 && <li>No matching facets</li>}</ul>}
  </section>;
}
