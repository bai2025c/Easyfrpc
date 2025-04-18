@echo off
setlocal enabledelayedexpansion

rem 设置路径变量
set "basese_dir=C:\Users\Laptop\Documents\Klei\DoNotStarveTogether"
set "backupse_dir=%basese_dir%\serverbak"
set "logse_file=%basese_dir%\backupse_log.txt"

:main
    cls  & rem 清屏提升交互体验[4](@ref)
    echo 请选择操作：
    echo  [1] 备份系统
    echo  [2] 恢复备份
    echo  [3] 返回主菜单
    echo  [4] 退出程序
    echo.

:input_loop
    set /p "choice=请输入选项（1-3）: "
    if "%choice%"=="" (
        echo 错误：未输入内容
        goto :input_loop
    )

    if "%choice%"=="1" (
        call :backup
    ) else if "%choice%"=="2" (
        call :restore
    ) else if "%choice%"=="3" (
	call :back
    ) else if "%choice%"=="4" (
	    goto :eof
    ) else (
        echo 错误：无效选项 "%choice%"，请重新输入！
        goto :input_loop
    )
:back
	explorer.exe "Easyfrpc.bat" 
	exit /b

:eof
	exit /b
:backup
    echo 用户选择了备份操作。

    rem 创建必要目录
    if not exist "%backupse_dir%" mkdir "%backupse_dir%"
    if not exist "%logse_file%" type nul > "%logse_file%"

    rem 获取时间戳
    for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "datetime=%%a"
    set "timestamp=%datetime:~0,14%"

    rem 开始备份流程
    echo [%date% %time%] 开始备份操作 >> "%logse_file%"
    echo 正在扫描集群目录...

    rem 遍历所有Cluster目录
    for /d %%c in ("%basese_dir%\Cluster_*") do (
        set "cluster=%%~nxc"
        echo [%date% %time%] 正在处理集群目录: !cluster! >> "%logse_file%"
        echo 正在处理集群: !cluster!

        rem 处理Caves和Master目录
        for %%t in ("Caves" "Master") do (
            set "type_dir=%%~t"
            set "source_path=%%c\!type_dir!\server.ini"
            set "target_path=%backupse_dir%\!cluster!\!type_dir!\"

            rem 创建目标目录并复制文件
            if exist "!source_path!" (
                mkdir "!target_path!" >nul 2>&1
                xcopy /y "!source_path!" "!target_path!" >nul
                if !errorlevel! equ 0 (
                    echo [%date% %time%] 已备份: !source_path! >> "%logse_file%"
                    echo 已备份: !type_dir!\server.ini
                ) else (
                    echo [%date% %time%] [错误] 备份失败: !source_path! >> "%logse_file%"
                    echo [错误] !type_dir!\server.ini 备份失败
                )
            ) else (
                echo [%date% %time%] [警告] 文件不存在: !source_path! >> "%logse_file%"
                echo [警告] !type_dir!\server.ini 不存在
            )
        )
    )

    rem 创建压缩包
    set "zip_file=%basese_dir%\bak0000000.zip.bak"

    rem 创建/覆盖压缩包
    echo [%date% %time%] 正在创建压缩包: %zip_file% >> "%logse_file%"
    echo 正在创建压缩包...
    "7z.exe" a -y -r "%zip_file%" "%backupse_dir%\*" >> "%logse_file%" 2>&1

    rem 结果检查
    if exist "%zip_file%" (
        echo [%date% %time%] 备份已覆盖至: %zip_file% >> "%logse_file%"
        echo 备份成功覆盖: %zip_file%
    ) else (
        echo [%date% %time%] [错误] 压缩包创建失败 >> "%logse_file%"
        echo [错误] 压缩包创建失败
    )

    rem 获取当前日期并格式化为 YYYYMMDD
    for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
    rem 获取规范化的时间戳（格式：YYYYMMDDHHmmss）
    for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"

    rem 提取日期时间各部分（强制补零）
    set "YYYY=!dt:~0,4!"
    set "MM=!dt:~4,2!"
    set "DD=!dt:~6,2!"
    set "HH=!dt:~8,2!"
    set "mm=!dt:~10,2!"
    set "ss=!dt:~12,2!"

    rem 构建文件名（正确拼接变量）
    set "newfilename=server!YYYY!!MM!!DD!!HH!!mm!!ss!.zip.bak"

    rem 验证输出
    echo 生成的文件名：!newfilename!
    rem 重命名文件
    ren "%basese_dir%\bak0000000.zip.bak" "%newfilename%"

    echo 文件已重命名为 %newfilename%

    if exist "%basese_dir%\%newfilename%" (
        echo [%date% %time%] 备份已保存至: %zip_file% >> "%logse_file%"
        echo 备份成功创建: %zip_file%
    ) else (
        echo [%date% %time%] [错误] 压缩包创建失败 >> "%logse_file%"
        echo [错误] 压缩包创建失败
    )

    rem 清理临时文件（可选）
    rd /s /q "%backupse_dir%"
    del /f /s /q %basese_dir%\bak0000000.zip.bak

    echo [%date% %time%] 备份操作完成 >> "%logse_file%"
    echo 所有操作已完成
pause
goto :main


:restore
    set /p "restore_date=请输入要恢复的文件名-需含日期）："
    set "restore_zip_file=%basese_dir%\!restore_date!"
    if exist "%restore_zip_file%" (
        echo 正在解压 %restore_date% 的备份压缩包...
        "7z.exe" x -y "%restore_zip_file%" -o"%backupse_dir%" >> "%logse_file%" 2>&1
        if exist "%backupse_dir%\%restore_date%" (
            echo 正在恢复 %restore_date% 的备份...
            for /d %%c in ("%basese_dir%\Cluster_*") do (
                set "cluster=%%~nxc"
                for %%t in ("Caves" "Master") do (
                    set "type_dir=%%~t"
                    set "source_path=%backupse_dir%\%restore_date%\!cluster!\!type_dir!\server.ini"
                    set "target_path=%%c\!type_dir!"
                    if exist "!source_path!" (
                        xcopy /y "!source_path!" "!target_path!" >nul
                        if !errorlevel! equ 0 (
                            echo [%date% %time%] 已恢复: !source_path! >> "%logse_file%"
                            echo 已恢复: !type_dir!\server.ini
                        ) else (
                            echo [%date% %time%] [错误] 恢复失败: !source_path! >> "%logse_file%"
                            echo [错误] !type_dir!\server.ini 恢复失败
                        )
                    ) else (
                        echo [%date% %time%] [警告] 文件不存在: !source_path! >> "%logse_file%"
                        echo [警告] !type_dir!\server.ini 不存在
                    )
                )
            )
            echo 恢复操作完成。
        ) else (
            echo 指定文件的备份解压失败。
        )
    ) else (
        echo 指定文件的备份压缩包不存在。

    )
pause

goto :main

