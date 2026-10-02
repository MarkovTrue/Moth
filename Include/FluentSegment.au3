#include-once
#include <StaticConstants.au3>
#include <StringConstants.au3>

#include "FluentCore.au3"

; ============================================================
; FluentSegment – переключатель-сегменты вместо радиокнопок
; ============================================================
; Группа рисуется в GDI+ одной картинкой в Pic: дорожка, выбранный сегмент
; пилюлей, иконка и подпись. Клик разбирается по X курсора.
; Ширина сегмента – по его собственной подписи: по самой длинной короткие
; превращались в пустые полосы. _FluentSegment_SetWidth растягивает группу до соседних
; строк, прибавка уходит сначала узким сегментам.

; Иконка сегмента – имя PNG из папки иконок, перекрашенного под подпись, либо полный путь
; к .ico: такая рисуется как есть, 16 px, в своих цветах.
; Выбор -1 – ни один сегмент не выбран: так группа служит рядом быстрых кнопок.

; Метрика: поле дорожки, поля внутри сегмента, зазор иконка-подпись, размер иконки PNG и .ico.
; Поле 2: выбранный сегмент на 4 px ниже дорожки, рядом с кнопкой той же высоты не теряется
Global Const $gc_iFluentSegmentPad = 2, $gc_iFluentSegmentPadX = 10, $gc_iFluentSegmentGap = 6, $gc_iFluentSegmentIcon = 14
Global Const $gc_iFluentSegmentIconFile = 16

; Реестр групп. Колонки:
; 0 ControlID Pic, 1 HBITMAP, 2 X, 3 Y, 4 W, 5 H, 6 подписи "A|B",
; 7 иконки "A|B", 8 выбранный, 9 подсвеченный (-1 нет), 10 ширины "w1|w2",
; 11 имя функции-обработчика смены, 12 заданная ширина группы (0 – по подписям),
; 13 ширины по подписям "w1|w2" – от них иконка с подписью встаёт по центру сегмента,
; 14 подсказки "A|B" ("" – без подсказок), 15 функция установки подсказки,
; 16 сегмент, чья подсказка сейчас стоит на Pic (-1 никакой)
Global $__g_aFluentSegments[0][17]

__FluentHookAdd('hover', '__FluentSegment_HoverTick')
__FluentHookAdd('render', '__FluentSegment_RenderAll')
__FluentHookAdd('shutdown', '__FluentSegment_Shutdown')


; Создаёт группу и возвращает ControlID её Pic. $sIcons – имена PNG через "|".
; Пустое имя (или "" на всю группу) – сегмент из одной подписи, без места под иконку.
Func _FluentSegment_Create($sTexts, $sIcons, $iX, $iY, $iH = 28, $iSelected = 0, $sOnChange = "")
	Local $sWidths, $sNatural
	Local $iW = __FluentSegment_Layout($sTexts, $sIcons, 0, $sWidths, $sNatural)

	Local $iCtrl = GUICtrlCreatePic("", $iX, $iY, $iW, $iH, $SS_NOTIFY)
	GUICtrlSetOnEvent($iCtrl, "__FluentSegment_OnClick")
	_FluentHandCursor($iCtrl)
	_FluentDockFixed($iCtrl)

	Local $iIndex = __FluentSegment_FreeSlot()
	If $iIndex < 0 Then
		$iIndex = UBound($__g_aFluentSegments)
		ReDim $__g_aFluentSegments[$iIndex + 1][17]
	EndIf
	$__g_aFluentSegments[$iIndex][0] = $iCtrl
	$__g_aFluentSegments[$iIndex][1] = 0
	$__g_aFluentSegments[$iIndex][2] = $iX
	$__g_aFluentSegments[$iIndex][3] = $iY
	$__g_aFluentSegments[$iIndex][4] = $iW
	$__g_aFluentSegments[$iIndex][5] = $iH
	$__g_aFluentSegments[$iIndex][6] = $sTexts
	$__g_aFluentSegments[$iIndex][7] = $sIcons
	$__g_aFluentSegments[$iIndex][8] = $iSelected
	$__g_aFluentSegments[$iIndex][9] = -1
	$__g_aFluentSegments[$iIndex][10] = $sWidths
	$__g_aFluentSegments[$iIndex][11] = $sOnChange
	$__g_aFluentSegments[$iIndex][12] = 0
	$__g_aFluentSegments[$iIndex][13] = $sNatural
	$__g_aFluentSegments[$iIndex][14] = ""
	$__g_aFluentSegments[$iIndex][15] = ""
	$__g_aFluentSegments[$iIndex][16] = -1

	__FluentSegment_Render($iIndex)
	Return $iCtrl
