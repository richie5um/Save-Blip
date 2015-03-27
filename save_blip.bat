@echo off
REM ##########################################
REM This program is provided on an 'as-is' basis.
REM No support is offered for any defects found 
REM in this program.
REM No liability is accepted for any damage 
REM caused through the use of this program.
REM ##########################################

REM ##########################################
REM
REM ##########################################

REM ##########################################
REM  
REM  This code relies on two programs other than
REM  the standard Windows command set, such as 
REM  mkdir, rmdir, del.
REM 
REM  These two commands are: wkhtmltopdf and wget
REM 
REM  You will need to install version 0.12.2.1 for
REM  the print out to be faithful to the Blip page
REM  layout. You can download that version from
REM  http://wkhtmltopdf.org/downloads.html
REM
REM  You will also need to install wget. You can
REM  download the windows version from here:
REM  http://sourceforge.net/projects/gnuwin32/files/wget/1.11.4-1/wget-1.11.4-1-setup.exe/download
REM  
REM  Bear in mind that you have to trust that this
REM  download is safe!
REM 
REM #############################################

if -%4- == -- (
	call :showusage
	exit /b
)

set base_url=https://www.polaroidblipfoto.com
set user=%1
set comments=%2
set headersandfooters=%3
set previous_url=%4
set final_url=%5
set docomments="var x = 0;"
set headerfooterjs="var x = 0;"
set tmp_file=.\blip_wget_tmp_file.tmp
set output_log_file=.\output_log.txt
set result_log_file=.\wkhtml_result.txt
echo  > %output_log_file%
echo  > %result_log_file%

if -%final_url%- == -- (
	set final_url=%base_url%
)

if not -%comments%- == -y- (
	if not -%comments%- == -n- (
		echo Comments option must be y or n
		call :showusage %0
		exit /b
	)
)

if -%comments%- == -y- (
        set docomments="load_comments.scrollIntoView(true); load_comments.click();"
)

if not -%headersandfooters%- == -y- (
	if not -%headersandfooters%- == -n- (
		echo Headers and footers option must be y or n
		call :showusage %0
		exit /b
	)
)

if -%headersandfooters%- == -n- (
        set headerfooterjs="var c = document.getElementsByClassName('topbar').item(0) ; var p = c.parentNode; p.removeChild(c); c = document.getElementsByClassName('footer').item(0) ; var p = c.parentNode; p.removeChild(c);"
)


REM  Use a 2 second delay between getting entries.
REM  Note - producing the PDF may take several second though.

set delay=2
set blip_entries_dir=.\blip_entries

if exist %blip_entries_dir% goto :blipDirExists

echo Making directory %blip_entries_dir%
mkdir %blip_entries_dir%
if %errorlevel% neq 0 (
	echo Failed to make directory %blip_entries_dir%
	exit /b
)

:blipDirExists

REM Check that wkhtml and wget are installed

echo Checking wkhtmltopdf and wget are installed...

REM Check if we are running something later than XP
REM systeminfo is only available on Vista and above
REM so a non-existent command will result in a non-zero
REM errorlevel

systeminfo > nul 2>&1
if %errorlevel% equ 0 goto :notXP

call :checkWkhtmlXP
call :checkWgetXP
goto :installChecks

:notXP

call :getWindowsDrive
call :checkWkhtmlNotXP %windrive%
call :checkWgetNotXP %windrive%

:installChecks

if "-%wkhtml%-" == -- (
	echo Please download and install wkhtmltopdf >> %output_log_file%
	exit /b
)

if "-%wget%-" == -- (
	echo Please download and install wget >> %output_log_file%
	exit /b
)

REM Start by printing a front cover

echo Printing front cover for user %user%....
"%wkhtml%" -q --run-script "console.log(document.readyState);" --run-script %headerfooterjs% %base_url%/%user% %blip_entries_dir%\front_cover.pdf 2>> %output_log_file% 


:main_loop
if %previous_url% == %final_url% goto :endofmainloop

"%wget%" --no-check-certificate -q -O %tmp_file% %previous_url%  2>> %output_log_file% 

