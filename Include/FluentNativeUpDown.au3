#include-once
#include <Misc.au3>
#include <UpDownConstants.au3>
#include <WinAPIvkeysConstants.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeUpDown – штатный UpDown (счётчик) в теме Fluent
; ============================================================
; Стрелки рисует сабкласс: две кнопки цветами кнопок темы и глифы Segoe MDL2 Assets,
; нажатая половина подсвечивается под курсором. По мотивам GUIDarkTheme (Nine, WildByDesign).

; Сдвинутые счётчики и счётчики под курсором: handle → True
Global $__g_oFluentUpDownMoved[], $__g_oFluentUpDownHover[]

__FluentTheme_RegisterClass('msctls_updown32', '__FluentNativeUpDown_Apply')


Func __FluentNativeUpDown_Apply($hGui, $hCtrl)
	#forceref $hGui
	Local Const $UDM_GETBUDDY = 0x046A
	; Счётчик у поля сдвигается на 2 px от поля один раз: рамка темы иначе срезает его край
	Local $hBuddy = HWnd(_SendMessage($hCtrl, $UDM_GETBUDDY))
	If $hBuddy And _WinAPI_GetClassName($hBuddy) = "Edit" And Not MapExists($__g_oFluentUpDownMoved, String($hCtrl)) Then
		$__g_oFluentUpDownMoved[String($hCtrl)] = True
		Local $iShift = BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $UDS_ALIGNLEFT) ? -2 : 2
		GUICtrlSetPos(_WinAPI_GetDlgCtrlID($hCtrl), ControlGetPos("", "", $hCtrl)[0] + $iShift)
	EndIf
	_FluentSubclass_Set($hCtrl, '__FluentNativeUpDown_Proc')
	Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? __FluentTheme_DarkName() : "Explorer")
EndFunc   ;==>__FluentNativeUpDown_Apply


Func __FluentNativeUpDown_Proc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Switch $iMsg
		Case $WM_PAINT
			__FluentNativeUpDown_Paint($hWnd)
			Return 0
		Case $WM_MOUSEMOVE
			$__g_oFluentUpDownHover[String($hWnd)] = True
			_WinAPI_TrackMouseEvent($hWnd, $TME_LEAVE)
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return 0
		Case $WM_MOUSELEAVE
			MapRemove($__g_oFluentUpDownHover, String($hWnd))
			_WinAPI_InvalidateRect($hWnd, 0, False)
			Return 0
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeUpDown_Proc


Func __FluentNativeUpDown_Paint($hWnd)
	Local $bHorz = BitAND(_WinAPI_GetWindowLong($hWnd, $GWL_STYLE), $UDS_HORZ) <> 0
	Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
	Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
	Local $tRect = _WinAPI_GetClientRect($hWnd)
	Local $iW = $tRect.right, $iH = $tRect.bottom
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
	Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

	; Две кнопки: общая рамка и разделитель посередине
	_WinAPI_SelectObject($hMemDC, $__g_hFluentPenBtnBorder)
	_WinAPI_SelectObject($hMemDC, $__g_hFluentBrBtn)
	_WinAPI_SetBkMode($hMemDC, $TRANSPARENT)
	_WinAPI_Rectangle($hMemDC, $tRect)
	If $bHorz Then
		_WinAPI_DrawLine($hMemDC, Int($iW / 2), 0, Int($iW / 2), $iH)
	Else
		_WinAPI_DrawLine($hMemDC, 0, Int($iH / 2), $iW, Int($iH / 2))
	EndIf

	; Половина под курсором: нажатая или наведённая
	Local $tHalf
	If MapExists($__g_oFluentUpDownHover, String($hWnd)) Then
		Local $tMouse = _WinAPI_GetMousePos(True, $hWnd)
		Local $bSecond = $bHorz ? Round($tMouse.x / $iW, 0) : Round($tMouse.y / $iH, 0)
		$tHalf = _WinAPI_GetClientRect($hWnd)
		If $bHorz Then
			If $bSecond Then
				$tHalf.left = Int($iW / 2)
			Else
				$tHalf.right = Int($iW / 2)
			EndIf
		ElseIf $bSecond Then
			$tHalf.top = Int($iH / 2)
		Else
			$tHalf.bottom = Int($iH / 2)
		EndIf
		_WinAPI_SelectObject($hMemDC, _IsPressed($VK_LBUTTON) ? $__g_hFluentBrBtnPressed : $__g_hFluentBrBtnHot)
		_WinAPI_Rectangle($hMemDC, $tHalf)
	EndIf

	; Стрелки глифами Segoe MDL2 Assets: EDD9/EDDA - влево/вправо, EDDB/EDDC - вверх/вниз
	Local $nScale = _FluentWinApi_GetDpiForWindow($hWnd) / 96
	If $nScale <= 0 Then $nScale = 1
	Local $iFontH = 7 * $nScale
	Local $hFont = _WinAPI_CreateFont($iFontH, 0, 0, 0, $FW_NORMAL, False, False, False, $DEFAULT_CHARSET, _
			$OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $PROOF_QUALITY, $DEFAULT_PITCH, "Segoe MDL2 Assets")
	_WinAPI_SelectObject($hMemDC, $hFont)
	_WinAPI_SetTextColor($hMemDC, _WinAPI_SwitchColor($g_iFluentText1))
	Local $iFlags = BitOR($DT_CENTER, $DT_VCENTER, $DT_NOCLIP)
	Local $tText = _WinAPI_GetClientRect($hWnd)
	If $bHorz Then
		$tText.top = Int(($iH - $iFontH) / 2)
		$tText.right = $iW / 2
		_WinAPI_DrawText($hMemDC, ChrW(0xEDD9), $tText, $iFlags)
		$tText.left = Int($iW / 2)
		$tText.right = $iW
		_WinAPI_DrawText($hMemDC, ChrW(0xEDDA), $tText, $iFlags)
	Else
		$tText.top = Int((Round($iH / 2) - $iFontH) / 2)
		_WinAPI_DrawText($hMemDC, ChrW(0xEDDB), $tText, $iFlags)
		$tText.top += Round($iH / 2)
		_WinAPI_DrawText($hMemDC, ChrW(0xEDDC), $tText, $iFlags)
	EndIf

	_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)
	_WinAPI_SelectObject($hMemDC, $hOldBmp)
	_WinAPI_DeleteObject($hBitmap)
	_WinAPI_DeleteDC($hMemDC)
	_WinAPI_DeleteObject($hFont)
	_WinAPI_EndPaint($hWnd, $tPaint)
EndFunc   ;==>__FluentNativeUpDown_Paint
