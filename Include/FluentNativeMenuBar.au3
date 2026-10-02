#include-once
#include <GuiMenu.au3>
#include <WinAPIGdi.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeMenuBar – меню окна (полоса пунктов под заголовком) в теме Fluent
; ============================================================
; Пункты полосы становятся owner-draw: фон и подсветка цветами меню темы, у неактивного
; окна текст бледнее. Светлую линию, которую Windows рисует под полосой, закрашивает
; цвет окна. Выпадающие подменю тёмные сами после _FluentWinApi_FlushMenuThemes.
; По мотивам GUIDarkTheme (UEZ, ahmet, ioa747, Nine, ProgAndy, WildByDesign).

; Пункты полосы [ID, текст], масштаб DPI окна, шрифт пунктов
Global $__g_aFluentMenuItems[0][2], $__g_nFluentMenuScale = 1, $__g_hFluentMenuFont = 0

__FluentHookAdd('theme-window', '__FluentNativeMenuBar_Apply')
OnAutoItExitRegister('__FluentNativeMenuBar_OnExit')


Func __FluentNativeMenuBar_Apply()
	Local $hGui = $__g_hFluentThemeGui
	Local $hMenu = _GUICtrlMenu_GetMenu($hGui)
	If Not $hMenu Then Return

	_FluentMsg_Register($WM_ACTIVATE, '__FluentNativeMenuBar_Line')
	_FluentMsg_Register($WM_WINDOWPOSCHANGED, '__FluentNativeMenuBar_Line')
	_FluentMsg_Register($WM_MEASUREITEM, '__FluentNativeMenuBar_Measure')
	_FluentMsg_Register($WM_DRAWITEM, '__FluentNativeMenuBar_Draw')

	If Not $__g_hFluentMenuFont Then $__g_hFluentMenuFont = __FluentNativeMenuBar_Font("Segoe UI", 9)
	$__g_nFluentMenuScale = Round(_FluentWinApi_GetDpiForWindow($hGui) / 96, 2)
	If $__g_nFluentMenuScale <= 0 Then $__g_nFluentMenuScale = 1

	$__g_aFluentMenuItems = __FluentNativeMenuBar_Items($hMenu)
	For $i = 0 To UBound($__g_aFluentMenuItems) - 1
		_GUICtrlMenu_SetItemType($hMenu, $i, $MFT_OWNERDRAW, True)
	Next

	; Фон полосы за пунктами
	Local $tInfo = DllStructCreate("int Size;int Mask;int Style;int YMax;handle hBack;int ContextHelpID;ptr MenuData")
	$tInfo.Size = DllStructGetSize($tInfo)
	$tInfo.Mask = 2 ; MIM_BACKGROUND
	$tInfo.hBack = $__g_hFluentBrMenuBk
	DllCall("user32.dll", "bool", "SetMenuInfo", "handle", $hMenu, "struct*", $tInfo)
	_GUICtrlMenu_DrawMenuBar($hGui)
EndFunc   ;==>__FluentNativeMenuBar_Apply


Func __FluentNativeMenuBar_OnExit()
	If $__g_hFluentMenuFont Then _WinAPI_DeleteObject($__g_hFluentMenuFont)
EndFunc   ;==>__FluentNativeMenuBar_OnExit


; Пункты полосы. Пункту без ID даётся свой с 10000: по ID их различает owner-draw.
; Текст - GetMenuStringW, _GUICtrlMenu_GetItemText отдаёт его не всегда
Func __FluentNativeMenuBar_Items($hMenu)
	Local $iCount = _GUICtrlMenu_GetItemCount($hMenu), $iNextID = 10000
	Local $aItems[$iCount][2], $tText, $aLen, $tInfo
	For $i = 0 To $iCount - 1
		$tInfo = _GUICtrlMenu_GetItemInfo($hMenu, $i)
		If Not $tInfo.ID Then
			_GUICtrlMenu_SetItemID($hMenu, $i, $iNextID)
			$iNextID += 1
		EndIf
		$aItems[$i][0] = _GUICtrlMenu_GetItemID($hMenu, $i)
		$tText = DllStructCreate("wchar s[256]")
		$aLen = DllCall("user32.dll", "int", "GetMenuStringW", "handle", $hMenu, "uint", $i, "struct*", $tText, _
				"int", 255, "uint", $MF_BYPOSITION)
		$aItems[$i][1] = (Not @error And $aLen[0] > 0) ? $tText.s : ""
	Next
	Return $aItems
EndFunc   ;==>__FluentNativeMenuBar_Items


; Текст пункта по его ID. Не найден - по позиции, как у Windows без ID
Func __FluentNativeMenuBar_Text($iItemID)
	Local $iCount = UBound($__g_aFluentMenuItems)
	If $iCount = 0 Then Return ""
	For $i = 0 To $iCount - 1
		If $__g_aFluentMenuItems[$i][0] = $iItemID Then Return $__g_aFluentMenuItems[$i][1]
	Next
	Return ($iItemID >= 0 And $iItemID < $iCount) ? $__g_aFluentMenuItems[$iItemID][1] : $__g_aFluentMenuItems[0][1]
