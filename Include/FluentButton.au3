#include-once
#include <StaticConstants.au3>

#include "FluentCore.au3"

; ============================================================
; FluentButton – кнопка со скруглённой рамкой
; ============================================================
; Вид рисуется в GDI+ и кладётся в Pic. Клик – штатное событие Pic: обработчик
; вешается обычным GUICtrlSetOnEvent. Состояния кнопки менять только функциями
; модуля: GUICtrlSetData на Pic грузит картинку из файла, а GUICtrlSetState
; не перерисовывает вид.
;
; Иконка – имя PNG из папки _FluentInit, перекрашивается в цвет подписи. Путь к .ico
; у кнопки без подписи рисуется как есть: иконки приложения в своих цветах.
;
; Виды:
;   $FLUENTBUTTON_ICON   – иконка в рамке (выбор файла, настройки); умеет «включённое» состояние
;   $FLUENTBUTTON_SUBTLE – без рамки, фон под курсором; умеет «включённое» состояние
;   $FLUENTBUTTON_TEXT   – подпись в рамке (кнопки окна настроек); умеет «включённое» состояние
;   $FLUENTBUTTON_ACCENT – акцентная заливка; при высоте от 44 иконка встаёт над подписью

Global Const $FLUENTBUTTON_ICON = 0, $FLUENTBUTTON_SUBTLE = 1, $FLUENTBUTTON_TEXT = 2, $FLUENTBUTTON_ACCENT = 3

; Реестр кнопок. Колонки:
; 0 ControlID, 1 HBITMAP, 2 W, 3 H, 4 подпись, 5 имя иконки, 6 размер иконки,
; 7 вид, 8 включено, 9 под курсором, 10 доступна
Global $__g_aFluentButtons[0][11]

__FluentHookAdd('hover', '__FluentButton_HoverTick')
__FluentHookAdd('render', '__FluentButton_RenderAll')
__FluentHookAdd('shutdown', '__FluentButton_Shutdown')


Func _FluentButton_Create($sText, $sIcon, $iIconSize, $iX, $iY, $iW, $iH, $iKind = $FLUENTBUTTON_ICON)
	Local $iCtrl = GUICtrlCreatePic("", $iX, $iY, $iW, $iH, $SS_NOTIFY)
	_FluentHandCursor($iCtrl)
	_FluentDockFixed($iCtrl)

	Local $iIndex = __FluentButton_FreeSlot()
	If $iIndex < 0 Then
		$iIndex = UBound($__g_aFluentButtons)
		ReDim $__g_aFluentButtons[$iIndex + 1][11]
	EndIf
	$__g_aFluentButtons[$iIndex][0] = $iCtrl
	$__g_aFluentButtons[$iIndex][1] = 0
	$__g_aFluentButtons[$iIndex][2] = $iW
	$__g_aFluentButtons[$iIndex][3] = $iH
	$__g_aFluentButtons[$iIndex][4] = $sText
	$__g_aFluentButtons[$iIndex][5] = $sIcon
	$__g_aFluentButtons[$iIndex][6] = $iIconSize
	$__g_aFluentButtons[$iIndex][7] = $iKind
	$__g_aFluentButtons[$iIndex][8] = False
	$__g_aFluentButtons[$iIndex][9] = False
	$__g_aFluentButtons[$iIndex][10] = True

	__FluentButton_Render($iIndex)
	Return $iCtrl
EndFunc   ;==>_FluentButton_Create


Func _FluentButton_SetText($iCtrl, $sText)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentButtons[$i][4] = $sText Then Return
	$__g_aFluentButtons[$i][4] = $sText
	__FluentButton_Render($i)
EndFunc   ;==>_FluentButton_SetText


Func _FluentButton_SetIcon($iCtrl, $sIcon)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentButtons[$i][5] = $sIcon Then Return
	$__g_aFluentButtons[$i][5] = $sIcon
	__FluentButton_Render($i)
EndFunc   ;==>_FluentButton_SetIcon


; «Включённое» состояние тихой кнопки: подложка акцентом (раскрытая шпаргалка)
Func _FluentButton_SetOn($iCtrl, $bOn)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentButtons[$i][8] = $bOn Then Return
	$__g_aFluentButtons[$i][8] = $bOn
	__FluentButton_Render($i)
EndFunc   ;==>_FluentButton_SetOn


Func _FluentButton_SetEnabled($iCtrl, $bEnabled)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentButtons[$i][10] = $bEnabled Then Return
	$__g_aFluentButtons[$i][10] = $bEnabled
	GUICtrlSetState($iCtrl, $bEnabled ? $GUI_ENABLE : $GUI_DISABLE)
	__FluentButton_Render($i)
EndFunc   ;==>_FluentButton_SetEnabled


