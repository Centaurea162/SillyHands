#!/usr/bin/env bash

# Make sure pwd is the directory of the script
cd "$(dirname "$0")"

if ! command -v npm &> /dev/null
then
    echo -e "\033[0;31mnpm could not be found in PATH. If the startup fails, please install Node.js from https://nodejs.org/\033[0m"
fi

echo "Installing Node Modules..."
export NODE_ENV=production
npm install --no-save --no-audit --no-fund --loglevel=error --no-progress --omit=dev --ignore-scripts

# === MCP 桥依赖自检（幂等）：确保本地化 filesystem 服务器的依赖就绪 ===
if [ -f "scripts/mcp-fs/package.json" ] && [ ! -d "scripts/mcp-fs/node_modules/@modelcontextprotocol/sdk" ]; then
    echo "Installing mcp-fs dependencies (MCP filesystem server)..."
    (cd scripts/mcp-fs && npm install --no-audit --no-fund --loglevel=error --no-progress)
fi

echo "Entering SillyTavern..."
node "server.js" "$@"


