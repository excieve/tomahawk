;Tomahawk installer script.

;-----------------------------------------------------------------------------
; Some installer script options (comment-out options not required)
;-----------------------------------------------------------------------------
;!define OPTION_LICENSE_AGREEMENT
;!define OPTION_UAC_PLUGIN_ENHANCED
!define OPTION_SECTION_SC_START_MENU
!define OPTION_SECTION_SC_DESKTOP
!define OPTION_SECTION_SC_QUICK_LAUNCH
!define OPTION_FINISHPAGE
;!define OPTION_FINISHPAGE_LAUNCHER
!define OPTION_FINISHPAGE_RELEASE_NOTES

;-----------------------------------------------------------------------------
; Some paths.
;-----------------------------------------------------------------------------
!define MING_PATH "/usr/i686-w64-mingw32/sys-root/mingw"
!define MING_BIN "${MING_PATH}/bin"
!define MING_DLL_PATH "${MING_BIN}"
!define MING_LIB "${MING_PATH}/lib"
!define ROOT_PATH "..\..\.." ; assuming the script is in ROOT/admin/win/nsi
!define BUILD_PATH "${ROOT_PATH}\build"
!define QT_DLL_PATH "${MING_BIN}"
!define SQLITE_DLL_PATH "${MING_LIB}/qt4/plugins/sqldrivers"
!define IMAGEFORMATS_DLL_PATH "${MING_LIB}/qt4/plugins/imageformats"

;-----------------------------------------------------------------------------
; Increment installer revision number as part of this script.
;-----------------------------------------------------------------------------
!define /file REVISION_LAST revision.txt
!define /math REVISION ${REVISION_LAST} + 1
!delfile revision.txt
!appendfile revision.txt ${REVISION}

!define VER_MAJOR "0"
!define VER_MINOR "0"
!define VER_BUILD "2"

!define VERSION "${VER_MAJOR}.${VER_MINOR}.${VER_BUILD}"

;-----------------------------------------------------------------------------
; Installer build timestamp.
;-----------------------------------------------------------------------------
!define /date BUILD_TIME "built on %Y/%m/%d at %I:%M %p  (rev. ${REVISION})"

;-----------------------------------------------------------------------------
; Initial installer setup and definitions.
;-----------------------------------------------------------------------------
Name "Tomahawk"
Caption "Tomahawk Installer"
BrandingText "Tomahawk ${VERSION}  -- ${BUILD_TIME}"
OutFile "tomahawk-${VERSION}.exe"
InstallDir "$PROGRAMFILES\Tomahawk"
InstallDirRegKey HKCU "Software\Tomahawk" ""
InstType Standard
InstType Full
InstType Minimal
CRCCheck On
SetCompressor /SOLID lzma
ReserveFile tomahawk.ini
ReserveFile "${NSISDIR}\Plugins\InstallOptions.dll"

;The UAC plugin provides an elevated user.
;Otherwise request admin level here.
!ifdef OPTION_UAC_PLUGIN_ENHANCED
   RequestExecutionLevel user
!else
   RequestExecutionLevel admin
!endif

;-----------------------------------------------------------------------------
; Include some required header files.
;-----------------------------------------------------------------------------
!include LogicLib.nsh ;Used by APPDATA uninstaller.
!include nsDialogs.nsh ;Used by APPDATA uninstaller.
!include MUI2.nsh ;Used by APPDATA uninstaller.
!include InstallOptions.nsh ;Required by MUI2 to support old MUI_INSTALLOPTIONS.
!include Memento.nsh ;Remember user selections.
!include WinVer.nsh ;Windows version detection.
!include WordFunc.nsh  ;Used by VersionCompare macro function.
!ifdef OPTION_UAC_PLUGIN_ENHANCED
   !include UAC.nsh ;Used by the UAC elevation to install as user or admin.
!endif

;-----------------------------------------------------------------------------
; Memento selections stored in registry.
;-----------------------------------------------------------------------------
!define MEMENTO_REGISTRY_ROOT HKLM
!define MEMENTO_REGISTRY_KEY Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk
                