Func _FluentButton_SetPos($iCtrl, $iX, $iY, $iW = -1, $iH = -1)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Then Return
	If $iW < 0 Then $iW = $__g_aFluentButtons[$i][2]
	If $iH < 0 Then $iH = $__g_aFluentButtons[$i][3]

	Local $bResize = ($iW <> $__g_aFluentButtons[$i][2]) Or ($iH <> $__g_aFluentButtons[$i][3])
	$__g_aFluentButtons[$i][2] = $iW
	$__g_aFluentButtons[$i][3] = $iH
	GUICtrlSetPos($iCtrl, $iX, $iY, $iW, $iH)
	If $bResize Then __FluentButton_Render($i)
EndFunc   ;==>_FluentButton_SetPos


; Удаляет кнопку. Окно, закрывающееся раньше приложения, зовёт это до GUIDelete:
; запись в реестре переживает окно, а ControlID AutoIt выдаёт заново.
; Строка помечается свободной, а не вырезается: отрисовка отдаёт элемент реестра
; в _FluentCanvasApply по ссылке, и ReDim из обработчика рвал бы её под таймером наведения.
Func _FluentButton_Delete($iCtrl)
	Local $i = __FluentButton_IndexOf($iCtrl)
	If $i < 0 Then Return
	_FluentHandCursorRemove($iCtrl)
	GUICtrlDelete($iCtrl)
	If $__g_aFluentButtons[$i][1] Then _WinAPI_DeleteObject($__g_aFluentButtons[$i][1])
	$__g_aFluentButtons[$i][0] = 0
	$__g_aFluentButtons[$i][1] = 0
EndFunc   ;==>_FluentButton_Delete


; Перерисовка всех кнопок после смены темы
Func __FluentButton_RenderAll()
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		__FluentButton_Render($i)
	Next
EndFunc   ;==>__FluentButton_RenderAll


Func __FluentButton_Shutdown()
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		If Not $__g_aFluentButtons[$i][0] Then ContinueLoop
		_FluentHandCursorRemove($__g_aFluentButtons[$i][0])
		If $__g_aFluentButtons[$i][1] Then _WinAPI_DeleteObject($__g_aFluentButtons[$i][1])
		$__g_aFluentButtons[$i][1] = 0
	Next
EndFunc   ;==>__FluentButton_Shutdown


; Перерисовывает кнопки, которым докинг поменял размер: картинка в Pic осталась прежней
Func _FluentButton_SyncSize()
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		If Not $__g_aFluentButtons[$i][0] Then ContinueLoop
		Local $aSize = _FluentCtrlSize($__g_aFluentButtons[$i][0])
		If $aSize[0] < 1 Then ContinueLoop
		If $aSize[0] = $__g_aFluentButtons[$i][2] And $aSize[1] = $__g_aFluentButtons[$i][3] Then ContinueLoop
		$__g_aFluentButtons[$i][2] = $aSize[0]
		$__g_aFluentButtons[$i][3] = $aSize[1]
		__FluentButton_Render($i)
	Next
EndFunc   ;==>_FluentButton_SyncSize


; Опрос наведения. Pic не шлёт WM_MOUSELEAVE, поэтому положение курсора
; опрашивает общий таймер ядра (хук 'hover').
Func __FluentButton_HoverTick()
	Local $iUnder = _FluentCtrlUnderCursor()
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		If Not $__g_aFluentButtons[$i][0] Then ContinueLoop
		Local $bHover = ($iUnder = $__g_aFluentButtons[$i][0]) And $__g_aFluentButtons[$i][10]
		If $bHover <> $__g_aFluentButtons[$i][9] Then
			$__g_aFluentButtons[$i][9] = $bHover
			__FluentButton_Render($i)
		EndIf
	Next
EndFunc   ;==>__FluentButton_HoverTick


; ============================================================
; Внутреннее
; ============================================================

Func __FluentButton_IndexOf($iCtrl)
	If Not $iCtrl Then Return -1 ; 0 стоит в свободных строках реестра
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		If $__g_aFluentButtons[$i][0] = $iCtrl Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentButton_IndexOf


; Строка, освободившаяся после _FluentButton_Delete, или -1
Func __FluentButton_FreeSlot()
	For $i = 0 To UBound($__g_aFluentButtons) - 1
		If Not $__g_aFluentButtons[$i][0] Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentButton_FreeSlot


