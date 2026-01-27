#include-once
#include "WinAPIThemeEx.au3"
#include "APIThemeConstantsEx.au3"
;~ #include "_FindDelayLoadThunkInModule.au3"

#include <WinAPIGdi.au3>

#include <WinAPIDlg.au3> ; _WinAPI_GetDlgCtrlID


#include <SendMessage.au3>
#include <WindowsConstants.au3>
#include <WinAPITheme.au3>
#include <WinAPISysWin.au3>

#include <Array.au3> ; Just for _ArrayDisplay()
#include <GuiListView.au3> ; Debug ListView Header


; #INDEX# =======================================================================================================================
; Title .........: GUIDarkmode UDF Library for AutoIt3
; AutoIt Version : 3.3.16.1
; Description ...: Additional variables, constants and functions for the WinAPITheme.au3
; Author(s) .....: NoNameCode
; ===============================================================================================================================

#Region Global Variables and Constants

; #VARIABLES# ===================================================================================================================

; Darkmode default colors for GUI / -Ctrls
Global $GUIDARKMODE_COLOR_GUIBK = 0x202020 ;Orig argumentum: 0x1B1B1B
Global $GUIDARKMODE_COLOR_GUICTRL = 0xe0e0e0 ;Orig argumentum: 0xFBFBFB
Global $GUIDARKMODE_COLOR_GUICTRLBK = 0x3f3f3f ;Orig argumentum: 0x2B2B2B

; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================

Global Const $DWMWA_USE_IMMERSIVE_DARK_MODE = (@OSBuild <= 18985) ? 19 : 20            ; before this build set to 19, otherwise set to 20, no thanks Windaube to document anything ??

; ===============================================================================================================================
#EndRegion Global Variables and Constants

#Region Functions list
; #CURRENT# =====================================================================================================================
; _GUISetDarkTheme
; _GUICtrlSetDarkTheme
; _GUICtrlAllSetDarkTheme
; ===============================================================================================================================
#EndRegion Functions list

Global $hHookOpenNcThemeData_DLL =  DllOpen("HookOpenNcThemeData.dll")		;Hook OpenNcThemeData DLL to change all "ScrollBar" to "Explorer::ScrollBar"
OnAutoItExitRegister("__DLLClose_HookOpenThemeData_DLL")
Func __DLLClose_HookOpenThemeData_DLL()
	DllClose($hHookOpenNcThemeData_DLL)
EndFunc


#Region Public Functions

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUISetDarkTheme
; Description ...: Sets the theme for a specified window to either dark or light mode on Windows 10.
; Syntax ........: _GUISetDarkTheme($hwnd, $dark_theme = True)
; Parameters ....: $hwnd          - The handle to the window.
;                  $dark_theme    - If True, sets the dark theme; if False, sets the light theme.
;                                   (Default is True for dark theme.)
; Return values .: None
; Author ........: DK12000, NoNameCode
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: https://www.autoitscript.com/forum/topic/211196-gui-title-bar-dark-theme-an-elegant-solution-using-dwmapi/
; Example .......: No
; ===============================================================================================================================
Func _GUISetDarkTheme($hWnd, $bEnableDarkTheme = True)
	Local $iPreferredAppMode = ($bEnableDarkTheme == True) ? $APPMODE_FORCEDARK : $APPMODE_FORCELIGHT
	Local $iGUI_BkColor = ($bEnableDarkTheme == True) ? $GUIDARKMODE_COLOR_GUIBK : _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_3DFACE))
	_WinAPI_SetPreferredAppMode($iPreferredAppMode)
	_WinAPI_RefreshImmersiveColorPolicyState()
	_WinAPI_FlushMenuThemes()
	GUISetBkColor($iGUI_BkColor, $hWnd)
	_GUICtrlSetDarkTheme($hWnd, $bEnableDarkTheme)			;To Color the GUI's own Scrollbar
;~ 	DllCall('dwmapi.dll', 'long', 'DwmSetWindowAttribute', 'hwnd', $hWnd, 'dword', $DWMWA_USE_IMMERSIVE_DARK_MODE, 'dword*', Int($bEnableDarkTheme), 'dword', 4)
	_WinAPI_DwmSetWindowAttribute_unr($hWnd, $DWMWA_USE_IMMERSIVE_DARK_MODE, $bEnableDarkTheme)
