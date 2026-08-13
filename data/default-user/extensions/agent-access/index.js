// 浏览器扩展:agent-access
// 向 LLM 暴露 read_local_file / fetch_webpage 两个函数工具,
// 通过酒馆内置 tool-calling 管线(registerFunctionTool)执行,
// 实际 I/O 由服务器插件 plugins/agent-access 完成。
// 安装后需在「AI 响应配置」中勾选 Enable function calling,且使用支持工具调用的 Chat Completion 模型。

const { registerFunctionTool } = SillyTavern.getContext();

const API_BASE = '/api/plugins/agent-access';

async function callPlugin(route, body) {
    const r = await fetch(`${API_BASE}/${route}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
    });
    const j = await r.json().catch(() => ({}));
    if (!r.ok || !j.ok) throw new Error(j.error || `插件接口错误 HTTP ${r.status}`);
    return j;
}

registerFunctionTool({
    name: 'read_local_file',
    displayName: '读取本地文件',
    description: '读取 PC 白名单目录内的 Markdown/文本文件并返回完整内容。当用户要求先阅读本地文档、设定、笔记后再继续对话时使用。',
    parameters: {
        $schema: 'http://json-schema.org/draft-04/schema#',
        type: 'object',
        properties: {
            filePath: { type: 'string', description: '文件路径。绝对路径(如 D:/Notes/背景.md)或相对酒馆根目录的路径(如 data/背景.md)' },
        },
        required: ['filePath'],
    },
    action: async ({ filePath }) => {
        const j = await callPlugin('read', { filePath });
        return j.content;
    },
});

registerFunctionTool({
    name: 'fetch_webpage',
    displayName: '抓取网页',
    description: '抓取一个网页并返回正文纯文本。当用户要求浏览网页、查询某页面内容时使用。',
    parameters: {
        $schema: 'http://json-schema.org/draft-04/schema#',
        type: 'object',
        properties: {
            url: { type: 'string', description: '网页完整 URL,如 https://example.com/page' },
        },
        required: ['url'],
    },
    action: async ({ url }) => {
        const j = await callPlugin('fetch', { url });
        return `[${j.url} 抓取结果]\n${j.content}`;
    },
});

console.log('[agent-access] 已注册 read_local_file / fetch_webpage 两个函数工具');
