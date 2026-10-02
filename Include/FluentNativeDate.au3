#include-once
#include <GuiDateTimePicker.au3>
#include <GuiMonthCal.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeDate – штатные DateTimePicker и MonthCal в теме Fluent
; ============================================================
; Тёмной темы у поля даты нет: процедура поля рисует его светлым в память, инвертирует
; и перекрашивает фон в цвет окна. Выпадающему календарю снимается тема, чтобы работали
; его цвета, а тень окна подтягивается к расширенной рамке по таймеру: она появляется позже.
; По мотивам GUIDarkTheme (UEZ, WildByDesign).

; Поля даты с подменённой процедурой, прежняя процедура класса, колбэк новой
Global $__g_aFluentDateCtrls[0], $__g_pFluentDateOld = 0, $__g_hFluentDateCB = 0
; Поле под курсором, такты ожидания тени, ID таймера тени
Global $__g_bFluentDateHover = False, $__g_iFluentDateTicks = 0
Global Const $__FLUENT_DATE_TIMER = 0x7F31

__FluentTheme_RegisterClass('SysDateTimePick32', '__FluentNativeDate_Picker')
__FluentTheme_RegisterClass('SysMonthCal32', '__FluentNativeDate_Calendar')
__FluentHookAdd('theme-cleanup', '__FluentNativeDate_Cleanup')


Func __FluentNativeDate_Picker($hGui, $hCtrl)
	#forceref $hGui
	_FluentMsg_Register($WM_NOTIFY, '__FluentNativeDate_Notify')
	If $g_bFluentDark Then
		If Not $__g_hFluentDateCB Then $__g_hFluentDateCB = DllCallbackRegister('__FluentNativeDate_Proc', 'ptr', 'hwnd;uint;wparam;lparam')
		Local $pOld = _WinAPI_SetWindowLong($hCtrl, $GWL_WNDPROC, DllCallbackGetPtr($__g_hFluentDateCB))
		If Not $__g_pFluentDateOld Then $__g_pFluentDateOld = $pOld
		ReDim $__g_aFluentDateCtrls[UBound($__g_aFluentDateCtrls) + 1]
		$__g_aFluentDateCtrls[UBound($__g_aFluentDateCtrls) - 1] = $hCtrl

		; Цвета выпадающего календаря: фон, текст, заголовок, текст заголовка, поле месяца, чужие дни
		_GUICtrlDTP_SetMCColor($hCtrl, 0, $g_iFluentCtrlBg)
		_GUICtrlDTP_SetMCColor($hCtrl, 1, $g_iFluentText1)
		_GUICtrlDTP_SetMCColor($hCtrl, 2, _WinAPI_SwitchColor($g_iFluentAccent))
		_GUICtrlDTP_SetMCColor($hCtrl, 3, $g_iFluentText1)
		_GUICtrlDTP_SetMCColor($hCtrl, 4, $g_iFluentCtrlBg)
		_GUICtrlDTP_SetMCColor($hCtrl, 5, $g_iFluentText1)
	EndIf
	Return __FluentTheme_SetTheme($hCtrl, Null)
EndFunc   ;==>__FluentNativeDate_Picker


Func __FluentNativeDate_Calendar($hGui, $hCtrl)
	#forceref $hGui
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TEXT, $g_iFluentText1)
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TITLEBK, _WinAPI_SwitchColor($g_iFluentAccent))
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TITLETEXT, $g_iFluentText1)
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_BACKGROUND, $g_iFluentCtrlBg)
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_MONTHBK, $g_iFluentCtrlBg)
	_GUICtrlMonthCal_SetColor($hCtrl, $MCSC_TRAILINGTEXT, $g_iFluentText1)
	; Цвета календарь берёт, только если тема снята
	Return __FluentTheme_SetTheme($hCtrl, "", "")
EndFunc   ;==>__FluentNativeDate_Calendar