;-----------------------------------------------------------------------------
; Modern User Interface (MUI) defintions and setup.
;-----------------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON installer.ico
!define MUI_UNICON installer.ico
!define MUI_WELCOMEFINISHPAGE_BITMAP welcome.bmp
!define MUI_WELCOMEPAGE_TITLE "Tomahawk ${VERSION} Setup$\r$\nInstaller Build Revision ${REVISION}"
!define MUI_WELCOMEPAGE_TEXT "This wizard will guide you through the installation.$\r$\n$\r$\n$_CLICK"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP page_header.bmp
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_TITLE "Tomahawk Install Completed"
!define MUI_FINISHPAGE_LINK "Click here to visit the Tomahawk website."
!define MUI_FINISHPAGE_LINK_LOCATION "http://tomahawk-player.org/"
!define MUI_FINISHPAGE_NOREBOOTSUPPORT
!ifdef OPTION_FINISHPAGE_RELEASE_NOTES
   !define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
   !define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\NOTES.txt"
   !define MUI_FINISHPAGE_SHOWREADME_TEXT "Show release notes"
!endif
!ifdef OPTION_FINISHPAGE_LAUNCHER
   !define MUI_FINISHPAGE_NOAUTOCLOSE
   !define MUI_FINISHPAGE_RUN
   !define MUI_FINISHPAGE_RUN_FUNCTION "LaunchTomahawk"
!endif

;-----------------------------------------------------------------------------
; Page macros.
;-----------------------------------------------------------------------------
!insertmacro MUI_PAGE_WELCOME
!ifdef OPTION_LICENSE_AGREEMENT
   !insertmacro MUI_PAGE_LICENSE "LICENSE.txt"
!endif
Page custom PageReinstall PageLeaveReinstall
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!ifdef OPTION_FINISHPAGE
   !insertmacro MUI_PAGE_FINISH
!endif
!insertmacro MUI_UNPAGE_CONFIRM
UninstPage custom un.UnPageUserAppData un.UnPageUserAppDataLeave
!insertmacro MUI_UNPAGE_INSTFILES

;-----------------------------------------------------------------------------
; Other MUI macros.
;-----------------------------------------------------------------------------
!insertmacro MUI_LANGUAGE "English"

##############################################################################
#                                                                            #
#   FINISH PAGE LAUNCHER FUNCTIONS                                           #
#                                                                            #
##############################################################################

Function LaunchTomahawk
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      ${UAC.CallFunctionAsUser} LaunchTomahawkAsUser
   !else
      Exec "$INSTDIR\tomahawk.exe"
   !endif
FunctionEnd

!ifdef OPTION_UAC_PLUGIN_ENHANCED
Function LaunchTomahawkAsUser
   Exec "$INSTDIR\tomahawk.exe"
FunctionEnd
!endif

##############################################################################
#                                                                            #
#   PROCESS HANDLING FUNCTIONS AND MACROS                                    #
#                                                                            #
##############################################################################

!macro CheckForProcess processName gotoWhenFound gotoWhenNotFound
   Processes::FindProcess ${processName}
   StrCmp $R0 "0" ${gotoWhenNotFound} ${gotoWhenFound}
!macroend

!macro ConfirmEndProcess processName
   MessageBox MB_YESNO|MB_ICONEXCLAMATION \
     "Found ${processName} process(s) which need to be stopped.$\nDo you want the installer to stop these for you?" \
     IDYES process_${processName}_kill IDNO process_${processName}_ended
   process_${processName}_kill:
      DetailPrint "Killing ${processName} processes."
      Processes::KillProcess ${processName}
      Sleep 1500
      StrCmp $R0 "1" process_${processName}_ended
      DetailPrint "Process to kill not found!"
   process_${processName}_ended:
!macroend

!macro CheckAndConfirmEndProcess processName
   !insertmacro CheckForProcess ${processName} 0 no_process_${processName}_to_end
   !insertmacro ConfirmEndProcess ${processName}
   no_process_${processName}_to_end:
!macroend

!macro EnsureTomahawkShutdown un
   Function ${un}EnsureTomahawkShutdown
      !insertmacro CheckAndConfirmEndProcess "tomahawk.exe"
   FunctionEnd
!macroend

!insertmacro EnsureTomahawkShutdown ""
!insertmacro EnsureTomahawkShutdown "un."

