@echo off
rem --- '4_sm_auto-collect.cmd' v2.9 by KdL (2022.11.27)

set TIMEOUT=1
set PROJECT=ocm_sm
set PARKING=fw
set OUTPUT=output_files\
set CURSEED=Not detected
set SEEDENV=%PROJECT%_synthesis_seed.env
set EPCSDEV=EPCS64
if "%1"=="" color 1f&title AUTO-COLLECT for %PROJECT%
if not exist %PROJECT%_device.env goto err_init
set DEVSTR=&set /P DEVICE=<%PROJECT%_device.env
if "%DEVICE%"=="smx" set DEVSTR= for SM-X
if "%DEVICE%"=="sx2" set DEVSTR= for SX-2
if "%1"=="--no-wait" color 1f&title Task "%~dp0%PROJECT%.qpf"%DEVSTR%
if not exist "%QUARTUS_ROOTDIR%\common\devinfo\cycloneive" goto err_quartus
if not exist src_addons\ goto err_msg
if exist %SEEDENV% set /P CURSEED=<%SEEDENV%

:auto_collect
if "%1"=="" echo.&echo Press any key to start building...&pause >nul 2>nul
cls&echo.&echo Please wait...&echo.&if "%1"=="" echo Output path: "%~dp0%PARKING%\"&echo.
rem ---------------cleanup----------------
call 2_sm_finalize.cmd --no-wait
call 3_sm_collect.cmd --no-wait
rem --------------------------------------
if exist "%QUARTUS_ROOTDIR%\bin64" set BIT=64
set STARTDATE=%DATE%
set STARTTIME=%TIME%
echo ^>^> Compile Design
echo   ^>^> Phase 1 - Analysis ^& Synthesis
set PHASE1="%QUARTUS_ROOTDIR%\bin%BIT%\quartus_map.exe" %PROJECT%.qpf
%PHASE1% >nul 2>nul
echo   ^>^> Phase 2 - Fitter (Place ^& Route)
set PHASE2="%QUARTUS_ROOTDIR%\bin%BIT%\quartus_fit.exe" %PROJECT%.qpf
%PHASE2% >nul 2>nul
rem ---------------retry------------------
if "%1"=="--no-wait" if not exist %OUTPUT%%PROJECT%.fit.summary echo              - Fitter (Second attempt)
if "%1"=="--no-wait" if not exist %OUTPUT%%PROJECT%.fit.summary %PHASE1% >nul 2>nul&%PHASE2% >nul 2>nul
if "%1"=="--no-wait" if not exist %OUTPUT%%PROJECT%.fit.summary echo              - Fitter (Final attempt)
if "%1"=="--no-wait" if not exist %OUTPUT%%PROJECT%.fit.summary %PHASE1% >nul 2>nul&%PHASE2% >nul 2>nul
rem --------------------------------------
echo   ^>^> Phase 3 - Assembler (Generate programming files)
"%QUARTUS_ROOTDIR%\bin%BIT%\quartus_asm.exe" %PROJECT%.qpf >nul 2>nul
echo   ^>^> Phase 4 - Convert programming files (%EPCSDEV% Device)
set CONFIG=%PROJECT%_512k_dual_epbios_backslash
if not exist %PROJECT%_512k.cof copy /Y %CONFIG%.cof %PROJECT%_512k.cof >nul 2>nul
"%QUARTUS_ROOTDIR%\bin%BIT%\quartus_cpf.exe" -c %PROJECT%_512k.cof >nul 2>nul
del %PROJECT%_512k.cof >nul 2>nul
set ENDTIME=%TIME%
rem ---------------collect----------------
call 2_sm_finalize.cmd --no-wait
call 3_sm_collect.cmd --no-wait
if "%1"=="" rd /S /Q %OUTPUT% >nul 2>nul
rem --------------------------------------
for /F "tokens=1-4 delims=:.," %%a in ("%STARTTIME%") do (
   set /A "start=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
)
for /F "tokens=1-4 delims=:.," %%a in ("%ENDTIME%") do (
   set /A "end=(((%%a*60)+1%%b %% 100)*60+1%%c %% 100)*100+1%%d %% 100"
)
set /A elapsed=end-start
set /A hh=elapsed/(60*60*100), rest=elapsed%%(60*60*100), mm=rest/(60*100), rest%%=60*100, ss=rest/100
if exist %PARKING%\fit_summary.log (echo Synthesis Seed : %CURSEED%)>>%PARKING%\fit_summary.log
if "%STARTDATE%" == "%DATE%" if exist %PARKING%\fit_summary.log (echo Building time : %hh%h %mm%m %ss%s)>>%PARKING%\fit_summary.log
cls&if not exist %PARKING%\fit_summary.log goto not_done
echo.&echo All done!&echo.&type %PARKING%\fit_summary.log
goto timer

:not_done
if "%1"=="" color f0
echo.&echo Building failed!
if exist %PARKING% if not exist %PARKING%\ ren %PARKING% "## BUILDING FAILED ##.log" >nul 2>nul
rem.>>"## BUILDING FAILED ##.log"
if "%1"=="" goto timer

:killall
taskkill /f /im conhost.exe>nul 2>nul
exit

:err_init
if "%1"=="" color f0
echo.&echo Please initialize a device first!
goto timer

:err_quartus
if "%1"=="" color f0
echo.&echo Quartus Prime was not found or unsupported device!
goto timer

:err_msg
if "%1"=="" color f0
echo.&echo 'src_addons\' not found!

:timer
waitfor /T %TIMEOUT% pause >nul 2>nul

:quit
rem if "%1"=="" call 5_sm_fw-upload.cmd --auto-collect --full-erase
exit
