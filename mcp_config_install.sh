#!/usr/bin/env bash
# ============================================================
# mcp_config_install.sh — 一键安装/修复 MCP 桥所需依赖（Linux / WSL / macOS / Termux）
#
# 用途：全新 Linux 环境 git clone 本仓库后，第一步先运行本脚本：
#       ./mcp_config_install.sh
#       然后再 ./start.sh 启动酒馆。
#
# 本脚本完成：
#   1. ST 主目录依赖（node_modules，生产模式，依据 package-lock.json）
#   2. scripts/mcp-fs 本地化 filesystem 服务器依赖（sdk/diff/minimatch/zod）
#   3. 搜索二进制 rg/fd 自动下载（依据 OS + 架构，从 GitHub release 获取，
#      直连失败自动切换 ghfast.top 镜像；已有可用二进制则跳过）
#   4. 验证关键依赖就绪
#   5. （可选 --prefetch）预下载 web / desktop-commander 两个 npx 服务器包
#      （避免首次启用时联网等待；需要网络）
#
# 幂等：可重复运行，已装好的依赖/二进制会跳过。
# ============================================================
set -euo pipefail

ST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
MCP_FS_DIR="$ST_ROOT/scripts/mcp-fs"
BIN_DIR="$MCP_FS_DIR/bin"
PREFETCH=0
for arg in "$@"; do
    case "$arg" in
        --prefetch) PREFETCH=1 ;;
        -h|--help) sed -n '1,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
    echo "=== [1/4] ST 主依赖已存在，跳过 ==="
else
    echo "=== [1/4] 安装 ST 主依赖（npm install --omit=dev，可能需要几分钟） ==="
    cd "$ST_ROOT"
    NODE_ENV=production npm install --no-audit --no-fund --loglevel=error --no-progress --omit=dev --ignore-scripts
fi

# --- 2. scripts/mcp-fs 依赖 ------------------------------------
if [ ! -d "$MCP_FS_DIR" ]; then
    echo "错误: 未找到 $MCP_FS_DIR（本地化 filesystem 服务器缺失）" >&2
    exit 1
fi
if [ -d "$MCP_FS_DIR/node_modules/@modelcontextprotocol/sdk" ]; then
    echo "=== [2/4] mcp-fs 依赖已存在，跳过 ==="
else
    echo "=== [2/4] 安装 mcp-fs 依赖（sdk/diff/minimatch/zod） ==="
    cd "$MCP_FS_DIR"
    npm install --no-audit --no-fund --loglevel=error --no-progress
fi

# --- 3. 搜索二进制 rg/fd 自动下载（依据 OS + 架构） -------------
echo "=== [3/4] 检查/下载搜索二进制 rg + fd ==="
mkdir -p "$BIN_DIR"

# 检测 OS 与架构，输出 GitHub release 的 target 三元组
detect_target() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Linux)  os=linux ;;
        Darwin) os=darwin ;;
        *) echo "错误: 不支持的 OS: $os（仅支持 Linux / macOS）" >&2; return 1 ;;
    esac
    case "$arch" in
        x86_64|amd64)  arch=x86_64 ;;
        aarch64|arm64) arch=aarch64 ;;
        *) echo "错误: 不支持的架构: $arch（仅支持 x86_64 / arm64）" >&2; return 1 ;;
    esac
    if [ "$os" = "linux" ]; then
        # Linux 统一用 musl 静态版：任意发行版（含 glibc / Termux bionic）均可直接运行
        echo "${arch}-unknown-linux-musl"
    else
        echo "${arch}-apple-darwin"
    fi
}

# 下载单个二进制：name(显示名) repo(owner/name) ver(tag) target asset binname(解压后的文件名)
download_binary() {
    local name="$1" repo="$2" ver="$3" target="$4" asset="$5" binname="$6"
    local dest="$BIN_DIR/$binname"
    if [ -x "$dest" ] && "$dest" --version >/dev/null 2>&1; then
        echo "  跳过: $binname 已存在且可运行（$("$dest" --version | head -1)）"
        return 0
    fi
    local url="https://github.com/$repo/releases/download/$ver/$asset"
    local tmp; tmp="$(mktemp -d)"
    echo "  下载 $name ($target): $url"
    if ! curl -fsSL --connect-timeout 15 -o "$tmp/$asset" "$url"; then
        echo "  直连失败，尝试镜像 ghfast.top ..."
        if ! curl -fsSL --connect-timeout 15 -o "$tmp/$asset" "https://ghfast.top/$url"; then
            echo "  镜像失败，尝试镜像 gh-proxy.com ..."
            curl -fsSL --connect-timeout 15 -o "$tmp/$asset" "https://gh-proxy.com/$url" || { echo "错误: $name 下载失败（直连 + 镜像均失败）" >&2; rm -rf "$tmp"; return 1; }
        fi
    fi
    tar -xzf "$tmp/$asset" -C "$tmp"
    find "$tmp" -name "$binname" -type f -exec cp {} "$dest" \;
    chmod +x "$dest"
    rm -rf "$tmp"
    if ! "$dest" --version >/dev/null 2>&1; then
        echo "错误: $binname 下载后运行验证失败" >&2
        return 1
    fi
    echo "  就绪: $("$dest" --version | head -1)"
    return 0
}

TARGET="$(detect_target)"
echo "  检测到平台: $(uname -s) / $(uname -m) → $TARGET"
download_binary "ripgrep" "BurntSushi/ripgrep" "14.1.1" "$TARGET" "ripgrep-14.1.1-$TARGET.tar.gz" "rg"
download_binary "fd" "sharkdp/fd" "v10.2.0" "$TARGET" "fd-v10.2.0-$TARGET.tar.gz" "fd"

# --- 4. 验证 ----------------------------------------------------
echo "=== [4/4] 验证 ==="
ok=1
[ -f "$MCP_FS_DIR/node_modules/@modelcontextprotocol/sdk/package.json" ] || { echo "[失败] mcp-fs: @modelcontextprotocol/sdk 缺失" >&2; ok=0; }
[ -f "$MCP_FS_DIR/node_modules/diff/package.json" ] || { echo "[失败] mcp-fs: diff 缺失" >&2; ok=0; }
[ -f "$ST_ROOT/plugins/SillyTavern-MCP-Server/dist/index.js" ] || { echo "[失败] MCP-Server 插件 dist 缺失" >&2; ok=0; }
[ -f "$ST_ROOT/plugins/agent-access/index.js" ] || { echo "[失败] agent-access 插件缺失" >&2; ok=0; }
[ -f "$ST_ROOT/scripts/mcp-dc-wrapper.js" ] || { echo "[失败] mcp-dc-wrapper.js 缺失" >&2; ok=0; }
# 搜索二进制：本平台对应文件必须可运行
case "$(uname -s)" in
    Linux|Darwin)
        [ -x "$BIN_DIR/rg" ] && "$BIN_DIR/rg" --version >/dev/null 2>&1 || { echo "[失败] 搜索二进制 rg 不可用（$BIN_DIR/rg）" >&2; ok=0; }
        [ -x "$BIN_DIR/fd" ] && "$BIN_DIR/fd" --version >/dev/null 2>&1 || { echo "[失败] 搜索二进制 fd 不可用（$BIN_DIR/fd）" >&2; ok=0; }
        ;;
esac
chmod +x "$ST_ROOT/mcp_config_install.sh" "$ST_ROOT/start.sh" 2>/dev/null || true
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