##############################################################################
#                                                                            #
#   RE-INSTALLER FUNCTIONS                                                   #
#                                                                            #
##############################################################################

Function PageReinstall
   ReadRegStr $R0 HKLM "Software\Tomahawk" ""
   StrCmp $R0 "" 0 +2
   Abort

   ;Detect version
   ReadRegDWORD $R0 HKLM "Software\Tomahawk" "VersionMajor"
   IntCmp $R0 ${VER_MAJOR} minor_check new_version older_version
   minor_check:
      ReadRegDWORD $R0 HKLM "Software\Tomahawk" "VersionMinor"
      IntCmp $R0 ${VER_MINOR} build_check new_version older_version
   build_check:
      ReadRegDWORD $R0 HKLM "Software\Tomahawk" "VersionBuild"
      IntCmp $R0 ${VER_BUILD} revision_check new_version older_version
   revision_check:
      ReadRegDWORD $R0 HKLM "Software\Tomahawk" "VersionRevision"
      IntCmp $R0 ${REVISION} same_version new_version older_version

   new_version:
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 1" "Text" "An older version of Tomahawk is installed on your system. It is recommended that you uninstall the current version before installing. Select the operation you want to perform and click Next to continue."
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 2" "Text" "Uninstall before installing"
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 3" "Text" "Do not uninstall"
      !insertmacro MUI_HEADER_TEXT "Already Installed" "Choose how you want to install Tomahawk."
      StrCpy $R0 "1"
      Goto reinst_start

   older_version:
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 1" "Text" "A newer version of Tomahawk is already installed! It is not recommended that you install an older version. If you really want to install this older version, it is better to uninstall the current version first. Select the operation you want to perform and click Next to continue."
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 2" "Text" "Uninstall before installing"
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 3" "Text" "Do not uninstall"
      !insertmacro MUI_HEADER_TEXT "Already Installed" "Choose how you want to install Tomahawk."
      StrCpy $R0 "1"
      Goto reinst_start

   same_version:
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 1" "Text" "Tomahawk ${VERSION} is already installed.\r\nSelect the operation you want to perform and click Next to continue."
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 2" "Text" "Add/Reinstall components"
      !insertmacro INSTALLOPTIONS_WRITE "tomahawk.ini" "Field 3" "Text" "Uninstall Tomahawk"
      !insertmacro MUI_HEADER_TEXT "Already Installed" "Choose the maintenance option to perform."
      StrCpy $R0 "2"

   reinst_start:
      !insertmacro INSTALLOPTIONS_DISPLAY "tomahawk.ini"
FunctionEnd

Function PageLeaveReinstall
   !insertmacro INSTALLOPTIONS_READ $R1 "tomahawk.ini" "Field 2" "State"
   StrCmp $R0 "1" 0 +2
   StrCmp $R1 "1" reinst_uninstall reinst_done
   StrCmp $R0 "2" 0 +3
   StrCmp $R1 "1" reinst_done reinst_uninstall
   reinst_uninstall:
      ReadRegStr $R1 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "UninstallString"
      HideWindow
      ClearErrors
      ExecWait '$R1 _?=$INSTDIR'
      IfErrors no_remove_uninstaller
      IfFileExists "$INSTDIR\tomahawk.exe" no_remove_uninstaller
      Delete $R1
      RMDir $INSTDIR
   no_remove_uninstaller:
      StrCmp $R0 "2" +2 0
      BringToFront
      !ifdef OPTION_UAC_PLUGIN_ENHANCED
         UAC::Unload
         Quit
      !endif
   reinst_done:
FunctionEnd

##############################################################################
#                                                                            #
#   INSTALLER SECTIONS                                                       #
#                                                                            #
##############################################################################

