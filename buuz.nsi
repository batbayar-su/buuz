# vim: set et ts=2 sw=2:

# Get the version number from "version.h"
!searchparse /file "version.h" "#define VERSION_STRING" TMP '"' VERSION_STRING '"'
!searchparse /file "version.h" "#define VERSION_NUMBER" TMP '"' VERSION_NUMBER '"'

!define BIN_DIR_X86 ".\objfre_w2k_x86\i386"
!define BIN_DIR_X64 ".\objfre_wnet_amd64\amd64"

!define REG_BUUZ "Software\Buuz"
!define REG_INST "Software\Microsoft\Windows\CurrentVersion\Uninstall\Buuz"

Name "Buuz v${VERSION_STRING}"
OutFile "Buuz_v${VERSION_STRING}.exe"

InstallDir "$PROGRAMFILES\Buuz"
InstallDirRegKey HKLM "${REG_INST}" "InstallLocation"

# Request admin privileges
RequestExecutionLevel admin

# Variables
Var inputHandle
Var inputLoadIme
Var inputUnloadIme

# Headers
!include "MUI2.nsh"
!include "Library.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"

# Interface Settings
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_NOAUTOCLOSE
!define MUI_UNFINISHPAGE_NOAUTOCLOSE

# Installer Pages
!insertmacro MUI_PAGE_LICENSE "license.txt"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

# Uninstaller Pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

# Languages
!insertmacro MUI_LANGUAGE "English"

#
# Init Funtions
#

Function .onInit

  ${IfNot} ${IsWin2000}
  ${AndIfNot} ${IsWinXP}
  ${AndIfNot} ${IsWin2003}
    MessageBox MB_OK|MB_ICONSTOP "Sorry, Buuz ${VERSION_STRING} works only on the following Windows versions: Windows 2000, Windows XP, Windows 2003"
    Abort
  ${EndIf}

  ClearErrors
  UserInfo::GetAccountType
  ${IfNot} ${Errors}
    Pop $1
    ${If} $1 != "Admin"
      MessageBox MB_OK|MB_ICONSTOP "You must have Administrator privileges to install Buuz."
      Abort
    ${EndIf}
  ${EndIf}

  ReadRegStr $R0 HKLM "${REG_INST}" "Version"
  ${IfNot} ${Errors}
    ${If} "${VERSION_NUMBER}" S< $R0
      MessageBox MB_OK|MB_ICONEXCLAMATION "A newer version of Buuz is already installed! It is not recommended that you install an older version. If you really want to install this older version, You must uninstall the current version first."
      Abort
    ${EndIf}
  ${EndIf}
  
  System::Call 'kernel32::CreateMutexA(i 0, i 0, t "NSIS_Buuz") i .r1 ?e'
  Pop $R0
  ${If} $R0 <> 0
    MessageBox MB_OK|MB_ICONEXCLAMATION "The installer is already running."
    Abort
  ${EndIf}

FunctionEnd

!macro LoadInputDll

  Push $0
  Push $1
  Push $2

  StrCpy $inputHandle 0

  System::Call "kernel32::LoadLibraryA(t 'input.dll') i .r0"
  ${If} $0 <> 0
    System::Call "kernel32::GetProcAddress(i r0., i 102) i .r1"
    ${If} $1 <> 0
      System::Call "kernel32::GetProcAddress(i r0., i 103) i .r2"
      ${If} $2 <> 0
        StrCpy $inputHandle $0
        StrCpy $inputLoadIme $1
        StrCpy $inputUnloadIme $2
      ${EndIf}
    ${EndIf}
  ${EndIf}

  Pop $2
  Pop $1
  Pop $0

!macroend

!macro UnloadInputDll

  Push $0

  StrCpy $0 $inputHandle
  ${If} $0 <> 0
    System::Call "kernel32::FreeLibrary(i r0.) i .."
  ${EndIf}

  Pop $0

!macroend

!macro LoadIme klid

  Push $0

  ${If} $inputHandle <> 0
    StrCpy $0 "${klid}" 4 -4
    System::Call "::$inputLoadIme(i 0x$0, i 0x${klid}, i 0, i 0, i 0, i 0) i .."
    System::Call "::$inputLoadIme(i 0x$0, i 0x${klid}, i 0, i 0, i 1, i 0) i .."
  ${EndIf}

  Pop $0

!macroend

!macro UnloadIme klid

  Push $0

  ${If} $inputHandle <> 0
    StrCpy $0 "${klid}" 4 -4
    System::Call "::$inputUnloadIme(i 0x$0, i 0x${klid}, i 0) i .."
    System::Call "::$inputUnloadIme(i 0x$0, i 0x${klid}, i 1) i .."
  ${EndIf}

  System::Call "user32::LoadKeyboardLayoutA(t '${klid}', i 0) i .r0"
  ${If} $0 <> 0
    System::Call "user32::UnloadKeyboardLayout(i r0.) i .."
  ${EndIf}

  Pop $0

