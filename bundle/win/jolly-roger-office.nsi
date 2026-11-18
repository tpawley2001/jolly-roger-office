; Jolly Roger Office: Windows installer (NSIS 3). Built on Linux by bundle/build-windows.sh.
; Per-user install (no admin): %LOCALAPPDATA%\Programs\Jolly Roger Office.
; File types are added to "Open with" only; existing default apps (Word, Excel...) are left alone.

Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!ifndef VERSION
  !define VERSION "0.1.0"
!endif
!ifndef STAGE
  !error "pass -DSTAGE=<staged dir>"
!endif
!ifndef OUTFILE
  !define OUTFILE "JollyRogerOffice-Setup-${VERSION}.exe"
!endif

!define NAME "Jolly Roger Office"
!define PUBLISHER "Hillyard Tech"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\JollyRogerOffice"
!define PROGID_PREFIX "JollyRogerOffice"

Name "${NAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${NAME}"
InstallDirRegKey HKCU "Software\Hillyard Tech\${NAME}" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma
BrandingText "${NAME} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${NAME}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${NAME} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "Hillyard Tech. Based on the ArtCraft Crafting Apps (MIT OR Apache-2.0)"

!define MUI_ICON "${STAGE}\icons\jolly-roger-office.ico"
!define MUI_UNICON "${STAGE}\icons\jolly-roger-office.ico"
!define MUI_WELCOMEPAGE_TITLE "Ahoy! Welcome aboard ${NAME}"
!define MUI_WELCOMEPAGE_TEXT "This installs ${NAME} ${VERSION}: Captain's Log (documents), Plunder Ledger (spreadsheets) and Broadside (presentations).$\r$\n$\r$\nIt installs for your account only and doesn't need administrator rights."
!define MUI_FINISHPAGE_RUN "$INSTDIR\jolly-roger-office.exe"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${NAME}"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${STAGE}\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

; ProgID for one app: "Open with" entry, icon and open command.
!macro ProgId ID LABEL EXE ICO
  WriteRegStr HKCU "Software\Classes\${PROGID_PREFIX}.${ID}" "" "${LABEL}"
  WriteRegStr HKCU "Software\Classes\${PROGID_PREFIX}.${ID}\DefaultIcon" "" "$INSTDIR\icons\${ICO},0"
  WriteRegStr HKCU "Software\Classes\${PROGID_PREFIX}.${ID}\shell\open\command" "" '"$INSTDIR\${EXE}" "%1"'
  WriteRegStr HKCU "Software\Classes\Applications\${EXE}" "FriendlyAppName" "${LABEL}"
!macroend
!macro OpenWith EXT ID
  WriteRegStr HKCU "Software\Classes\.${EXT}\OpenWithProgids" "${PROGID_PREFIX}.${ID}" ""
!macroend
!macro UnOpenWith EXT ID
  DeleteRegValue HKCU "Software\Classes\.${EXT}\OpenWithProgids" "${PROGID_PREFIX}.${ID}"
!macroend

; Stop if a suite program is running: its .exe is locked, and a silent install would otherwise
; skip it without a word (a stale launcher was left behind that way). Closes nothing itself.
!macro EnsureClosed EXE LABEL
  !define _EC ${__LINE__}
  IfFileExists "$INSTDIR\${EXE}" 0 ec_done_${_EC}
  ec_retry_${_EC}:
  ClearErrors
  FileOpen $0 "$INSTDIR\${EXE}" a
  IfErrors 0 ec_ok_${_EC}
  MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "${LABEL} is open. Close it, then click Retry." /SD IDCANCEL IDRETRY ec_retry_${_EC}
  SetErrorLevel 3
  Abort "${LABEL} is open. Close it and run this again."
  ec_ok_${_EC}:
  FileClose $0
  ec_done_${_EC}:
  !undef _EC
!macroend
!macro EnsureAllClosed
  !insertmacro EnsureClosed "jolly-roger-office.exe" "Jolly Roger Office"
  !insertmacro EnsureClosed "apps\captains-log.exe" "Captain's Log"
  !insertmacro EnsureClosed "apps\plunder-ledger.exe" "Plunder Ledger"
  !insertmacro EnsureClosed "apps\broadside.exe" "Broadside"
!macroend