EndFunc   ;==>_FluentSegment_Create


; Подсказки сегментов, тексты через "|". $sSetTip – функция окна (ControlID, текст),
; которая ставит подсказку по-своему; пустая – штатный GUICtrlSetTip.
Func _FluentSegment_SetTips($iCtrl, $sTips, $sSetTip = "")
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Then Return
	$__g_aFluentSegments[$i][14] = $sTips
	$__g_aFluentSegments[$i][15] = $sSetTip
	$__g_aFluentSegments[$i][16] = -1 ; тексты могли смениться – поставить заново
	__FluentSegment_ApplyTip($i, ($__g_aFluentSegments[$i][9] >= 0) ? $__g_aFluentSegments[$i][9] : $__g_aFluentSegments[$i][8])
EndFunc   ;==>_FluentSegment_SetTips


; Растягивает группу до $iW, чтобы её край совпал с соседними строками.
; Уже своих подписей группа не становится. 0 – снова ширина по подписям.
Func _FluentSegment_SetWidth($iCtrl, $iW)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Then Return
	$__g_aFluentSegments[$i][12] = $iW
	__FluentSegment_ApplyLayout($i)
EndFunc   ;==>_FluentSegment_SetWidth


; Ширина группы: вызывающему для раскладки соседних контролов
Func _FluentSegment_Width($iCtrl)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	Return ($i < 0) ? 0 : $__g_aFluentSegments[$i][4]
EndFunc   ;==>_FluentSegment_Width


Func _FluentSegment_GetSel($iCtrl)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	Return ($i < 0) ? -1 : $__g_aFluentSegments[$i][8]
EndFunc   ;==>_FluentSegment_GetSel


; Выбор без вызова обработчика: его зовёт только клик
Func _FluentSegment_SetSel($iCtrl, $iSel)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentSegments[$i][8] = $iSel Then Return
	$__g_aFluentSegments[$i][8] = $iSel
	__FluentSegment_Render($i)
EndFunc   ;==>_FluentSegment_SetSel


; Новые подписи (смена языка): ширины пересчитываются, контрол меняет размер
Func _FluentSegment_SetTexts($iCtrl, $sTexts)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Then Return
	$__g_aFluentSegments[$i][6] = $sTexts
	__FluentSegment_ApplyLayout($i)
EndFunc   ;==>_FluentSegment_SetTexts


; Иконки сегментов "A|B" (как у _FluentSegment_Create). Те же - ничего не делает
Func _FluentSegment_SetIcons($iCtrl, $sIcons)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Or $__g_aFluentSegments[$i][7] == $sIcons Then Return
	$__g_aFluentSegments[$i][7] = $sIcons
	__FluentSegment_ApplyLayout($i)
EndFunc   ;==>_FluentSegment_SetIcons


Func _FluentSegment_SetPos($iCtrl, $iX, $iY)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Then Return
	$__g_aFluentSegments[$i][2] = $iX
	$__g_aFluentSegments[$i][3] = $iY
	GUICtrlSetPos($iCtrl, $iX, $iY, $__g_aFluentSegments[$i][4], $__g_aFluentSegments[$i][5])
EndFunc   ;==>_FluentSegment_SetPos


; Удаляет группу. Окно, закрывающееся раньше приложения, зовёт это до GUIDelete:
; запись в реестре переживает окно, а ControlID AutoIt выдаёт заново.
; Строка помечается свободной, а не вырезается: см. _FluentButton_Delete.
Func _FluentSegment_Delete($iCtrl)
	Local $i = __FluentSegment_IndexOf($iCtrl)
	If $i < 0 Then Return
	_FluentHandCursorRemove($iCtrl)
	GUICtrlDelete($iCtrl)
	If $__g_aFluentSegments[$i][1] Then _WinAPI_DeleteObject($__g_aFluentSegments[$i][1])
	$__g_aFluentSegments[$i][0] = 0
	$__g_aFluentSegments[$i][1] = 0
EndFunc   ;==>_FluentSegment_Delete


Func __FluentSegment_RenderAll()
	For $i = 0 To UBound($__g_aFluentSegments) - 1
		__FluentSegment_Render($i)
	Next
EndFunc   ;==>__FluentSegment_RenderAll


Func __FluentSegment_Shutdown()
	For $i = 0 To UBound($__g_aFluentSegments) - 1
		If Not $__g_aFluentSegments[$i][0] Then ContinueLoop
		_FluentHandCursorRemove($__g_aFluentSegments[$i][0])
		If $__g_aFluentSegments[$i][1] Then _WinAPI_DeleteObject($__g_aFluentSegments[$i][1])
		$__g_aFluentSegments[$i][1] = 0
	Next
