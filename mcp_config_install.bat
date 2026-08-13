@echo off
rem ============================================================
rem mcp_config_install.bat — 修复 MCP 本地化服务器依赖（filesystem 增强包）Windows 版
rem 用途：在 ST 根目录下运行，为 scripts\mcp-fs 安装缺失的 node_modules 依赖
rem 适用：Windows（与 mcp_config_install.sh 等价）
rem 原理：mcp-fs 是本地化增强版 filesystem 服务器（含 rg/fd 搜索工具），
rem       依赖 @modelcontextprotocol/sdk 等包；仓库不携带 node_modules，
rem       克隆/迁移后需执行本脚本重建（依据 package-lock.json 精确复刻版本）。
rem ============================================================
setlocal

rem 脚本所在目录 = ST 根目录（%~dp0 含结尾反斜杠）
set "ST_ROOT=%~dp0"
set "MCP_FS_DIR=%ST_ROOT%scripts\mcp-fs"

echo === mcp_config_install.bat ===
echo ST 根目录: %ST_ROOT%
echo mcp-fs 目录: %MCP_FS_DIR%

rem --- 前置检查 ---
if not exist "%MCP_FS_DIR%" (
    echo 错误: 未找到 %MCP_FS_DIR%，请确认脚本位于 ST 根目录
    exit /b 1
)
if not exist "%MCP_FS_DIR%\package.json" (
    echo 错误: 未找到 %MCP_FS_DIR%\package.json，mcp-fs 目录不完整
    exit /b 1
)
where node >nul 2>nul
if errorlevel 1 (
    echo 错误: 未找到 node，请先安装 Node.js ^(^>=20^)
    exit /b 1
)
where npm >nul 2>nul
if errorlevel 1 (
    echo 错误: 未找到 npm，请先安装 Node.js ^(^>=20^)
    exit /b 1
)

rem --- 安装依赖 ---
cd /d "%MCP_FS_DIR%"
echo === 安装依赖: npm install（依据 package-lock.json 精确复刻） ===
call npm install
if errorlevel 1 (
    echo 错误: npm install 失败
    exit /b 1
)

rem --- 验证 ---
echo === 验证 ===
if exist "%MCP_FS_DIR%\node_modules\@modelcontextprotocol\sdk" (
    echo [OK] node_modules\@modelcontextprotocol\sdk 已就绪
    echo === 完成：mcp-fs 依赖已安装，重启 ST 后 filesystem 服务器即可启动 ===
) else (
    echo [失败] 验证未通过: @modelcontextprotocol/sdk 未安装成功
    exit /b 1
)

endlocal
