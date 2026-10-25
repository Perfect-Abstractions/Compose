const colors = ['#aca0ff', '#83b6f4', '#67d5e0', '#8cc7ed', '#6ed8b3', '#e9b76c', '#f28cab', '#be99f0'];
const categoryLabels = { access: 'Access Control', diamond: 'Diamond Core', interfaceDetection: 'Interface Detection', token: 'Tokens' };
// Babylon's noncoplanar constellation anchors preserve recognizable neighborhoods.
const anchors = {
  'access/AccessControl': [-8.689, 6.059, -0.66],
  'access/Owner': [-4.122, 3.062, -0.18],
  'diamond/': [-7.26648, -0.02962, 1.2],
  'interfaceDetection/ERC165': [-0.22698, -3.28612, 1.08],
  'token/ERC20': [1.047, 0.722, -0.12],
  'token/ERC721': [5.827, 0.154, -0.36],
  'token/ERC1155': [6.183, -3.343, 1.44],
  'token/ERC6909': [2.617, -3.173, 0.54],
  'token/Royalty': [0.369, 5.825, -1.44],
};
// Move whole constellations along the viewing axis, independently of their x/y grouping.
const constellationDepths = {
  'access/AccessControl': -3.8,
  'access/Owner': 3.2,
  'diamond/': 5.8,
  'interfaceDetection/ERC165': -4.4,
  'token/ERC20': 1.5,
  'token/ERC721': -5.5,
  'token/ERC1155': 4.4,
  'token/ERC6909': -2.8,
  'token/Royalty': 5.5,
};
const familyColors = { ERC20: '#e9b76c', ERC721: '#be99f0', ERC1155: '#6ed8b3', ERC6909: '#f28cab', Royalty: '#83b6f4' };
const categoryAnchors = { access: [-6.4055, 4.5605, -0.42], token: [3.2086, 0.037, 0.012], interfaceDetection: [-1.65048, -2.02408, 0.66] };

/** Directory membership defines the map. Presets only change emphasis. */
export function libraryGraph(catalog, docs = [], { query = '', preset = '' } = {}) {
  const routes = new Map(docs.map((doc) => [doc.id, doc.path]));
  const facets = catalog.files.filter((file) => file.kind === 'facet');
  const families = [...new Set(facets.map((file) => `${file.category}/${file.family ?? ''}`))];
  const nodes = [];
  const links = [];
  const term = query.trim().toLowerCase();
  for (const [index, familyId] of families.entries()) {
    const members = facets.filter((file) => `${file.category}/${file.family ?? ''}` === familyId);
    const [category, family] = familyId.split('/');
    const phase = index * 2.399963;
    const anchor = anchors[familyId] ?? [Math.cos(phase) * 9, Math.sin(phase) * 6, Math.sin(index * 1.7) * 3];
    const center = anchor.map((value, axis) => value + back[axis] * (constellationDepths[familyId] ?? Math.sin(index * 2.1) * 5));
    const group = { id: familyId, name: family || categoryLabels[category] || category, kind: 'group', color: familyColors[family] ?? colors[index % colors.length], position: center, category, matches: false };
    nodes.push(group);
    members.forEach((file, i) => {
      const angle = i / members.length * Math.PI * 2 + 0.36;
      const radius = members.length === 1 ? 0.68 : 1.1 + (i % 3) * 0.22;
      const matches = (!term || file.path.toLowerCase().includes(term) || file.name.toLowerCase().includes(term))
        && (!preset || file.presets.some((membership) => membership.id === preset));
      const node = { ...file, id: file.path, kind: 'facet', color: group.color, parentId: familyId, matches,
        href: routes.get(`library/${file.path.slice(4, -4)}`),
        position: [center[0] + Math.cos(angle) * radius, center[1] + Math.sin(angle) * radius * 0.79, center[2] + Math.sin(i * 1.7) * (members.length >= 4 ? 1.35 : 0.3)] };
      group.matches ||= matches;
      nodes.push(node);
      links.push({ source: familyId, target: file.path });
    });
  }
  for (const [category, anchor] of Object.entries(categoryAnchors)) {
    const children = nodes.filter((node) => node.kind === 'group' && node.category === category);
    if (!children.length) continue;
    const childAnchor = anchors[children[0].id] ?? children[0].position;
    const position = children.length === 1
      ? anchor.map((value, axis) => value + children[0].position[axis] - childAnchor[axis])
      : [0, 1, 2].map((axis) => children.reduce((sum, node) => sum + node.position[axis], 0) / children.length);
    const id = `category:${category}`;
    nodes.push({ id, name: categoryLabels[category], kind: 'group', level: 'category', category, position, color: category === 'token' ? '#f0c17e' : '#aca0ff', matches: children.some((node) => node.matches) });
    children.forEach((node) => links.push({ source: id, target: node.id }));
  }
  return { nodes, links };
}

const dot = (a, b) => a.reduce((sum, value, i) => sum + value * b[i], 0);
const length = Math.hypot(0.24, -0.38, 1);
const back = [0.24, -0.38, 1].map((value) => value / length);
const horizontal = Math.hypot(back[0], back[2]);
const right = [back[2] / horizontal, 0, -back[0] / horizontal];
const up = [-back[1] * back[0] / horizontal, horizontal, -back[1] * back[2] / horizontal];
const fromView = (point) => [0, 1, 2].map((i) => right[i] * point[0] + up[i] * point[1] + back[i] * point[2]);

/** Retain a readable minimum while making near/far stars visually distinct. */
export function starDepthScale(distance, referenceDistance) {
  return Math.min(1.45, Math.max(0.72, (referenceDistance / Math.max(0.1, distance)) ** 0.65));
}

/** The same oblique camera and portrait rotation drive WebGL and the SVG fallback. */
export function constellationView(nodes, aspect) {
  const view = nodes.map((node) => {
    const p = [dot(node.position, right), dot(node.position, up), dot(node.position, back)];
    return { id: node.id, point: aspect < 1 ? [-p[1], p[0], p[2]] : p };
  });
  const center = [0, 1, 2].map((axis) => {
    const values = view.map(({ point }) => point[axis]);
    return (Math.min(...values) + Math.max(...values)) / 2;
  });
  const tangent = Math.tan(43 * Math.PI / 360);
  const distance = Math.max(12, ...view.map(({ point }) => point[2] - center[2] + Math.max(
    (Math.abs(point[0] - center[0]) + 1.2) / (tangent * aspect * 0.9),
    (Math.abs(point[1] - center[1]) + 1.2) / (tangent * 0.9),
  )));
  return {
    positions: new Map(view.map(({ id, point }) => [id, fromView(point)])),
    target: fromView(center),
    camera: fromView([center[0], center[1], center[2] + distance]),
    projected: new Map(view.map(({ id, point }) => {
      const depth = distance - (point[2] - center[2]);
      return [id, [(point[0] - center[0]) / (depth * tangent * aspect), (point[1] - center[1]) / (depth * tangent)]];
    })),
  };
}