EndFunc   ;==>__FluentSegment_Shutdown


; Клик по группе: сегмент определяется X курсора
Func __FluentSegment_OnClick()
	Local $i = __FluentSegment_IndexOf(@GUI_CtrlId)
	If $i < 0 Then Return

	Local $iHit = __FluentSegment_HitTest($i)
	If $iHit < 0 Or $iHit = $__g_aFluentSegments[$i][8] Then Return

	$__g_aFluentSegments[$i][8] = $iHit
	__FluentSegment_Render($i)
	If $__g_aFluentSegments[$i][11] <> "" Then Call($__g_aFluentSegments[$i][11], $__g_aFluentSegments[$i][0])
EndFunc   ;==>__FluentSegment_OnClick


; Подсветка сегмента под курсором. Pic не шлёт WM_MOUSELEAVE, поэтому опрос таймером ядра
Func __FluentSegment_HoverTick()
	Local $iUnder = _FluentCtrlUnderCursor()
	For $i = 0 To UBound($__g_aFluentSegments) - 1
		If Not $__g_aFluentSegments[$i][0] Then ContinueLoop
		Local $iHover = -1
		If $iUnder = $__g_aFluentSegments[$i][0] Then $iHover = __FluentSegment_HitTest($i)
		If $iHover <> $__g_aFluentSegments[$i][9] Then
			$__g_aFluentSegments[$i][9] = $iHover
			__FluentSegment_Render($i)
			If $iHover >= 0 Then __FluentSegment_ApplyTip($i, $iHover)
		EndIf
	Next
EndFunc   ;==>__FluentSegment_HoverTick


; ============================================================
; Внутреннее
; ============================================================

Func __FluentSegment_IndexOf($iCtrl)
	If Not $iCtrl Then Return -1 ; 0 стоит в свободных строках реестра
	For $i = 0 To UBound($__g_aFluentSegments) - 1
		If $__g_aFluentSegments[$i][0] = $iCtrl Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentSegment_IndexOf


; Подсказка сегмента $iSeg на общем Pic группы. Ставится только при смене сегмента:
; GUICtrlSetTip пересоздаёт окно подсказки.
Func __FluentSegment_ApplyTip($iIndex, $iSeg)
	If $__g_aFluentSegments[$iIndex][14] = "" Or $iSeg < 0 Or $iSeg = $__g_aFluentSegments[$iIndex][16] Then Return

	Local $aTips = StringSplit($__g_aFluentSegments[$iIndex][14], "|", $STR_NOCOUNT)
	Local $sTip = ($iSeg < UBound($aTips)) ? $aTips[$iSeg] : ""
	$__g_aFluentSegments[$iIndex][16] = $iSeg
	If $__g_aFluentSegments[$iIndex][15] <> "" Then
		Call($__g_aFluentSegments[$iIndex][15], $__g_aFluentSegments[$iIndex][0], $sTip)
	Else
		GUICtrlSetTip($__g_aFluentSegments[$iIndex][0], $sTip)
	EndIf
EndFunc   ;==>__FluentSegment_ApplyTip


; Строка, освободившаяся после _FluentSegment_Delete, или -1
Func __FluentSegment_FreeSlot()
	For $i = 0 To UBound($__g_aFluentSegments) - 1
		If Not $__g_aFluentSegments[$i][0] Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentSegment_FreeSlot


; Индекс сегмента под курсором, -1 если курсор вне группы
Func __FluentSegment_HitTest($iIndex)
	Local $iLocalX = _FluentCursorLocalX($__g_aFluentSegments[$iIndex][0]) - $gc_iFluentSegmentPad
	If $iLocalX < 0 Then Return -1

	Local $aWidths = StringSplit($__g_aFluentSegments[$iIndex][10], "|", $STR_NOCOUNT)
	Local $iEdge = 0
	For $i = 0 To UBound($aWidths) - 1
		$iEdge += Int($aWidths[$i])
		If $iLocalX < $iEdge Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentSegment_HitTest


