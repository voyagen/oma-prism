import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {setTimeout as sleep} from 'node:timers/promises';
import resolver from '../IconResolver.js';
import {isDeepStrictEqual} from 'node:util';
import {createHash} from 'node:crypto';

const project = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const home = os.homedir();
const configPath = path.join(home, '.config/omarchy/shell.json');
const pluginDirectory = path.join(home, '.config/omarchy/plugins');
const targets = [['voyagen.prism', project], ['voyagen.prism.settings', path.join(project, 'settings')]];
const marker = '.oma-prism-install.json';
const required = ['Bar.qml', 'BarSurface.qml', 'AxisRail.qml', 'ModuleSlot.qml', 'CustomCommandModule.qml', 'Settings.qml', 'IconAdapter.qml', 'InteractionMotion.qml', 'StatePill.qml', 'BarModel.js', 'SettingsModel.js', 'IconResolver.js', 'shared/SvgIcon.qml', 'shared/AnimatedIcon.qml', 'shared/prism.svg', 'LICENSE'];
const plain = value => value !== null && typeof value === 'object' && !Array.isArray(value);
function command(program, args, required = true, timeout = 5000) {
  const result = spawnSync(program, args, {encoding: 'utf8', timeout, killSignal: 'SIGKILL'});
  if (required && (result.error || result.status !== 0)) throw new Error(`${program}: ${result.error?.message || result.stderr || result.stdout}`);
  return result;
}
function parseConfig(bytes, file) {
  const value = JSON.parse(bytes);
  if (!plain(value) || value.version !== 1 || ('bar' in value && !plain(value.bar))) throw new Error(`${file}: expected version-1 JSON object with an object bar subtree`);
  return value;
}
function snapshot() {
  let bytes;
  try { bytes = fs.readFileSync(configPath); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  const state = bytes === undefined ? 'absent' : bytes.length === 0 ? 'empty' : 'present';
  const source = state === 'present' ? configPath : path.join(process.env.OMARCHY_PATH || '/usr/share/omarchy', 'config/omarchy/shell.json');
  return {schemaVersion: 1, state, mode: bytes === undefined ? 0o600 : fs.statSync(configPath).mode & 0o777, bytes: bytes?.toString('base64') ?? null, effective: parseConfig(state === 'present' ? bytes : fs.readFileSync(source), source)};
}
function validateProject(root = project) {
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
  const entry = manifest.entryPoints?.bar;
  if (manifest.schemaVersion !== 1 || manifest.id !== 'voyagen.prism' || !manifest.kinds?.includes('bar') || typeof entry !== 'string' || !/^(runtime-[a-f0-9]{64}\/)?Bar\.qml$/.test(entry) || typeof manifest.version !== 'string') throw new Error('Invalid Prism manifest');
  root = path.join(root, path.dirname(entry));
  for (const relative of required) fs.accessSync(path.join(root, relative), fs.constants.R_OK);
  for (const relative of resolver.expectedSources()) {
    const asset = fs.readFileSync(path.join(root, relative), 'utf8');
    if (!/<svg\b/.test(asset) || !/<\/svg>\s*$/.test(asset)) throw new Error(`Missing or malformed catalogue SVG: ${relative}`);
  }
  for (const name of ['x', 'palette', 'shapes', 'layout-panel-top', 'circle-help', 'layers', 'panel-top', 'arrow-up', 'arrow-down', 'arrow-left', 'arrow-right', 'check', 'rotate-ccw', 'plus', 'trash-2']) {
    const asset = fs.readFileSync(path.join(root, 'assets/menu', `${name}.svg`), 'utf8');
    if (!/<svg\b/.test(asset) || !/<\/svg>\s*$/.test(asset)) throw new Error(`Missing or malformed menu SVG: ${name}`);
  }
  return manifest;
}
function validateWidget(root) {
  const widget = JSON.parse(fs.readFileSync(path.join(root, 'manifest.json'), 'utf8'));
  const entry = widget.entryPoints?.barWidget;
  if (widget.schemaVersion !== 1 || widget.id !== 'voyagen.prism.settings' || !widget.kinds?.includes('bar-widget') || typeof entry !== 'string' || !/^(runtime-[a-f0-9]{64}\/)?BarWidget\.qml$/.test(entry)) throw new Error('Invalid Prism settings widget manifest');
  root = path.join(root, path.dirname(entry));
  for (const file of ['BarWidget.qml', 'shared/SvgIcon.qml', 'shared/prism.svg']) fs.accessSync(path.join(root, file), fs.constants.R_OK);
}
function reachable() {
  const result = command('omarchy-shell', ['shell', 'ping'], false);
  return result.status === 0 && result.stdout.trim() === 'ok';
}
function atomicWrite(file, bytes, mode) {
  fs.mkdirSync(path.dirname(file), {recursive: true});
  const temporary = `${file}.${process.pid}.${Date.now()}.tmp`;
  let fd;
  try {
    fd = fs.openSync(temporary, 'wx', mode);
    fs.fchmodSync(fd, mode);
    fs.writeFileSync(fd, bytes);
    fs.fsyncSync(fd);
    fs.closeSync(fd); fd = undefined;
    fs.renameSync(temporary, file);
  } finally {
    if (fd !== undefined) fs.closeSync(fd);
    fs.rmSync(temporary, {force: true});
  }
}
function withoutBar(value) {
  const result = {...value};
  delete result.bar;
  return result;
}
function restore(backup) {
  const saved = JSON.parse(fs.readFileSync(backup, 'utf8'));
  if (saved.schemaVersion !== 1 || !['absent', 'empty', 'present'].includes(saved.state) || !plain(saved.effective) || saved.effective.version !== 1 || !Number.isInteger(saved.mode)) throw new Error('Invalid Prism backup metadata');
  const current = snapshot().effective;
  if (saved.state !== 'present' && isDeepStrictEqual(withoutBar(current), withoutBar(saved.effective))) {
    if (saved.state === 'absent') fs.rmSync(configPath, {force: true});
    else atomicWrite(configPath, Buffer.alloc(0), saved.mode);
  } else {
    if (Object.hasOwn(saved.effective, 'bar')) current.bar = saved.effective.bar;
    else delete current.bar;
    atomicWrite(configPath, JSON.stringify(current, null, 2) + '\n', saved.mode);
  }
  command('omarchy-shell', ['shell', 'reloadConfig']);
  console.log(`Restored bar subtree from ${backup}`);
}
function owned(destination, source, id) {
  let stat;
  try { stat = fs.lstatSync(destination); } catch (error) { if (error.code === 'ENOENT') return false; throw error; }
  if (stat.isSymbolicLink() && path.resolve(path.dirname(destination), fs.readlinkSync(destination)) === source) return true;
  if (stat.isDirectory()) {
    try {
      const metadata = JSON.parse(fs.readFileSync(path.join(destination, marker), 'utf8'));
      const manifest = JSON.parse(fs.readFileSync(path.join(destination, 'manifest.json'), 'utf8'));
      if (metadata.owner === 'oma-prism' && metadata.id === id && metadata.schemaVersion === 1 && manifest.id === id) return true;
    } catch { /* An unmarked directory is not ours to replace. */ }
  }
  throw new Error(`Refusing unrelated existing path: ${destination}`);
}
function runtimeDigest(root, manifest) {
  const hash = createHash('sha256').update(JSON.stringify(manifest));
  function visit(directory, prefix) {
    for (const entry of fs.readdirSync(directory, {withFileTypes:true}).sort((a,b) => a.name.localeCompare(b.name))) {
      const file = path.join(directory, entry.name), relative = prefix + entry.name;
      if (entry.isDirectory()) visit(file, relative + '/');
      else {
        const bytes = fs.readFileSync(file);
        hash.update(relative + '\0' + bytes.length + '\0').update(bytes);
      }
    }
  }
  visit(root, '');
  return hash.digest('hex');
}
function install(dev) {
  validateProject();
  validateWidget(path.join(project, 'settings'));
  fs.mkdirSync(pluginDirectory, {recursive: true});
  const existing = targets.map(([id, source]) => owned(path.join(pluginDirectory, id), source, id));
  const staging = fs.mkdtempSync(path.join(pluginDirectory, '.prism-stage-'));
  const swapped = [];
  try {
    for (const [id, source] of targets) {
      const staged = path.join(staging, id);
      if (dev) fs.symlinkSync(source, staged, 'dir');
      else {
        const runtime = path.join(staged, 'runtime');
        fs.mkdirSync(runtime, {recursive:true});
        if (id === 'voyagen.prism') {
          const files = fs.readdirSync(project).filter(name => (name.endsWith('.qml') && !/^(Smoke|development)/i.test(name)) || ['BarModel.js', 'SettingsModel.js', 'IconResolver.js', 'LICENSE'].includes(name));
          for (const name of [...files, 'assets', 'shared']) fs.cpSync(path.join(project, name), path.join(runtime, name), {recursive:true,dereference:true});
        } else {
          fs.copyFileSync(path.join(source, 'BarWidget.qml'), path.join(runtime, 'BarWidget.qml'));
          fs.cpSync(path.join(project, 'shared'), path.join(runtime, 'shared'), {recursive:true,dereference:true});
          fs.copyFileSync(path.join(project, 'LICENSE'), path.join(runtime, 'LICENSE'));
        }
        const manifest = JSON.parse(fs.readFileSync(path.join(source, 'manifest.json'), 'utf8'));
        const directory = 'runtime-' + runtimeDigest(runtime, manifest);
        fs.renameSync(runtime, path.join(staged, directory));
        const kind = id === 'voyagen.prism' ? 'bar' : 'barWidget';
        manifest.entryPoints[kind] = directory + '/' + manifest.entryPoints[kind];
        fs.writeFileSync(path.join(staged, 'manifest.json'), JSON.stringify(manifest,null,2) + '\n');
        fs.copyFileSync(path.join(project, 'LICENSE'), path.join(staged, 'LICENSE'));
        fs.writeFileSync(path.join(staged, marker), JSON.stringify({schemaVersion: 1, owner: 'oma-prism', id}) + '\n');
      }
    }
    targets.forEach(([id], index) => {
      const destination = path.join(pluginDirectory, id);
      const previous = path.join(staging, `${id}.previous`);
      if (existing[index]) fs.renameSync(destination, previous);
      swapped.push({destination, previous, existed: existing[index]});
      fs.renameSync(path.join(staging, id), destination);
    });
    if (reachable()) command('omarchy-shell', ['shell', 'rescanPlugins']);
    else console.log('Shell unavailable; discovery will occur at next shell start.');
  } catch (error) {
    for (const {destination, previous, existed} of swapped.reverse()) {
      fs.rmSync(destination, {recursive: true, force: true});
      if (existed) fs.renameSync(previous, destination);
    }
    command('omarchy-shell', ['shell', 'rescanPlugins'], false);
    throw error;
  } finally { fs.rmSync(staging, {recursive: true, force: true}); }
  console.log(`Installed ${dev ? 'development links' : 'runtime copies'}; selection unchanged.`);
}
async function activate() {
  const manifest = validateProject(path.join(pluginDirectory, 'voyagen.prism'));
  const source = pathToFileURL(path.join(pluginDirectory, 'voyagen.prism', manifest.entryPoints.bar)).href;
  validateWidget(path.join(pluginDirectory, 'voyagen.prism.settings'));
  if (!reachable()) throw new Error('Activation requires a reachable Omarchy shell');
  const entries = JSON.parse(command('omarchy-plugin-catalog', []).stdout);
  for (const [id] of targets) {
    const entry = entries.find(entry => entry.id === id);
    if (!entry || !(id.endsWith('.settings') ? entry.kinds?.includes('bar-widget') && entry.barWidgetPath : entry.kinds?.includes('bar') && entry.barPath)) throw new Error(`${id} is not catalogued; run install first`);
  }
  const timeout = Number(process.env.PRISM_ACTIVATION_TIMEOUT_MS || 10000);
  if (!Number.isInteger(timeout) || timeout < 1 || timeout > 120000) throw new Error('PRISM_ACTIVATION_TIMEOUT_MS must be 1–120000');
  const directory = path.join(home, '.local/state/oma-prism/backups');
  fs.mkdirSync(directory, {recursive: true, mode: 0o700});
  const backup = path.join(directory, `shell-${Date.now()}-${process.pid}.json`);
  atomicWrite(backup, JSON.stringify(snapshot(), null, 2) + '\n', 0o600);
  console.log(`Backup: ${backup}`);
  try {
    process.stdout.write(command('omarchy-bar', ['use', 'voyagen.prism']).stdout);
    if (snapshot().effective.bar?.id !== 'voyagen.prism') throw new Error('Activation did not persist Prism selection');
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const result = command('omarchy-shell', ['voyagen.prism', 'health'], false, Math.max(1, Math.min(2000, deadline - Date.now())));
      if (!result.error && result.status === 0) {
        try {
          const health = JSON.parse(result.stdout);
          if (health.id === manifest.id && health.version === manifest.version && health.source === source && health.ready === true && Number.isInteger(health.screenCount) && health.screenCount > 0 && Number.isInteger(health.recordCount) && health.recordCount >= 0) {
            console.log(`Activated ${manifest.id} ${manifest.version}; ${health.screenCount} screen(s) ready.`);
            return;
          }
        } catch { /* The asynchronous Loader may not have registered IPC yet. */ }
      }
      await sleep(Math.min(100, Math.max(0, deadline - Date.now())));
    }
    throw new Error(`Prism runtime did not become ready within ${timeout}ms (Loader failure or timeout)`);
  } catch (error) {
    try { restore(backup); } catch (rollbackError) { throw new Error(`${error.message}; rollback failed: ${rollbackError.message}; backup: ${backup}`); }
    throw error;
  }
}
try {
  const [action, ...args] = process.argv.slice(2);
  if (action === 'install' && (args.length === 0 || (args.length === 1 && args[0] === '--dev'))) install(args[0] === '--dev');
  else if (action === 'activate' && args.length === 0) await activate();
  else if (action === 'rollback' && args.length === 1) restore(path.resolve(args[0]));
  else throw new Error('Usage: bash install.sh install [--dev] | activate | rollback <backup-path>');
} catch (error) { console.error(error.message); process.exitCode = 1; }
