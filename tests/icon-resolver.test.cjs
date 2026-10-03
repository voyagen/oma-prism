const test = require('node:test');
const assert = require('node:assert/strict');
const {resolve, validateOverridePath, expectedSources} = require('../IconResolver.js');

// Independent expected glyph data: do not derive test expectations from the resolver catalogue.
const audio = [
  ['', 'volume-muted'],
  ['󰋋', 'headphones'],
  ['', 'volume-low'],
  ['', 'volume-medium'],
  ['', 'volume-high'],
];

for (const pack of ['lucide', 'material-symbols']) {
  test(`${pack} resolves each exact audio glyph without altering its context`, () => {
    for (const [glyph, semantic] of audio) {
      assert.deepEqual(resolve('omarchy.audio', glyph, {iconPack: pack}), {
        semantic, prefix: '', source: `assets/icons/${pack}/${semantic}.svg`, origin: 'pack', reason: '',
      });
      const foreign = resolve('third.party', glyph, {iconPack: pack});
      assert.equal(foreign.source, '');
      assert.equal(foreign.origin, 'original');
      assert.equal(foreign.semantic, '');
      assert.match(foreign.reason, /third\.party/);
    }
  });
}

test('every acceptance glyph resolves contextually in both packs with a bundled source', () => {
  const cases = require('./catalogue-cases.cjs');
  const fs = require('node:fs');
  const path = require('node:path');
  const expected = [];
  for (const pack of ['lucide','material-symbols']) {
    for (const [context,rows] of Object.entries(cases)) {
      for (const [glyph,semantic] of rows) {
        const source = `assets/icons/${pack}/${semantic}.svg`;
        assert.deepEqual(resolve(context,glyph,{iconPack:pack}),{semantic,prefix:'',source,origin:'pack',reason:''});
        assert.match(fs.readFileSync(path.join(__dirname,'..',source),'utf8'), /<svg\b/);
        expected.push(source);
      }
    }
  }
  assert.deepEqual(expectedSources().sort(),expected.sort());
});

test('widget/glyph override wins over semantic override and selected pack', () => {
  const settings = {
    iconPack: 'material-symbols',
    semanticOverrides: {'volume-high': '/icons/semantic.svg'},
    widgetOverrides: {'omarchy.audio': {'': '~/icons/widget.svg'}},
  };
  assert.deepEqual(resolve('omarchy.audio', '', settings), {
    semantic: 'volume-high', prefix: '', source: '~/icons/widget.svg', origin: 'widget-override', reason: '',
  });
  delete settings.widgetOverrides['omarchy.audio'][''];
  assert.equal(resolve('omarchy.audio', '', settings).source, '/icons/semantic.svg');
  assert.equal(resolve('omarchy.audio', '', settings).origin, 'semantic-override');
  delete settings.semanticOverrides['volume-high'];
  assert.equal(resolve('omarchy.audio', '', settings).origin, 'pack');
});

test('valid explicit overrides cover unknown complete glyphs in exact contexts', () => {
  const glyph = '🎧 + custom';
  const settings = {widgetOverrides: {'third.party': {[glyph]: '/custom/audio.svg'}}};
  assert.deepEqual(resolve('third.party', glyph, settings), {
    semantic: '', prefix: '', source: '/custom/audio.svg', origin: 'widget-override', reason: '',
  });
  assert.equal(resolve('omarchy.audio', glyph, settings).origin, 'original');
});

test('invalid high-priority overrides retain the original instead of falling through', () => {
  const settings = {
    iconPack: 'lucide',
    semanticOverrides: {'volume-high': '/valid/semantic.svg'},
    widgetOverrides: {'omarchy.audio': {'': 'https://icons.example/high.svg'}},
  };
  let result = resolve('omarchy.audio', '', settings);
  assert.equal(result.source, '');
  assert.equal(result.origin, 'original');
  assert.equal(result.semantic, 'volume-high');
  assert.match(result.reason, /https:\/\/icons\.example\/high\.svg/);
  settings.widgetOverrides['omarchy.audio'][''] = '';
  settings.semanticOverrides['volume-high'] = '/icons/not-svg.png';
  result = resolve('omarchy.audio', '', settings);
  assert.equal(result.origin, 'original');
  assert.equal(result.source, '');
  assert.match(result.reason, /not-svg\.png/);
});

test('empty override drafts remove only their precedence tier', () => {
  const settings = {
    semanticOverrides: {'volume-high': '/semantic/high.svg'},
    widgetOverrides: {'omarchy.audio': {'': '   '}},
  };
  assert.equal(resolve('omarchy.audio', '', settings).source, '/semantic/high.svg');
  settings.semanticOverrides['volume-high'] = '';
  assert.equal(resolve('omarchy.audio', '', settings).origin, 'pack');
});

