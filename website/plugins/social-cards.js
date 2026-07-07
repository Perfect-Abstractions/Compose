const path = require('path');
const fs = require('fs-extra');
const { parse, HTMLElement } = require('node-html-parser');
const sharp = require('sharp');
const objectHash = require('object-hash');
const { docs: docsRenderer, blog: blogRenderer } = require('../lib/ImageRenderers.js');

const WIDTH = 1200;
const HEIGHT = 630;

const IMAGE_META_ELEMENTS = [
  ['name', 'image'],
  ['property', 'og:image'],
  ['name', 'twitter:image'],
];

class ImageGenerator {
  constructor(outDir, websiteUrl) {
    this.outDir = path.join(outDir, 'preview-images');
    this.websiteUrl = websiteUrl;
    this.cache = {};
    this.satori = null;
  }

  async init() {
    await fs.ensureDir(this.outDir);
    this.satori = (await import('satori')).default;
  }

  async generate(element, options) {
    const hash = objectHash([element, options]);
    if (this.cache[hash]) return this.cache[hash];

    const imageName = `${hash}.png`;
    const absolutePath = path.join(this.outDir, imageName);
    const relativePath = `/preview-images/${imageName}`;

    const svg = await this.satori(element, options);
    await sharp(Buffer.from(svg)).png().toFile(absolutePath);

    const url = new URL(this.websiteUrl);
    url.pathname = relativePath;

    this.cache[hash] = {
      relativePath,
      absolutePath,
      url: url.toString(),
    };

    return this.cache[hash];
  }
}

class Document {
  constructor(filePath) {
    this.path = filePath;
    this.loaded = false;
  }

  async load() {
    const htmlString = await fs.readFile(this.path, 'utf-8');
    this.root = parse(htmlString);
    this.loaded = true;
  }

  async write() {
    await fs.writeFile(this.path, Buffer.from(this.root.outerHTML));
  }

  async setImage(url) {
    IMAGE_META_ELEMENTS.forEach(([attr, value]) => this.updateMeta(attr, value, { content: url }));
  }

  get head() {
    return this.root.querySelector('head');
  }

  getMeta(attr, value) {
    const { head } = this;
    let meta = head.querySelector(`meta[${attr}=${value}]`);
    if (!meta) {
      meta = new HTMLElement('meta', {}, '', undefined, [0, 0]);
      meta.setAttribute(attr, value);
      head.appendChild(meta);
    }
    return meta;
  }

  updateMeta(attr, value, attrs) {
    const el = this.getMeta(attr, value);
    Object.entries(attrs).forEach(([key, val]) => el.setAttribute(key, val));
    return el;
  }
}

module.exports = function socialCardsPlugin(context, options) {
  return {
    name: 'social-cards',

    async postBuild({ outDir, siteConfig, plugins }) {
      console.log('[social-cards] Generating OG images...');

      const generator = new ImageGenerator(outDir, siteConfig.url);
      await generator.init();

      const fontPath = path.join(
        __dirname,
        '../../node_modules/@fontsource/ibm-plex-sans/files/ibm-plex-sans-latin-400-normal.woff'
      );
      const fontData = await fs.readFile(fontPath);

      const fontConfig = [
        {
          name: 'IBM Plex Sans',
          data: fontData,
          weight: 400,
          style: 'normal',
        },
      ];

      const imageOptions = {
        width: WIDTH,
        height: HEIGHT,
        fonts: fontConfig,
      };

      let generatedCount = 0;

      const docPlugins = plugins.filter((p) => p.name === 'docusaurus-plugin-content-docs');
      for (const plugin of docPlugins) {
        if (!plugin.content || !plugin.content.loadedVersions) continue;

        for (const version of plugin.content.loadedVersions) {
          for (const doc of version.docs) {
            if (!doc.permalink) continue;

            const htmlPath = path.join(outDir, doc.permalink, 'index.html');
            if (!(await fs.pathExists(htmlPath))) continue;

            const document = new Document(htmlPath);
            await document.load();

            const renderData = {
              metadata: doc,
              version,
              plugin: plugin.options,
              document,
              websiteOutDir: outDir,
            };

            const [element, opts] = docsRenderer(renderData, context);
            const generated = await generator.generate(element, { ...imageOptions, ...opts });

            await document.setImage(generated.url);
            await document.write();
            generatedCount++;
          }
        }
      }

      const blogPlugins = plugins.filter((p) => p.name === 'docusaurus-plugin-content-blog');
      for (const plugin of blogPlugins) {
        if (!plugin.content || !plugin.content.blogPosts) continue;

        for (const post of plugin.content.blogPosts) {
          if (!post.metadata || !post.metadata.permalink) continue;

          const htmlPath = path.join(outDir, post.metadata.permalink, 'index.html');
          if (!(await fs.pathExists(htmlPath))) continue;

          const document = new Document(htmlPath);
          await document.load();

          const renderData = {
            data: post,
            plugin: plugin.options,
            pageType: 'post',
            permalink: post.metadata.permalink,
            document,
            websiteOutDir: outDir,
          };

          const [element, opts] = blogRenderer(renderData, context);
          const generated = await generator.generate(element, { ...imageOptions, ...opts });

          await document.setImage(generated.url);
          await document.write();
          generatedCount++;
        }
      }

      console.log(`[social-cards] Generated ${generatedCount} OG images`);
    },
  };
};
