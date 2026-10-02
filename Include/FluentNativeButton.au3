#include-once
#include <ButtonConstants.au3>
#include <GuiButton.au3>
#include <WinAPITheme.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeButton – штатные Button, CheckBox, Radio, GroupBox в теме Fluent
; ============================================================
; Кнопка берёт тёмную тему системы. Флажок, переключатель и рамка группы до Windows 11
; 24H2 в тёмной теме не рисуются: их рисует сабкласс поверх частей темы DarkMode_Explorer.
; На вкладке фон контрола - фон страницы вкладки. По мотивам GUIDarkTheme (argumentum, WildByDesign).

; Флажки и переключатели под сабклассом: [часть темы, выравнивание BS_*, на вкладке]
Global $__g_aFluentBtnSub[0][3]

__FluentTheme_RegisterClass('Button', '__FluentNativeButton_Apply')
__FluentHookAdd('theme-reset', '__FluentNativeButton_Reset')


Func __FluentNativeButton_Apply($hGui, $hCtrl)
	Local Const $BP_RADIOBUTTON = 2, $BP_CHECKBOX = 3
	Local $iStyle = _WinAPI_GetWindowLong($hCtrl, $GWL_STYLE)
	Local $iType = BitAND($iStyle, 0xF)
	Local $bCheckBox = $iType = $BS_CHECKBOX Or $iType = $BS_AUTOCHECKBOX
	Local $bCheck = $bCheckBox Or $iType = $BS_AUTO3STATE
	Local $bRadio = $iType = $BS_AUTORADIOBUTTON, $bGroup = $iType = $BS_GROUPBOX
	Local $iID = _WinAPI_GetDlgCtrlID($hCtrl), $bInTab = __FluentTheme_InTab($hGui, $hCtrl)
	__FluentTheme_UseCtlColor($WM_CTLCOLORBTN)

	If $g_bFluentDark And Not __FluentTheme_Is24H2() Then
		If $bGroup Then
			__FluentTheme_SetTheme($hCtrl, "DarkMode_Explorer", "Button")
			Return _FluentSubclass_Set($hCtrl, '__FluentNativeButton_GroupProc')
		EndIf
		If $bCheck Or $bRadio Then
			__FluentTheme_SetTheme($hCtrl, "DarkMode_Explorer", "Button")
			Local $iIndex = UBound($__g_aFluentBtnSub)
			ReDim $__g_aFluentBtnSub[$iIndex + 1][3]
			$__g_aFluentBtnSub[$iIndex][0] = $bRadio ? $BP_RADIOBUTTON : $BP_CHECKBOX
			$__g_aFluentBtnSub[$iIndex][1] = BitAND($iStyle, $BS_CENTER)
			$__g_aFluentBtnSub[$iIndex][2] = $bInTab
			Return _FluentSubclass_Set($hCtrl, '__FluentNativeButton_CheckProc', $iIndex)
		EndIf
	EndIf

	; Подпись группы и переключателя красит AutoIt по GUICtrlSetColor
	If $bGroup Or $bRadio Then
		GUICtrlSetColor($iID, $g_iFluentText1)
		If $bInTab Then
			If $bGroup Then
				ReDim $__g_aFluentGroupInTab[UBound($__g_aFluentGroupInTab) + 1]
				$__g_aFluentGroupInTab[UBound($__g_aFluentGroupInTab) - 1] = $hCtrl
			EndIf
			GUICtrlSetBkColor($iID, $g_iFluentBg)
		EndIf
		Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? __FluentTheme_DarkName() : "Explorer")
	EndIf

	If $bInTab And $bCheckBox Then GUICtrlSetBkColor($iID, $g_iFluentBg)
	Return __FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? "DarkMode_Explorer" : "Explorer")
EndFunc   ;==>__FluentNativeButton_Apply


Func __FluentNativeButton_Reset()
	ReDim $__g_aFluentBtnSub[0][3]
EndFunc   ;==>__FluentNativeButton_Reset


