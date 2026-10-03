import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const project = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const args = process.argv.slice(2);
const runtimeArgument = args.find(arg => !['--motion','--layout','--design'].includes(arg));
const fixture = args.includes('--design') ? 'DesignSmoke.qml' : args.includes('--layout') ? 'LayoutSmoke.qml' : args.includes('--motion') ? 'MotionSmoke.qml' : 'RuntimeSmoke.qml';
const runtime = runtimeArgument ? path.dirname(path.join(path.resolve(runtimeArgument),JSON.parse(fs.readFileSync(path.join(runtimeArgument,'manifest.json'))).entryPoints.bar)) : project;
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'prism-runtime-'));
if (args.includes('--design') && process.env.PRISM_DESIGN_CAPTURE) fs.mkdirSync(process.env.PRISM_DESIGN_CAPTURE, {recursive:true});
try {
  const host = path.join(process.env.OMARCHY_PATH || '/usr/share/omarchy', 'shell');
  for (const name of ['Commons', 'Ui', 'services', 'plugins']) fs.symlinkSync(path.join(host, name), path.join(temporary, name), 'dir');
  fs.mkdirSync(path.join(temporary,'project/tests'),{recursive:true});
  for (const name of fs.readdirSync(runtime)) if (name !== 'tests') fs.symlinkSync(path.join(runtime,name),path.join(temporary,'project',name));
  fs.copyFileSync(path.join(project,'tests',fixture),path.join(temporary,'project/tests',fixture));
  fs.mkdirSync(path.join(temporary, '.config/omarchy'), {recursive:true});
  fs.writeFileSync(path.join(temporary, '.config/omarchy/shell.json'), JSON.stringify({version:1,bar:{id:'voyagen.prism',position:'top',layout:{left:[],center:[],right:[]},prism:{reserveSpace:false,radius:12}}}));
  fs.writeFileSync(path.join(temporary, 'custom.svg'), "<svg xmlns='http://www.w3.org/2000/svg' width='18' height='18'><rect width='18' height='18' fill='red'/></svg>");
  fs.writeFileSync(path.join(temporary, 'shell.qml'), `import "./project/tests" as Tests\nTests.${fixture.slice(0,-4)} {}\n`);
  const result = spawnSync('quickshell', ['--no-color', '-n', '-p', path.join(temporary, 'shell.qml')], {encoding:'utf8',timeout:30000,env:{...process.env,PRISM_TEST_HOME:temporary}});
  const output = (result.stdout || '') + (result.stderr || '');
  process.stdout.write(output);
  if (result.error || result.status !== 0 || !output.includes('PRISM RUNTIME PASS') || /\bERROR\b|PRISM RUNTIME FAIL|ReferenceError|TypeError|SyntaxError|Binding loop|Internal error - attempted|Cannot assign|is not a type/.test(output)) {
    console.error(result.error?.message || 'Prism QML runtime smoke failed');
    process.exitCode = 1;
  }
} finally {
  fs.rmSync(temporary, {recursive:true,force:true});
}
