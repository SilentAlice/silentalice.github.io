@echo off
title SilentMing's Blog - Build & Deploy
cd /d D:\Codes\blog
echo ==========================================
echo  Building blog ... (source reads from Obsidian vault)
echo ==========================================
call npx hexo clean
if errorlevel 1 goto :err
call npx hexo generate
if errorlevel 1 goto :err
echo.
echo ==========================================
echo  Deploying to GitHub Pages ...
echo ==========================================
call npx hexo deploy
if errorlevel 1 goto :err
echo.
echo ==========================================
echo  DONE! https://silentming.net
echo ==========================================
pause
exit /b 0

:err
echo.
echo  [ERROR] Build or deploy failed, see output above.
pause
exit /b 1