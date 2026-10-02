#include-once
#include <ButtonConstants.au3>
#include <MsgBoxConstants.au3>
#include <WinAPIProc.au3>
#include <WinAPISys.au3>
#include <WinAPITheme.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentMsgBox – MsgBox в теме приложения
; ============================================================
; Обычный MsgBox, но на время показа стоит CBT-хук: диалог получает тёмный заголовок
; и сабкласс с цветами $g_iFluentMsgTop (текст) и $g_iFluentMsgBottom (полоса кнопок),
; кнопки - тёмную тему. В светлой теме диалог системный.
; По мотивам GUIDarkTheme (UEZ, MattyD, WildByDesign, argumentum).

Global $__g_hFluentMsgHook = 0, $__g_hFluentMsgTop = 0, $__g_hFluentMsgBottom = 0, $__g_nFluentMsgScale = 1


; Параметры и ответ как у MsgBox. $iFlag по умолчанию - информация поверх всех окон
Func _FluentMsgBox($iFlag, $sTitle, $sText, $iTimeout = 0, $hParent = 0)
	If $iFlag = Default Then $iFlag = BitOR($MB_TOPMOST, $MB_ICONINFORMATION)
	If $sTitle = Default Then $sTitle = "Information"
	If Not $g_bFluentDark Then Return MsgBox($iFlag, $sTitle, $sText, $iTimeout, $hParent)

	; Полоса кнопок - 48 px при 100%
	$__g_nFluentMsgScale = Round(_FluentWinApi_GetDpi() / 96, 2)
	If $__g_nFluentMsgScale <= 0 Then $__g_nFluentMsgScale = 1
	$__g_hFluentMsgTop = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($g_iFluentMsgTop))
	$__g_hFluentMsgBottom = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($g_iFluentMsgBottom))

	Local $hHookProc = DllCallbackRegister('__FluentMsgBox_Hook', "int", "int;wparam;lparam")
	$__g_hFluentMsgHook = _WinAPI_SetWindowsHookEx($WH_CBT, DllCallbackGetPtr($hHookProc), Null, _WinAPI_GetCurrentThreadId())
	Local $iRet = MsgBox($iFlag, $sTitle, $sText, $iTimeout, $hParent)
	If $__g_hFluentMsgHook Then _WinAPI_UnhookWindowsHookEx($__g_hFluentMsgHook)
	$__g_hFluentMsgHook = 0
	DllCallbackFree($hHookProc)
	_WinAPI_DeleteObject($__g_hFluentMsgTop)
	_WinAPI_DeleteObject($__g_hFluentMsgBottom)

	; Клики по диалогу не должны дойти до окна приложения
	While GUIGetMsg()
	WEnd
	Return $iRet
EndFunc   ;==>_FluentMsgBox


; Создание диалога: сабкласс на окно, тёмная тема на кнопки
Func __FluentMsgBox_Hook($iCode, $wParam, $lParam)
	Local Const $HCBT_CREATEWND = 3
	If $iCode = $HCBT_CREATEWND Then
		Local $hWnd = HWnd($wParam)
		Switch _WinAPI_GetClassName($hWnd)
			Case "#32770"
				_WinAPI_SetWindowSubclass($hWnd, _FluentSubclass_Callback('__FluentMsgBox_Proc'), 1000)
			Case "Button"
				_WinAPI_SetWindowTheme($hWnd, __FluentTheme_DarkName())
		EndSwitch
	EndIf
	Return _WinAPI_CallNextHookEx($__g_hFluentMsgHook, $iCode, $wParam, $lParam)
EndFunc   ;==>__FluentMsgBox_Hook


Func __FluentMsgBox_Proc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $pData
	Local Const $DWMWA_USE_IMMERSIVE_DARK_MODE = 20
	Switch $iMsg
		Case $WM_NCCREATE
			_WinAPI_DwmSetWindowAttribute($hWnd, $DWMWA_USE_IMMERSIVE_DARK_MODE, True)

		Case $WM_CTLCOLORSTATIC, $WM_CTLCOLORDLG
			_WinAPI_SetBkMode($wParam, $TRANSPARENT)
			_WinAPI_SetTextColor($wParam, 0xFFFFFF)
			Return $__g_hFluentMsgTop

		Case $WM_CTLCOLORBTN
			_WinAPI_SetTextColor($wParam, _WinAPI_SwitchColor($g_iFluentMsgBottom))
			Return $__g_hFluentMsgBottom

		Case $WM_PAINT
			; Полоса кнопок внизу диалога
			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			Local $tRect = DllStructCreate($tagRECT, DllStructGetPtr($tPaint, "rPaint"))
			$tRect.Top = $tRect.Bottom - 48 * $__g_nFluentMsgScale
			_WinAPI_FillRect($hDC, $tRect, $__g_hFluentMsgBottom)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 1

		Case $WM_COMMAND
			; Сабкласс перехватывает команды диалога: кнопку закрывает он сам
			If Not $lParam Or _WinAPI_HiWord($wParam) = $BN_CLICKED Then Return _FluentWinApi_EndDialog($hWnd, _WinAPI_LoWord($wParam))

		Case $WM_DESTROY
			_WinAPI_RemoveWindowSubclass($hWnd, _FluentSubclass_Callback('__FluentMsgBox_Proc'), $iID)
			_WinAPI_SetActiveWindow(_WinAPI_GetParent($hWnd))
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentMsgBox_Proc
