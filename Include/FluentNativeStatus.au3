#include-once
#include <Array.au3>
#include <GuiStatusBar.au3>
#include <WinAPIRes.au3>
#include <WinAPITheme.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeStatus – штатный StatusBar в теме Fluent
; ============================================================
; Строка состояния берёт тёмную тему системы. Уголок-захват в тёмной теме системный
; не подходит: у окна с изменяемым размером его заменяет своё окно SBS_SIZEBOX с точками
; темы на фоне строки. Части строки при ресайзе сохраняют доли ширины.
; Одна строка состояния на приложение. По мотивам GUIDarkTheme (Andreik, pixelsearch, WildByDesign).

Global $__g_hFluentStatus = 0, $__g_hFluentSizebox = 0, $__g_hFluentGripDots = 0, $__g_hFluentGripCursor = 0
; Размер захвата темы, его сдвиг от угла, высота строки, доли частей от ширины окна, фон строки
Global $__g_iFluentGrip = 0, $__g_iFluentGripPos = 1, $__g_iFluentStatusH = 0, $__g_aFluentStatusRatio[0]
Global $__g_iFluentStatusBg = 0x1C1C1C

__FluentTheme_RegisterClass('msctls_statusbar32', '__FluentNativeStatus_Apply')
OnAutoItExitRegister('__FluentNativeStatus_OnExit')


Func __FluentNativeStatus_Apply($hGui, $hCtrl)
	Local Const $SP_GRIPPER = 3
	$__g_hFluentStatus = $hCtrl
	Local $hTheme = _WinAPI_OpenThemeData($hGui, 'Status')
	$__g_iFluentGrip = _WinAPI_GetThemePartSize($hTheme, $SP_GRIPPER, 0, Null, Null, $TS_TRUE).X
	_WinAPI_CloseThemeData($hTheme)

	Local $sName = Null, $sList = Null
	$__g_iFluentStatusBg = $g_iFluentStatusBg
	If $g_bFluentDark Then
		Local $b24H2 = __FluentTheme_Is24H2()
		$sName = $b24H2 ? 'DarkMode_DarkTheme' : 'DarkMode'
		$sList = $b24H2 ? 'Status' : 'ExplorerStatusBar'
		; Фон строки у тем разный, точки захвата рисуются на нём
		If $b24H2 Then $__g_iFluentStatusBg = 0x3B3B3B
		$__g_iFluentGripPos = $b24H2 ? 0 : 1
	EndIf

	If __FluentTheme_IsResizable($hGui) Then
		_FluentMsg_Register($WM_SIZE, '__FluentNativeStatus_WmSize')
		__FluentNativeStatus_Ratio($hGui)
		__FluentNativeStatus_Sizebox($hGui)
		_WinAPI_ShowWindow($__g_hFluentSizebox, $g_bFluentDark ? @SW_SHOW : @SW_HIDE)
		_WinAPI_RedrawWindow($__g_hFluentSizebox)
	EndIf
	Return __FluentTheme_SetTheme($hCtrl, $sName, $sList)
EndFunc   ;==>__FluentNativeStatus_Apply


Func __FluentNativeStatus_OnExit()
	If $__g_hFluentGripDots Then _GDIPlus_BitmapDispose($__g_hFluentGripDots)
	If $__g_hFluentGripCursor Then _WinAPI_DestroyCursor($__g_hFluentGripCursor)
EndFunc   ;==>__FluentNativeStatus_OnExit


; Доли частей строки от ширины окна: по ним части растягиваются при ресайзе
Func __FluentNativeStatus_Ratio($hGui)
	Local $iWidth = WinGetClientSize($hGui)[0]
	Local $aParts = _GUICtrlStatusBar_GetParts($__g_hFluentStatus)
	_ArrayDelete($aParts, 0)
	ReDim $__g_aFluentStatusRatio[UBound($aParts)]
	For $i = 0 To UBound($aParts) - 1
		$__g_aFluentStatusRatio[$i] = $aParts[$i] / $iWidth
	Next
EndFunc   ;==>__FluentNativeStatus_Ratio


; Окно-захват в правом нижнем углу: класс Scrollbar со стилем SBS_SIZEBOX тянет размер
; окна сам, рисует его сабкласс
Func __FluentNativeStatus_Sizebox($hGui)
	Local Const $SBS_SIZEBOX = 0x08
	If $__g_hFluentGripDots Then _GDIPlus_BitmapDispose($__g_hFluentGripDots)
	If $__g_hFluentSizebox Then _WinAPI_DestroyWindow($__g_hFluentSizebox)
	Local $iSize = $__g_iFluentGrip + 2
	$__g_iFluentStatusH = WinGetPos($__g_hFluentStatus)[3] - 3
	$__g_hFluentGripDots = __FluentNativeStatus_Dots($hGui, $iSize)

	$__g_hFluentSizebox = _WinAPI_CreateWindowEx(0, "Scrollbar", "", BitOR($WS_CHILD, $WS_VISIBLE, $SBS_SIZEBOX), 0, 0, 0, 0, $hGui)
	_FluentSubclass_Set($__g_hFluentSizebox, '__FluentNativeStatus_SizeboxProc')
	; Курсор задаётся классу: у окна Scrollbar своего нет
	$__g_hFluentGripCursor = _WinAPI_LoadCursor(0, $OCR_SIZENWSE)
	_WinAPI_SetClassLongEx($__g_hFluentSizebox, $GCL_HCURSOR, $__g_hFluentGripCursor)
	; Прозрачный, поверх остальных, строка его не перекрывает: иначе курсор не появлялся
	_WinAPI_SetWindowLong($__g_hFluentSizebox, $GWL_EXSTYLE, BitOR(_WinAPI_GetWindowLong($__g_hFluentSizebox, $GWL_EXSTYLE), $WS_EX_TRANSPARENT))
	_WinAPI_SetWindowPos($__g_hFluentSizebox, $HWND_TOP, 0, 0, 0, 0, BitOR($SWP_NOMOVE, $SWP_NOREDRAW, $SWP_NOSIZE))
	_WinAPI_SetWindowLong($__g_hFluentStatus, $GWL_STYLE, BitOR(_WinAPI_GetWindowLong($__g_hFluentStatus, $GWL_STYLE), $WS_CLIPSIBLINGS))

	Local $aSize = WinGetClientSize($hGui)
	WinMove($__g_hFluentSizebox, "", $aSize[0] - $iSize - $__g_iFluentGripPos, $aSize[1] - $iSize - $__g_iFluentGripPos, $iSize, $iSize)
	_WinAPI_RedrawWindow($__g_hFluentSizebox)
