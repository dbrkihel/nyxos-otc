@echo off
REM Roda o cliente sob o CDB e despeja a pilha na segunda excecao (o crash de
REM verdade), gravando em crash-stack.txt na raiz do repo.
REM
REM Usa kb simples em vez de kp: o unwind de parametros costuma falhar em build
REM otimizado, e kb ainda resolve os nomes de funcao. O .reload antes garante
REM que os simbolos do proprio exe estejam carregados.
REM
REM Uso (a partir da raiz do repo):
REM   tools\crash-cdb.cmd                    usa NyxosClient.exe
REM   tools\crash-cdb.cmd build-debug\NyxosClient.exe

setlocal
set REPO=%~dp0..
set EXE=%~1
if "%EXE%"=="" set EXE=%REPO%\NyxosClient.exe

if not exist "%EXE%" (
    echo Executavel nao encontrado: %EXE%
    echo Compile primeiro com compile-cmake.ps1.
    exit /b 1
)

REM O CDB vem com o WinDbg. Se voce instalou pela Store, o caminho tem versao no
REM nome, entao procuramos em vez de fixar.
set CDB=
for /f "delims=" %%i in ('where cdb.exe 2^>nul') do set CDB=%%i
if "%CDB%"=="" (
    for /f "delims=" %%i in ('dir /b /s "%ProgramFiles%\WindowsApps\Microsoft.WinDbg_*\amd64\cdb.exe" 2^>nul') do set CDB=%%i
)
if "%CDB%"=="" (
    echo cdb.exe nao encontrado. Instale o WinDbg ou ponha o cdb.exe no PATH.
    exit /b 1
)

echo CDB: %CDB%
echo EXE: %EXE%

pushd "%REPO%"
"%CDB%" -g -c "g; .echo ===CRASH===; .reload; kb 100; .echo ===END===; q" "%EXE%" > "%REPO%\crash-stack.txt" 2>&1
popd

echo Pilha gravada em %REPO%\crash-stack.txt
endlocal