; Флажок и переключатель: часть темы по состоянию и подпись светлым текстом, через буфер
Func __FluentNativeButton_CheckProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID
	Local Const $BP_CHECKBOX = 3
	Switch $iMsg
		Case $WM_ERASEBKGND
			Return 1

		Case $WM_PAINT
			Local $iPart = $__g_aFluentBtnSub[$pData][0], $iAlign = $__g_aFluentBtnSub[$pData][1]
			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			Local $tClient = _WinAPI_GetClientRect($hWnd)
			Local $iW = $tClient.Right, $iH = $tClient.Bottom
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

			Local $hTheme = _WinAPI_OpenThemeData($hWnd, "DarkMode_Explorer::Button")
			Local $iState = __FluentNativeButton_StateId($hWnd, $iPart)
			Local $iTextFlags = BitOR($DT_SINGLELINE, $DT_NOCLIP, $DT_VCENTER)
			Switch $iAlign
				Case $BS_CENTER
					$iTextFlags = BitOR($iTextFlags, $DT_CENTER)
				Case $BS_RIGHT
					$iTextFlags = BitOR($iTextFlags, $DT_RIGHT)
			EndSwitch

			Local $tTextRect = _WinAPI_GetThemeBackgroundContentRect($hTheme, $iPart, $iState, $hMemDC, $tClient)
			Local $tSize = _WinAPI_GetThemePartSize($hTheme, $iPart, 0, Null, Null, $TS_TRUE)
			_WinAPI_DrawThemeParentBackground($hWnd, $hMemDC, $tClient)
			If $__g_aFluentBtnSub[$pData][2] Then _WinAPI_FillRect($hMemDC, $tClient, $__g_hFluentBrTabBk)

			; Часть темы - по высоте контрола, подпись справа от неё частью CheckBox и у переключателя
			Local $tPart = _WinAPI_CreateRectEx(0, 0, $tSize.X, $iH)
			_WinAPI_DrawThemeBackground($hTheme, $iPart, $iState, $hMemDC, $tPart)

			Local $tOpts = DllStructCreate($tagDTTOPTS)
			$tOpts.Size = DllStructGetSize($tOpts)
			$tOpts.Flags = $DTT_TEXTCOLOR
			$tOpts.clrText = _WinAPI_IsWindowEnabled($hWnd) ? _WinAPI_SwitchColor($g_iFluentText1) : 0x808080
			Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
			If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
			Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)
			$tTextRect.Left += $tSize.X + 3
			$tTextRect.Right += $tSize.X + 3
			_WinAPI_DrawThemeTextEx($hTheme, $BP_CHECKBOX, $iState, $hMemDC, _WinAPI_GetWindowText($hWnd), $tTextRect, $iTextFlags, $tOpts)

			_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)
			_WinAPI_CloseThemeData($hTheme)
			_WinAPI_SelectObject($hMemDC, $hOldFont)
			_WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 0
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeButton_CheckProc


; Состояние части темы флажка (CBS_*) или переключателя (RBS_*): включён, под курсором, недоступен
Func __FluentNativeButton_StateId($hWnd, $iPart)
	Local Const $BP_RADIOBUTTON = 2, $BST_HOT = 0x0200
	Local $iState = _GUICtrlButton_GetState($hWnd)
	Local $bHot = BitAND($iState, $BST_HOT) <> 0, $bEnabled = _WinAPI_IsWindowEnabled($hWnd)
	; Строки тем: 1-4 выключен, 5-8 включён, 9-12 третье состояние; внутри - обычный, наведён,
	; нажат, недоступен
	Local $iBase = 1
	If BitAND($iState, $BST_CHECKED) Then $iBase = 5
	If $iPart <> $BP_RADIOBUTTON And BitAND($iState, $BST_INDETERMINATE) Then $iBase = 9
	If Not $bEnabled Then Return $iBase + 3
	Return $bHot ? $iBase + 1 : $iBase
EndFunc   ;==>__FluentNativeButton_StateId