; Пересчёт ширин из подписей и заданной ширины группы, размер и перерисовка
Func __FluentSegment_ApplyLayout($iIndex)
	Local $sWidths, $sNatural
	Local $iW = __FluentSegment_Layout($__g_aFluentSegments[$iIndex][6], $__g_aFluentSegments[$iIndex][7], _
			$__g_aFluentSegments[$iIndex][12], $sWidths, $sNatural)

	$__g_aFluentSegments[$iIndex][4] = $iW
	$__g_aFluentSegments[$iIndex][10] = $sWidths
	$__g_aFluentSegments[$iIndex][13] = $sNatural
	GUICtrlSetPos($__g_aFluentSegments[$iIndex][0], $__g_aFluentSegments[$iIndex][2], $__g_aFluentSegments[$iIndex][3], _
			$iW, $__g_aFluentSegments[$iIndex][5])
	__FluentSegment_Render($iIndex)
EndFunc   ;==>__FluentSegment_ApplyLayout


; Ширины сегментов "w1|w2": по подписям ($sNatural) и растянутые до $iTargetW ($sWidths).
; Возвращает ширину группы. Уже подписей группа не становится.
Func __FluentSegment_Layout($sTexts, $sIcons, $iTargetW, ByRef $sWidths, ByRef $sNatural)
	Local $aWidths = __FluentSegment_Measure($sTexts, $sIcons)
	Local $iSum = 0
	$sNatural = ""
	For $i = 0 To UBound($aWidths) - 1
		$iSum += $aWidths[$i]
		$sNatural &= (($i = 0) ? "" : "|") & $aWidths[$i]
	Next

	If $iTargetW - $gc_iFluentSegmentPad * 2 > $iSum Then __FluentSegment_Stretch($aWidths, $iTargetW - $gc_iFluentSegmentPad * 2)

	Local $iW = $gc_iFluentSegmentPad * 2
	$sWidths = ""
	For $i = 0 To UBound($aWidths) - 1
		$iW += $aWidths[$i]
		$sWidths &= (($i = 0) ? "" : "|") & $aWidths[$i]
	Next
	Return $iW
EndFunc   ;==>__FluentSegment_Layout


; Растягивает сегменты до суммы $iTotal. Прибавка достаётся сначала узким:
; группа стремится к равным долям, а сегмент шире равной доли остаётся как есть.
Func __FluentSegment_Stretch(ByRef $aWidths, $iTotal)
	Local $iN = UBound($aWidths)
	Local $aKeep[$iN]
	Local $iFree = $iTotal, $iCount = $iN

	Local $bAgain = True
	While $bAgain
		$bAgain = False
		For $i = 0 To $iN - 1
			If $aKeep[$i] Or $aWidths[$i] * $iCount <= $iFree Then ContinueLoop
			$aKeep[$i] = True
			$iFree -= $aWidths[$i]
			$iCount -= 1
			$bAgain = True
		Next
	WEnd

	; Остаток поровну, пиксели от деления – последнему растянутому
	For $i = 0 To $iN - 1
		If $aKeep[$i] Then ContinueLoop
		$aWidths[$i] = ($iCount = 1) ? $iFree : Int($iFree / $iCount)
		$iFree -= $aWidths[$i]
		$iCount -= 1
	Next
EndFunc   ;==>__FluentSegment_Stretch


; Ширина сегмента: поля, иконка с зазором и своя подпись. Без иконки место под неё
; не резервируется, иначе подпись уезжает вправо.
Func __FluentSegment_Measure($sTexts, $sIcons)
	Local $aTexts = StringSplit($sTexts, "|", $STR_NOCOUNT)
	Local $aIcons = StringSplit($sIcons, "|", $STR_NOCOUNT)
	Local $aWidths[UBound($aTexts)]
	Local $hFont = _FluentFont()

	For $i = 0 To UBound($aTexts) - 1
		$aWidths[$i] = $gc_iFluentSegmentPadX * 2 + _FluentTextW($aTexts[$i], $hFont)
		If __FluentSegment_Icon($aIcons, $i) <> "" Then $aWidths[$i] += __FluentSegment_IconSize(__FluentSegment_Icon($aIcons, $i)) + $gc_iFluentSegmentGap
	Next
	Return $aWidths
EndFunc   ;==>__FluentSegment_Measure


; Имя иконки сегмента без расширения или путь к .ico. "" – сегмент из одной подписи
Func __FluentSegment_Icon(ByRef $aIcons, $iIndex)
	If $iIndex >= UBound($aIcons) Then Return ""
	Return StringReplace($aIcons[$iIndex], ".png", "")
EndFunc   ;==>__FluentSegment_Icon


Func __FluentSegment_IconSize($sIcon)
	Return StringRight($sIcon, 4) = ".ico" ? $gc_iFluentSegmentIconFile : $gc_iFluentSegmentIcon
EndFunc   ;==>__FluentSegment_IconSize