EndFunc   ;==>__FluentNativeMenuBar_Text


Func __FluentNativeMenuBar_Measure($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	Local Const $ODT_MENU = 1
	Local $tItem = DllStructCreate("uint CtlType;uint CtlID;uint itemID;uint itemWidth;uint itemHeight;ulong_ptr itemData", $lParam)
	If $tItem.CtlType <> $ODT_MENU Then Return $GUI_RUNDEFMSG
	Local $hDC = _WinAPI_GetDC($hWnd)
	_WinAPI_SelectObject($hDC, $__g_hFluentMenuFont)
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, __FluentNativeMenuBar_Text($tItem.itemID))
	_WinAPI_ReleaseDC($hWnd, $hDC)
	; Windows сама добавляет поля по бокам пункта
	$tItem.itemWidth = $tSize.X - 8 * $__g_nFluentMenuScale
	$tItem.itemHeight = $tSize.Y + 1
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeMenuBar_Measure


Func __FluentNativeMenuBar_Draw($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam
	Local Const $ODT_MENU = 1, $ODS_SELECTED = 0x0001, $ODS_HOTLIGHT = 0x0040
	Local $tItem = DllStructCreate("uint CtlType;uint CtlID;uint itemID;uint itemAction;uint itemState;ptr hwndItem;" & _
			"handle hDC;long left;long top;long right;long bottom;ulong_ptr itemData", $lParam)
	If $tItem.CtlType <> $ODT_MENU Then Return $GUI_RUNDEFMSG
	Local $hDC = $tItem.hDC, $iState = $tItem.itemState
	Local $tRect = _WinAPI_CreateRect($tItem.left, $tItem.top, $tItem.right, $tItem.bottom)

	Local $hBrush = $__g_hFluentBrMenuBk
	If BitAND($iState, $ODS_HOTLIGHT) Then $hBrush = $__g_hFluentBrMenuHot
	If BitAND($iState, $ODS_SELECTED) Then $hBrush = $__g_hFluentBrMenuSel
	_WinAPI_FillRect($hDC, $tRect, $hBrush)

	Local $iText = _WinAPI_SwitchColor($g_iFluentText1)
	If _WinAPI_GetForegroundWindow() <> $hWnd Then $iText = $g_bFluentDark ? _WinAPI_ColorAdjustLuma($iText, -30) : 0x6D6D6D
	_WinAPI_SelectObject($hDC, $__g_hFluentMenuFont)
	_WinAPI_SetBkMode($hDC, $TRANSPARENT)
	_WinAPI_SetTextColor($hDC, $iText)
	DllCall("user32.dll", "int", "DrawTextW", "handle", $hDC, "wstr", StringReplace(__FluentNativeMenuBar_Text($tItem.itemID), "&", ""), _
			"int", -1, "struct*", $tRect, "uint", BitOR($DT_SINGLELINE, $DT_VCENTER, $DT_CENTER, $DT_NOCLIP))
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeMenuBar_Draw


; Светлая линия между полосой меню и клиентской областью - цветом окна
Func __FluentNativeMenuBar_Line($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	; Дочерние окна без меню тоже шлют эти сообщения
	If Not _GUICtrlMenu_GetMenu($hWnd) Then Return $GUI_RUNDEFMSG
	Local $tClient = _WinAPI_GetClientRect($hWnd)
	DllCall("user32.dll", "int", "MapWindowPoints", "hwnd", $hWnd, "hwnd", 0, "struct*", $tClient, "uint", 2)
	If @error Then Return $GUI_RUNDEFMSG
	Local $tWindow = _WinAPI_GetWindowRect($hWnd)
	_WinAPI_OffsetRect($tClient, -$tWindow.left, -$tWindow.top)
	Local $tLine = _WinAPI_CreateRect($tClient.left, $tClient.top - 1, $tClient.right, $tClient.top)

	Local $hRgn = _WinAPI_CreateRectRgn(-20000, -20000, 20000, 20000)
	Local $hDC = _WinAPI_GetDCEx($hWnd, $hRgn, BitOR($DCX_WINDOW, $DCX_INTERSECTRGN))
	_WinAPI_FillRect($hDC, $tLine, $__g_hFluentBrGui)
	_WinAPI_ReleaseDC($hWnd, $hDC)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeMenuBar_Line


Func __FluentNativeMenuBar_Font($sFont, $nSize)
	Local Const $LOGPIXELSY = 90
	Local $hDC = _WinAPI_GetDC(0)
	Local $iHeight = -_WinAPI_MulDiv($nSize, _WinAPI_GetDeviceCaps($hDC, $LOGPIXELSY), 72)
	_WinAPI_ReleaseDC(0, $hDC)
	Return _WinAPI_CreateFont($iHeight, 0, 0, 0, $FW_NORMAL, False, False, False, $DEFAULT_CHARSET, _
			$OUT_DEFAULT_PRECIS, $CLIP_DEFAULT_PRECIS, $PROOF_QUALITY, $DEFAULT_PITCH, $sFont)
EndFunc   ;==>__FluentNativeMenuBar_Font
