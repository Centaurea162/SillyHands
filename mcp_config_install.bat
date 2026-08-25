@echo off
rem ============================================================
rem mcp_config_install.bat - one-shot MCP bridge dependency setup (Windows)
rem 1. install missing node_modules deps for scripts\mcp-fs
rem Equivalent to mcp_config_install.sh (Linux/macOS/Termux).
rem ASCII-only (GBK-codepage-safe). Idempotent.
rem ============================================================
setlocal

rem script dir = ST root (%~dp0 ends with backslash)
set "ST_ROOT=%~dp0"
set "MCP_FS_DIR=%ST_ROOT%scripts\mcp-fs"

echo === mcp_config_install.bat ===
echo ST root: %ST_ROOT%
echo mcp-fs dir: %MCP_FS_DIR%

rem --- pre-checks ---
if not exist "%MCP_FS_DIR%" (
    echo ERROR: %MCP_FS_DIR% not found, run this script from ST root
    exit /b 1
)
if not exist "%MCP_FS_DIR%\package.json" (
    echo ERROR: %MCP_FS_DIR%\package.json not found, mcp-fs incomplete
    exit /b 1
)
where node >nul 2>nul
if errorlevel 1 (
    echo ERROR: node not found. Install Node.js ^(^>=20^)
    exit /b 1
)
where npm >nul 2>nul
if errorlevel 1 (
    echo ERROR: npm not found. Install Node.js ^(^>=20^)
    exit /b 1
)

rem --- 1. install mcp-fs deps ---
cd /d "%MCP_FS_DIR%"
if exist "%MCP_FS_DIR%\node_modules\@modelcontextprotocol\sdk" (
    echo === [1/2] mcp-fs deps already present, skip ===
) else (
    echo === [1/2] installing mcp-fs deps ^(npm install, package-lock.json pinned^) ===
    call npm install
    if errorlevel 1 (
        echo ERROR: npm install failed
        exit /b 1
    )
)

rem --- 2. verify ---
echo === [2/2] verify ===
set "OK=1"
if exist "%MCP_FS_DIR%\node_modules\@modelcontextprotocol\sdk" (
    echo [OK] node_modules\@modelcontextprotocol\sdk ready
) else (
    echo [FAIL] @modelcontextprotocol/sdk not installed
    set "OK=0"
)
if exist "%ST_ROOT%plugins\SillyTavern-MCP-Server\dist\index.js" (
    echo [OK] MCP-Server plugin dist ready
) else (
    echo [FAIL] MCP-Server plugin dist missing
    set "OK=0"
)
if exist "%ST_ROOT%plugins\agent-access\index.js" (
    echo [OK] agent-access plugin ready
) else (
    echo [FAIL] agent-access plugin missing
    set "OK=0"
)
if exist "%ST_ROOT%scripts\mcp-dc-wrapper.js" (
    echo [OK] mcp-dc-wrapper.js ready
) else (
    echo [FAIL] mcp-dc-wrapper.js missing
    set "OK=0"
)

if not "%OK%"=="1" (
    echo [FAIL] dependencies incomplete, check errors above
    exit /b 1
)

rem --- whitelist path hints ---
echo.
echo === IMPORTANT: check whitelist paths after clone ===
echo   1) data\default-user\mcp_settings.json - filesystem args ^(currently may be H:/workspace^)
echo      change to your workdir absolute path, e.g. D:/workspace
echo   2) plugins\agent-access\config.json - roots ^(currently may include H:/workspace^)
echo      same as above
echo.
echo === Done. You can run Start.bat to launch the tavern ===

endlocal