Section "Tomahawk Player" SEC_TOMAHAWK_PLAYER
   SectionIn 1 2 3 RO
   SetDetailsPrint listonly
   
   SetDetailsPrint textonly
   DetailPrint "Installing Tomahawk Player essentials."
   SetDetailsPrint listonly
   SetOutPath "$INSTDIR"

   !ifdef INSTALL_PATH
        ;Main executable.
        File "${INSTALL_PATH}\bin\tomahawk.exe"

        File "${INSTALL_PATH}\lib\librtaudio.dll"
        File "${INSTALL_PATH}\lib\libqxtweb-standalone.dll"
        File "${INSTALL_PATH}\lib\libtomahawk_jdns.dll"
        File "${INSTALL_PATH}\lib\libtomahawk_qtweetlib.dll"
        File "${INSTALL_PATH}\lib\libtomahawklib.dll"
        File "${INSTALL_PATH}\lib\libtomahawk_sipjabber.dll"
        File "${INSTALL_PATH}\lib\libtomahawk_siptwitter.dll"
        File "${INSTALL_PATH}\lib\libtomahawk_sipzeroconf.dll"
   !endif
   !ifndef INSTALL_PATH
        ;Main executable.
        File "${BUILD_PATH}\tomahawk.exe"

        File "${BUILD_PATH}\thirdparty\rtaudio\librtaudio.dll"
        File "${BUILD_PATH}\thirdparty\qxt\qxtweb-standalone\libqxtweb-standalone.dll"
        File "${BUILD_PATH}\thirdparty\jdns\libtomahawk_jdns.dll"
        File "${BUILD_PATH}\thirdparty\qtweetlib\libtomahawk_qtweetlib.dll"
        File "${BUILD_PATH}\src\libtomahawk\libtomahawklib.dll"
        File "${BUILD_PATH}\libtomahawk_sipjabber.dll"
        File "${BUILD_PATH}\libtomahawk_siptwitter.dll"
        File "${BUILD_PATH}\libtomahawk_sipzeroconf.dll"
   !endif

   ;License & release notes.
   File "${ROOT_PATH}\LICENSE.txt"
   File /oname=NOTES.txt RELEASE_NOTES.txt
    
   ;QT stuff:  
   File "${QT_DLL_PATH}\QtCore4.dll"
   File "${QT_DLL_PATH}\QtGui4.dll"
   File "${QT_DLL_PATH}\QtNetwork4.dll"
   File "${QT_DLL_PATH}\QtSql4.dll"
   File "${QT_DLL_PATH}\QtXml4.dll"
   File "${QT_DLL_PATH}\QtWebKit4.dll"

   ;SQLite driver
   SetOutPath "$INSTDIR\sqldrivers"
   File "${SQLITE_DLL_PATH}\qsqlite4.dll"
   SetOutPath "$INSTDIR"

   ;Image plugins
   SetOutPath "$INSTDIR\imageformats"
   File "${IMAGEFORMATS_DLL_PATH}\qgif4.dll"
   File "${IMAGEFORMATS_DLL_PATH}\qjpeg4.dll"
   SetOutPath "$INSTDIR"
    
   ;Cygwin/c++ stuff
   ;File "${MING_DLL_PATH}\cygmad-0.dll"
   ;File "${MING_DLL_PATH}\libgcc_s_dw2-1.dll"
   ;File "${MING_DLL_PATH}\mingwm10.dll"
   File "${MING_DLL_PATH}\libgcc_s_sjlj-1.dll"
   File "${MING_DLL_PATH}\libstdc++-6.dll"
   
   ;Audio stuff
   File "${MING_DLL_PATH}\libmad-0.dll"
   File "${MING_DLL_PATH}\libogg-0.dll"
   File "${MING_DLL_PATH}\libvorbisfile-3.dll"
   File "${MING_DLL_PATH}\libvorbis-0.dll"
   File "${MING_DLL_PATH}\libFLAC-8.dll"
   File "${MING_DLL_PATH}\libFLAC++-6.dll"
    
   ;Other
   File "${MING_DLL_PATH}\libqjson.dll"
   File "${MING_DLL_PATH}\libtag.dll"
   File "${MING_DLL_PATH}\libgloox-8.dll"
   File "${MING_DLL_PATH}\libpng15-15.dll"
   File "${MING_DLL_PATH}\libjpeg-8.dll"
   File "${MING_DLL_PATH}\zlib1.dll"

   File "${MING_DLL_PATH}\libechonest.dll"
   File "${MING_DLL_PATH}\liblastfm.dll"

   File "${MING_LIB}\libclucene-core.dll"
   File "${MING_LIB}\libclucene-shared.dll"

   File "${MING_BIN}\libqtsparkle.dll"
SectionEnd

SectionGroup "Shortcuts"

