const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const project = path.resolve(__dirname, '..');

function fixture(t) {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'prism-install-'));
  t.after(() => fs.rmSync(temporary, {recursive: true, force: true}));
  const home = path.join(temporary, 'home');
  const host = path.join(temporary, 'host');
  const bin = path.join(temporary, 'bin');
  const checkout = path.join(temporary, 'checkout');
  fs.cpSync(project, checkout, {recursive: true, filter: source => !source.split(path.sep).includes('.git')});
  fs.mkdirSync(bin, {recursive: true});
  fs.mkdirSync(path.join(host, 'config/omarchy'), {recursive: true});
  const original = {version: 1, bar: {id: 'omarchy.bar', layout: {left: ['clock'], center: [], right: []}}, plugins: ['foreign.plugin'], foreign: {keep: true}};
  fs.writeFileSync(path.join(host, 'config/omarchy/shell.json'), JSON.stringify(original));
  const stub = `#!${process.execPath}
const fs=require('node:fs'),path=require('node:path');
const name=path.basename(process.argv[1]),args=process.argv.slice(2);
const file=path.join(process.env.HOME,'.config/omarchy/shell.json');
if(name==='omarchy-plugin-catalog') {
 console.log(JSON.stringify([{id:'voyagen.prism',kinds:['bar'],barPath:'Bar.qml'},{id:'voyagen.prism.settings',kinds:['bar-widget'],barWidgetPath:'BarWidget.qml'}]));
} else if(name==='omarchy-bar') {
 const source=fs.existsSync(file)&&fs.statSync(file).size?file:path.join(process.env.OMARCHY_PATH,'config/omarchy/shell.json');
 const value=JSON.parse(fs.readFileSync(source)); value.bar.id='voyagen.prism';
 if(process.env.EDIT_UNRELATED) {value.foreign={changed:true};value.plugins.push('new.plugin');}
 fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,JSON.stringify(value));
} else if(args[0]==='voyagen.prism') {
 if(process.env.BAD_HEALTH==='missing') {console.log('Target not found.');process.exit(1);}
 const manifest=JSON.parse(fs.readFileSync(path.join(process.env.HOME,'.config/omarchy/plugins/voyagen.prism/manifest.json')));
 console.log(JSON.stringify({id:manifest.id,version:process.env.BAD_HEALTH==='version'?'wrong':manifest.version,source:process.env.BAD_HEALTH==='source'?'file:///cached-old/Bar.qml':require('node:url').pathToFileURL(path.join(process.env.HOME,'.config/omarchy/plugins/voyagen.prism',manifest.entryPoints.bar)).href,ready:!['not-ready'].includes(process.env.BAD_HEALTH),screenCount:1,recordCount:0}));
} else if(args[1]==='ping') console.log('ok');
else if(args[1]==='rescanPlugins' && process.env.FAIL_RESCAN) process.exit(1);
`;
  for (const name of ['omarchy-shell', 'omarchy-bar', 'omarchy-plugin-catalog']) fs.writeFileSync(path.join(bin, name), stub, {mode: 0o755});
  const env = {...process.env, HOME: home, OMARCHY_PATH: host, PATH: `${bin}:${process.env.PATH}`, PRISM_ACTIVATION_TIMEOUT_MS: '80'};
  const config = path.join(home, '.config/omarchy/shell.json');
  const runtime = path.join(home, '.config/omarchy/plugins/voyagen.prism');
  function run(args, extra = {}) { return spawnSync(process.execPath, [path.join(checkout, 'tools/install.mjs'), ...args], {env: {...env, ...extra}, encoding: 'utf8'}); }
  function ok(result) { assert.equal(result.status, 0, result.stderr); }
  function backup(result) { const match = result.stdout.match(/^Backup: (.+)$/m); assert.ok(match, result.stdout); return match[1]; }
  function put(value) { fs.mkdirSync(path.dirname(config), {recursive: true}); fs.writeFileSync(config, typeof value === 'string' ? value : JSON.stringify(value)); }
  return {home, checkout, config, runtime, original, run, ok, backup, put};
}

test('release upgrade preserves checkout and selection, replacing owned development links', t => {
  const f = fixture(t);
  f.put(f.original);
  f.ok(f.run(['install', '--dev']));
  assert.equal(fs.readlinkSync(f.runtime), f.checkout);
  f.ok(f.run(['install']));
  assert.ok(fs.lstatSync(f.runtime).isDirectory());
  assert.ok(fs.existsSync(path.join(f.checkout, 'Bar.qml')));
  assert.deepEqual(JSON.parse(fs.readFileSync(f.config)),f.original,'install does not select a bar');
});

