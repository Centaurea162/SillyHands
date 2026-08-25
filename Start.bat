@echo off
rem SillyTavern 启动脚本（Win10 原生运行，监听 0.0.0.0:8000，手机可访问 http://<本机IP>:8000）
cd /d "%~dp0"
node server.js
