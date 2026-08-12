// SillyTavern 服务器插件:agent-access
// 提供两个端点,供浏览器端 function tool 调用:
//   POST /api/plugins/agent-access/read  读取白名单内本地文件
//   POST /api/plugins/agent-access/fetch 抓取网页并转纯文本
// 白名单见同目录 config.json(roots 相对酒馆根目录解析;也支持绝对路径)。
'use strict';

const path = require('path');
const fs = require('fs/promises');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileP = promisify(execFile);
const PLUGIN_DIR = __dirname;
const ST_ROOT = path.resolve(__dirname, '..', '..'); // SillyTavern 根目录

let allowedRoots = [];

function loadConfig() {
    try {
        const cfg = require(path.join(PLUGIN_DIR, 'config.json'));
        allowedRoots = (cfg.roots || []).map(r => path.resolve(ST_ROOT, r));
        console.log(`[agent-access] 白名单根目录: ${allowedRoots.join(' | ')}`);
    } catch (e) {
        allowedRoots = [path.resolve(ST_ROOT, 'data')];
        console.warn('[agent-access] config.json 读取失败,默认白名单 = data/');
    }
}

function isAllowed(target) {
    const resolved = path.resolve(target);
    return allowedRoots.some(root => resolved === root || resolved.startsWith(root + path.sep));
}

// 简易 HTML -> 纯文本(去 script/style/标签)
function htmlToText(html) {
    return html
        .replace(/<script[\s\S]*?<\/script>/gi, ' ')
        .replace(/<style[\s\S]*?<\/style>/gi, ' ')
        .replace(/<noscript[\s\S]*?<\/noscript>/gi, ' ')
        .replace(/<!--[\s\S]*?-->/g, ' ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/gi, ' ').replace(/&amp;/gi, '&').replace(/&lt;/gi, '<').replace(/&gt;/gi, '>').replace(/&quot;/gi, '"').replace(/&#39;/gi, "'")
        .replace(/[ \t]+/g, ' ')
        .replace(/\n{3,}/g, '\n\n')
        .trim();
}

// 先直接 fetch;失败则回退系统 curl(会自动走 http_proxy/https_proxy 环境变量)
async function fetchWithFallback(url) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 30000);
    try {
        const r = await fetch(url, {
            signal: ctrl.signal,
            redirect: 'follow',
            headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36' },
        });
        if (!r.ok) throw new Error(`HTTP ${r.status}`);
        const text = await r.text();
        return { source: 'fetch', text };
    } catch (e) {
        const { stdout } = await execFileP('curl', ['-sL', '--max-time', '30', url], { maxBuffer: 8 * 1024 * 1024 });
        return { source: 'curl', text: stdout };
    } finally {
        clearTimeout(timer);
    }
}

async function init(router) {
    loadConfig();

    router.post('/read', async (req, res) => {
        const { filePath, maxChars = 200000 } = req.body ?? {};
        if (!filePath || typeof filePath !== 'string') return res.status(400).json({ error: '缺少 filePath' });
        if (!isAllowed(filePath)) return res.status(403).json({ error: `路径不在白名单内: ${filePath}` });
        try {
            const stat = await fs.stat(filePath);
            if (!stat.isFile()) return res.status(400).json({ error: '不是文件' });
            if (stat.size > maxChars) return res.status(413).json({ error: `文件过大(>${maxChars} 字符),可增大 maxChars` });
            const content = await fs.readFile(filePath, 'utf-8');
            return res.json({ ok: true, name: path.basename(filePath), path: filePath, chars: content.length, content });
        } catch (e) {
            return res.status(404).json({ error: e.message });
        }
    });

    router.post('/fetch', async (req, res) => {
        const { url, maxChars = 100000 } = req.body ?? {};
        if (!url || !/^https?:\/\//i.test(url)) return res.status(400).json({ error: 'url 必须是 http(s) 地址' });
        try {
            const { source, text } = await fetchWithFallback(url);
            const plain = htmlToText(text).slice(0, maxChars);
            return res.json({ ok: true, url, source, chars: plain.length, content: plain });
        } catch (e) {
            return res.status(502).json({ error: `抓取失败: ${e.message}` });
        }
    });

    console.log('[agent-access] 插件已加载: POST /api/plugins/agent-access/{read,fetch}');
}

module.exports = {
    init,
    info: {
        id: 'agent-access',
        name: 'Agent Access',
        description: '读取白名单内本地文件与抓取网页正文,供 LLM agent 工具调用',
    },
};