!ifdef OPTION_SECTION_SC_START_MENU
   ${MementoSection} "Start Menu Program Group" SEC_START_MENU
      SectionIn 1 2
      SetDetailsPrint textonly
      DetailPrint "Adding shortcuts for the Tomahawk program group to the Start Menu."
      SetDetailsPrint listonly
      SetShellVarContext all
      RMDir /r "$SMPROGRAMS\Tomahawk"
      CreateDirectory "$SMPROGRAMS\Tomahawk"
      CreateShortCut "$SMPROGRAMS\Tomahawk\LICENSE.lnk" "$INSTDIR\LICENSE.txt"
      CreateShortCut "$SMPROGRAMS\Tomahawk\Tomahawk.lnk" "$INSTDIR\tomahawk.exe"
      CreateShortCut "$SMPROGRAMS\Tomahawk\Release notes.lnk" "$INSTDIR\NOTES.txt"
      CreateShortCut "$SMPROGRAMS\Tomahawk\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
      SetShellVarContext current
   ${MementoSectionEnd}
!endif

!ifdef OPTION_SECTION_SC_DESKTOP
   ${MementoSection} "Desktop Shortcut" SEC_DESKTOP
      SectionIn 1 2
      SetDetailsPrint textonly
      DetailPrint "Creating Desktop Shortcuts"
      SetDetailsPrint listonly
      CreateShortCut "$DESKTOP\Tomahawk.lnk" "$INSTDIR\tomahawk.exe"
   ${MementoSectionEnd}
!endif

!ifdef OPTION_SECTION_SC_QUICK_LAUNCH
   ${MementoSection} "Quick Launch Shortcut" SEC_QUICK_LAUNCH
      SectionIn 1 2
      SetDetailsPrint textonly
      DetailPrint "Creating Quick Launch Shortcut"
      SetDetailsPrint listonly
      CreateShortCut "$QUICKLAUNCH\Tomahawk.lnk" "$INSTDIR\tomahawk.exe"
   ${MementoSectionEnd}
!endif

SectionGroupEnd

${MementoSectionDone}

; Installer section descriptions
;--------------------------------
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${SEC_TOMAHAWK_PLAYER} "Tomahawk player essentials."
!insertmacro MUI_DESCRIPTION_TEXT ${SEC_START_MENU} "Tomahawk program group."
!insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} "Desktop shortcut for Tomahawk."
!insertmacro MUI_DESCRIPTION_TEXT ${SEC_QUICK_LAUNCH} "Quick Launch shortcut for Tomahawk."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section -post

   ;Uninstaller file.
   SetDetailsPrint textonly
   DetailPrint "Writing Uninstaller"
   SetDetailsPrint listonly
   WriteUninstaller $INSTDIR\Uninstall.exe

   ;Registry keys required for installer version handling and uninstaller.
   SetDetailsPrint textonly
   DetailPrint "Writing Installer Registry Keys"
   SetDetailsPrint listonly

   ;Version numbers used to detect existing installation version for comparisson.
   WriteRegStr HKLM "Software\Tomahawk" "" $INSTDIR
   WriteRegDWORD HKLM "Software\Tomahawk" "VersionMajor" "${VER_MAJOR}"
   WriteRegDWORD HKLM "Software\Tomahawk" "VersionMinor" "${VER_MINOR}"
   WriteRegDWORD HKLM "Software\Tomahawk" "VersionRevision" "${REVISION}"
   WriteRegDWORD HKLM "Software\Tomahawk" "VersionBuild" "${VER_BUILD}"

   ;Add or Remove Programs entry.
   WriteRegExpandStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "UninstallString" '"$INSTDIR\Uninstall.exe"'
   WriteRegExpandStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "InstallLocation" "$INSTDIR"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "DisplayName" "Tomahawk"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "Publisher" "Tomahawk-player.org"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "DisplayIcon" "$INSTDIR\Uninstall.exe,0"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "DisplayVersion" "${VERSION}"
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "VersionMajor" "${VER_MAJOR}"
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "VersionMinor" "${VER_MINOR}.${REVISION}"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "URLInfoAbout" "http://tomahawk-player.org/"
   WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "HelpLink" "http://tomahawk-player.org/"
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "NoModify" "1"
   WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "NoRepair" "1"

   ; Register tomahawk:// protocol handler
   WriteRegStr HKCR "tomahawk" "" "URL: Tomahawk Protocol"
   WriteRegStr HKCR "tomahawk\DefaultIcon" "" $INSTDIR\tomahawk.exe,1
   WriteRegStr HKCR "tomahawk\shell" "" "open"
   WriteRegStr HKCR "tomahawk\shell\open\command" "" '"$INSTDIR\tomahawk.exe" "%1"'

   SetDetailsPrint textonly
   DetailPrint "Finsihed."