EndFunc   ;==>_GUISetDarkTheme

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUICtrlAllSetDarkTheme
; Description ...: Sets the dark theme to all existing sub Controls from a GUI
; Syntax ........: _GUICtrlAllSetDarkTheme($hGUI[, $bEnableDarkTheme = True])
; Parameters ....: $hGUI                - GUI handle
;                  $bEnableDarkTheme    - [optional] a boolean value. Default is True.
; Return values .: None
; Author ........: NoName
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; ===============================================================================================================================
Func _GUICtrlAllSetDarkTheme($hGUI, $bEnableDarkTheme = True)
    Local $aCtrls = _WinAPI_EnumChildWindows($hGUI, False)
    For $i = 1 To $aCtrls[0][0]
        _GUICtrlSetDarkTheme($aCtrls[$i][0], $bEnableDarkTheme)
    Next
	Return $aCtrls
EndFunc


; #FUNCTION# ====================================================================================================================
; Name ..........: _GUICtrlSetDarkTheme
; Description ...: Sets the dark theme for a specified control.
; Syntax ........: _GUICtrlSetDarkTheme($vCtrl, $bEnableDarkTheme = True)
; Parameters ....: $vCtrl            - The control handle or identifier.
;                  $bEnableDarkTheme - If True, enables the dark theme; if False, disables it.
;                                      (Default is True for enabling dark theme.)
; Return values .: Success: True
;                  Failure: False and sets the @error flag:
;                           1: Invalid control handle or identifier.
;                           2: Error while allowing dark mode for the window.
;                           3: Error while setting the window theme.
;                           4: Error while sending the WM_THEMECHANGED message.
; Author ........: NoNameCode
; Modified ......:
; Remarks .......: This function requires the _WinAPI_SetWindowTheme and _WinAPI_AllowDarkModeForWindow functions.
; Related .......:
; Link ..........: http://www.opengate.at/blog/2021/08/dark-mode-win32/
; Example .......: Yes
; ===============================================================================================================================
Func _GUICtrlSetDarkTheme($vCtrl, $bEnableDarkTheme = True)
	Local $sThemeName = Null, $sThemeList = Null
	Local $iGUI_Ctrl_Color = ($bEnableDarkTheme == True) ? $GUIDARKMODE_COLOR_GUICTRL : _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_WINDOWTEXT))
	Local $iGUI_Ctrl_BkColor = ($bEnableDarkTheme == True) ? $GUIDARKMODE_COLOR_GUICTRLBK : _WinAPI_SwitchColor(_WinAPI_GetSysColor($COLOR_BTNFACE))
	If Not IsHWnd($vCtrl) Then $vCtrl = GUICtrlGetHandle($vCtrl)
	If Not IsHWnd($vCtrl) Then Return SetError(1, 0, False)
	_WinAPI_AllowDarkModeForWindow($vCtrl, $bEnableDarkTheme)
	If @error <> 0 Then Return SetError(2, @error, False)
	;=========
;~ 	ConsoleWrite(@CRLF & _WinAPI_GetClassName($vCtrl))
	Switch _WinAPI_GetClassName($vCtrl)
		Case 'Button', 'AutoIt v3 GUI'
			$sThemeName = 'Explorer'

		Case 'ComboBox','Edit'
			$sThemeName = 'CFD'
			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($vCtrl), $iGUI_Ctrl_Color)
			GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($vCtrl), $iGUI_Ctrl_BkColor)
		Case 'SysHeader32'
			$sThemeName = 'DarkMode_ItemsView'
			$sThemeList = 'Header'

		Case 'Static'
			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($vCtrl), $iGUI_Ctrl_Color)

		Case 'SysTabControl32'
			$sThemeList = 'ExplorerStatusBar'				;=> Favorite	More Dark
;~ 			$sThemeList = 'FileExplorerBannerContainer'		;=> Favorite	Less Dark

		Case Else
			$sThemeName = 'Explorer'
			GUICtrlSetColor(_WinAPI_GetDlgCtrlID($vCtrl), $iGUI_Ctrl_Color)
			GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($vCtrl), $iGUI_Ctrl_BkColor)
	EndSwitch
;~ 	ConsoleWrite(@CRLF & 'Class:' & _WinAPI_GetClassName($vCtrl) & ' Theme:' & $sThemeName & '::' & $sThemeList)
	;=========
	_WinAPI_SetWindowTheme_unr($vCtrl, $sThemeName, $sThemeList)
	If @error <> 0 Then Return SetError(3, @error, False)
	_SendMessage($vCtrl, $WM_THEMECHANGED, 0, 0)
	If @error <> 0 Then Return SetError(4, @error, False)
	Return True
EndFunc   ;==>_GUICtrlSetDarkTheme

