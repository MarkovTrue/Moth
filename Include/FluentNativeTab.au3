#include-once
#include <GuiTab.au3>
#include <TabConstants.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeTab – штатный Tab в теме Fluent
; ============================================================
; Вкладки рисует сабкласс: страница цветом фона с рамкой, выбранная вкладка открыта
; снизу и отмечена акцентной линией. Счётчик прокрутки вкладок Windows создаёт позже,
; при переполнении: он получает тему в момент появления. GroupBox на вкладке уводятся
; вниз по порядку перекрытия и перерисовываются после неё, иначе вкладка их закрасила бы.
; По мотивам GUIDarkTheme (UEZ, mLipok, WildByDesign).

; Вкладки, уже опущенные вниз порядка перекрытия
Global $__g_oFluentTabLowered[]

__FluentTheme_RegisterClass('SysTabControl32', '__FluentNativeTab_Apply')


Func __FluentNativeTab_Apply($hGui, $hCtrl)
	#forceref $hGui
	Local Const $WM_CHANGEUISTATE = 0x0127, $UIS_SET_HIDEFOCUS = 0x00010001
	; Вкладка ниже своих контролов, иначе она перекрыла бы их при перерисовке
	If Not MapExists($__g_oFluentTabLowered, String($hCtrl)) Then
		$__g_oFluentTabLowered[String($hCtrl)] = True
		_WinAPI_SetWindowPos($hCtrl, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))
	EndIf
	_FluentSubclass_Set($hCtrl, '__FluentNativeTab_Proc')
	; Без рамки фокуса у вкладок
	_SendMessage($hCtrl, $WM_CHANGEUISTATE, $UIS_SET_HIDEFOCUS, 0)
	If Not $g_bFluentDark Then Return __FluentTheme_SetTheme($hCtrl, "Explorer")
	Return __FluentTheme_SetTheme($hCtrl, __FluentTheme_DarkName(), "Tab")
EndFunc   ;==>__FluentNativeTab_Apply


Func __FluentNativeTab_Proc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Switch $iMsg
		Case $WM_ERASEBKGND
			Return 1

		Case $WM_PAINT
			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			If @error Or Not $hDC Then Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
			__FluentNativeTab_Paint($hWnd, $hDC)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 0

		Case $WM_PARENTNOTIFY
			; Счётчик прокрутки вкладок: lParam - handle нового окна числом
			If _WinAPI_LoWord($wParam) = $WM_CREATE Then
				Local $hChild = HWnd($lParam)
				If _WinAPI_GetClassName($hChild) = "msctls_updown32" Then _FluentTheme_ApplyCtrl(_WinAPI_GetParent($hWnd), $hChild)
			EndIf
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeTab_Proc


