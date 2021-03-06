;
; Common install macros
;

; 1 if this is an admin install 0 otherwise
Var AdminInstall

; Directory of an existing Python installation if/when available
Var PythonDir

;
; Initialize the $AdminInstall variable
;

!macro GET_ACCOUNT_TYPE
	StrCpy $AdminInstall 1
	UserInfo::GetAccountType
	Pop $1
	SetShellVarContext all
	${If} $1 != "Admin"
		SetShellVarContext current
		StrCpy $AdminInstall 0
	${Else}
		SetShellVarContext all
		StrCpy $AdminInstall 1
	${EndIf}
!macroend
!define InitAdminInstall "!insertmacro GET_ACCOUNT_TYPE"

;
; Initialize Python installation directory ($PythonDir variable)
;
!macro GET_PYTHON_DIR
    ${If} $AdminInstall == 0
	    ReadRegStr $PythonDir HKCU Software\Python\PythonCore\${PYVER}\InstallPath ""
		StrCmp $PythonDir "" 0 trim_backslash
		ReadRegStr $PythonDir HKLM Software\Python\PythonCore\${PYVER}\InstallPath ""
		StrCmp $PythonDir "" return
		MessageBox MB_OK "Please ask the administrator to install Orange$\r$\n(this is because Python was installed by him, too)."
		Quit
	${Else}
	    ReadRegStr $PythonDir HKLM Software\Python\PythonCore\${PYVER}\InstallPath ""
		StrCmp $PythonDir "" 0 trim_backslash
		ReadRegStr $PythonDir HKCU Software\Python\PythonCore\${PYVER}\InstallPath ""
		StrCmp $PythonDir "" return
		StrCpy $AdminInstall 0
	${EndIf}

	trim_backslash:
	StrCpy $0 $PythonDir "" -1
    ${If} $0 == "\"
        StrLen $0 $PythonDir
        IntOp $0 $0 - 1
        StrCpy $PythonDir $PythonDir $0 0
    ${EndIf}

	return:
!macroend
!define InitPythonDir "!insertmacro GET_PYTHON_DIR"

#
# ${PythonExec} COMMAND_STR
#
# Execute a python interpreter with a command string.
# (example: ${PythonExec} '-c "import this"')
#
!macro PYTHON_EXEC_MACRO COMMAND_LINE_STR
	#ExecWait '$PythonDir\python ${COMMAND_LINE_STR}' $0
	nsExec::ExecToLog '"$PythonDir\python" ${COMMAND_LINE_STR}'
!macroend
!define PythonExec "!insertmacro PYTHON_EXEC_MACRO"

;
; Check if a python package dist_name is present in the python's
; site-packages directory (the result is stored in $0)
; (example  ${IsInstalled} Orange )
;
!define IsDistInstalled '!insertmacro IS_INSTALLED'
!macro IS_INSTALLED DIST_NAME
	${If} ${FileExists} ${DIST_NAME}.egg-info ${OrIf} $FileExists ${DIST_NAME}*.egg ${OrIf} ${FileExists} ${DIST_NAME}.dist-info
		StrCpy $0 1
	${Else}
		StrCpy $0 0
	${EndId}
!macroend


# ${InstallPython} python.msi
#
# 	Install Python from a msi installer
#
!macro INSTALL_PYTHON INSTALLER
	Push $1
	${If} ${Silent}
		StrCpy $1 "-qn"
	${Else}
		StrCpy $1 ""
	${EndIf}

	${If} $AdminInstall == 1
		ExecWait 'msiexec.exe $1 -i "${INSTALLER}" ALLUSERS=1' $0
	${Else}
		ExecWait 'msiexec.exe $1 -i "${INSTALLER}"' $0
	${EndIf}

	${If} $0 != 0
		Abort "Error. Could not install required package Python."
	${EndIF}
	Pop $1
!macroend
!define InstallPython "!insertmacro INSTALL_PYTHON"

;
; Install PyWin32 from a bdist_wininst .exe installer
; (INSTALLER must point to an existing file at install time)

!macro INSTALL_PYWIN32 INSTALLER
;	${If} ${FileExists} "$SysDir\${NAME_MFC}"
;		SetOutPath $SysDir
;		File ${PARTY}\${NAME_MFC}
;	${EndIf}

;	SetOutPath $DESKTOP
;	File ${PARTY}\${INSTALLER}

	${If} ${Silent}
		${PythonExec} '-m easy_install "${INSTALLER}"'
		${PythonExec} '$PythonDir\Scripts\pywin32_postinstall.py'
;		ExecWait "$EASY_INSTALL $DESKTOP\${INSTALLER}"
;		ExecWait "$PYTHON $PYTHON_BIN\pywin32_postinstall.py"
	${Else}
		ExecWait "${INSTALLER}
;		ExecWait "$DESKTOP\${INSTALLER}"
	${EndIf}
	Delete "$DESKTOP\${INSTALLER}"
!macroend


!macro INSTALL_BDIST_WININST INSTALLER
	${If} ${Silent}
		${PythonExec} '-m easy_install "${INSTALLER}"'
	${Else}
		ExecWait "${INSTALLER}"
	${EndIf}
!macroend


#
# ${ExtractTemp} Resource TargetLocation
#
#   Extract a Resource (available at compile time) to
#   Target Location (available at install time)
#
!macro _EXTRACT_TEMP_MACRO RESOURCE LOCATION
	SetOutPath ${LOCATION}
	File ${RESOURCE}
!macroend
!define ExtractTemp "!insertmacro _EXTRACT_TEMP_MACRO"


#
# ${ExtractTempRec} Resource TargetLocation
#
#   Extract a Resource (available at compile time) recursively to
#   Target Location (available at install time)
#
!macro _EXTRACT_TEMP_MACRO_REC RESOURCE LOCATION
	SetOutPath ${LOCATION}
	File /r ${RESOURCE}
!macroend
!define ExtractTempRec "!insertmacro _EXTRACT_TEMP_MACRO_REC"



;
; Install a portable python interpreter from a python msi installer
; into TARGETDIR, including msvc redistrib
; (The installer is not registered with windows)

!macro INSTALL_PYTHON_PORTABLE INSTALLER MSVREDIST TARGETDIR
	ExecWait 'msiexec -qn -a "${INSTALLER}" TARGETDIR="${TARGETDIR}" ' $0
	SetOutPath ${TARGETDIR}
	File "${MSVREDIST}\*"
!macroend


;
; Ensure pip is installed
;
!macro PIP_BOOTSTRAP
	${PythonExec} '-m ensurepip'
!macroend


#
# ${PipExec} CMD
#
# Run pip.exe CMD
#
!macro _PIP_EXEC_MACRO COMMAND_LINE_STR
	nsExec::ExecToLog '"$PythonDir\Scripts\pip.exe" ${COMMAND_LINE_STR}'
!macroend
!define PipExec "!insertmacro _PIP_EXEC_MACRO"


#
#  ${Pip} COMMAND_STRING
#
#  Run python -m pip COMMAND_STRING
#
!macro _PIP_MACRO COMMAND_STRING
	${PipExec} '${COMMAND_STRING}'
#	${PythonExec} '-m pip ${COMMAND_STRING}'
!macroend
!define Pip "!insertmacro _PIP_MACRO"