EndFunc   ;==>__FluentNativeStatus_Sizebox


; Картинка захвата GDI+: точки SP_GRIPPER темы на фоне строки состояния
Func __FluentNativeStatus_Dots($hGui, $iSize)
	Local Const $SP_GRIPPER = 3
	Local $hTheme = _WinAPI_OpenThemeData($hGui, 'Status')
	Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($iSize, $iSize)
	Local $hGfx = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsClear($hGfx, _FluentArgb($__g_iFluentStatusBg))
	Local $hDC = _GDIPlus_GraphicsGetDC($hGfx)
	Local $iOffset = 2 + $__g_iFluentGripPos
	_WinAPI_DrawThemeBackground($hTheme, $SP_GRIPPER, 0, $hDC, _WinAPI_CreateRectEx($iOffset, $iOffset, $__g_iFluentGrip, $__g_iFluentGrip))
	_GDIPlus_GraphicsReleaseDC($hGfx, $hDC)
	_GDIPlus_GraphicsDispose($hGfx)
	_WinAPI_CloseThemeData($hTheme)
	Return $hBitmap
EndFunc   ;==>__FluentNativeStatus_Dots


Func __FluentNativeStatus_SizeboxProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	#forceref $iID, $pData
	If $iMsg = $WM_PAINT Then
		Local $tPaint = DllStructCreate($tagPAINTSTRUCT)
		Local $hDC = _WinAPI_BeginPaint($hWnd, $tPaint)
		Local $hGfx = _GDIPlus_GraphicsCreateFromHDC($hDC)
		_GDIPlus_GraphicsDrawImageRect($hGfx, $__g_hFluentGripDots, 0, 0, $__g_iFluentGrip + 2, $__g_iFluentGrip + 2)
		_GDIPlus_GraphicsDispose($hGfx)
		_WinAPI_EndPaint($hWnd, $tPaint)
		Return 0
	EndIf
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentNativeStatus_SizeboxProc


; Части строки по долям ширины, захват в угол. У развёрнутого окна захвата нет
Func __FluentNativeStatus_WmSize($hWnd, $iMsg, $wParam, $lParam)
	#forceref $iMsg, $wParam, $lParam
	If Not $__g_hFluentSizebox Or _WinAPI_GetParent($__g_hFluentSizebox) <> $hWnd Then Return $GUI_RUNDEFMSG
	Local Static $bShown = True
	If Not $g_bFluentDark Then _WinAPI_ShowWindow($__g_hFluentSizebox, @SW_HIDE)

	Local $aSize = WinGetClientSize($hWnd)
	Local $aOld = _GUICtrlStatusBar_GetParts($__g_hFluentStatus)
	Local $aParts[$aOld[0]]
	For $i = 0 To $aOld[0] - 1
		$aParts[$i] = Int($aSize[0] * $__g_aFluentStatusRatio[$i])
	Next

	If BitAND(WinGetState($hWnd), $WIN_STATE_MAXIMIZED) Then
		_GUICtrlStatusBar_SetParts($__g_hFluentStatus, $aParts)
		_WinAPI_ShowWindow($__g_hFluentSizebox, @SW_HIDE)
		$bShown = False
		Return $GUI_RUNDEFMSG
	EndIf

	; Последняя часть до края - место под захват
	If $__g_aFluentStatusRatio[UBound($aParts) - 1] <> 1 Then $aParts[UBound($aParts) - 1] = $aSize[0] - $__g_iFluentStatusH
	_GUICtrlStatusBar_SetParts($__g_hFluentStatus, $aParts)
	Local $iSize = $__g_iFluentGrip + 2
	WinMove($__g_hFluentSizebox, "", $aSize[0] - $iSize - $__g_iFluentGripPos, $aSize[1] - $iSize - $__g_iFluentGripPos, $iSize, $iSize)
	If Not $bShown And $g_bFluentDark Then
		_WinAPI_ShowWindow($__g_hFluentSizebox, @SW_SHOW)
		$bShown = True
	EndIf
	_WinAPI_RedrawWindow($__g_hFluentSizebox)
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentNativeStatus_WmSize