for (const state of ['absent', 'empty', 'present']) test(`activation and rollback preserve ${state} starting semantics`, t => {
  const f = fixture(t);
  f.ok(f.run(['install']));
  if (state !== 'absent') f.put(state === 'empty' ? '' : f.original);
  const result = f.run(['activate']);
  f.ok(result);
  assert.equal(JSON.parse(fs.readFileSync(f.config)).bar.id, 'voyagen.prism');
  const backup = f.backup(result);
  assert.equal(JSON.parse(fs.readFileSync(backup)).state, state);
  f.ok(f.run(['rollback', backup]));
  if (state === 'absent') assert.equal(fs.existsSync(f.config), false);
  else if (state === 'empty') assert.equal(fs.statSync(f.config).size, 0);
  else assert.deepEqual(JSON.parse(fs.readFileSync(f.config)), f.original);
});

for (const health of ['missing', 'version', 'source', 'not-ready']) test(`health ${health} rolls back selection while preserving unrelated edits`, t => {
  const f = fixture(t);
  f.ok(f.run(['install']));
  f.put(f.original);
  const result = f.run(['activate'], {BAD_HEALTH: health, EDIT_UNRELATED: '1'});
  assert.equal(result.status, 1);
  assert.match(result.stderr, /did not become ready/);
  const current = JSON.parse(fs.readFileSync(f.config));
  assert.deepEqual(current.bar, f.original.bar);
  assert.deepEqual(current.foreign, {changed: true});
  assert.deepEqual(current.plugins, ['foreign.plugin', 'new.plugin']);
});

for (const state of ['absent', 'empty']) test(`failed first-run activation restores ${state} without unrelated changes`, t => {
  const f = fixture(t);
  f.ok(f.run(['install']));
  if (state === 'empty') f.put('');
  const result = f.run(['activate'], {BAD_HEALTH: 'missing'});
  assert.equal(result.status, 1);
  assert.match(result.stderr, /did not become ready/);
  if (state === 'absent') assert.equal(fs.existsSync(f.config), false);
  else assert.equal(fs.statSync(f.config).size, 0);
});

test('first-run failure preserves new unrelated user configuration', t => {
  const f = fixture(t);
  f.ok(f.run(['install']));
  assert.equal(f.run(['activate'], {BAD_HEALTH: 'missing', EDIT_UNRELATED: '1'}).status, 1);
  const current = JSON.parse(fs.readFileSync(f.config));
  assert.deepEqual(current.bar, f.original.bar);
  assert.deepEqual(current.foreign, {changed: true});
});

test('unrelated destination is refused without replacing either plugin', t => {
  const f = fixture(t);
  const foreign = path.join(path.dirname(f.runtime), 'voyagen.prism.settings');
  fs.mkdirSync(foreign, {recursive: true});
  fs.writeFileSync(path.join(foreign, 'keep'), 'user data');
  const result = f.run(['install']);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Refusing unrelated/);
  assert.equal(fs.readFileSync(path.join(foreign, 'keep'), 'utf8'), 'user data');
  assert.equal(fs.existsSync(f.runtime), false);
});

test('failed rescan restores both prior plugin trees and leaves checkout intact', t => {
  const f = fixture(t);
  f.ok(f.run(['install', '--dev']));
  assert.equal(f.run(['install'], {FAIL_RESCAN: '1'}).status, 1);
  assert.equal(fs.readlinkSync(f.runtime), f.checkout);
  assert.equal(fs.readlinkSync(path.join(path.dirname(f.runtime), 'voyagen.prism.settings')), path.join(f.checkout, 'settings'));
  assert.ok(fs.existsSync(path.join(f.checkout, 'Bar.qml')));
});

test('missing installed local dependency fails before changing selection', t => {
  const f = fixture(t);
  f.ok(f.run(['install']));
  f.put(f.original);
  const manifest = JSON.parse(fs.readFileSync(path.join(f.runtime,'manifest.json')));
  fs.unlinkSync(path.join(f.runtime,path.dirname(manifest.entryPoints.bar),'IconAdapter.qml'));
  assert.equal(f.run(['activate']).status, 1);
  assert.deepEqual(JSON.parse(fs.readFileSync(f.config)), f.original);
});
