#include-once
#include "FluentTheme.au3"

; ============================================================
; FluentNativeEdit – штатные Edit, ListBox, ComboBox, IP Address, HotKey в теме Fluent
; ============================================================
; Поле и список получают тёмную тему системы, свою рамку (FluentTheme) и цвета через
; WM_CTLCOLOR*. Комбо - тему CFD, в которой его выпадающий список тоже тёмный.
; По мотивам GUIDarkTheme (UEZ, WildByDesign).

__FluentTheme_RegisterClass('Edit', '__FluentNativeEdit_Edit')
__FluentTheme_RegisterClass('ListBox', '__FluentNativeEdit_ListBox')
__FluentTheme_RegisterClass('ComboBox', '__FluentNativeEdit_Combo')
__FluentTheme_RegisterClass('SysIPAddress32', '__FluentNativeEdit_IpAddress')
__FluentTheme_RegisterClass('msctls_hotkey32', '__FluentNativeEdit_HotKey')


Func __FluentNativeEdit_Edit($hGui, $hCtrl)
	#forceref $hGui
	; Поле внутри комбо и IP-адреса рамку не получает: её рисует само комбо или IP-адрес.
	; Поле без своей рамки - тоже: его рамку рисует приложение или FluentInput
	Local $bBorder = BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), $WS_EX_CLIENTEDGE) Or _
			BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $WS_BORDER)
	Switch _WinAPI_GetClassName(_WinAPI_GetParent($hCtrl))
		Case "ComboBox", "SysIPAddress32"
		Case Else
			If $bBorder Then __FluentTheme_Frame($hCtrl, True)
	EndSwitch
	__FluentTheme_UseCtlColor($WM_CTLCOLOREDIT)
	; Поле только для чтения красится через WM_CTLCOLORSTATIC
	__FluentTheme_UseCtlColor($WM_CTLCOLORSTATIC)
	Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? __FluentTheme_DarkName() : "Explorer")
EndFunc   ;==>__FluentNativeEdit_Edit


Func __FluentNativeEdit_ListBox($hGui, $hCtrl)
	#forceref $hGui
	__FluentTheme_Frame($hCtrl, True)
	__FluentTheme_UseCtlColor($WM_CTLCOLORLISTBOX)
	Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? __FluentTheme_DarkName() : "Explorer")
EndFunc   ;==>__FluentNativeEdit_ListBox


Func __FluentNativeEdit_Combo($hGui, $hCtrl)
	#forceref $hGui
	Local Const $CB_GETCURSEL = 0x0147, $CB_SETCURSEL = 0x014E
	If $g_bFluentDark Then
		__FluentTheme_SetTheme($hCtrl, __FluentTheme_Is24H2() ? "DarkMode_DarkTheme" : "DarkMode_CFD", "Combobox")
		__FluentTheme_Frame($hCtrl)
	Else
		__FluentTheme_SetTheme($hCtrl, "CFD", "Combobox")
	EndIf

	; Рамка фокуса осталась бы на недоступном комбо: фокус и End её сбрасывают.
	; End переводит выбор списка-комбо на последний пункт, поэтому выбор восстанавливается
	Local $iSel = _SendMessage($hCtrl, $CB_GETCURSEL)
	Local $bDisabled = Not BitAND(WinGetState($hCtrl), $WIN_STATE_ENABLED)
	If $bDisabled Then WinSetState($hCtrl, "", @SW_ENABLE)
	ControlFocus($hCtrl, "", "")
	ControlSend($hCtrl, "", "", "{END}")
	If $bDisabled Then WinSetState($hCtrl, "", @SW_DISABLE)
	If $iSel >= 0 Then _SendMessage($hCtrl, $CB_SETCURSEL, $iSel)
	Return True
EndFunc   ;==>__FluentNativeEdit_Combo


; Рамка темы вместо системной. Цвета полей - из WM_CTLCOLOREDIT в сабклассе рамки,
; фон и точки между полями рисует свой сабкласс
Func __FluentNativeEdit_IpAddress($hGui, $hCtrl)
	#forceref $hGui
	__FluentTheme_Frame($hCtrl, True)
	_FluentSubclass_Set($hCtrl, '__FluentNativeEdit_IpProc')
	_WinAPI_RedrawWindow($hCtrl, 0, 0, BitOR($RDW_INVALIDATE, $RDW_ERASE, $RDW_ALLCHILDREN))
	Return True
EndFunc   ;==>__FluentNativeEdit_IpAddress


; IP-адрес заливает фон системным цветом окна, а точки между полями рисует бледными
Func __FluentNativeEdit_IpProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Switch $iMsg
		Case $WM_ERASEBKGND
			Return 1
		Case $WM_PAINT
			__FluentNativeEdit_IpPaint($hWnd)
			Return 0
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeEdit_IpProc


; Фон цветом полей и точка посередине каждого промежутка между полями
Func __FluentNativeEdit_IpPaint($hWnd)
	Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
	Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
	Local $tClient = _WinAPI_GetClientRect($hWnd)
	_WinAPI_FillRect($hDC, $tClient, $__g_hFluentBrCtrl)

	; Края полей в координатах IP-адреса, слева направо
	Local $aFields = _WinAPI_EnumChildWindows($hWnd, False)
	If Not @error Then
		Local $iCount = $aFields[0][0], $aEdge[$iCount][2], $tRect, $iLeft, $iRight
		For $i = 0 To $iCount - 1
			$tRect = _WinAPI_GetWindowRect($aFields[$i + 1][0])
			DllCall("user32.dll", "int", "MapWindowPoints", "hwnd", 0, "hwnd", $hWnd, "struct*", $tRect, "uint", 2)
			$iLeft = $tRect.left
			$iRight = $tRect.right
			; Вставка по левому краю
			Local $j = $i
			While $j > 0 And $aEdge[$j - 1][0] > $iLeft
				$aEdge[$j][0] = $aEdge[$j - 1][0]
				$aEdge[$j][1] = $aEdge[$j - 1][1]
				$j -= 1
			WEnd
			$aEdge[$j][0] = $iLeft
			$aEdge[$j][1] = $iRight
		Next

		Local $hOldFont = _WinAPI_SelectObject($hDC, _SendMessage($hWnd, $WM_GETFONT))
		_WinAPI_SetBkMode($hDC, $TRANSPARENT)
		_WinAPI_SetTextColor($hDC, _WinAPI_SwitchColor($g_iFluentText1))
		For $i = 0 To $iCount - 2
			$tRect = _WinAPI_CreateRect($aEdge[$i][1], $tClient.top, $aEdge[$i + 1][0], $tClient.bottom)
			_WinAPI_DrawText($hDC, ".", $tRect, BitOR($DT_CENTER, $DT_VCENTER, $DT_SINGLELINE, $DT_NOCLIP))
		Next
		_WinAPI_SelectObject($hDC, $hOldFont)
	EndIf
	_WinAPI_EndPaint($hWnd, $tPaint)
EndFunc   ;==>__FluentNativeEdit_IpPaint


; Поле горячей клавиши рисует себя само и тему не принимает
Func __FluentNativeEdit_HotKey($hGui, $hCtrl)
	#forceref $hGui, $hCtrl
	Return True
EndFunc   ;==>__FluentNativeEdit_HotKey
