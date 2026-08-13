@echo off
rem ============================================================
rem mcp_config_install.bat — 一键安装/修复 MCP 桥所需依赖（Windows 版）
rem 用途：在 ST 根目录下运行
rem   1. 为 scripts\mcp-fs 安装缺失的 node_modules 依赖
rem   2. 搜索二进制 rg.exe / fd.exe 自动下载（Windows x86_64，GitHub release，
rem      直连失败自动切换 ghfast.top / gh-proxy.com 镜像；已有可用二进制则跳过）
rem 与 mcp_config_install.sh（Linux/macOS/Termux）等价。
rem ============================================================
setlocal

rem 脚本所在目录 = ST 根目录（%~dp0 含结尾反斜杠）
set "ST_ROOT=%~dp0"
set "MCP_FS_DIR=%ST_ROOT%scripts\mcp-fs"
set "BIN_DIR=%MCP_FS_DIR%\bin"

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
where curl >nul 2>nul
if errorlevel 1 (
    echo 错误: 未找到 curl（Win10 1803+ 自带，请确认系统版本或安装 curl）
    exit /b 1
)
where tar >nul 2>nul
if errorlevel 1 (
    echo 错误: 未找到 tar（Win10 1803+ 自带，请确认系统版本或安装 tar）
    exit /b 1
)

rem --- 1. 安装 mcp-fs 依赖 ---
cd /d "%MCP_FS_DIR%"
if exist "%MCP_FS_DIR%\node_modules\@modelcontextprotocol\sdk" (
    echo === [1/3] mcp-fs 依赖已存在，跳过 ===
) else (
    echo === [1/3] 安装 mcp-fs 依赖（npm install，依据 package-lock.json 精确复刻） ===
    call npm install
    if errorlevel 1 (
        echo 错误: npm install 失败
        exit /b 1
    )
)

rem --- 2. 搜索二进制 rg.exe / fd.exe 自动下载 ---
echo === [2/3] 检查/下载搜索二进制 rg.exe + fd.exe ===
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

rem 下载单个二进制：%1=显示名 %2=repo %3=ver %4=asset %5=目标exe名
:check_rg
if exist "%BIN_DIR%\rg.exe" (
    "%BIN_DIR%\rg.exe" --version >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%v in ('"%BIN_DIR%\rg.exe" --version ^| findstr /b "ripgrep"') do echo   跳过: rg.exe 已存在且可运行 ^(%%v^)
        goto :check_fd
    )
    del /q "%BIN_DIR%\rg.exe"
)
set "ASSET=ripgrep-14.1.1-x86_64-pc-windows-msvc.zip"
set "URL=https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/%ASSET%"
echo   下载 ripgrep ^(x86_64-pc-windows-msvc^)
curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "%URL%"
if errorlevel 1 (
    echo   直连失败，尝试镜像 ghfast.top ...
    curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "https://ghfast.top/%URL%"
    if errorlevel 1 (
        echo   镜像失败，尝试镜像 gh-proxy.com ...
        curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "https://gh-proxy.com/%URL%"
        if errorlevel 1 (
            echo 错误: ripgrep 下载失败 ^(直连 + 镜像均失败^)
            exit /b 1
        )
    )
)
tar -xf "%TEMP%\%ASSET%" -C "%TEMP%"
copy /y "%TEMP%\ripgrep-14.1.1-x86_64-pc-windows-msvc\rg.exe" "%BIN_DIR%\rg.exe" >nul
if errorlevel 1 (
    echo 错误: 解压/复制 rg.exe 失败
    exit /b 1
)
"%BIN_DIR%\rg.exe" --version >nul 2>nul
if errorlevel 1 (
    echo 错误: rg.exe 下载后运行验证失败
    exit /b 1
)
for /f "delims=" %%v in ('"%BIN_DIR%\rg.exe" --version ^| findstr /b "ripgrep"') do echo   就绪: %%v