;//Testting
Func _GUICtrlSetDarkThemeEx($vCtrl, $sThemeName = Null, $sThemeList = Null, $bEnableDarkTheme = True)
	If Not IsHWnd($vCtrl) Then $vCtrl = GUICtrlGetHandle($vCtrl)
	If Not IsHWnd($vCtrl) Then Return SetError(1, 0, False)
	_WinAPI_AllowDarkModeForWindow($vCtrl, $bEnableDarkTheme)
	If @error <> 0 Then Return SetError(2, @error, False)
	_WinAPI_SetWindowTheme_unr($vCtrl, $sThemeName, $sThemeList)
	If @error <> 0 Then Return SetError(3, @error, False)
	_SendMessage($vCtrl, $WM_THEMECHANGED, 0, 0)
	If @error <> 0 Then Return SetError(4, @error, False)
	Return True
EndFunc   ;==>_GUICtrlSetDarkThemeEx

#EndRegion Public Functions

#Region Internal Functions


; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_SetWindowTheme_unr
; Description ...:  Dose the same as _WinAPI_SetWindowTheme; But has no Restrictions
; Syntax ........: _WinAPI_SetWindowTheme_unr($hWnd[, $sName = Null[, $sList = Null]])
; Parameters ....: $hWnd                - a handle value.
;                  $sName               - [optional] a string value. Default is Null.
;                  $sList               - [optional] a string value. Default is Null.
; Return values .: Success: 1 Failure: @error, @extended & False
; Author ........: argumentum
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: https://www.autoitscript.com/forum/topic/211475-winapithemeex-darkmode-for-autoits-win32guis/?do=findComment&comment=1530103
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_SetWindowTheme_unr($hWnd, $sName = Null, $sList = Null) ; #include <WinAPITheme.au3> ; unthoughtful unrestricting mod.
    Local $sResult = DllCall('UxTheme.dll', 'long', 'SetWindowTheme', 'hwnd', $hWnd, 'wstr', $sName, 'wstr', $sList)
    If @error Then Return SetError(@error, @extended, 0)
    If $sResult[0] Then Return SetError(10, $sResult[0], 0)
    Return 1
EndFunc   ;==>_WinAPI_SetWindowTheme_unr

; #FUNCTION# ====================================================================================================================
; Name ..........: _WinAPI_DwmSetWindowAttribute_unr
; Description ...: Dose the same as _WinAPI_DwmSetWindowAttribute; But has no Restrictions
; Syntax ........: _WinAPI_DwmSetWindowAttribute_unr($hWnd, $iAttribute, $iData)
; Parameters ....: $hWnd                - a handle value.
;                  $iAttribute          - an integer value.
;                  $iData               - an integer value.
; Return values .: Success: 1 Failure: @error, @extended & False
; Author ........: argumentum
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: https://www.autoitscript.com/forum/topic/211475-winapithemeex-darkmode-for-autoits-win32guis/?do=findComment&comment=1530103
; Example .......: No
; ===============================================================================================================================
Func _WinAPI_DwmSetWindowAttribute_unr($hWnd, $iAttribute, $iData) ; #include <WinAPIGdi.au3> ; unthoughtful unrestricting mod.
    Local $aCall = DllCall('dwmapi.dll', 'long', 'DwmSetWindowAttribute', 'hwnd', $hWnd, 'dword', $iAttribute, _
            'dword*', $iData, 'dword', 4)
    If @error Then Return SetError(@error, @extended, 0)
    If $aCall[0] Then Return SetError(10, $aCall[0], 0)
    Return 1
EndFunc   ;==>_WinAPI_DwmSetWindowAttribute_unr

#EndRegion

#Region Experimental Functions

;~ Func FixDarkScrollBar()
;~     Local $hComctl = _WinAPI_GetModuleHandle("comctl32.dll")
;~     If $hComctl Then
;~         Local $addr = _FindDelayLoadThunkInModule($hComctl, $UxThemeDLL, $OpenNcThemeDataOrdinal)
;~         If $addr Then
;~             Local $oldProtect, $MyOpenThemeData

;~             If _WinAPI_VirtualProtect($addr, DllStructGetSize(DllStructCreate("ptr")), $PAGE_READWRITE, $oldProtect) Then
;~                 $MyOpenThemeData = DLLCallbackRegister("_Modifyed_OpenNcThemeData", "lresult", "hwnd;wstr")
;~                 DllStructSetData(DllStructCreate("ptr", $addr), 1, $MyOpenThemeData)
;~                 _WinAPI_VirtualProtect($addr, DllStructGetSize(DllStructCreate("ptr")), $oldProtect, 0)
;~             EndIf
;~         EndIf
;~     EndIf
;~ EndFunc


;~ Func _Modifyed_OpenNcThemeData($hWnd, $classList)
;~     If StringCompare($classList, "ScrollBar") = 0 Then
;~         $hWnd = 0
;~         $classList = "Explorer::ScrollBar"
;~     EndIf
;~     Return _WinAPI_OpenNcThemeData($hWnd, $classList)
;~ EndFunc

#EndRegion