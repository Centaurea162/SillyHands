#!/usr/bin/env bash
# ============================================================
# mcp_config_install.sh — 一键安装/修复 MCP 桥所需依赖（Linux / WSL / macOS）
#
# 用途：全新 Linux 环境 git clone 本仓库后，第一步先运行本脚本：
#       ./mcp_config_install.sh
#       然后再 ./start.sh 启动酒馆。
#
# 本脚本完成：
#   1. ST 主目录依赖（node_modules，生产模式，依据 package-lock.json）
#   2. scripts/mcp-fs 本地化 filesystem 服务器依赖（sdk/diff/minimatch/zod）
#   3. 验证关键依赖就绪
#   4. （可选 --prefetch）预下载 web / desktop-commander 两个 npx 服务器包
#      （避免首次启用时联网等待；需要网络）
#
# 幂等：可重复运行，已装好的依赖会跳过。
# ============================================================
set -euo pipefail

ST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_FS_DIR="$ST_ROOT/scripts/mcp-fs"
PREFETCH=0
for arg in "$@"; do
    case "$arg" in
        --prefetch) PREFETCH=1 ;;
        -h|--help) sed -n '1,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "未知参数: $arg（支持 --prefetch）" >&2; exit 1 ;;
    esac
done

echo "=== mcp_config_install.sh ==="
echo "ST 根目录: $ST_ROOT"

# --- 前置检查 -------------------------------------------------
if [ ! -f "$ST_ROOT/server.js" ]; then
    echo "错误: 未在 $ST_ROOT 找到 server.js，请确认脚本位于 ST 仓库根目录" >&2
    exit 1
fi
if ! command -v node >/dev/null 2>&1; then
    echo "错误: 未找到 node。请先安装 Node.js >= 20（https://nodejs.org）" >&2
    exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
    echo "错误: 未找到 npm。请先安装 Node.js >= 20（https://nodejs.org）" >&2
    exit 1
fi
echo "node: $(node --version)  npm: $(npm --version)"

# --- 1. ST 主目录依赖 ------------------------------------------
if [ -d "$ST_ROOT/node_modules" ] && [ -d "$ST_ROOT/node_modules/express" ]; then
    echo "=== [1/3] ST 主依赖已存在，跳过 ==="
else
    echo "=== [1/3] 安装 ST 主依赖（npm install --omit=dev，可能需要几分钟） ==="
    cd "$ST_ROOT"
    NODE_ENV=production npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --ignore-scripts
fi

# --- 2. scripts/mcp-fs 依赖 ------------------------------------
if [ ! -d "$ST_ROOT/scripts/mcp-fs" ]; then
    echo "错误: 未找到 $ST_ROOT/scripts/mcp-fs（本地化 filesystem 服务器缺失）" >&2
    exit 1
fi
if [ -d "$MCP_FS_DIR/node_modules/@modelcontextprotocol/sdk" ]; then
    echo "=== [2/3] mcp-fs 依赖已存在，跳过 ==="
else
    echo "=== [2/3] 安装 mcp-fs 依赖（sdk/diff/minimatch/zod） ==="
    cd "$MCP_FS_DIR"
    npm install --no-audit --no-fund --loglevel=error --no-progress
fi

# --- 3. 验证 ----------------------------------------------------
echo "=== [3/3] 验证 ==="
ok=1
[ -f "$MCP_FS_DIR/node_modules/@modelcontextprotocol/sdk/package.json" ] || { echo "[失败] mcp-fs: @modelcontextprotocol/sdk 缺失" >&2; ok=0; }
[ -f "$MCP_FS_DIR/node_modules/diff/package.json" ] || { echo "[失败] mcp-fs: diff 缺失" >&2; ok=0; }
[ -f "$ST_ROOT/plugins/SillyTavern-MCP-Server/dist/index.js" ] || { echo "[失败] MCP-Server 插件 dist 缺失" >&2; ok=0; }
[ -f "$ST_ROOT/plugins/agent-access/index.js" ] || { echo "[失败] agent-access 插件缺失" >&2; ok=0; }
[ -f "$ST_ROOT/scripts/mcp-dc-wrapper.js" ] || { echo "[失败] mcp-dc-wrapper.js 缺失" >&2; ok=0; }
# Linux 二进制（无后缀）或 Windows 二进制（.exe）至少存在其一
if [ -f "$MCP_FS_DIR/bin/rg" ] || [ -f "$MCP_FS_DIR/bin/rg.exe" ]; then :; else echo "[警告] rg 二进制缺失（bin/rg 或 bin/rg.exe）" >&2; fi
if [ -f "$MCP_FS_DIR/bin/fd" ] || [ -f "$MCP_FS_DIR/bin/fd.exe" ]; then :; else echo "[警告] fd 二进制缺失（bin/fd 或 bin/fd.exe）" >&2; fi
if [ "$ok" = "1" ]; then
    echo "[OK] 依赖就绪。"
else
    echo "[失败] 依赖不完整，请检查上方错误信息" >&2
    exit 1
fi

# --- 可选：预下载 npx 服务器包 ---------------------------------
if [ "$PREFETCH" = "1" ]; then
    echo "=== 预下载 npx 服务器包（需要网络） ==="
    echo "--- web: html-extractor-mcp ..."
    timeout 120 npx -y html-extractor-mcp </dev/null >/dev/null 2>&1 || echo "  （下载完成或已超时，首次连接时会重试）"
    echo "--- desktop-commander: @wonderwhy-er/desktop-commander ..."
    timeout 120 npx -y @wonderwhy-er/desktop-commander </dev/null >/dev/null 2>&1 || echo "  （下载完成或已超时，首次连接时会重试）"
    echo "=== 预下载完成 ==="
fi

# --- 白名单路径提示 ---------------------------------------------
echo ""
echo "=== 重要：检查以下文件中的白名单路径（clone 后按你的环境修改） ==="
echo "  1) data/default-user/mcp_settings.json → filesystem 的 args（当前可能为 H:/workspace）"
echo "     改为你的工作区绝对路径，如 /home/<user>/workspace"
echo "  2) plugins/agent-access/config.json → roots（当前可能含 H:/workspace）"
echo "     同上改为你的工作区绝对路径"
echo ""
echo "=== 完成。现在可以运行 ./start.sh 启动酒馆 ==="
