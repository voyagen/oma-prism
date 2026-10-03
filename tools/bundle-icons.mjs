// Copyright (c) 2026 Oma Prism contributors. See LICENSE.
// Build-time downloads only. The running bar uses these local files without network access.
import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import resolver from '../IconResolver.js';

const project = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const lucideVersion = '0.468.0';
const materialCommit = '6d7ca43bd6e6668531a00fcaca06d921b63dd716';
const menuIcons = ['x','palette','shapes','layout-panel-top','circle-help','layers','panel-top','arrow-up','arrow-down','arrow-left','arrow-right','check','rotate-ccw','plus','trash-2'];
const sources = {
  lucide: {
    version: `lucide-static ${lucideVersion}`,
    icon: stem => `https://unpkg.com/lucide-static@${lucideVersion}/icons/${stem}.svg`,
    license: `https://unpkg.com/lucide-static@${lucideVersion}/LICENSE`,
    licensePattern: /ISC License/,
    stemKey: 'lucide',
  },
  'material-symbols': {
    version: `Google Material Symbols outlined commit ${materialCommit}`,
    icon: stem => `https://raw.githubusercontent.com/google/material-design-icons/${materialCommit}/symbols/web/${stem}/materialsymbolsoutlined/${stem}_24px.svg`,
    license: `https://raw.githubusercontent.com/google/material-design-icons/${materialCommit}/LICENSE`,
    licensePattern: /Apache License[\s\S]*Version 2\.0/,
    stemKey: 'materialSymbols',
  },
};

async function fetchText(url) {
  const response = await fetch(url, {signal: AbortSignal.timeout(30000)});
  if (!response.ok) throw new Error(`${url}: HTTP ${response.status}`);
  const text = await response.text();
  if (!text.trim()) throw new Error(`${url}: empty response`);
  return text;
}

function whiteSvg(text, url, version) {
  const input = text.trim().replace(/^<\?xml[^>]*>\s*/i, '');
  const preamble = input.match(/^(?:<!--[\s\S]*?-->\s*)*/)[0];
  const svg = input.slice(preamble.length);
  if (!/^<svg\b/i.test(svg) || !/<\/svg>\s*$/i.test(svg))
    throw new Error(`${url}: expected a complete SVG`);
  if (/<(?:script|style|foreignObject|image|use)\b/i.test(svg) || /\bon\w+\s*=|\b(?:href|xlink:href)\s*=|url\s*\(/i.test(svg))
    throw new Error(`${url}: unexpected executable, external, or styled SVG content`);
  // No path data, dimensions, stroke widths, opacity, or viewBox is rewritten.
  let result = svg.replace(/\b(fill|stroke|color)\s*=\s*(["'])([^"']*)\2/gi, (attribute, name, quote, value) => {
    if (value.trim().toLowerCase() === 'none') return attribute;
    return `${name}=${quote}#ffffff${quote}`;
  });
  const root = result.match(/^<svg\b[^>]*>/i)[0];
  if (!/\bfill\s*=/.test(root)) result = result.replace(/^<svg\b/i, '<svg fill="#ffffff"');
  if (!/\bviewBox\s*=/.test(root)) {
    const width = /\bwidth=["']([0-9.]+)["']/.exec(root);
    const height = /\bheight=["']([0-9.]+)["']/.exec(root);
    if (!width || !height || !(Number(width[1]) > 0 && Number(height[1]) > 0)) throw new Error(`${url}: missing SVG viewport`);
    result = result.replace(/^<svg\b/i, `<svg viewBox="0 0 ${width[1]} ${height[1]}"`);
  }
  return `<!-- ${version}; source: ${url}\nModified by Oma Prism: explicit white fill/stroke colors for alpha-preserving tint; original geometry retained. SVGs lacking viewBox use their original numeric width/height as the viewport. -->\n${preamble}${result}\n`;
}

function batteryVariant(svg, pack, semantic) {
  const match = /^battery-(charging-)?level-([0-9])$/.exec(semantic);
  if (!match) return svg;
  const charging = !!match[1];
  const fraction = Number(match[2]) / 9;
  let fills = '';
  const rect = (x,y,width,height) => `<rect x="${x}" y="${y}" width="${width}" height="${height}" fill="#ffffff" stroke="none"/>`;
  if (fraction > 0) {
    if (pack === 'lucide') {
      fills = charging ? rect(4,9,3*fraction,6)+rect(14,9,2*fraction,6) : rect(4,9,12*fraction,6);
    } else {
      fills = rect(360,-160-560*fraction,charging ? 80 : 240,560*fraction);
    }
  }
  return svg.replace('</svg>', `<!-- Modified by Oma Prism: static level ${match[2]} of 9; source frame/bolt retained. -->${fills}</svg>`);
}

async function bundle() {
  const entries = resolver.catalogueEntries();
  const outputs = [];
  // Finish all fetches/validation before writing so HTTP failures cannot leave placeholder assets.
  for (const pack of resolver.packs) {
    const source = sources[pack];
    const license = await fetchText(source.license);
    if (!source.licensePattern.test(license)) throw new Error(`${source.license}: unexpected license text`);
    if (pack === 'lucide' && !/Feather/i.test(license))
      throw new Error(`${source.license}: required Feather attribution is missing`);
    outputs.push({
      relative: `assets/icons/${pack}/LICENSE.txt`,
      text: `${source.version}\nLicense source: ${source.license}\nAssets are monochrome derivatives. Battery variants add static interior level fills; upstream frame/bolt geometry and viewBoxes are retained.\n\n${license.trim()}\n`,
    });
    const fetched = new Map();
    for (const entry of entries) {
      const stem = entry[source.stemKey];
      if (typeof stem !== 'string' || !/^[a-z0-9_-]+$/.test(stem))
        throw new Error(`${pack}/${entry.semantic}: invalid upstream SVG stem`);
      const url = source.icon(stem);
      if (!fetched.has(stem)) fetched.set(stem, whiteSvg(await fetchText(url), url, source.version));
      outputs.push({relative: `assets/icons/${pack}/${entry.semantic}.svg`, text: batteryVariant(fetched.get(stem),pack,entry.semantic)});
    }
    if (pack === 'lucide') for (const stem of menuIcons) {
      const url = source.icon(stem);
      if (!fetched.has(stem)) fetched.set(stem,whiteSvg(await fetchText(url),url,source.version));
      outputs.push({relative:`assets/menu/${stem}.svg`,text:fetched.get(stem)});
    }
  }
  const expected = resolver.expectedSources();
  const bundled = new Set(outputs.filter(output => output.relative.startsWith('assets/icons/') && output.relative.endsWith('.svg')).map(output => output.relative));
  if (bundled.size !== expected.length || expected.some(relative => !bundled.has(relative)))
    throw new Error('Catalogue asset paths and bundled outputs do not match');
  for (const output of outputs) {
    const target = path.join(project, output.relative);
    await fs.mkdir(path.dirname(target), {recursive: true});
    await fs.writeFile(target, output.text, 'utf8');
  }
  console.log(`Bundled ${expected.length} catalogue SVG assets in both pinned packs and ${menuIcons.length} Lucide menu SVGs, with upstream licenses.`);
}

try {
  await bundle();
} catch (error) {
  console.error(`Icon bundling failed: ${error.message}`);
  process.exitCode = 1;
}
