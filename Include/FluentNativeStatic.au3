#include-once
#include <ProgressConstants.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeStatic – подписи, SysLink, Progress, Scrollbar, подсказки в теме Fluent
; ============================================================
; Подпись со стандартными цветами перекрашивается в цвета темы, свои цвета приложения
; сохраняются. Прогресс без темы: плоская полоса цветом акцента в рамке.
; По мотивам GUIDarkTheme (WildByDesign, argumentum).

__FluentTheme_RegisterClass('Static', '__FluentNativeStatic_Label')
__FluentTheme_RegisterClass('SysLink', '__FluentNativeStatic_Link')
__FluentTheme_RegisterClass('msctls_progress32', '__FluentNativeStatic_Progress')
__FluentTheme_RegisterClass('Scrollbar', '__FluentNativeStatic_Scrollbar')
__FluentTheme_RegisterClass('tooltips_class32', '__FluentNativeStatic_Tooltip')


; Текст и фон подписи. Цвета узнаются у окна тем же WM_CTLCOLORSTATIC, которым их
; спрашивает сама подпись. Стандартный цвет любой из тем меняется на цвет текущей
Func __FluentNativeStatic_Label($hGui, $hCtrl)
	Local $iID = _WinAPI_GetDlgCtrlID($hCtrl)
	Local $hDC = _WinAPI_GetDC($hCtrl)
	_SendMessage(_WinAPI_GetParent($hCtrl), $WM_CTLCOLORSTATIC, $hDC, $hCtrl)
	Local $iText = _WinAPI_SwitchColor(_WinAPI_GetTextColor($hDC))
	Local $iBack = _WinAPI_SwitchColor(_WinAPI_GetBkColor($hDC))
	Local $bOpaque = _WinAPI_GetBkMode($hDC) = $OPAQUE
	_WinAPI_ReleaseDC($hCtrl, $hDC)

	Switch $iText
		Case 0x000000, 0xFFFFFF, 0xE6E6E6, 0x1B1B1B
			GUICtrlSetColor($iID, $g_iFluentText1)
	EndSwitch

	; Фон по умолчанию или прозрачный: на вкладке - фон страницы, иначе прозрачный.
	; Непрозрачный фон своего цвета остаётся
	Local $bDefault = False
	Switch $iBack
		Case 0x202020, 0xF3F3F3, 0x333333, 0xFFFFFF, $g_iFluentBg, $g_iFluentCtrlBg
			$bDefault = True
	EndSwitch
	If $bDefault Or Not $bOpaque Then
		GUICtrlSetBkColor($iID, __FluentTheme_InTab($hGui, $hCtrl) ? $g_iFluentBg : $GUI_BKCOLOR_TRANSPARENT)
	EndIf
	Return True
EndFunc   ;==>__FluentNativeStatic_Label


Func __FluentNativeStatic_Link($hGui, $hCtrl)
	#forceref $hGui, $hCtrl
	__FluentTheme_UseCtlColor($WM_CTLCOLORSTATIC)
	_FluentMsg_Register($WM_NOTIFY, '__FluentNativeStatic_LinkNotify')
	Return True
EndFunc   ;==>__FluentNativeStatic_Link


; Клик или Enter по ссылке с id открывает её адрес
Func __FluentNativeStatic_LinkNotify($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $wParam
	Local $tNMHDR = DllStructCreate($tagNMHDR, $lParam)
	If $tNMHDR.Code <> $NM_CLICK And $tNMHDR.Code <> $NM_RETURN Then Return $GUI_RUNDEFMSG
	If _WinAPI_GetClassName($tNMHDR.hWndFrom) <> "SysLink" Then Return $GUI_RUNDEFMSG
	Local Const $tagNMLINK = "struct;hwnd hwndFrom;uint_ptr idFrom;int code;" & (@AutoItX64 ? "int pad;" : "") & _
			"endstruct;struct;uint mask;int iLink;uint state;uint stateMask;wchar szID[48];wchar szURL[2083];endstruct"
	Local $tLink = DllStructCreate($tagNMLINK, $lParam)
	If DllStructGetData($tLink, "szID") = "" Then Return $GUI_RUNDEFMSG
	ShellExecute(DllStructGetData($tLink, "szURL"))
	Return 0
EndFunc   ;==>__FluentNativeStatic_LinkNotify


; Тема снимается, полоса и фон задаются цветом. После смены стиля позиция теряется
; и восстанавливается, скрытый прогресс остаётся скрытым
Func __FluentNativeStatic_Progress($hGui, $hCtrl)
	#forceref $hGui
	Local Const $PBST_ERROR = 2, $PBST_PAUSED = 3, $PBS_ALL = 0x1F
	Local $iID = _WinAPI_GetDlgCtrlID($hCtrl)
	Local $iPos = _SendMessage($hCtrl, $PBM_GETPOS, 0, 0)
	Local $bHidden = BitAND(GUICtrlGetState($iID), $GUI_HIDE) <> 0

	_WinAPI_SetWindowTheme($hCtrl, "", "")
	_WinAPI_SetWindowLong($hCtrl, $GWL_EXSTYLE, BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_EXSTYLE), BitNOT($WS_EX_STATICEDGE)))

	; Цвет полосы для ошибки и паузы Windows у прогресса без темы не меняет
	Local $iBar = $g_iFluentAccent
	Switch _SendMessage($hCtrl, $PBM_GETSTATE, 0, 0)
		Case $PBST_ERROR
			$iBar = 0xFF2222
		Case $PBST_PAUSED
			$iBar = 0xFCE100
	EndSwitch
	_SendMessage($hCtrl, $PBM_SETBARCOLOR, 0, _WinAPI_SwitchColor($iBar))
	_SendMessage($hCtrl, $PBM_SETBKCOLOR, 0, _WinAPI_SwitchColor($g_iFluentCtrlBg))

	; Свои стили PBS_* сохраняются, добавляется рамка
	GUICtrlSetStyle($iID, BitOR(BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $PBS_ALL), $WS_BORDER))
	_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
	_SendMessage($hCtrl, $PBM_SETPOS, $iPos, 0)
	GUICtrlSetData($iID, $iPos)
	If $bHidden Then GUICtrlSetState($iID, $GUI_HIDE)
	Return True
EndFunc   ;==>__FluentNativeStatic_Progress


Func __FluentNativeStatic_Scrollbar($hGui, $hCtrl)
	#forceref $hGui
	Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? "DarkMode_Explorer" : Null)
EndFunc   ;==>__FluentNativeStatic_Scrollbar


; DarkMode_DarkTheme у подсказки выходит блёклой
Func __FluentNativeStatic_Tooltip($hGui, $hCtrl)
	#forceref $hGui
	If Not $g_bFluentDark Then Return __FluentTheme_SetTheme($hCtrl, Null)
	Return __FluentTheme_SetTheme($hCtrl, "DarkMode_Explorer", "ToolTip")
EndFunc   ;==>__FluentNativeStatic_Tooltip
