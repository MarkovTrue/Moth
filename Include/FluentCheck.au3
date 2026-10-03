#include-once
#include <StaticConstants.au3>

#include "FluentCore.au3"

; ============================================================
; FluentCheck – флажок: квадрат со скруглением и подпись
; ============================================================
; Флажок в цветах палитры: вид рисуется в GDI+ и кладётся в Pic, как у кнопок.
; Штатный флажок под тему – FluentNativeButton. Включённый – заливка акцентом и белая птичка.
; Клик по квадрату и по подписи переключает флажок на отпускание, после чего зовётся
; обработчик смены. Состояние менять только функциями модуля.
; Подпись с фигурными скобками рисует клавиши: «по {SHIFT} + Правый клик», см. _FluentTextKeys.
;
; Квадрат рисует _FluentCheck_Draw: годится и для окон, которые рисуют всё одной картинкой.

; Метрика: сторона квадрата, зазор квадрат-подпись
Global Const $gc_iFluentCheckBox = 14, $gc_iFluentCheckGap = 8

; Реестр флажков. Колонки:
; 0 ControlID, 1 HBITMAP, 2 W, 3 H, 4 подпись, 5 включён, 6 под курсором,
; 7 доступен, 8 имя функции-обработчика смены
Global $__g_aFluentChecks[0][9]

__FluentHookAdd('hover', '__FluentCheck_HoverTick')
__FluentHookAdd('render', '__FluentCheck_RenderAll')
__FluentHookAdd('shutdown', '__FluentCheck_Shutdown')


; Создаёт флажок и возвращает ControlID его Pic. $iW = -1 – ширина по подписи.
; $sOnChange получает ControlID флажка
Func _FluentCheck_Create($sText, $iX, $iY, $iW = -1, $iH = 20, $bChecked = False, $sOnChange = "")
	If $iW < 0 Then $iW = _FluentCheck_Width($sText)
	Local $iCtrl = GUICtrlCreatePic("", $iX, $iY, $iW, $iH, $SS_NOTIFY)
	GUICtrlSetOnEvent($iCtrl, "__FluentCheck_OnClick")
	_FluentHandCursor($iCtrl)
	_FluentClickOnRelease($iCtrl)
	_FluentDockFixed($iCtrl)

	Local $iIndex = __FluentCheck_FreeSlot()
	If $iIndex < 0 Then
		$iIndex = UBound($__g_aFluentChecks)
		ReDim $__g_aFluentChecks[$iIndex + 1][9]
	EndIf
	$__g_aFluentChecks[$iIndex][0] = $iCtrl
	$__g_aFluentChecks[$iIndex][1] = 0
	$__g_aFluentChecks[$iIndex][2] = $iW
	$__g_aFluentChecks[$iIndex][3] = $iH
	$__g_aFluentChecks[$iIndex][4] = $sText
	$__g_aFluentChecks[$iIndex][5] = $bChecked
	$__g_aFluentChecks[$iIndex][6] = False
	$__g_aFluentChecks[$iIndex][7] = True
	$__g_aFluentChecks[$iIndex][8] = $sOnChange

	__FluentCheck_Render($iIndex)
	Return $iCtrl
EndFunc   ;==>_FluentCheck_Create


; Ширина флажка с подписью: вызывающему для раскладки
Func _FluentCheck_Width($sText)
	If $sText = "" Then Return $gc_iFluentCheckBox
	Local $iTextW = StringInStr($sText, "{") ? _FluentTextKeys(0, $sText, 0, 0, 0, _FluentFont(), 0) : _FluentTextW($sText, _FluentFont())
	Return $gc_iFluentCheckBox + $gc_iFluentCheckGap + $iTextW + 2
EndFunc   ;==>_FluentCheck_Width


Func _FluentCheck_Get($iCtrl)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	Return ($i < 0) ? False : $__g_aFluentChecks[$i][5]
EndFunc   ;==>_FluentCheck_Get


; Ставит состояние без вызова обработчика: его зовёт только клик
Func _FluentCheck_Set($iCtrl, $bChecked)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentChecks[$i][5] = $bChecked Then Return
	$__g_aFluentChecks[$i][5] = $bChecked
	__FluentCheck_Render($i)
EndFunc   ;==>_FluentCheck_Set