; Рамка группы: скруглённый контур с разрывом под подписью, подпись светлым текстом темы
Func __FluentNativeButton_GroupProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	Local Const $BP_GROUPBOX = 4, $GBS_NORMAL = 1
	Switch $iMsg
		Case $WM_ERASEBKGND
			Return 1

		Case $WM_PAINT
			Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
			Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
			Local $tClient = _WinAPI_GetClientRect($hWnd)
			Local $iW = $tClient.Right, $iH = $tClient.Bottom
			Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
			Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iW, $iH)
			Local $hOldBmp = _WinAPI_SelectObject($hMemDC, $hBitmap)

			Local $hFont = _SendMessage($hWnd, $WM_GETFONT, 0, 0)
			If Not $hFont Then $hFont = _WinAPI_GetStockObject($DEFAULT_GUI_FONT)
			Local $hOldFont = _WinAPI_SelectObject($hMemDC, $hFont)
			Local $sText = _WinAPI_GetWindowText($hWnd)
			Local $tTextSize = _WinAPI_GetTextExtentPoint32($hMemDC, $sText)
			Local $iTextW = $tTextSize.X, $iTextH = $tTextSize.Y

			; Внутренность группы не перерисовывается: там свои контролы
			Local $tInner = _WinAPI_GetClientRect($hWnd)
			$tInner.Top += $iTextH + 2
			$tInner.Bottom -= 5
			$tInner.Left += 5
			$tInner.Right -= 5
			_WinAPI_ExcludeClipRect($hDC, $tInner)
			_WinAPI_ExcludeClipRect($hMemDC, $tInner)
			_WinAPI_DrawThemeParentBackground($hWnd, $hMemDC, $tClient)

			Local $hGfx = _GDIPlus_GraphicsCreateFromHDC($hMemDC)
			_GDIPlus_GraphicsSetSmoothingMode($hGfx, 2)
			Local $iTop = Int($iTextH / 2)
			Local $hPath = _FluentPathRR(0, $iTop, $iW - 1, $iH - 2 - $iTop, 1)
			If $sText <> "" Then
				; Разрыв контура под подписью
				Local $hRegion = _GDIPlus_RegionCreate()
				_GDIPlus_RegionCombineRect($hRegion, 7, 0, $iTextW + 4, $iTextH, 0)
				_GDIPlus_GraphicsSetClipRegion($hGfx, $hRegion, 3)
				_GDIPlus_RegionDispose($hRegion)
			EndIf
			Local $hPen = _GDIPlus_PenCreate(0xFF505050, 1)
			_GDIPlus_GraphicsDrawPath($hGfx, $hPath, $hPen)
			_GDIPlus_GraphicsResetClip($hGfx)
			_GDIPlus_PenDispose($hPen)
			_GDIPlus_PathDispose($hPath)
			_GDIPlus_GraphicsDispose($hGfx)

			If $sText <> "" Then
				Local $hTheme = _WinAPI_OpenThemeData($hWnd, "DarkMode_Explorer::Button")
				Local $tOpts = DllStructCreate($tagDTTOPTS)
				$tOpts.Size = DllStructGetSize($tOpts)
				$tOpts.Flags = $DTT_TEXTCOLOR
				$tOpts.clrText = 0xFFFFFF
				_WinAPI_DrawThemeTextEx($hTheme, $BP_GROUPBOX, $GBS_NORMAL, $hMemDC, $sText, _
						_WinAPI_CreateRectEx(9, 0, $iTextW, $iTextH), BitOR($DT_SINGLELINE, $DT_LEFT, $DT_TOP), $tOpts)
				_WinAPI_CloseThemeData($hTheme)
			EndIf

			_WinAPI_BitBlt($hDC, 0, 0, $iW, $iH, $hMemDC, 0, 0, $SRCCOPY)
			_WinAPI_SelectObject($hMemDC, $hOldFont)
			_WinAPI_SelectObject($hMemDC, $hOldBmp)
			_WinAPI_DeleteObject($hBitmap)
			_WinAPI_DeleteDC($hMemDC)
			_WinAPI_EndPaint($hWnd, $tPaint)
			Return 0
	EndSwitch
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeButton_GroupProc
