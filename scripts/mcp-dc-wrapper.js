#!/usr/bin/env node
/**
 * desktop-commander MCP 启动包装器（迁移安全的白名单锚定）
 *
 * 由 ST MCP 插件以 cwd=ST 根目录 spawn（mcp_settings.json 用相对路径
 * "scripts/mcp-dc-wrapper.js"），因此 __dirname 推导出的 ST 根在项目
 * 整体迁移后依然正确——白名单永远锚定在 <ST>/mcp_data。
 *
 * 职责：
 *   1. 确保 <ST>/mcp_data 存在
 *   2. 每次启动把 desktop-commander 的 allowedDirectories 重写为
 *      <ST>/mcp_data 的绝对路径（其校验不支持相对路径，源码实测确认），
 *      写后恢复只读防篡改
 *   3. stdio 透传启动真正的 desktop-commander（npx）
 */
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs';
import os from 'node:os';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ST_ROOT = path.resolve(__dirname, '..'); // 本文件位于 <ST>/scripts/ 下
const MCP_DATA = path.join(ST_ROOT, 'mcp_data');

// 1. 确保锚点目录存在
fs.mkdirSync(MCP_DATA, { recursive: true });

// 2. 重写 allowedDirectories（清只读 → 写 → 恢复只读）
const configDir = path.join(os.homedir(), '.claude-server-commander');
fs.mkdirSync(configDir, { recursive: true }); // 首次运行目录可能不存在（Linux/WSL）
const configPath = path.join(configDir, 'config.json');
let config = {};
try {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
} catch { /* 首次运行无配置文件 */ }
try { fs.chmodSync(configPath, 0o666); } catch { /* 文件可能不存在 */ }
config.allowedDirectories = [MCP_DATA];
fs.writeFileSync(configPath, JSON.stringify(config, null, 2), 'utf8');
try { fs.chmodSync(configPath, 0o444); } catch { /* 忽略 */ }

// 3. stdio 透传启动真正的服务器（MCP 走 stdin/stdout）
const npxArgs = ['-y', '@wonderwhy-er/desktop-commander'];
const child = process.platform === 'win32'
    ? spawn('cmd', ['/C', 'npx', ...npxArgs], { stdio: 'inherit' })
    : spawn('npx', npxArgs, { stdio: 'inherit' });
child.on('exit', (code) => process.exit(code ?? 0));
child.on('error', (err) => { console.error('[mcp-dc-wrapper]', err); process.exit(1); });