Func _FluentCheck_SetEnabled($iCtrl, $bEnabled)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentChecks[$i][7] = $bEnabled Then Return
	$__g_aFluentChecks[$i][7] = $bEnabled
	GUICtrlSetState($iCtrl, $bEnabled ? $GUI_ENABLE : $GUI_DISABLE)
	__FluentCheck_Render($i)
EndFunc   ;==>_FluentCheck_SetEnabled


Func _FluentCheck_SetText($iCtrl, $sText)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentChecks[$i][4] = $sText Then Return
	$__g_aFluentChecks[$i][4] = $sText
	__FluentCheck_Render($i)
EndFunc   ;==>_FluentCheck_SetText


Func _FluentCheck_SetPos($iCtrl, $iX, $iY, $iW = -1, $iH = -1)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	If $i < 0 Then Return
	If $iW < 0 Then $iW = $__g_aFluentChecks[$i][2]
	If $iH < 0 Then $iH = $__g_aFluentChecks[$i][3]

	Local $bResize = ($iW <> $__g_aFluentChecks[$i][2]) Or ($iH <> $__g_aFluentChecks[$i][3])
	$__g_aFluentChecks[$i][2] = $iW
	$__g_aFluentChecks[$i][3] = $iH
	GUICtrlSetPos($iCtrl, $iX, $iY, $iW, $iH)
	If $bResize Then __FluentCheck_Render($i)
EndFunc   ;==>_FluentCheck_SetPos


; Удаляет флажок. Строка реестра помечается свободной: см. _FluentButton_Delete
Func _FluentCheck_Delete($iCtrl)
	Local $i = __FluentCheck_IndexOf($iCtrl)
	If $i < 0 Then Return
	_FluentHandCursorRemove($iCtrl)
	_FluentClickOnReleaseRemove($iCtrl)
	GUICtrlDelete($iCtrl)
	If $__g_aFluentChecks[$i][1] Then _WinAPI_DeleteObject($__g_aFluentChecks[$i][1])
	$__g_aFluentChecks[$i][0] = 0
	$__g_aFluentChecks[$i][1] = 0
EndFunc   ;==>_FluentCheck_Delete


; Перерисовка всех флажков после смены темы
Func __FluentCheck_RenderAll()
	For $i = 0 To UBound($__g_aFluentChecks) - 1
		__FluentCheck_Render($i)
	Next
EndFunc   ;==>__FluentCheck_RenderAll


Func __FluentCheck_Shutdown()
	For $i = 0 To UBound($__g_aFluentChecks) - 1
		If Not $__g_aFluentChecks[$i][0] Then ContinueLoop
		_FluentHandCursorRemove($__g_aFluentChecks[$i][0])
		_FluentClickOnReleaseRemove($__g_aFluentChecks[$i][0])
		If $__g_aFluentChecks[$i][1] Then _WinAPI_DeleteObject($__g_aFluentChecks[$i][1])
		$__g_aFluentChecks[$i][1] = 0
	Next
EndFunc   ;==>__FluentCheck_Shutdown


Func __FluentCheck_OnClick()
	Local $i = __FluentCheck_IndexOf(@GUI_CtrlId)
	If $i < 0 Or Not $__g_aFluentChecks[$i][7] Then Return
	$__g_aFluentChecks[$i][5] = Not $__g_aFluentChecks[$i][5]
	__FluentCheck_Render($i)
	If $__g_aFluentChecks[$i][8] <> "" Then Call($__g_aFluentChecks[$i][8], $__g_aFluentChecks[$i][0])
EndFunc   ;==>__FluentCheck_OnClick


; Опрос наведения: Pic не шлёт WM_MOUSELEAVE, положение курсора опрашивает таймер ядра
Func __FluentCheck_HoverTick()
	Local $iUnder = _FluentCtrlUnderCursor()
	For $i = 0 To UBound($__g_aFluentChecks) - 1
		If Not $__g_aFluentChecks[$i][0] Then ContinueLoop
		Local $bHover = ($iUnder = $__g_aFluentChecks[$i][0]) And $__g_aFluentChecks[$i][7]
		If $bHover <> $__g_aFluentChecks[$i][6] Then
			$__g_aFluentChecks[$i][6] = $bHover
			__FluentCheck_Render($i)
		EndIf
	Next
EndFunc   ;==>__FluentCheck_HoverTick