SectionEnd

##############################################################################
#                                                                            #
#   UNINSTALLER SECTION                                                      #
#                                                                            #
##############################################################################

Var UnPageUserAppDataDialog
Var UnPageUserAppDataCheckbox
Var UnPageUserAppDataCheckbox_State
Var UnPageUserAppDataEditBox

Function un.UnPageUserAppData
   !insertmacro MUI_HEADER_TEXT "Uninstall Tomahawk" "Remove Tomahawk's data folder from your computer."
   nsDialogs::Create /NOUNLOAD 1018
   Pop $UnPageUserAppDataDialog

   ${If} $UnPageUserAppDataDialog == error
      Abort
   ${EndIf}

   ${NSD_CreateLabel} 0 0 100% 12u "Do you want to delete Tomahawk's data folder?"
   Pop $0

   ${NSD_CreateText} 0 13u 100% 12u "$LOCALAPPDATA\Tomahawk"
   Pop $UnPageUserAppDataEditBox
   SendMessage $UnPageUserAppDataEditBox ${EM_SETREADONLY} 1 0

   ${NSD_CreateLabel} 0 46u 100% 24u "Leave unchecked to keep the data folder for later use or check to delete the data folder."
   Pop $0

   ${NSD_CreateCheckbox} 0 71u 100% 8u "Yes, delete this data folder."
   Pop $UnPageUserAppDataCheckbox

   nsDialogs::Show
FunctionEnd

Function un.UnPageUserAppDataLeave
   ${NSD_GetState} $UnPageUserAppDataCheckbox $UnPageUserAppDataCheckbox_State
FunctionEnd

Section Uninstall
   IfFileExists "$INSTDIR\tomahawk.exe" tomahawk_installed
      MessageBox MB_YESNO "It does not appear that Tomahawk is installed in the directory '$INSTDIR'.$\r$\nContinue anyway (not recommended)?" IDYES tomahawk_installed
      Abort "Uninstall aborted by user"
   tomahawk_installed:

   ;Delete registry keys.
   DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk"
   DeleteRegValue HKLM "Software\Tomahawk" "VersionBuild"
   DeleteRegValue HKLM "Software\Tomahawk" "VersionMajor"
   DeleteRegValue HKLM "Software\Tomahawk" "VersionMinor"
   DeleteRegValue HKLM "Software\Tomahawk" "VersionRevision"
   DeleteRegValue HKLM "Software\Tomahawk" ""
   DeleteRegKey HKLM "Software\Tomahawk"

   DeleteRegKey HKCR "tomahawk"

   ;Start menu shortcuts.
   !ifdef OPTION_SECTION_SC_START_MENU
      SetShellVarContext all
      RMDir /r "$SMPROGRAMS\Tomahawk"
      SetShellVarContext current
   !endif

   ;Desktop shortcut.
   !ifdef OPTION_SECTION_SC_DESKTOP
      IfFileExists "$DESKTOP\Tomahawk.lnk" 0 +2
         Delete "$DESKTOP\Tomahawk.lnk"
   !endif

   ;Quick Launch shortcut.
   !ifdef OPTION_SECTION_SC_QUICK_LAUNCH
      IfFileExists "$QUICKLAUNCH\Tomahawk.lnk" 0 +2
         Delete "$QUICKLAUNCH\Tomahawk.lnk"
   !endif

   ;Remove all the Program Files.
   RMDir /r $INSTDIR
  
   ;Uninstall User Data if option is checked, otherwise skip.
   ${If} $UnPageUserAppDataCheckbox_State == ${BST_CHECKED}
      RMDir /r "$LOCALAPPDATA\Tomahawk"
   ${EndIf}

   SetDetailsPrint textonly
   DetailPrint "Finsihed."