:check_fd
if exist "%BIN_DIR%\fd.exe" (
    "%BIN_DIR%\fd.exe" --version >nul 2>nul
    if not errorlevel 1 (
        for /f "delims=" %%v in ('"%BIN_DIR%\fd.exe" --version ^| findstr /b "fd"') do echo   跳过: fd.exe 已存在且可运行 ^(%%v^)
        goto :verify
    )
    del /q "%BIN_DIR%\fd.exe"
)
set "ASSET=fd-v10.2.0-x86_64-pc-windows-msvc.zip"
set "URL=https://github.com/sharkdp/fd/releases/download/v10.2.0/%ASSET%"
echo   下载 fd ^(x86_64-pc-windows-msvc^)
curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "%URL%"
if errorlevel 1 (
    echo   直连失败，尝试镜像 ghfast.top ...
    curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "https://ghfast.top/%URL%"
    if errorlevel 1 (
        echo   镜像失败，尝试镜像 gh-proxy.com ...
        curl -fsSL --connect-timeout 15 -o "%TEMP%\%ASSET%" "https://gh-proxy.com/%URL%"
        if errorlevel 1 (
            echo 错误: fd 下载失败 ^(直连 + 镜像均失败^)
            exit /b 1
        )
    )
)
tar -xf "%TEMP%\%ASSET%" -C "%TEMP%"
copy /y "%TEMP%\fd-v10.2.0-x86_64-pc-windows-msvc\fd.exe" "%BIN_DIR%\fd.exe" >nul
if errorlevel 1 (
    echo 错误: 解压/复制 fd.exe 失败
    exit /b 1
)
"%BIN_DIR%\fd.exe" --version >nul 2>nul
if errorlevel 1 (
    echo 错误: fd.exe 下载后运行验证失败
    exit /b 1
)
for /f "delims=" %%v in ('"%BIN_DIR%\fd.exe" --version ^| findstr /b "fd"') do echo   就绪: %%v

rem --- 3. 验证 ---
:verify
echo === [3/3] 验证 ===
set "OK=1"
if exist "%MCP_FS_DIR%\node_modules\@modelcontextprotocol\sdk" (
    echo [OK] node_modules\@modelcontextprotocol\sdk 已就绪
) else (
    echo [失败] @modelcontextprotocol/sdk 未安装成功
    set "OK=0"
)
if exist "%ST_ROOT%plugins\SillyTavern-MCP-Server\dist\index.js" (
    echo [OK] MCP-Server 插件 dist 已就绪
) else (
    echo [失败] MCP-Server 插件 dist 缺失
    set "OK=0"
)
if exist "%ST_ROOT%plugins\agent-access\index.js" (
    echo [OK] agent-access 插件已就绪
) else (
    echo [失败] agent-access 插件缺失
    set "OK=0"
)
if exist "%ST_ROOT%scripts\mcp-dc-wrapper.js" (
    echo [OK] mcp-dc-wrapper.js 已就绪
) else (
    echo [失败] mcp-dc-wrapper.js 缺失
    set "OK=0"
)
if exist "%BIN_DIR%\rg.exe" (
    "%BIN_DIR%\rg.exe" --version >nul 2>nul
    if not errorlevel 1 (echo [OK] rg.exe 可运行) else (echo [失败] rg.exe 不可运行 & set "OK=0")
) else (
    echo [失败] rg.exe 缺失
    set "OK=0"
)
if exist "%BIN_DIR%\fd.exe" (
    "%BIN_DIR%\fd.exe" --version >nul 2>nul
    if not errorlevel 1 (echo [OK] fd.exe 可运行) else (echo [失败] fd.exe 不可运行 & set "OK=0")
) else (
    echo [失败] fd.exe 缺失
    set "OK=0"
)

if not "%OK%"=="1" (
    echo [失败] 依赖不完整，请检查上方错误信息
    exit /b 1
)

rem --- 白名单路径提示 ---
echo.
echo === 重要：检查以下文件中的白名单路径（clone 后按你的环境修改） ===
echo   1) data\default-user\mcp_settings.json → filesystem 的 args（当前可能为 H:/workspace）
echo      改为你的工作区绝对路径，如 D:/workspace
echo   2) plugins\agent-access\config.json → roots（当前可能含 H:/workspace）
echo      同上改为你的工作区绝对路径
echo.
echo === 完成。现在可以运行 Start.bat 启动酒馆 ===

endlocal
