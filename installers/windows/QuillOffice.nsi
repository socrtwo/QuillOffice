; Anne's Office Windows installer: one setup that installs the Anne's Office apps you tick.
; Each app's own installer (built by that app's release) is embedded and run silently.
; Built with makensis (NSIS 3) on any OS; the payload files come from scripts/resolve.mjs.
;
; Defines expected on the command line:
;   /DVERSION=0.1.0 /DARCH=x64|arm64 /DPAYLOAD=path\to\payload /DOUTFILE=QuillOffice-0.1.0-windows-x64-setup.exe
;   and for each app that has an installer in this payload:
;   /DPEN_FILE=QuillPen-1.2.0-windows-x64-setup.exe /DPEN_VERSION=1.2.0   (same for GRID_, POST_, STAGE_)
;   POST_FILE is an .msi (installed with msiexec); the others are NSIS installers that accept /S.

Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

Name "Anne's Office ${VERSION}"
OutFile "${OUTFILE}"
; Nothing of Anne's Office's own is installed; only an uninstall-helper note goes here.
InstallDir "$LOCALAPPDATA\Programs\QuillOffice"
RequestExecutionLevel user
; The embedded installers are already compressed.
SetCompress off
BrandingText "Anne's Office ${VERSION} (${ARCH}) — MIT License"

!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_WELCOMEPAGE_TITLE "Anne's Office ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This installs the Anne's Office suite: Anne's Pen (documents), Anne's Grid (spreadsheets), Anne's Post (email) and Anne's Stage (presentations).$\r$\n$\r$\nEach app is installed by its own installer, for the current user, and appears in the Start menu and in Apps & features on its own. Untick any app you do not want.$\r$\n$\r$\nThe apps are open source (MIT License) and are not signed with a paid certificate, so Windows SmartScreen may ask once per app."
!define MUI_FINISHPAGE_TITLE "Anne's Office is installed"
!define MUI_FINISHPAGE_TEXT "The apps you chose are in the Start menu. Each one can be removed separately from Settings ▸ Apps."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_LANGUAGE "English"

Var Failed

Function .onInit
  InitPluginsDir
  StrCpy $Failed ""
!if "${ARCH}" == "arm64"
  ${IfNot} ${IsNativeARM64}
    MessageBox MB_ICONSTOP "This Anne's Office setup is for Windows on ARM. Download the x64 setup for this computer."
    Abort
  ${EndIf}
!else
  ${IfNot} ${IsNativeAMD64}
    ${If} ${IsNativeARM64}
      MessageBox MB_ICONQUESTION|MB_YESNO "This setup contains x64 apps. They run on this ARM computer through emulation, but the arm64 setup would be faster. Install the x64 apps anyway?" IDYES +2
      Abort
    ${Else}
      MessageBox MB_ICONSTOP "Anne's Office needs 64-bit Windows."
      Abort
    ${EndIf}
  ${EndIf}
!endif
FunctionEnd

; Runs an embedded NSIS installer silently and records a failure instead of stopping the whole setup.
!macro RunNsis label file
  DetailPrint "Installing ${label}…"
  File "/oname=$PLUGINSDIR\${file}" "${PAYLOAD}\${file}"
  ClearErrors
  ExecWait '"$PLUGINSDIR\${file}" /S' $0
  ${If} ${Errors}
  ${OrIf} $0 != 0
    DetailPrint "${label} did not install (exit code $0)."
    StrCpy $Failed "$Failed ${label}"
  ${EndIf}
  Delete "$PLUGINSDIR\${file}"
!macroend

!macro RunMsi label file
  DetailPrint "Installing ${label}…"
  File "/oname=$PLUGINSDIR\${file}" "${PAYLOAD}\${file}"
  ClearErrors
  ExecWait 'msiexec.exe /i "$PLUGINSDIR\${file}" /qn /norestart' $0
  ; 3010 = installed, restart required later.
  ${If} ${Errors}
  ${OrIf} $0 != 0
  ${AndIf} $0 != 3010
    DetailPrint "${label} did not install (exit code $0)."
    StrCpy $Failed "$Failed ${label}"
  ${EndIf}
  Delete "$PLUGINSDIR\${file}"
!macroend

!ifdef PEN_FILE
Section "Anne's Pen ${PEN_VERSION} (documents)" SecPen
  !insertmacro RunNsis "Anne's Pen" "${PEN_FILE}"
SectionEnd
!endif

!ifdef GRID_FILE
Section "Anne's Grid ${GRID_VERSION} (spreadsheets)" SecGrid
  !insertmacro RunNsis "Anne's Grid" "${GRID_FILE}"
SectionEnd
!endif

!ifdef POST_FILE
Section "Anne's Post ${POST_VERSION} (email)" SecPost
  !insertmacro RunMsi "Anne's Post" "${POST_FILE}"
SectionEnd
!endif

!ifdef STAGE_FILE
Section "Anne's Stage ${STAGE_VERSION} (presentations)" SecStage
  !insertmacro RunNsis "Anne's Stage" "${STAGE_FILE}"
SectionEnd
!endif

Section "-finish"
  ${If} $Failed != ""
    MessageBox MB_ICONEXCLAMATION "These apps did not install:$Failed$\r$\n$\r$\nYou can download them separately from github.com/socrtwo."
  ${EndIf}
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!ifdef PEN_FILE
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPen} "Word processor. Opens and saves .docx, .odt, .rtf and many more."
!endif
!ifdef GRID_FILE
  !insertmacro MUI_DESCRIPTION_TEXT ${SecGrid} "Spreadsheet. Opens and saves .xlsx, .ods and .csv, with 500+ functions."
!endif
!ifdef POST_FILE
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPost} "Email, calendar and contacts for IMAP, POP3 and SMTP accounts."
!endif
!ifdef STAGE_FILE
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStage} "Presentations. Opens and saves .pptx and .odp, with presenter view."
!endif
!insertmacro MUI_FUNCTION_DESCRIPTION_END
