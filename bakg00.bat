@echo off
setlocal enabledelayedexpansion

rem ����·������
set "basese_dir=C:\Users\Laptop\Documents\Klei\DoNotStarveTogether"
set "backupse_dir=%basese_dir%\serverbak"
set "logse_file=%basese_dir%\backupse_log.txt"

:main
    cls  & rem ����������������[4](@ref)
    echo ��ѡ�������
    echo  [1] ����ϵͳ
    echo  [2] �ָ�����
    echo  [3] �������˵�
    echo  [4] �˳�����
    echo.

:input_loop
    set /p "choice=������ѡ�1-3��: "
    if "%choice%"=="" (
        echo ����δ��������
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
        echo ������Чѡ�� "%choice%"�����������룡
        goto :input_loop
    )
:back
	explorer.exe "Easyfrpc.bat" 
	exit /b

:eof
	exit /b
:backup
    echo �û�ѡ���˱��ݲ�����

    rem ������ҪĿ¼
    if not exist "%backupse_dir%" mkdir "%backupse_dir%"
    if not exist "%logse_file%" type nul > "%logse_file%"

    rem ��ȡʱ���
    for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "datetime=%%a"
    set "timestamp=%datetime:~0,14%"

    rem ��ʼ��������
    echo [%date% %time%] ��ʼ���ݲ��� >> "%logse_file%"
    echo ����ɨ�輯ȺĿ¼...

    rem ��������ClusterĿ¼
    for /d %%c in ("%basese_dir%\Cluster_*") do (
        set "cluster=%%~nxc"
        echo [%date% %time%] ���ڴ���ȺĿ¼: !cluster! >> "%logse_file%"
        echo ���ڴ���Ⱥ: !cluster!

        rem ����Caves��MasterĿ¼
        for %%t in ("Caves" "Master") do (
            set "type_dir=%%~t"
            set "source_path=%%c\!type_dir!\server.ini"
            set "target_path=%backupse_dir%\!cluster!\!type_dir!\"

            rem ����Ŀ��Ŀ¼�������ļ�
            if exist "!source_path!" (
                mkdir "!target_path!" >nul 2>&1
                xcopy /y "!source_path!" "!target_path!" >nul
                if !errorlevel! equ 0 (
                    echo [%date% %time%] �ѱ���: !source_path! >> "%logse_file%"
                    echo �ѱ���: !type_dir!\server.ini
                ) else (
                    echo [%date% %time%] [����] ����ʧ��: !source_path! >> "%logse_file%"
                    echo [����] !type_dir!\server.ini ����ʧ��
                )
            ) else (
                echo [%date% %time%] [����] �ļ�������: !source_path! >> "%logse_file%"
                echo [����] !type_dir!\server.ini ������
            )
        )
    )

    rem ����ѹ����
    set "zip_file=%basese_dir%\bak0000000.zip.bak"

    rem ����/����ѹ����
    echo [%date% %time%] ���ڴ���ѹ����: %zip_file% >> "%logse_file%"
    echo ���ڴ���ѹ����...
    "7z.exe" a -y -r "%zip_file%" "%backupse_dir%\*" >> "%logse_file%" 2>&1

    rem ������
    if exist "%zip_file%" (
        echo [%date% %time%] �����Ѹ�����: %zip_file% >> "%logse_file%"
        echo ���ݳɹ�����: %zip_file%
    ) else (
        echo [%date% %time%] [����] ѹ��������ʧ�� >> "%logse_file%"
        echo [����] ѹ��������ʧ��
    )

    rem ��ȡ��ǰ���ڲ���ʽ��Ϊ YYYYMMDD
    for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
    rem ��ȡ�淶����ʱ�������ʽ��YYYYMMDDHHmmss��
    for /f "tokens=2 delims==" %%a in ('wmic os get localdatetime /value') do set "dt=%%a"

    rem ��ȡ����ʱ������֣�ǿ�Ʋ��㣩
    set "YYYY=!dt:~0,4!"
    set "MM=!dt:~4,2!"
    set "DD=!dt:~6,2!"
    set "HH=!dt:~8,2!"
    set "mm=!dt:~10,2!"
    set "ss=!dt:~12,2!"

    rem �����ļ�������ȷƴ�ӱ�����
    set "newfilename=server!YYYY!!MM!!DD!!HH!!mm!!ss!.zip.bak"

    rem ��֤���
    echo ���ɵ��ļ�����!newfilename!
    rem �������ļ�
    ren "%basese_dir%\bak0000000.zip.bak" "%newfilename%"

    echo �ļ���������Ϊ %newfilename%

    if exist "%basese_dir%\%newfilename%" (
        echo [%date% %time%] �����ѱ�����: %zip_file% >> "%logse_file%"
        echo ���ݳɹ�����: %zip_file%
    ) else (
        echo [%date% %time%] [����] ѹ��������ʧ�� >> "%logse_file%"
        echo [����] ѹ��������ʧ��
    )

    rem ������ʱ�ļ�����ѡ��
    rd /s /q "%backupse_dir%"
    del /f /s /q %basese_dir%\bak0000000.zip.bak

    echo [%date% %time%] ���ݲ������ >> "%logse_file%"
    echo ���в��������
pause
goto :main


:restore
    set /p "restore_date=������Ҫ�ָ����ļ���-�躬���ڣ���"
    set "restore_zip_file=%basese_dir%\!restore_date!"
    if exist "%restore_zip_file%" (
        echo ���ڽ�ѹ %restore_date% �ı���ѹ����...
        "7z.exe" x -y "%restore_zip_file%" -o"%backupse_dir%" >> "%logse_file%" 2>&1
        if exist "%backupse_dir%\%restore_date%" (
            echo ���ڻָ� %restore_date% �ı���...
            for /d %%c in ("%basese_dir%\Cluster_*") do (
                set "cluster=%%~nxc"
                for %%t in ("Caves" "Master") do (
                    set "type_dir=%%~t"
                    set "source_path=%backupse_dir%\%restore_date%\!cluster!\!type_dir!\server.ini"
                    set "target_path=%%c\!type_dir!"
                    if exist "!source_path!" (
                        xcopy /y "!source_path!" "!target_path!" >nul
                        if !errorlevel! equ 0 (
                            echo [%date% %time%] �ѻָ�: !source_path! >> "%logse_file%"
                            echo �ѻָ�: !type_dir!\server.ini
                        ) else (
                            echo [%date% %time%] [����] �ָ�ʧ��: !source_path! >> "%logse_file%"
                            echo [����] !type_dir!\server.ini �ָ�ʧ��
                        )
                    ) else (
                        echo [%date% %time%] [����] �ļ�������: !source_path! >> "%logse_file%"
                        echo [����] !type_dir!\server.ini ������
                    )
                )
            )
            echo �ָ�������ɡ�
        ) else (
            echo ָ���ļ��ı��ݽ�ѹʧ�ܡ�
        )
    ) else (
        echo ָ���ļ��ı���ѹ���������ڡ�

    )
pause

goto :main

