#include-once
#include <SliderConstants.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeSlider – штатный Trackbar (ползунок) в теме Fluent
; ============================================================
; Дорожку и бегунок рисует WM_NOTIFY (NM_CUSTOMDRAW): дорожка серым, бегунок цветом
; акцента по форме стиля (пятиугольник вверх, вниз, влево, вправо или прямоугольник),
; под курсором светлее. Деления рисует Windows. По мотивам GUIDarkTheme (WildByDesign).

__FluentTheme_RegisterClass('msctls_trackbar32', '__FluentNativeSlider_Apply')


Func __FluentNativeSlider_Apply($hGui, $hCtrl)
	#forceref $hGui
	Local Const $WM_CHANGEUISTATE = 0x0127, $UIS_SET_HIDEFOCUS = 0x00010001
	GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentText1)
	GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentBg)
	_FluentMsg_Register($WM_NOTIFY, '__FluentNativeSlider_Notify')
	; Без рамки фокуса
	_SendMessage($hCtrl, $WM_CHANGEUISTATE, $UIS_SET_HIDEFOCUS, 0)
	Return __FluentTheme_SetTheme($hCtrl, Null)
EndFunc   ;==>__FluentNativeSlider_Apply


Func __FluentNativeSlider_Notify($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	If Not $g_bFluentDark Then Return $GUI_RUNDEFMSG
	Local $tNMCD = DllStructCreate($__tagFLUENT_NMCUSTOMDRAW, $lParam)
	If $tNMCD.Code <> $NM_CUSTOMDRAW Or _WinAPI_GetClassName($tNMCD.hWndFrom) <> "msctls_trackbar32" Then Return $GUI_RUNDEFMSG

	Switch $tNMCD.dwDrawStage
		Case $CDDS_PREPAINT
			$tNMCD.uItemState = BitAND($tNMCD.uItemState, BitNOT($CDIS_FOCUS))
			Return $CDRF_NOTIFYSUBITEMDRAW
		Case $CDDS_ITEMPREPAINT
			Switch $tNMCD.dwItemSpec
				Case $TBCD_THUMB
					Return __FluentNativeSlider_Thumb($tNMCD)
				Case $TBCD_CHANNEL
					_WinAPI_FillRect($tNMCD.hdc, _WinAPI_CreateRect($tNMCD.left, $tNMCD.top, $tNMCD.right, $tNMCD.bottom), $__g_hFluentBrChannel)
					Return $CDRF_SKIPDEFAULT
			EndSwitch
			; Деления рисует Windows
			Return $CDRF_DODEFAULT
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeSlider_Notify


; Бегунок: прямоугольник при TBS_BOTH, иначе пятиугольник остриём к делениям
Func __FluentNativeSlider_Thumb($tNMCD)
	Local $hFrom = $tNMCD.hWndFrom, $hDC = $tNMCD.hdc
	Local $iStyle = _WinAPI_GetWindowLong($hFrom, $GWL_STYLE)
	; TBS_NOTHUMB - бегунка нет вовсе
	If BitAND($iStyle, $TBS_NOTHUMB) Then Return $CDRF_SKIPDEFAULT
	Local $bBoth = BitAND($iStyle, $TBS_BOTH) <> 0, $bVert = BitAND($iStyle, $TBS_VERT) <> 0
	Local $bTop = BitAND($iStyle, $TBS_TOP) <> 0, $bLeft = BitAND($iStyle, $TBS_LEFT) <> 0

	Local $iL = $tNMCD.left, $iT = $tNMCD.top, $iR = $tNMCD.right - 1, $iB = $tNMCD.bottom
	Local $tPoint = DllStructCreate($tagPOINT)
	DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPoint)
	_WinAPI_ScreenToClient($hFrom, $tPoint)
	Local $bHot = $tPoint.X >= $iL And $tPoint.X <= $iR And $tPoint.Y >= $iT And $tPoint.Y <= $iB - 1

	Local $hOldBrush = _WinAPI_SelectObject($hDC, $bHot ? $__g_hFluentBrAccentHot : $__g_hFluentBrAccent)
	Local $hOldPen = _WinAPI_SelectObject($hDC, $__g_hFluentPenGui)
	If $bBoth Then
		DllCall("gdi32.dll", "bool", "Rectangle", "handle", $hDC, "int", $iL, "int", $iT, "int", $iR + 1, "int", $iB)
	Else
		; Пять вершин по кругу: остриё и две пары углов основания
		Local $tPoints = DllStructCreate("int p[10]"), $aP
		If $bVert Then
			Local $iMidV = ($iT + $iB) / 2
			If $bLeft Then
				Local $iSplitL = $iL + ($iB - $iT) / 2
				Local $aLeft[10] = [$iL, $iMidV, $iSplitL, $iT, $iR, $iT, $iR, $iB, $iSplitL, $iB]
				$aP = $aLeft
			Else
				Local $iSplitR = $iR - ($iB - $iT) / 2
				Local $aRight[10] = [$iR, $iMidV, $iSplitR, $iB, $iL, $iB, $iL, $iT, $iSplitR, $iT]
				$aP = $aRight
			EndIf
		Else
			Local $iMidH = ($iL + $iR) / 2
			If $bTop Then
				Local $iSplitT = $iT + ($iR - $iL) / 2
				Local $aUp[10] = [$iMidH, $iT, $iR, $iSplitT, $iR, $iB, $iL, $iB, $iL, $iSplitT]
				$aP = $aUp
			Else
				Local $iSplitB = $iB - ($iR - $iL) / 2
				Local $aDown[10] = [$iL, $iT, $iR, $iT, $iR, $iSplitB, $iMidH, $iB, $iL, $iSplitB]
				$aP = $aDown
			EndIf
		EndIf
		For $i = 0 To 9
			$tPoints.p(($i + 1)) = $aP[$i]
		Next
		DllCall("gdi32.dll", "bool", "Polygon", "handle", $hDC, "struct*", $tPoints, "int", 5)
	EndIf
	_WinAPI_SelectObject($hDC, $hOldBrush)
	_WinAPI_SelectObject($hDC, $hOldPen)
	Return $CDRF_SKIPDEFAULT
EndFunc   ;==>__FluentNativeSlider_Thumb
