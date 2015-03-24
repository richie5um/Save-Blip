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

if -%3- == -- (
	echo There are two forms of usage.
	echo 	The first prints all entries in reverse chronological order
	echo 	given an initial entry
	echo 
	echo 	Usage: blip_username with_comments url_of_first_blip_to_print
	echo 	Example:
	echo 	%0 yourusername y https://www.polaroidblipfoto.com/entry/1234567890 
	echo 
	echo 	The second prints entries from an initial entry up to, but not
	echo 	including, a final entry in reverse chronological order.
	echo 	No check is made that the last entry is before the first.
	echo 
	echo 	Usage: blip_username with_comments url_of_first_blip_to_print url_of_final_blip_to_stop_at"
	echo 	Example:
	echo 	%0 yourusername n https://www.polaroidblipfoto.com/entry/4321 https://www.polaroidblipfoto.com/entry/1234
	exit /b
)

set base_url=https://www.polaroidblipfoto.com
set user=%1
set comments=%2
set previous_url=%3
set final_url=%4
set tmp_file=.\blip_wget_tmp_file.tmp
set output_log_file=.\output_log.txt
set result_log_file=.\wkhtml_result.txt
echo "" > %output_log_file%
echo "" > %result_log_file%

if -%final_url%- == -- (
	set final_url=%base_url%
)

if not -%comments%- == -y- (
	if not -%comments%- == -n- (
		echo Comments option must be y or n
		exit /b
	)
)

REM  Use a 2 second delay between getting entries.
REM  Note - producing the PDF may take several second though.

set delay=2
set blip_entries_dir=.\blip_entries


if not exist %blip_entries_dir% (
	echo Making directory %blip_entries_dir%
	mkdir %blip_entries_dir%
	if %errorlevel% neq 0 (
		echo Failed to make directory %blip_entries_dir%
		exit /b
	)
)

REM Check that wkhtml and wget are installed

for /f "delims= skip=2" %%i in ( 'reg query HKEY_LOCAL_MACHINE\SOFTWARE\wkhtmltopdf /v PdfPath' ) do set "wkhtml=%%i"
set "wkhtml=%wkhtml:~19%"

if "-%wkhtml%-" == -- (
	echo Please download and install "%wkhtml%" >> %output_log_file%
	exit /b
)


for /f "delims= skip=2" %%i in ( 'reg query HKEY_LOCAL_MACHINE\SOFTWARE\GnuWin32\Wget\1.11.4-1\setup /v InstallPath' ) do set "wget=%%i"
set "wget=%wget:~23%\bin\wget"

if "-%wget%-" == -- (
	echo Please download and install wget >> %output_log_file%
	exit /b
)

REM Start by printing a front cover

echo Printing front cover for user %user%....
"%wkhtml%" -q %base_url%/%user% %blip_entries_dir%\front_cover.pdf 2>> %output_log_file% 


:main_loop
if %previous_url% == %final_url% goto :endofmainloop

"%wget%" --no-check-certificate -q -O %tmp_file% %previous_url%  2>> %output_log_file% 

for /f "delims=" %%i in ( 'findstr JournalGallery %tmp_file%' ) do set line=%%i
for /f "tokens=3 delims=:" %%i in ( 'echo %line%' ) do set part=%%i

set "c=%part: =_%
set "d=%c:"=%"
set "entry_date=%d:_items=%"

echo Printing entry %entry_date%.... 
if -%comments%- == -n- (
	call :nocomment
) 

if -%comments%- == -y- (
	call :comment
)

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
:nocomment
setlocal
"%wkhtml%" -q %previous_url%  "%blip_entries_dir%\%entry_date%.pdf" 2>> %output_log_file% 
endlocal
REM Return from call
exit /b

:comment
setlocal
:commentloop
set "line="
"%wkhtml%" %previous_url% --no-stop-slow-scripts --run-script "console.log(document.readyState);" --run-script "document.onload = load_comments.click();" --run-script "load_comments.click();" --run-script "load_comments.scrollIntoView(true);" --run-script "load_comments.click();" --javascript-delay 2000 --debug-javascript %blip_entries_dir%\%entry_date%.pdf 2>> %result_log_file% 

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
