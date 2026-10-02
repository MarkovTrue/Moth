#include-once
#include <GuiReBar.au3>
#include <GuiToolbar.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeToolbar – штатные Toolbar и Rebar в теме Fluent
; ============================================================
; Кнопки панели рисует WM_NOTIFY (NM_CUSTOMDRAW): фон окна, наведённая и нажатая кнопка
; скруглённой плашкой цветов кнопок темы. Rebar - без темы, цветом полей.
; По мотивам GUIDarkTheme (WildByDesign, Nine).

; NMTBCUSTOMDRAW: NMCUSTOMDRAW и цвета, которые панель берёт при TBCDRF_USECDCOLORS
Global Const $__tagFLUENT_NMTBCUSTOMDRAW = $__tagFLUENT_NMCUSTOMDRAW & ";ptr hbrMonoDither;ptr hbrLines;ptr hpenLines;" & _
		"dword clrText;dword clrMark;dword clrTextHighlight;dword clrBtnFace;dword clrBtnHighlight;dword clrHighlightHotTrack;" & _
		"long TextLeft;long TextTop;long TextRight;long TextBottom;int nStringBkMode;int nHLStringBkMode;int iListGap"

__FluentTheme_RegisterClass('ToolbarWindow32', '__FluentNativeToolbar_Toolbar')
__FluentTheme_RegisterClass('ReBarWindow32', '__FluentNativeToolbar_Rebar')


; Прозрачная панель на фоне окна или сплошная цветом полей
Func _FluentNativeToolbar_SetTransparent($hToolbar, $bOn = True)
	_GUICtrlToolbar_SetStyleTransparent($hToolbar, $bOn)
	; Цвет полосы над панелью
	Local $iColor = $bOn ? $g_iFluentBg : $g_iFluentCtrlBg
	_GUICtrlToolbar_SetColorScheme($hToolbar, $iColor, $iColor)
	_WinAPI_SetWindowPos($hToolbar, 0, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOSIZE, $SWP_NOZORDER, $SWP_FRAMECHANGED))
EndFunc   ;==>_FluentNativeToolbar_SetTransparent


Func __FluentNativeToolbar_Toolbar($hGui, $hCtrl)
	#forceref $hGui
	; Панель AutoIt по умолчанию плоская и прозрачная: прозрачность здесь лишняя
	If _GUICtrlToolbar_GetStyleFlat($hCtrl) And _GUICtrlToolbar_GetStyleTransparent($hCtrl) Then
		_GUICtrlToolbar_SetStyleTransparent($hCtrl, False)
		_GUICtrlToolbar_SetStyleFlat($hCtrl, False)
	EndIf
	_GUICtrlToolbar_SetColorScheme($hCtrl, $g_iFluentBg, $g_iFluentBg)
	_FluentMsg_Register($WM_NOTIFY, '__FluentNativeToolbar_Notify')
	Return True
EndFunc   ;==>__FluentNativeToolbar_Toolbar


Func __FluentNativeToolbar_Rebar($hGui, $hCtrl)
	#forceref $hGui
	__FluentTheme_SetTheme($hCtrl, "", "")
	_GUICtrlRebar_SetColorScheme($hCtrl, $g_iFluentCtrlBg, $g_iFluentCtrlBg)
	Local $tInfo = DllStructCreate($tagREBARBANDINFO)
	$tInfo.cbSize = DllStructGetSize($tInfo)
	$tInfo.fMask = $RBBIM_COLORS
	$tInfo.clrBack = _WinAPI_SwitchColor($g_iFluentCtrlBg)
	$tInfo.clrFore = _WinAPI_SwitchColor($g_iFluentText1)
	For $i = 0 To _GUICtrlRebar_GetBandCount($hCtrl) - 1
		_SendMessage($hCtrl, $RB_SETBANDINFOA, $i, $tInfo, 0, "wparam", "struct*")
	Next
	; Без разделителя сверху и рамок полос
	Local $iStyle = BitOR(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $CCS_NODIVIDER)
	_WinAPI_SetWindowLong($hCtrl, $GWL_STYLE, BitAND($iStyle, BitNOT($RBS_BANDBORDERS)))
	_WinAPI_SetWindowPos($hCtrl, 0, 0, 0, 0, 0, $SWP_NOMOVE)
	__FluentTheme_Frame($hCtrl)
	Return True
EndFunc   ;==>__FluentNativeToolbar_Rebar


Func __FluentNativeToolbar_Notify($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	If Not $g_bFluentDark Then Return $GUI_RUNDEFMSG
	Local $tTool = DllStructCreate($__tagFLUENT_NMTBCUSTOMDRAW, $lParam)
	If $tTool.Code <> $NM_CUSTOMDRAW Or _WinAPI_GetClassName($tTool.hWndFrom) <> "ToolbarWindow32" Then Return $GUI_RUNDEFMSG
	Local Const $TBCDRF_USECDCOLORS = 0x00800000

	; Панель во всю ширину окна тянется за его шириной. Размеры - по первому рисованию
	Local Static $iGuiW = WinGetClientSize($hWnd)[0], $iToolW = _WinAPI_GetWindowWidth($tTool.hWndFrom)
	If $iToolW = $iGuiW And __FluentTheme_IsResizable($hWnd) Then WinMove($tTool.hWndFrom, "", 0, 0, WinGetClientSize($hWnd)[0])

	Local $tRect = DllStructCreate($tagRECT, DllStructGetPtr($tTool, "left"))
	Switch $tTool.dwDrawStage
		Case $CDDS_PREPAINT
			_WinAPI_FillRect($tTool.hdc, $tRect, $__g_hFluentBrGui)
			Return $CDRF_NOTIFYITEMDRAW

		Case $CDDS_ITEMPREPAINT
			Local $iState = $tTool.uItemState
			If BitAND($iState, $CDIS_DISABLED) And Not BitAND($iState, BitOR($CDIS_HOT, $CDIS_CHECKED)) Then Return $GUI_RUNDEFMSG
			$tTool.clrText = _WinAPI_SwitchColor($g_iFluentText1)
			$tTool.clrTextHighlight = _WinAPI_SwitchColor($g_iFluentText1)
			If BitAND($iState, BitOR($CDIS_HOT, $CDIS_CHECKED)) Then
				_WinAPI_SelectObject($tTool.hdc, $__g_hFluentPenBtnBorder)
				_WinAPI_SelectObject($tTool.hdc, BitAND($iState, $CDIS_SELECTED) ? $__g_hFluentBrBtnPressed : $__g_hFluentBrBtnHot)
				_WinAPI_RoundRect($tTool.hdc, $tRect, 8, 8)
				; Иначе панель поверх нарисует свою подсветку
				$tTool.uItemState = 0
			EndIf
			Return $TBCDRF_USECDCOLORS
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeToolbar_Notify