Section "Install"
  !insertmacro EnsureAllClosed
  SetOutPath "$INSTDIR"
  File "${STAGE}\jolly-roger-office.exe"
  File "${STAGE}\README.txt"
  File "${STAGE}\LICENSE.txt"
  File /nonfatal "${STAGE}\*.dll"
  SetOutPath "$INSTDIR\apps"
  File "${STAGE}\apps\*.exe"
  File /nonfatal "${STAGE}\apps\*.dll"
  SetOutPath "$INSTDIR\icons"
  File "${STAGE}\icons\*.ico"
  SetOutPath "$INSTDIR\licenses"
  File /r "${STAGE}\licenses\*"
  SetOutPath "$INSTDIR"

  !insertmacro ProgId "CaptainsLog" "Captain's Log" "apps\captains-log.exe" "captains-log.ico"
  !insertmacro ProgId "PlunderLedger" "Plunder Ledger" "apps\plunder-ledger.exe" "plunder-ledger.ico"
  !insertmacro ProgId "Broadside" "Broadside" "apps\broadside.exe" "broadside.ico"
  !insertmacro OpenWith "docx" "CaptainsLog"
  !insertmacro OpenWith "docm" "CaptainsLog"
  !insertmacro OpenWith "dotx" "CaptainsLog"
  !insertmacro OpenWith "doc" "CaptainsLog"
  !insertmacro OpenWith "odt" "CaptainsLog"
  !insertmacro OpenWith "rtf" "CaptainsLog"
  !insertmacro OpenWith "md" "CaptainsLog"
  !insertmacro OpenWith "xlsx" "PlunderLedger"
  !insertmacro OpenWith "xlsm" "PlunderLedger"
  !insertmacro OpenWith "xls" "PlunderLedger"
  !insertmacro OpenWith "ods" "PlunderLedger"
  !insertmacro OpenWith "csv" "PlunderLedger"
  !insertmacro OpenWith "pptx" "Broadside"
  !insertmacro OpenWith "pptm" "Broadside"
  !insertmacro OpenWith "ppsx" "Broadside"
  !insertmacro OpenWith "potx" "Broadside"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'  ; SHCNE_ASSOCCHANGED

  CreateDirectory "$SMPROGRAMS\${NAME}"
  CreateShortcut "$SMPROGRAMS\${NAME}\${NAME}.lnk" "$INSTDIR\jolly-roger-office.exe" "" "$INSTDIR\icons\jolly-roger-office.ico"
  CreateShortcut "$SMPROGRAMS\${NAME}\Captain's Log.lnk" "$INSTDIR\apps\captains-log.exe" "" "$INSTDIR\icons\captains-log.ico"
  CreateShortcut "$SMPROGRAMS\${NAME}\Plunder Ledger.lnk" "$INSTDIR\apps\plunder-ledger.exe" "" "$INSTDIR\icons\plunder-ledger.ico"
  CreateShortcut "$SMPROGRAMS\${NAME}\Broadside.lnk" "$INSTDIR\apps\broadside.exe" "" "$INSTDIR\icons\broadside.ico"
  CreateShortcut "$DESKTOP\${NAME}.lnk" "$INSTDIR\jolly-roger-office.exe" "" "$INSTDIR\icons\jolly-roger-office.ico"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Hillyard Tech\${NAME}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\icons\jolly-roger-office.ico"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  !insertmacro EnsureAllClosed
  !insertmacro UnOpenWith "docx" "CaptainsLog"
  !insertmacro UnOpenWith "docm" "CaptainsLog"
  !insertmacro UnOpenWith "dotx" "CaptainsLog"
  !insertmacro UnOpenWith "doc" "CaptainsLog"
  !insertmacro UnOpenWith "odt" "CaptainsLog"
  !insertmacro UnOpenWith "rtf" "CaptainsLog"
  !insertmacro UnOpenWith "md" "CaptainsLog"
  !insertmacro UnOpenWith "xlsx" "PlunderLedger"
  !insertmacro UnOpenWith "xlsm" "PlunderLedger"
  !insertmacro UnOpenWith "xls" "PlunderLedger"
  !insertmacro UnOpenWith "ods" "PlunderLedger"
  !insertmacro UnOpenWith "csv" "PlunderLedger"
  !insertmacro UnOpenWith "pptx" "Broadside"
  !insertmacro UnOpenWith "pptm" "Broadside"
  !insertmacro UnOpenWith "ppsx" "Broadside"
  !insertmacro UnOpenWith "potx" "Broadside"
  DeleteRegKey HKCU "Software\Classes\${PROGID_PREFIX}.CaptainsLog"
  DeleteRegKey HKCU "Software\Classes\${PROGID_PREFIX}.PlunderLedger"
  DeleteRegKey HKCU "Software\Classes\${PROGID_PREFIX}.Broadside"
  DeleteRegKey HKCU "Software\Classes\Applications\captains-log.exe"
  DeleteRegKey HKCU "Software\Classes\Applications\plunder-ledger.exe"
  DeleteRegKey HKCU "Software\Classes\Applications\broadside.exe"
  System::Call 'shell32::SHChangeNotify(i 0x08000000, i 0, p 0, p 0)'

  Delete "$DESKTOP\${NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${NAME}"
  ; Only what we installed; user settings in %APPDATA% are kept.
  RMDir /r "$INSTDIR\apps"
  RMDir /r "$INSTDIR\icons"
  RMDir /r "$INSTDIR\licenses"
  Delete "$INSTDIR\jolly-roger-office.exe"
  Delete "$INSTDIR\*.dll"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\Hillyard Tech\${NAME}"
  DeleteRegKey /ifempty HKCU "Software\Hillyard Tech"
SectionEnd