!macroend

!macro InstallIme filename klid language

  Push $0

  !insertmacro InstallLib DLL NOTSHARED REBOOT_NOTPROTECTED "${BIN_DIR_X86}\buuz.ime" "$SYSDIR\${filename}" $SYSDIR

  ${If} ${RunningX64}
    !define LIBRARY_X64
    !insertmacro InstallLib DLL NOTSHARED REBOOT_NOTPROTECTED "${BIN_DIR_X64}\buuz.ime" "$SYSDIR\${filename}" $SYSDIR
    !undef LIBRARY_X64
  ${Endif}

  StrCpy $0 "System\CurrentControlSet\Control\Keyboard Layouts\${klid}"
  WriteRegStr HKLM $0 "IME File" "${filename}"
  WriteRegStr HKLM $0 "Layout Display Name" "Buuz (${language})"
  WriteRegStr HKLM $0 "Layout File" "kbdus.dll"
  WriteRegStr HKLM $0 "Layout Text" "Buuz (${language})"

  Pop $0
  
!macroend

!macro UninstallIme filename klid

  DeleteRegKey HKLM "System\CurrentControlSet\Control\Keyboard Layouts\${klid}"

  !insertmacro UninstallLib DLL NOTSHARED REBOOT_NOTPROTECTED "$SYSDIR\${filename}"

  ${If} ${RunningX64}
    !define LIBRARY_X64
    !insertmacro UninstallLib DLL NOTSHARED REBOOT_NOTPROTECTED "$SYSDIR\${filename}"
    !undef LIBRARY_X64
  ${Endif}

!macroend

#
# Installer
#

Section "-Init"

  !insertmacro LoadInputDll

SectionEnd

Section "Buuz (required)" SecBuuz
  
  SectionIn RO

  SetOutPath "$INSTDIR"
  File "license.txt"

  SetOutPath "$INSTDIR\docs"
  File "docs\configure.html"
  File "docs\configure1.png"
  File "docs\configure2.png"
  File "docs\configure3.png"
  File "docs\style.css"
  File "docs\table.html"

  !insertmacro InstallIme "buuz_mon.ime" E0800450 Mongolian
  !insertmacro LoadIme E0800450
  
  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKLM "${REG_INST}" "Version" "${VERSION_NUMBER}"

  WriteRegExpandStr HKLM ${REG_INST} "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegExpandStr HKLM ${REG_INST} "InstallLocation" "$INSTDIR"
  WriteRegStr       HKLM ${REG_INST} "DisplayName"     "Buuz ${VERSION_STRING}"
  WriteRegStr       HKLM ${REG_INST} "DisplayVersion"  "${VERSION_STRING}"
  WriteRegStr       HKLM ${REG_INST} "URLInfoAbout"    "http://buuz.sourceforge.net/"
  WriteRegStr       HKLM ${REG_INST} "HelpLink"        "http://buuz.sourceforge.net/"
  WriteRegDWORD     HKLM ${REG_INST} "NoModify"        "1"
  WriteRegDWORD     HKLM ${REG_INST} "NoRepair"        "1"

SectionEnd

Section "Start Menu Group" SecStartMenu

  SetShellVarContext all
  CreateDirectory "$SMPROGRAMS\Buuz"
  CreateShortCut "$SMPROGRAMS\Buuz\Conversion Table.lnk" "$INSTDIR\docs\table.html"
  CreateShortCut "$SMPROGRAMS\Buuz\Configuration Guide.lnk" "$INSTDIR\docs\configure.html"
  CreateShortCut "$SMPROGRAMS\Buuz\License.lnk" "$INSTDIR\license.txt"
  CreateShortCut "$SMPROGRAMS\Buuz\Uninstall.lnk" "$INSTDIR\uninstall.exe"

SectionEnd

Section "-Uninit"

  !insertmacro UnloadInputDll

SectionEnd

#
# Uninstaller
#

Section "un.Init"

  !insertmacro LoadInputDll

SectionEnd

Section "un.Main"

  !insertmacro UnloadIme E0800450
  !insertmacro UninstallIme "buuz_mon.ime" E0800450

  # Previous versions used to use the name `buuz.ime' instead of `buuz_mon.ime'.
  !insertmacro UninstallLib DLL NOTSHARED REBOOT_NOTPROTECTED "$SYSDIR\buuz.ime"

  SetShellVarContext all
  RMDir /r "$SMPROGRAMS\Buuz"

  RMDir /r "$INSTDIR\docs"
  Delete "$INSTDIR\license.txt"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"

  DeleteRegKey HKLM ${REG_BUUZ}
  DeleteRegKey HKLM ${REG_INST}

SectionEnd

Section "un.Uninit"

  !insertmacro UnloadInputDll

SectionEnd