; Возвращает полям даты родную процедуру
Func __FluentNativeDate_Cleanup()
	If $__g_pFluentDateOld Then
		For $hCtrl In $__g_aFluentDateCtrls
			_WinAPI_SetWindowLong($hCtrl, $GWL_WNDPROC, $__g_pFluentDateOld)
		Next
	EndIf
	ReDim $__g_aFluentDateCtrls[0]
EndFunc   ;==>__FluentNativeDate_Cleanup


; Раскрытие календаря: тема снимается, рамка шире на 3 px, тень подтягивает таймер
Func __FluentNativeDate_Notify($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If Not $g_bFluentDark Then Return $GUI_RUNDEFMSG
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	If _WinAPI_GetClassName($tNMHDR.hWndFrom) <> "SysDateTimePick32" Then Return $GUI_RUNDEFMSG
	Switch $tNMHDR.Code
		Case $DTN_DROPDOWN
			__FluentTheme_SetTheme(_GUICtrlDTP_GetMonthCal($tNMHDR.hWndFrom), "", "")
			Local $hDropDown = _FluentWinApi_FindWindowEx(Null, "DropDown")
			If $hDropDown Then
				Local $aPos = WinGetPos($hDropDown)
				If IsArray($aPos) Then WinMove($hDropDown, "", $aPos[0], $aPos[1], $aPos[2] + 3, $aPos[3] + 3)
			EndIf
			$__g_iFluentDateTicks = 0
			_FluentMsg_Register($WM_TIMER, '__FluentNativeDate_Timer')
			DllCall("user32.dll", "uint_ptr", "SetTimer", "hwnd", $hWnd, "uint_ptr", $__FLUENT_DATE_TIMER, "uint", 5, "ptr", 0)
		Case $DTN_CLOSEUP
			__FluentNativeDate_TimerStop($hWnd)
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeDate_Notify


; Тень выпадающего окна появляется не сразу. Нет её за 10 тактов - тени в системе выключены
Func __FluentNativeDate_Timer($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $lParam
	If $wParam <> $__FLUENT_DATE_TIMER Then Return $GUI_RUNDEFMSG
	Local $hShadow = _FluentWinApi_FindWindowEx(Null, "SysShadow")
	If Not $hShadow Then
		$__g_iFluentDateTicks += 1
		If $__g_iFluentDateTicks <= 10 Then Return 0
	EndIf

	; Календарь мог создаться позже раскрытия: тема снимается и здесь
	Local $aWindows = _WinAPI_EnumWindows(True)
	If Not @error Then
		For $i = 1 To $aWindows[0][0]
			If $aWindows[$i][1] = "SysMonthCal32" Then __FluentTheme_SetTheme($aWindows[$i][0], "", "")
		Next
	EndIf
	If $hShadow Then
		Local $aPos = WinGetPos($hShadow)
		If IsArray($aPos) Then WinMove($hShadow, "", $aPos[0] - 3, $aPos[1] - 3, $aPos[2], $aPos[3])
	EndIf
	__FluentNativeDate_TimerStop($hWnd)
	Return 0
EndFunc   ;==>__FluentNativeDate_Timer


Func __FluentNativeDate_TimerStop($hWnd)
	DllCall("user32.dll", "bool", "KillTimer", "hwnd", $hWnd, "uint_ptr", $__FLUENT_DATE_TIMER)
	_FluentMsg_Unregister($WM_TIMER, '__FluentNativeDate_Timer')
	$__g_iFluentDateTicks = 0
EndFunc   ;==>__FluentNativeDate_TimerStop


; Процедура поля даты: светлая отрисовка системой, инверсия, серые тона и фон окна
Func __FluentNativeDate_Proc($hWnd, $iMsg, $wParam, $lParam)
	Local $iRet
	Switch $iMsg
		Case $WM_NOTIFY
			; Белая рамка выпадающего календаря убирается его покадровой отрисовкой
			Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
			If $tNMHDR.Code = $NM_CUSTOMDRAW And DllStructGetData(DllStructCreate($__tagFLUENT_NMCUSTOMDRAW, $lParam), "dwDrawStage") = $CDDS_PREPAINT Then _
					Return $CDRF_NOTIFYITEMDRAW

		Case $WM_PAINT
			__FluentNativeDate_Paint($hWnd)
			Return 0

		Case $WM_ERASEBKGND
			Return 1

		Case $WM_SETFOCUS, $WM_KILLFOCUS, $WM_LBUTTONDOWN, $WM_LBUTTONUP
			$iRet = _WinAPI_CallWindowProc($__g_pFluentDateOld, $hWnd, $iMsg, $wParam, $lParam)
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return $iRet

		Case $WM_MOUSEMOVE
			$iRet = _WinAPI_CallWindowProc($__g_pFluentDateOld, $hWnd, $iMsg, $wParam, $lParam)
			If Not $__g_bFluentDateHover Then
				$__g_bFluentDateHover = True
				_WinAPI_InvalidateRect($hWnd, 0, False)
			EndIf
			Return $iRet

		Case $WM_MOUSELEAVE
			$__g_bFluentDateHover = False
			_WinAPI_InvalidateRect($hWnd, 0, False)
	EndSwitch
	Return _WinAPI_CallWindowProc($__g_pFluentDateOld, $hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeDate_Proc


Func __FluentNativeDate_Paint($hWnd)
	Local Const $PRF_CLIENT = 0x0004
	Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
	Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
	Local $tClient = _WinAPI_GetClientRect($hWnd)
	Local $iW = $tClient.Right, $iH = $tClient.Bottom
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
	Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

	; Светлое поле системы в память и инверсия: фон чёрный, текст белый, выделение оранжевое
	_WinAPI_CallWindowProc($__g_pFluentDateOld, $hWnd, $WM_PRINTCLIENT, $hMemDC, $PRF_CLIENT)
	_WinAPI_InvertRect($hMemDC, _WinAPI_CreateRect(0, 0, $iW, $iH))

	; Пиксели в серый, почти чёрный фон - в цвет окна. Слово пикселя 0x00RRGGBB, как и RGB палитры
	Local $iSize = $iW * $iH
	Local $tPixels = DllStructCreate("dword c[" & $iSize & "]")
	Local $aBytes = DllCall("gdi32.dll", "long", "GetBitmapBits", "handle", $hBitmap, "long", $iSize * 4, "struct*", $tPixels)
	If Not @error And $aBytes[0] = $iSize * 4 Then
		Local $iPixel, $iGray
		For $i = 1 To $iSize
			$iPixel = $tPixels.c(($i))
			$iGray = Int((BitAND($iPixel, 0xFF) + BitAND(BitShift($iPixel, 8), 0xFF) + BitAND(BitShift($iPixel, 16), 0xFF)) / 3)
			$tPixels.c(($i)) = $iGray < 15 ? $g_iFluentBg : BitOR(BitShift($iGray, -16), BitShift($iGray, -8), $iGray)
		Next
		DllCall("gdi32.dll", "long", "SetBitmapBits", "handle", $hBitmap, "long", $iSize * 4, "struct*", $tPixels)
	EndIf

	Local $hOldPen = _WinAPI_SelectObject($hMemDC, $__g_hFluentPenFrame)
	Local $hOldBrush = _WinAPI_SelectObject($hMemDC, _WinAPI_GetStockObject($NULL_BRUSH))
	DllCall("gdi32.dll", "bool", "Rectangle", "handle", $hMemDC, "int", 0, "int", 0, "int", $iW, "int", $iH)
	_WinAPI_SelectObject($hMemDC, $hOldPen)
	_WinAPI_SelectObject($hMemDC, $hOldBrush)

	_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)
	_WinAPI_SelectObject($hMemDC, $hOldBmp)
	_WinAPI_DeleteObject($hBitmap)
	_WinAPI_DeleteDC($hMemDC)
	_WinAPI_EndPaint($hWnd, $tPaint)
EndFunc   ;==>__FluentNativeDate_Paint
