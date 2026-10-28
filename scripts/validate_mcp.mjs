#!/usr/bin/env node
// Exercise the configured stdio MCP wrappers, not a substitute Godot API.
// --install-addon explicitly installs/enables the pinned bridge in project.godot.
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import readline from 'node:readline';
import { fileURLToPath } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const logs = path.join(root, '.tools/logs');
mkdirSync(logs, { recursive: true });
const pins = readFileSync(path.join(root, 'scripts/tooling/versions.env'), 'utf8');
const pin = name => {
  const match = pins.match(new RegExp(`^${name}="([^"]+)"$`, 'm'));
  assert(match, `Missing pin: ${name}`);
  return match[1];
};
assert(process.argv.slice(2).every(arg => arg === '--install-addon'), 'Usage: node scripts/validate_mcp.mjs [--install-addon]');

class Client {
  constructor(name) {
    this.name = name;
    this.pending = new Map();
    this.nextId = 1;
    this.child = spawn('bash', [`scripts/mcp/${name}_mcp.sh`], {
      cwd: root, stdio: ['pipe', 'pipe', 'pipe'],
    });
    this.log = path.join(logs, `${name}-validation.log`);
    writeFileSync(this.log, '');
    this.child.stderr.on('data', chunk => appendFileSync(this.log, chunk));
    this.lines = readline.createInterface({ input: this.child.stdout });
    this.lines.on('line', line => {
      appendFileSync(this.log, `${line}\n`);
      let message;
      try { message = JSON.parse(line); } catch { return; }
      const pending = this.pending.get(message.id);
      if (!pending) return;
      this.pending.delete(message.id);
      clearTimeout(pending.timer);
      if (message.error) pending.reject(new Error(JSON.stringify(message.error)));
      else pending.resolve(message.result);
    });
    const fail = error => {
      for (const pending of this.pending.values()) {
        clearTimeout(pending.timer);
        pending.reject(error);
      }
      this.pending.clear();
    };
    this.child.on('error', fail);
    this.child.on('exit', code => fail(new Error(`${name} exited (${code}); see .tools/logs/${name}-validation.log`)));
    this.child.stdin.on('error', fail);
  }

  send(message) { this.child.stdin.write(`${JSON.stringify(message)}\n`); }

  request(method, params = {}) {
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`${this.name}: ${method} timed out; see .tools/logs/${this.name}-validation.log`));
      }, 240_000);
      this.pending.set(id, { resolve, reject, timer });
      this.send({ jsonrpc: '2.0', id, method, params });
    });
  }

  async initialize() {
    const result = await this.request('initialize', {
      protocolVersion: '2024-11-05', capabilities: {},
      clientInfo: { name: 'black-island-p00-validation', version: '1' },
    });
    this.send({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} });
    return result.serverInfo;
  }

  async call(name, args = {}) {
    const result = await this.request('tools/call', { name, arguments: args });
    assert(!result.isError, `${this.name}/${name}: ${JSON.stringify(result.content)}`);
    if (result.structuredContent) return result.structuredContent;
    const text = result.content?.filter(entry => entry.type === 'text').map(entry => entry.text).join('\n');
    try { return JSON.parse(text); } catch { return { result: text }; }
  }

  async close() {
    if (this.child.exitCode !== null || this.child.signalCode !== null) return;
    await new Promise(resolve => {
      this.child.once('exit', resolve);
      this.child.kill('SIGTERM');
      const timer = setTimeout(() => this.child.kill('SIGKILL'), 3000);
      timer.unref();
      this.child.once('exit', () => clearTimeout(timer));
    });
    this.lines.close();
  }
}

const clients = [];
try {
  const godot = new Client('godot');
  clients.push(godot);
  const server = await godot.initialize();
  // The first engine call is always status, including on a fresh checkout.
  let status = await godot.call('godot_status');
  assert.equal(server.version, pin('GODOT_MCP_VERSION'));
  assert.equal(status.server_version, pin('GODOT_MCP_VERSION'));
  assert.equal(status.project_path, path.join(root, 'game'));
  assert(status.godot.version.startsWith(`${pin('GODOT_VERSION')}.`));
  if (process.argv.includes('--install-addon')) {
    const installed = await godot.call('godot_call_write', { operation: 'addon.install', args: {} });
    assert.equal(installed.installed_version, pin('GODOT_MCP_VERSION'));
  } else {
    assert(status.addon_installed, 'Run again with --install-addon to install/enable the pinned bridge');
  }

  const serena = new Client('serena');
  clients.push(serena);
  const serenaServer = await serena.initialize();
  assert.equal(serenaServer.version, pin('SERENA_VERSION'));
  await serena.call('initial_instructions');
  const fixture = 'tests/integration/voxel_capability_probe.gd';
  const symbols = await serena.call('find_symbol', {
    name_path_pattern: '_probe_smooth_path', relative_path: fixture,
    include_body: false, max_answer_chars: 2000,
  });
  const found = typeof symbols.result === 'string' ? JSON.parse(symbols.result) : symbols;
  assert(Array.isArray(found) && found.some(symbol => symbol.name_path.endsWith('/_probe_smooth_path')), 'Serena symbol missing');
  console.log('PASS Serena: GDScript symbol located through LSP :6008');

  for (let attempt = 0; attempt < 20; attempt++) {
    status = await godot.call('godot_status');
    if (status.editor_connected) break;
    await delay(500);
  }
  assert(status.editor_connected, 'Live bridge not connected. If addon was enabled in an already-open editor, reopen the exact pinned editor and retry.');
  assert.equal(status.editor.plugin_version, pin('GODOT_MCP_VERSION'));
  assert(status.editor.godot_version.startsWith(`${pin('GODOT_VERSION')}.`));
  assert.equal(status.editor.project_path, path.join(root, 'game'));
  console.log(`PASS Godot MCP ${server.version}: live editor bridge, playing=${status.editor.is_playing}`);

  const diagnostics = await godot.call('godot_call_read', {
    operation: 'code.diagnostics', args: { paths: [`res://${fixture}`] },
  });
  assert.equal(diagnostics.source, 'lsp (connected editor)', 'Diagnostics must use the live editor, not a private fallback');
  assert.equal(diagnostics.checked, 1);
  assert.equal(diagnostics.errors, 0);
  assert.equal(diagnostics.warnings, 0);
  const editorLog = await godot.call('godot_call_read', {
    operation: 'editor.logs', args: { level: 'error', limit: 100 },
  });
  assert(Array.isArray(editorLog.entries), 'Unexpected editor log schema');
  assert.equal(editorLog.entries.length, 0, 'Editor reported errors; inspect local validation log');
  console.log('PASS Godot diagnostics: fixture has no errors/warnings; editor error log empty');
  writeFileSync(path.join(logs, 'mcp-validation.json'), `${JSON.stringify({
    godot: status.godot.version, godot_mcp: server.version, serena_server: serenaServer,
    editor_connected: status.editor_connected, editor: status.editor,
    symbol: found, diagnostics, editor_log: editorLog,
  }, null, 2)}\n`);
  console.log('Evidence: .tools/logs/mcp-validation.json (local, not committed)');
} catch (error) {
  console.error(`FAIL: ${error.message}`);
  process.exitCode = 1;
} finally {
  for (const client of clients.reverse()) await client.close();
}