; Квадрат флажка стороной $gc_iFluentCheckBox с левым верхним углом в ($nX, $nY).
; Выключенный – рамка по усиленной грани поля, включённый – акцент и птичка;
; под курсором рамка и заливка светлеют, недоступный – приглушён
Func _FluentCheck_Draw($hGfx, $nX, $nY, $bChecked, $bHover = False, $bEnabled = True)
	Local $iBox = $gc_iFluentCheckBox
	If Not $bChecked Then
		Local $iFill = ($bHover And $bEnabled) ? $g_iFluentHover : $g_iFluentCtrlBg
		Local $iEdge = $bEnabled ? ($bHover ? $g_iFluentText3 : $g_iFluentCtrlUnder) : $g_iFluentTrackBorder
		_FluentBox($hGfx, $nX, $nY, $iBox, $iBox, $gc_nFluentRadCtrl, _FluentArgb($iFill), _FluentArgb($iEdge))
		Return
	EndIf

	Local $iAccent = $bEnabled ? ($bHover ? $g_iFluentAccentHot : $g_iFluentAccent) : $g_iFluentTrackBorder
	_FluentFill($hGfx, $nX, $nY, $iBox, $iBox, $gc_nFluentRadCtrl, _FluentArgb($iAccent))
	; Птичка в долях стороны: квадрат можно увеличить, не пересчитывая точки
	Local $hPen = _GDIPlus_PenCreate(_FluentArgb($bEnabled ? $g_iFluentOnAccent : $g_iFluentText3), $iBox / 8.75)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + $iBox * 0.25, $nY + $iBox * 0.51, $nX + $iBox * 0.43, $nY + $iBox * 0.7, $hPen)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX + $iBox * 0.43, $nY + $iBox * 0.7, $nX + $iBox * 0.77, $nY + $iBox * 0.3, $hPen)
	_GDIPlus_PenDispose($hPen)
EndFunc   ;==>_FluentCheck_Draw


; ============================================================
; Внутреннее
; ============================================================

Func __FluentCheck_IndexOf($iCtrl)
	If Not $iCtrl Then Return -1 ; 0 стоит в свободных строках реестра
	For $i = 0 To UBound($__g_aFluentChecks) - 1
		If $__g_aFluentChecks[$i][0] = $iCtrl Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentCheck_IndexOf


; Строка, освободившаяся после _FluentCheck_Delete, или -1
Func __FluentCheck_FreeSlot()
	For $i = 0 To UBound($__g_aFluentChecks) - 1
		If Not $__g_aFluentChecks[$i][0] Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentCheck_FreeSlot


Func __FluentCheck_Render($iIndex)
	If $iIndex < 0 Or $iIndex >= UBound($__g_aFluentChecks) Then Return
	If Not $__g_aFluentChecks[$iIndex][0] Then Return ; строка освобождена

	Local $iW = $__g_aFluentChecks[$iIndex][2], $iH = $__g_aFluentChecks[$iIndex][3]
	If $iW < 1 Or $iH < 1 Then Return
	Local $bEnabled = $__g_aFluentChecks[$iIndex][7]

	Local $hGfx
	Local $hCanvas = _FluentCanvas($iW, $iH, _FluentArgb($g_iFluentBg), $hGfx)

	_FluentCheck_Draw($hGfx, 0, Int(($iH - $gc_iFluentCheckBox) / 2), $__g_aFluentChecks[$iIndex][5], _
			$__g_aFluentChecks[$iIndex][6], $bEnabled)
	Local $iTextX = $gc_iFluentCheckBox + $gc_iFluentCheckGap
	; Подпись цветом подписей строк, как у соседних меток окна
	Local $sText = $__g_aFluentChecks[$iIndex][4], $iArgb = _FluentArgb($bEnabled ? $g_iFluentText2 : $g_iFluentText3)
	If StringInStr($sText, "{") Then
		_FluentTextKeys($hGfx, $sText, $iTextX, 0, $iH, _FluentFont(), $iArgb)
	ElseIf $sText <> "" Then
		_FluentText($hGfx, $sText, $iTextX, 0, $iW - $iTextX, $iH, _FluentFont(), $iArgb, 0, 1, 3)
	EndIf

	_FluentCanvasApply($__g_aFluentChecks[$iIndex][0], $__g_aFluentChecks[$iIndex][1], $hCanvas, $hGfx)
EndFunc   ;==>__FluentCheck_Render