Func __FluentNativeTab_Paint($hWnd, $hDC)
	For $hGroup In $__g_aFluentGroupInTab
		If _WinAPI_IsWindowVisible($hGroup) Then _
				_WinAPI_SetWindowPos($hGroup, $HWND_BOTTOM, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))
	Next

	Local $tClient = _WinAPI_GetClientRect($hWnd)
	Local $iW = $tClient.Right, $iH = $tClient.Bottom
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
	Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

	; Счётчик прокрутки вкладок не закрашивается
	Local $hUpDown = _FluentWinApi_FindWindowEx($hWnd, "msctls_updown32")
	If $hUpDown And _WinAPI_IsWindowVisible($hUpDown) Then
		Local $tUp = _WinAPI_GetWindowRect($hUpDown), $tTab = _WinAPI_GetWindowRect($hWnd)
		DllCall("gdi32.dll", "int", "ExcludeClipRect", "handle", $hDC, "int", $tUp.Left - $tTab.Left, _
				"int", $tUp.Top - $tTab.Top - 100, "int", $tUp.Right - $tTab.Left, "int", $tUp.Bottom - $tTab.Top + 2)
	EndIf
	_WinAPI_FillRect($hMemDC, $tClient, $__g_hFluentBrGui)

	Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
	If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
	Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)

	; Страница - под нижним краем вкладок
	Local $tFirst = DllStructCreate($tagRECT)
	_SendMessage($hWnd, $TCM_GETITEMRECT, 0, DllStructGetPtr($tFirst))
	Local $tBody = _WinAPI_CreateRect(0, $tFirst.Bottom, $iW, $iH)
	_WinAPI_FillRect($hMemDC, $tBody, $__g_hFluentBrTabBk)
	_WinAPI_FrameRect($hMemDC, $tBody, $__g_hFluentBrFrame)

	_WinAPI_SetBkMode($hMemDC, $TRANSPARENT)
	_WinAPI_SetTextColor($hMemDC, _WinAPI_SwitchColor($g_iFluentText1))
	Local $iCount = _SendMessage($hWnd, $TCM_GETITEMCOUNT, 0, 0), $iSel = _SendMessage($hWnd, $TCM_GETCURSEL, 0, 0)
	Local $tRect, $tText, $bSel
	For $i = 0 To $iCount - 1
		$bSel = $i = $iSel
		$tRect = DllStructCreate($tagRECT)
		_SendMessage($hWnd, $TCM_GETITEMRECT, $i, DllStructGetPtr($tRect))
		If $tRect.Right < 0 Or $tRect.Left > $iW Then ContinueLoop

		If $bSel Then
			$tRect.top -= 2
			_WinAPI_FillRect($hMemDC, $tRect, $__g_hFluentBrTabBk)
			_WinAPI_FrameRect($hMemDC, $tRect, $__g_hFluentBrFrame)
			; Низ выбранной вкладки открыт в страницу, сверху акцентная линия
			Local $tOpen = _WinAPI_CreateRect($tRect.Left + 1, $tRect.Bottom - 1, $tRect.Right - 1, $tRect.Bottom + 1)
			_WinAPI_FillRect($hMemDC, $tOpen, $__g_hFluentBrTabBk)
			Local $hOldPen = _WinAPI_SelectObject($hMemDC, $__g_hFluentPen2Accent)
			_WinAPI_MoveTo($hMemDC, $tRect.Left + 1, $tRect.Top)
			_WinAPI_LineTo($hMemDC, $tRect.Right - 2, $tRect.Top + 1)
			_WinAPI_SelectObject($hMemDC, $hOldPen)
		Else
			$tRect.bottom += 1
			$tRect.Left -= 1
			$tRect.Right += 1
			_WinAPI_FillRect($hMemDC, $tRect, $__g_hFluentBrTab)
			_WinAPI_FrameRect($hMemDC, $tRect, $__g_hFluentBrFrame)
		EndIf

		$tText = _WinAPI_CreateRect($tRect.Left + 6, $tRect.Top + ($bSel ? 1 : 3), $tRect.Right - 6, $tRect.Bottom - 3)
		DllCall("user32.dll", "int", "DrawTextW", "handle", $hMemDC, "wstr", _GUICtrlTab_GetItemText($hWnd, $i), _
				"int", -1, "struct*", $tText, "uint", BitOR($DT_CENTER, $DT_VCENTER, $DT_SINGLELINE, $DT_NOCLIP))
	Next

	_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)

	; GroupBox на вкладке - поверх готовой вкладки
	For $hGroup In $__g_aFluentGroupInTab
		If _WinAPI_IsWindowVisible($hGroup) Then _WinAPI_RedrawWindow($hGroup, 0, 0, BitOR($RDW_INVALIDATE, $RDW_NOERASE))
	Next

	_WinAPI_SelectObject($hMemDC, $hOldBmp)
	_WinAPI_SelectObject($hMemDC, $hOldFont)
	_WinAPI_DeleteObject($hBitmap)
	_WinAPI_DeleteDC($hMemDC)
EndFunc   ;==>__FluentNativeTab_Paint