Func __FluentSegment_Render($iIndex)
	If $iIndex < 0 Or $iIndex >= UBound($__g_aFluentSegments) Then Return
	If Not $__g_aFluentSegments[$iIndex][0] Then Return ; строка освобождена

	Local $iW = $__g_aFluentSegments[$iIndex][4], $iH = $__g_aFluentSegments[$iIndex][5]
	If $iW < 1 Or $iH < 1 Then Return

	Local $aTexts = StringSplit($__g_aFluentSegments[$iIndex][6], "|", $STR_NOCOUNT)
	Local $aIcons = StringSplit($__g_aFluentSegments[$iIndex][7], "|", $STR_NOCOUNT)
	Local $aWidths = StringSplit($__g_aFluentSegments[$iIndex][10], "|", $STR_NOCOUNT)
	Local $aNatural = StringSplit($__g_aFluentSegments[$iIndex][13], "|", $STR_NOCOUNT)
	Local $iSel = $__g_aFluentSegments[$iIndex][8], $iHover = $__g_aFluentSegments[$iIndex][9]

	Local $hGfx
	Local $hCanvas = _FluentCanvas($iW, $iH, _FluentArgb($g_iFluentBg), $hGfx)

	; Дорожка
	_FluentBox($hGfx, 0, 0, $iW, $iH, $gc_nFluentRadTrack, _
			_FluentArgb($g_iFluentTrack), _FluentArgb($g_iFluentTrackBorder))

	Local $hFont = _FluentFont()
	Local $hFontSel = _FluentFont(0, True)
	Local $iX = $gc_iFluentSegmentPad

	For $i = 0 To UBound($aTexts) - 1
		Local $iSegW = Int($aWidths[$i])
		Local $bOn = ($i = $iSel)
		Local $iFg = $g_iFluentText2, $iIconFg = $g_iFluentText3

		If $bOn Then
			; Пилюля без тени снизу: смещённая копия утяжеляла нижние углы
			_FluentBox($hGfx, $iX, $gc_iFluentSegmentPad, $iSegW, $iH - $gc_iFluentSegmentPad * 2, $gc_nFluentRadCtrl, _
					_FluentArgb($g_iFluentSegSelBg), _FluentArgb($g_iFluentSegSelBorder))
			$iFg = $g_iFluentSegSelText
			$iIconFg = $iFg ; иконка выбранного сегмента цветом текста, не акцентом
		ElseIf $i = $iHover Then
			_FluentFill($hGfx, $iX, $gc_iFluentSegmentPad, $iSegW, $iH - $gc_iFluentSegmentPad * 2, _
					$gc_nFluentRadCtrl, _FluentArgb($g_iFluentHover))
			$iFg = $g_iFluentText1
		EndIf

		Local $hTextFont = $bOn ? $hFontSel : $hFont
		Local $sIcon = __FluentSegment_Icon($aIcons, $i)
		If $sIcon = "" Then
			; Без иконки подпись стоит по центру всей ширины сегмента
			_FluentText($hGfx, $aTexts[$i], $iX, 0, $iSegW, $iH, $hTextFont, _FluentArgb($iFg), 1, 1)
		Else
			; Иконка с подписью – одним блоком, в растянутом сегменте тоже по центру
			Local $iIconX = $iX + $gc_iFluentSegmentPadX, $iIconSize = __FluentSegment_IconSize($sIcon)
			If $i < UBound($aNatural) Then $iIconX += Int(($iSegW - Int($aNatural[$i])) / 2)
			If $iIconSize = $gc_iFluentSegmentIconFile Then
				Local $hIconFile = _FluentIconFile($sIcon, $iIconSize)
				If $hIconFile Then _GDIPlus_GraphicsDrawImageRect($hGfx, $hIconFile, $iIconX, Int(($iH - $iIconSize) / 2), $iIconSize, $iIconSize)
			Else
				_FluentDrawIcon($hGfx, $sIcon, $iIconSize, $iIconFg, $iIconX, Int(($iH - $iIconSize) / 2))
			EndIf

			Local $iTextX = $iIconX + $iIconSize + $gc_iFluentSegmentGap
			_FluentText($hGfx, $aTexts[$i], $iTextX, 0, $iX + $iSegW - $iTextX, $iH, _
					$hTextFont, _FluentArgb($iFg), 0, 1)
		EndIf

		$iX += $iSegW
	Next

	_FluentCanvasApply($__g_aFluentSegments[$iIndex][0], $__g_aFluentSegments[$iIndex][1], $hCanvas, $hGfx)
EndFunc   ;==>__FluentSegment_Render