SectionEnd

##############################################################################
#                                                                            #
#   NSIS Installer Event Handler Functions                                   #
#                                                                            #
##############################################################################

Function .onInit   
   !insertmacro INSTALLOPTIONS_EXTRACT "tomahawk.ini"

   ;Remove Quick Launch option from Windows 7, as no longer applicable - usually.
   ${IfNot} ${AtMostWinVista}
      SectionSetText ${SEC_QUICK_LAUNCH} "Quick Launch Shortcut (N/A)"
      SectionSetFlags ${SEC_QUICK_LAUNCH} ${SF_RO}
      SectionSetInstTypes ${SEC_QUICK_LAUNCH} 0
   ${EndIf}

   ${MementoSectionRestore}

   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC_Elevate:
         UAC::RunElevated 
         StrCmp 1223 $0 UAC_ElevationAborted ; UAC dialog aborted by user?
         StrCmp 0 $0 0 UAC_Err ; Error?
         StrCmp 1 $1 0 UAC_Success ;Are we the real deal or just the wrapper?
         Quit
       
      UAC_Err:
         MessageBox MB_ICONSTOP "Unable to elevate, error $0"
         Abort
       
      UAC_ElevationAborted:
         Abort
       
      UAC_Success:
         StrCmp 1 $3 +4 ;Admin?
         StrCmp 3 $1 0 UAC_ElevationAborted ;Try again?
         MessageBox MB_ICONSTOP "This installer requires admin access, try again"
         goto UAC_Elevate
   !endif

   ;Prevent multiple instances.
   System::Call 'kernel32::CreateMutexA(i 0, i 0, t "tomahawkInstaller") i .r1 ?e'
   Pop $R0
   StrCmp $R0 0 +3
      MessageBox MB_OK|MB_ICONEXCLAMATION "The installer is already running."
      Abort

   ;Use available InstallLocation when possible. This is useful in the uninstaller
   ;via re-install, which would otherwise use a default location - a bug.
   ReadRegStr $R0 HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Tomahawk" "InstallLocation"
   StrCmp $R0 "" SkipSetInstDir
   StrCpy $INSTDIR $R0
   SkipSetInstDir:
   
   ;Shutdown Tomahawk in case Add/Remove re-installer option used.
   Call EnsureTomahawkShutdown
FunctionEnd

Function .onInstSuccess
   ${MementoSectionSave}
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC::Unload ;Must call unload!
   !endif
FunctionEnd

Function .onInstFailed
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC::Unload ;Must call unload!
   !endif
FunctionEnd

##############################################################################
#                                                                            #
#   NSIS Uninstaller Event Handler Functions                                 #
#                                                                            #
##############################################################################

Function un.onInit
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC_Elevate:
         UAC::RunElevated 
         StrCmp 1223 $0 UAC_ElevationAborted ; UAC dialog aborted by user?
         StrCmp 0 $0 0 UAC_Err ; Error?
         StrCmp 1 $1 0 UAC_Success ;Are we the real deal or just the wrapper?
         Quit

      UAC_Err:
         MessageBox MB_ICONSTOP "Unable to elevate, error $0"
         Abort
       
      UAC_ElevationAborted:
         Abort
       
      UAC_Success:
         StrCmp 1 $3 +4 ;Admin?
         StrCmp 3 $1 0 UAC_ElevationAborted ;Try again?
         MessageBox MB_ICONSTOP "This uninstaller requires admin access, try again"
         goto UAC_Elevate 
   !endif

   ;Prevent multiple instances.
   System::Call 'kernel32::CreateMutexA(i 0, i 0, t "tomahawkUninstaller") i .r1 ?e'
   Pop $R0
   StrCmp $R0 0 +3
      MessageBox MB_OK|MB_ICONEXCLAMATION "This uninstaller is already running."
      Abort
FunctionEnd

Function un.onUnInstSuccess
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC::Unload ;Must call unload!
   !endif
FunctionEnd

Function un.onUnInstFailed
   !ifdef OPTION_UAC_PLUGIN_ENHANCED
      UAC::Unload ;Must call unload!
   !endif
FunctionEnd