for /f "delims=" %%i in ( 'findstr JournalGallery %tmp_file%' ) do set line=%%i
for /f "tokens=3 delims=:" %%i in ( 'echo %line%' ) do set part=%%i

set "c=%part: =_%
set "d=%c:"=%"
set "entry_date=%d:_items=%"

echo Printing entry %entry_date%.... 
call :printloop

for /f "delims=" %%i in ( 'findstr "title=.Previous." %tmp_file%' ) do set "line=%%i"
set "a=%line:<=%"
set "b=%a:>=%"
set "c=%b:"= %"
for /f "tokens=3 delims= " %%i in ( 'echo %c%' ) do set "last_entry=%%i"

set "previous_url=%base_url%%last_entry%"

del %tmp_file%

call :sleep
goto :main_loop

:endofmainloop

REM Exit here
exit /b

REM Functions here

:printloop
setlocal
:commentloop
set "line="
"%wkhtml%" %previous_url% --no-stop-slow-scripts --run-script %headerfooterjs% --run-script "console.log(document.readyState);" --run-script %docomments% --javascript-delay 2000 --debug-javascript %blip_entries_dir%\%entry_date%.pdf 2>> %result_log_file% 

for /f "delims=" %%i in ( 'findstr "interactive complete" %result_log_file%' ) do set "line=%%i"
del %result_log_file%
set "result=%line: =%"
set "result=%result::=%"
set "result=%result:*Warning1=%"

if not -%result%- == -- goto :success
echo Retrying....
call :sleep
goto :commentloop

:success
endlocal
REM Return from call
exit /b

:sleep
setlocal
REM fake 1 sec delay
ping -n 1 127.0.0.1 >nul 
endlocal
REM Return from call
exit /b

:getWindowsDrive
setlocal
systeminfo 2>&1 | find "Windows Directory" > %tmp_file%
for /f "tokens=3 delims= " %%i in ( 'type %tmp_file% ') do set tmp=%%i
for /f "tokens=1 delims=:" %%i in ( 'echo %tmp%' ) do set result=%%i
del %tmp_file%
endlocal & set "windrive=%result%"
exit /b

:checkWkhtmlXP
setlocal
for /f "delims= skip=2" %%i in ( 'reg query HKEY_LOCAL_MACHINE\SOFTWARE\wkhtmltopdf /v PdfPath' ) do set "result=%%i"
set "result=%result:~19%"
endlocal & set "wkhtml=%result%"
exit /b

:checkWkhtmlNotXP
setlocal
for /f "delims=" %%i in ( 'where /R %1%:\ wkhtmltopdf.exe' ) do set "result=%%i"
endlocal & set "wkhtml=%result%"
exit /b

:checkWgetXP
setlocal
for /f "delims= skip=2" %%i in ( 'reg query HKEY_LOCAL_MACHINE\SOFTWARE\GnuWin32\Wget\1.11.4-1\setup /v InstallPath' ) do set "result=%%i"
set "result=%result:~23%\bin\wget"
endlocal & set "wget=%result%"
exit /b

:checkWgetNotXP
setlocal
for /f "delims=" %%i in ( 'where /R %1%:\ wget.exe' ) do set "result=%%i"
endlocal & set "wget=%result%"
exit /b

:showusage
setlocal
echo There are two forms of usage.
echo 	The first prints all entries in reverse chronological order given an initial entry
echo.
echo 	Usage: 
echo 	%1 blip_username with_comments with_headers_and_footers url_of_first_blip_to_print
echo.
echo 	Example:
echo 	%1 yourusername y y https://www.polaroidblipfoto.com/entry/1234567890
echo.
echo 	The second prints entries from an initial entry up to, but not including, a final entry in reverse chronological order.
echo 	No check is made that the last entry is before the first.
echo.
echo 	Usage: 
echo 	%1 blip_username with_comments with_headers_and_footers url_of_first_blip_to_print url_of_final_blip_to_stop_at
echo.
echo 	Example:
echo 	%1 yourusername n y https://www.polaroidblipfoto.com/entry/4321 https://www.polaroidblipfoto.com/entry/1234
endlocal
exit /b