test('local SVG syntax is validated without claiming filesystem readability', () => {
  for (const value of ['/not-created/missing.svg', '~/some icon.SVG', '/icons/with # ? and spaces.svg']) {
    assert.deepEqual(validateOverridePath(value), {valid: true, value, error: ''});
  }
  for (const value of ['', ' \n ']) {
    assert.deepEqual(validateOverridePath(value), {valid: true, value: '', error: ''});
  }
  for (const value of ['https://example.com/icon.svg', 'file:///tmp/icon.svg', '//server/icon.svg', 'icons/icon.svg', '~other/icon.svg', '/icons/icon.png', '/icons/icon.svg?x=1', '/icons/\u0000.svg', '/icons/\n.svg', null, 42, false]) {
    const checked = validateOverridePath(value);
    assert.equal(checked.valid, false, JSON.stringify(value));
    assert.ok(checked.error.includes('SVG') || checked.error.includes('path'), JSON.stringify(value));
  }
  const result = resolve('omarchy.audio', '', {semanticOverrides: {'volume-high': '/not-created/missing.svg'}});
  assert.equal(result.source, '/not-created/missing.svg');
  assert.equal(result.reason, ''); // The persistent QML probe, not this pure module, checks readability.
});

test('empty text is absent even when settings contain invalid overrides', () => {
  assert.deepEqual(resolve('omarchy.audio', '', {widgetOverrides: null, iconPack: 'invalid'}), {
    semantic: '', prefix: '', source: '', origin: 'original', reason: '',
  });
});

test('whole Unicode scalars and composites are never sliced or guessed', () => {
  for (const text of ['󰋋 extra', '', '🎧', '󰋋\u0301', '45% ', '\uDB80', '\uDECB']) {
    const result = resolve('omarchy.audio', text, {});
    assert.equal(result.source, '', JSON.stringify(text));
    assert.equal(result.semantic, '');
    assert.equal(result.prefix, '');
    assert.equal(result.origin, 'original');
    assert.match(result.reason, /complete glyph/);
  }
  assert.equal(resolve('omarchy.audio', '󰋋', {}).semantic, 'headphones');
});

test('inherited dictionary properties cannot provide overrides', () => {
  const glyphs = Object.create({'': '/inherited/widget.svg'});
  const semantics = Object.create({'volume-high': '/inherited/semantic.svg'});
  assert.equal(resolve('omarchy.audio', '', {
    widgetOverrides: {'omarchy.audio': glyphs}, semanticOverrides: semantics,
  }).origin, 'pack');
  assert.equal(resolve('omarchy.audio', '', {
    widgetOverrides: Object.create({'omarchy.audio': {'': '/inherited/context.svg'}}),
  }).origin, 'pack');
  assert.equal(resolve('omarchy.audio', '', Object.create({iconPack: 'material-symbols'})).source,
    'assets/icons/lucide/volume-high.svg');
  const nullPrototypeGlyphs = Object.create(null);
  nullPrototypeGlyphs[''] = '/own/icon.svg';
  assert.equal(resolve('omarchy.audio', '', {widgetOverrides: {'omarchy.audio': nullPrototypeGlyphs}}).source,
    '/own/icon.svg');
});

test('prototype-looking unknown contexts and glyphs are ordinary own keys', () => {
  const overrides = JSON.parse('{"__proto__":{"constructor":"/own/prototype.svg"}}');
  assert.equal(resolve('__proto__', 'constructor', {widgetOverrides: overrides}).source, '/own/prototype.svg');
  assert.equal(resolve('__proto__', 'constructor', {widgetOverrides: {}}).origin, 'original');
});

test('malformed relevant dictionaries and unknown packs diagnose rather than throw or guess', () => {
  for (const settings of [
    {widgetOverrides: null},
    {widgetOverrides: []},
    {widgetOverrides: {'omarchy.audio': '/not-a-map.svg'}},
    {widgetOverrides: {'omarchy.audio': {'': 12}}},
    {semanticOverrides: []},
    {semanticOverrides: {'volume-high': null}},
    {iconPack: 'material'},
  ]) {
    const result = resolve('omarchy.audio', '', settings);
    assert.equal(result.origin, 'original');
    assert.equal(result.source, '');
    assert.notEqual(result.reason, '');
  }
  assert.match(resolve('omarchy.audio', 12, {}).reason, /Unicode string/);
  assert.match(resolve(null, '', {}).reason, /widget ID/);
});

test('power percentage preserves the whole prefix only for exact mapped power glyphs', () => {
  const result = resolve('omarchy.power','100% 󰂅',{});
  assert.equal(result.prefix,'100% ');
  assert.equal(result.semantic,'battery-charging-level-9');
  assert.equal(result.origin,'pack');
  assert.equal(resolve('omarchy.audio','100% 󰂅',{}).origin,'original');
  for (const text of ['1000% 󰂅','45% unknown','45%󰂅','45.5% 󰂅','45% 󰂅 extra'])
    assert.equal(resolve('omarchy.power',text,{}).origin,'original',text);
  const override = resolve('omarchy.power','45% 󰂅',{widgetOverrides:{'omarchy.power':{'󰂅':'/tmp/custom.svg'}}});
  assert.equal(override.prefix,'45% ');
  assert.equal(override.source,'/tmp/custom.svg');
  assert.equal(resolve('omarchy.power','45% unknown',{widgetOverrides:{'omarchy.power':{unknown:'/tmp/custom.svg'}}}).origin,'original');
  assert.equal(resolve('omarchy.power','45% unknown',{widgetOverrides:{'omarchy.power':{'45% unknown':'/tmp/whole.svg'}}}).source,'/tmp/whole.svg');
});