Func __FluentButton_Render($iIndex)
	If $iIndex < 0 Or $iIndex >= UBound($__g_aFluentButtons) Then Return
	If Not $__g_aFluentButtons[$iIndex][0] Then Return ; строка освобождена

	Local $iCtrl = $__g_aFluentButtons[$iIndex][0]
	Local $iW = $__g_aFluentButtons[$iIndex][2], $iH = $__g_aFluentButtons[$iIndex][3]
	Local $sText = $__g_aFluentButtons[$iIndex][4], $sIcon = $__g_aFluentButtons[$iIndex][5]
	Local $iIconSize = $__g_aFluentButtons[$iIndex][6], $iKind = $__g_aFluentButtons[$iIndex][7]
	Local $bOn = $__g_aFluentButtons[$iIndex][8], $bHover = $__g_aFluentButtons[$iIndex][9]
	Local $bEnabled = $__g_aFluentButtons[$iIndex][10]
	If $iW < 1 Or $iH < 1 Then Return

	Local $hGfx
	; Pic прямоугольный, а рамка скруглена: под углами должен быть фон окна
	Local $hCanvas = _FluentCanvas($iW, $iH, _FluentArgb($g_iFluentBg), $hGfx)

	Local $iFg = $bEnabled ? $g_iFluentText2 : $g_iFluentText3
	Local $nRad = $gc_nFluentRadCtrl

	; Включённая кнопка - как выбранный сегмент: светлая плашка с рамкой и яркая иконка.
	; Акцентом не красится: синий здесь читался как выделение, а не как нажатое
	Switch $iKind
		Case $FLUENTBUTTON_SUBTLE
			If $bOn Then
				_FluentBox($hGfx, 0, 0, $iW, $iH, $nRad, _FluentArgb($g_iFluentSegSelBg), _FluentArgb($g_iFluentSegSelBorder))
				$iFg = $g_iFluentSegSelText
			ElseIf $bHover Then
				_FluentFill($hGfx, 0, 0, $iW, $iH, $nRad, _FluentArgb($g_iFluentHover))
			EndIf

		Case $FLUENTBUTTON_ACCENT
			Local $iFill = $bHover ? $g_iFluentAccentHot : $g_iFluentAccent
			If Not $bEnabled Then $iFill = $g_iFluentTrack
			_FluentBox($hGfx, 0, 0, $iW, $iH, $nRad, _FluentArgb($iFill), _
					_FluentArgb($bEnabled ? $g_iFluentAccentEdge : $g_iFluentTrackBorder))
			$iFg = $bEnabled ? $g_iFluentOnAccent : $g_iFluentText3

		Case Else ; $FLUENTBUTTON_ICON, $FLUENTBUTTON_TEXT
			; Рамка ровная по периметру: подчёркивание снизу делало нижние углы площе
			Local $iBg = $bHover ? $g_iFluentHover : $g_iFluentCtrlBg
			_FluentBox($hGfx, 0, 0, $iW, $iH, $nRad, _FluentArgb($iBg), _FluentArgb($g_iFluentCtrlBorder))
			; Включённая кнопка ложится поверх рамки так же, как $FLUENTBUTTON_SUBTLE
			If $bOn Then
				_FluentBox($hGfx, 0, 0, $iW, $iH, $nRad, _FluentArgb($g_iFluentSegSelBg), _FluentArgb($g_iFluentSegSelBorder))
				$iFg = $g_iFluentSegSelText
			EndIf
	EndSwitch

	__FluentButton_Content($hGfx, $iW, $iH, $sText, $sIcon, $iIconSize, $iKind, $iFg)
	_FluentCanvasApply($iCtrl, $__g_aFluentButtons[$iIndex][1], $hCanvas, $hGfx)
EndFunc   ;==>__FluentButton_Render


; Иконка и подпись внутри кнопки. В высокой кнопке иконка над подписью,
; в остальных – в строку по центру.
Func __FluentButton_Content($hGfx, $iW, $iH, $sText, $sIcon, $iIconSize, $iKind, $iFg)
	Local $bSemi = ($iKind = $FLUENTBUTTON_ACCENT)
	Local $hFont = _FluentFont(0, $bSemi)

	If $sText = "" Then
		If StringRight($sIcon, 4) = ".ico" Then
			; Путь к .ico – иконка приложения в своих цветах, без перекраски
			Local $hIco = _FluentIconFile($sIcon, $iIconSize)
			If $hIco Then _GDIPlus_GraphicsDrawImage($hGfx, $hIco, Int(($iW - $iIconSize) / 2), Int(($iH - $iIconSize) / 2))
		ElseIf $sIcon <> "" Then
			_FluentDrawIcon($hGfx, $sIcon, $iIconSize, $iFg, Int(($iW - $iIconSize) / 2), Int(($iH - $iIconSize) / 2))
		EndIf
		Return
	EndIf

	Local $iTextW = _FluentTextW($sText, $hFont)

	If $sIcon = "" Then
		_FluentText($hGfx, $sText, 0, 0, $iW, $iH, $hFont, _FluentArgb($iFg), 1, 1)
		Return
	EndIf

	If $iH >= 44 Then ; иконка сверху, подпись снизу
		_FluentDrawIcon($hGfx, $sIcon, $iIconSize, $iFg, Int(($iW - $iIconSize) / 2), Int(($iH - $iIconSize - 20) / 2))
		_FluentText($hGfx, $sText, 0, $iH - 24, $iW, 20, $hFont, _FluentArgb($iFg), 1, 1)
		Return
	EndIf

	Local $iBlockW = $iIconSize + 6 + $iTextW
	Local $iX = Int(($iW - $iBlockW) / 2)
	_FluentDrawIcon($hGfx, $sIcon, $iIconSize, $iFg, $iX, Int(($iH - $iIconSize) / 2))
	_FluentText($hGfx, $sText, $iX + $iIconSize + 6, 0, $iTextW + 4, $iH, $hFont, _FluentArgb($iFg), 0, 1)
EndFunc   ;==>__FluentButton_Content
