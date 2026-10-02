#include-once
#include <EditConstants.au3>
#include <StaticConstants.au3>
#include <WindowsConstants.au3>

#include "FluentCore.au3"

; ============================================================
; FluentInput – поле ввода со скруглённой рамкой и подписью внутри
; ============================================================
; Рамка рисуется в GDI+ и кладётся в Pic, поверх лежит Edit без рамки с той же
; заливкой. Возвращается ControlID именно Edit: приложение работает с полем
; обычными GUICtrlSetData и GUICtrlRead. Родом из SkinInput проекта VCLauncher.
;
; Подпись поля ($sPrefix слева, $sSuffix справа) стоит внутри рамки плашкой через черту,
; как у селектора: «ширина | 1920», «50 | %». Иконка вместо подписи - как у FluentSegment:
; «Имя.png» - PNG из папки _FluentInit, перекрашенный под подпись, полный путь к .ico - 16 px
; в своих цветах. Клик по плашке и по рамке ставит фокус в поле и выделяет текст. Фокус и наведение – цветом рамки, их опрашивает общий таймер ядра.
;
; Edit рисует первую строку от верха клиентской области, поэтому по центру рамки
; ставится строчный бокс высотой _FluentGdiLineHeight, а не контрол.
; Цвета Edit модуль отдаёт сам через WM_CTLCOLOREDIT (маршрутизатор ядра). FluentTheme
; рамку на такой Edit не вешает: у него нет своей рамки.

; Поле от рамки до текста, ширина черты у плашки; иконка на плашке: PNG и .ico, как у FluentSegment
Global Const $gc_iFluentInputPadX = 7, $gc_iFluentInputAddonPadX = 8, $gc_iFluentInputIcon = 14, $gc_iFluentInputIconFile = 16

; Реестр полей. Колонки:
; 0 ControlID Edit, 1 ControlID Pic-рамки, 2 HBITMAP, 3 X, 4 Y, 5 W, 6 H,
; 7 подпись слева, 8 подпись справа, 9 в фокусе, 10 под курсором
Global $__g_aFluentInputs[0][11]
; Кисть фона Edit и её цвет: пересоздаётся, когда палитра сменилась
Global $__g_hFluentInputBrush = 0, $__g_iFluentInputBrushRgb = -1

__FluentHookAdd('hover', '__FluentInput_HoverTick')
__FluentHookAdd('render', '__FluentInput_RenderAll')
__FluentHookAdd('shutdown', '__FluentInput_Shutdown')


; Создаёт поле и возвращает ControlID его Edit. $sPrefix и $sSuffix – подписи внутри рамки
; слева и справа ('' – без подписи), $iStyle – добавочные стили Edit ($ES_NUMBER, $ES_RIGHT)
Func _FluentInput_Create($iX, $iY, $iW, $iH, $sPrefix = '', $sSuffix = '', $iStyle = -1)
	; $WS_CLIPSIBLINGS обязателен: иначе рамка при перерисовке закрашивает лежащий на ней Edit
	Local $iPic = GUICtrlCreatePic('', $iX, $iY, $iW, $iH, BitOR($SS_NOTIFY, $WS_CLIPSIBLINGS))
	GUICtrlSetOnEvent($iPic, '__FluentInput_OnFrameClick')

	Local $iEditStyle = BitOR($ES_LEFT, $ES_AUTOHSCROLL)
	If $iStyle <> -1 Then $iEditStyle = BitOR($iEditStyle, $iStyle)
	; Последний аргумент 0 снимает $WS_EX_CLIENTEDGE: рамку рисуем сами
	Local $aRect = __FluentInput_EditRect($iX, $iY, $iW, $iH, $sPrefix, $sSuffix)
	Local $iEdit = GUICtrlCreateInput('', $aRect[0], $aRect[1], $aRect[2], $aRect[3], $iEditStyle, 0)
	_FluentDockFixed($iPic)
	_FluentDockFixed($iEdit)
	; Рамка – подложка под Edit, иначе она перехватывает у него клики
	_FluentSendToBack($iPic)
	_FluentMsg_Register($WM_CTLCOLOREDIT, '__FluentInput_CtlColor')
	_FluentMsg_Register($WM_CTLCOLORSTATIC, '__FluentInput_CtlColor')

	Local $iIndex = __FluentInput_FreeSlot()
	If $iIndex < 0 Then
		$iIndex = UBound($__g_aFluentInputs)
		ReDim $__g_aFluentInputs[$iIndex + 1][11]
	EndIf
	$__g_aFluentInputs[$iIndex][0] = $iEdit
	$__g_aFluentInputs[$iIndex][1] = $iPic
	$__g_aFluentInputs[$iIndex][2] = 0
	$__g_aFluentInputs[$iIndex][3] = $iX
	$__g_aFluentInputs[$iIndex][4] = $iY
	$__g_aFluentInputs[$iIndex][5] = $iW
	$__g_aFluentInputs[$iIndex][6] = $iH
	$__g_aFluentInputs[$iIndex][7] = $sPrefix
	$__g_aFluentInputs[$iIndex][8] = $sSuffix
	$__g_aFluentInputs[$iIndex][9] = False
	$__g_aFluentInputs[$iIndex][10] = False

	__FluentInput_Render($iIndex)
	Return $iEdit
EndFunc   ;==>_FluentInput_Create


; Pic-рамка поля: вызывающему для докинга
Func _FluentInput_Frame($iEdit)
	Local $i = __FluentInput_IndexOf($iEdit)
	Return ($i < 0) ? 0 : $__g_aFluentInputs[$i][1]
EndFunc   ;==>_FluentInput_Frame


Func _FluentInput_SetPos($iEdit, $iX, $iY, $iW = -1, $iH = -1)
	Local $i = __FluentInput_IndexOf($iEdit)
	If $i < 0 Then Return
	If $iW < 0 Then $iW = $__g_aFluentInputs[$i][5]
	If $iH < 0 Then $iH = $__g_aFluentInputs[$i][6]

	Local $bResize = ($iW <> $__g_aFluentInputs[$i][5]) Or ($iH <> $__g_aFluentInputs[$i][6])
	$__g_aFluentInputs[$i][3] = $iX
	$__g_aFluentInputs[$i][4] = $iY
	$__g_aFluentInputs[$i][5] = $iW
	$__g_aFluentInputs[$i][6] = $iH
	GUICtrlSetPos($__g_aFluentInputs[$i][1], $iX, $iY, $iW, $iH)
	Local $aRect = __FluentInput_EditRect($iX, $iY, $iW, $iH, $__g_aFluentInputs[$i][7], $__g_aFluentInputs[$i][8])
	GUICtrlSetPos($iEdit, $aRect[0], $aRect[1], $aRect[2], $aRect[3])
	If $bResize Then __FluentInput_Render($i)
EndFunc   ;==>_FluentInput_SetPos


; Удаляет поле. Окно, закрывающееся раньше приложения, зовёт это до GUIDelete.
; Строка реестра помечается свободной: см. _FluentButton_Delete
Func _FluentInput_Delete($iEdit)
	Local $i = __FluentInput_IndexOf($iEdit)
	If $i < 0 Then Return
	GUICtrlDelete($__g_aFluentInputs[$i][1])
	GUICtrlDelete($iEdit)
	If $__g_aFluentInputs[$i][2] Then _WinAPI_DeleteObject($__g_aFluentInputs[$i][2])
	$__g_aFluentInputs[$i][0] = 0
	$__g_aFluentInputs[$i][1] = 0
	$__g_aFluentInputs[$i][2] = 0
EndFunc   ;==>_FluentInput_Delete


; ============================================================
; Внутреннее
; ============================================================

Func __FluentInput_IndexOf($iEdit)
	If Not $iEdit Then Return -1 ; 0 стоит в свободных строках реестра
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		If $__g_aFluentInputs[$i][0] = $iEdit Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentInput_IndexOf


Func __FluentInput_FreeSlot()
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		If Not $__g_aFluentInputs[$i][0] Then Return $i
	Next
	Return -1
EndFunc   ;==>__FluentInput_FreeSlot


; Ширина плашки с подписью вместе с чертой, 0 – подписи нет
Func __FluentInput_AddonW($sText)
	If $sText = '' Then Return 0
	Local $iIcon = __FluentInput_IconSize($sText)
	Return ($iIcon ? $iIcon : _FluentTextW($sText, _FluentFont())) + $gc_iFluentInputAddonPadX * 2 + 1
EndFunc   ;==>__FluentInput_AddonW


; Размер иконки подписи: PNG из папки иконок - как у сегментов, .ico - 16; 0 - подпись текстом
Func __FluentInput_IconSize($sText)
	Switch StringRight($sText, 4)
		Case '.png'
			Return $gc_iFluentInputIcon
		Case '.ico'
			Return $gc_iFluentInputIconFile
	EndSwitch
	Return 0
EndFunc   ;==>__FluentInput_IconSize


; Прямоугольник Edit внутри рамки между плашками: [x, y, w, h]. По вертикали
; центрируется строчный бокс. Вся высота до нижней грани: клик по пустому низу
; попадает в поле, а саму грань непрозрачный Edit не стирает
Func __FluentInput_EditRect($iX, $iY, $iW, $iH, $sPrefix, $sSuffix)
	Local $aRect[4]
	Local $iLineH = _FluentGdiLineHeight()
	Local $iTop = _Max(0, Int(($iH - $iLineH) / 2))
	Local $iLeft = __FluentInput_AddonW($sPrefix), $iRight = __FluentInput_AddonW($sSuffix)
	$aRect[0] = $iX + $iLeft + $gc_iFluentInputPadX
	$aRect[1] = $iY + $iTop
	$aRect[2] = $iW - $iLeft - $iRight - $gc_iFluentInputPadX * 2
	$aRect[3] = _Max($iLineH, $iH - $iTop - 1)
	Return $aRect
EndFunc   ;==>__FluentInput_EditRect


Func __FluentInput_Render($iIndex)
	If $iIndex < 0 Or $iIndex >= UBound($__g_aFluentInputs) Or Not $__g_aFluentInputs[$iIndex][0] Then Return
	Local $iW = $__g_aFluentInputs[$iIndex][5], $iH = $__g_aFluentInputs[$iIndex][6]
	If $iW < 1 Or $iH < 1 Then Return

	Local $hGfx
	; Pic прямоугольный, рамка скруглена: под углами должен лежать фон окна
	Local $hCanvas = _FluentCanvas($iW, $iH, _FluentArgb($g_iFluentBg), $hGfx)
	_FluentFill($hGfx, 0, 0, $iW, $iH, $gc_nFluentRadCtrl, _FluentArgb($g_iFluentCtrlBg))

	; Плашки: заливка дорожки по форме рамки, отрезанная у черты
	Local $sPrefix = $__g_aFluentInputs[$iIndex][7], $sSuffix = $__g_aFluentInputs[$iIndex][8]
	Local $iLeft = __FluentInput_AddonW($sPrefix), $iRight = __FluentInput_AddonW($sSuffix)
	If $iLeft Then __FluentInput_DrawAddon($hGfx, $sPrefix, 0, $iLeft - 1, $iW, $iH, $iLeft - 1)
	If $iRight Then __FluentInput_DrawAddon($hGfx, $sSuffix, $iW - $iRight + 1, $iRight - 1, $iW, $iH, $iW - $iRight)

	; Фокус и наведение – цветом рамки: полоска снизу делала нижние углы площе верхних
	Local $iBorder = $g_iFluentCtrlBorder
	If $__g_aFluentInputs[$iIndex][10] Then $iBorder = $g_iFluentCtrlUnder
	If $__g_aFluentInputs[$iIndex][9] Then $iBorder = $g_iFluentAccent
	_FluentStroke($hGfx, 0, 0, $iW, $iH, $gc_nFluentRadCtrl, _FluentArgb($iBorder))

	_FluentCanvasApply($__g_aFluentInputs[$iIndex][1], $__g_aFluentInputs[$iIndex][2], $hCanvas, $hGfx)

	; Рамка при перерисовке успевает мазнуть по Edit, без его перерисовки
	; текст пропадал до следующего ввода
	Local $hEdit = GUICtrlGetHandle($__g_aFluentInputs[$iIndex][0])
	If $hEdit Then _WinAPI_RedrawWindow($hEdit, 0, 0, BitOR($RDW_INVALIDATE, $RDW_UPDATENOW))
EndFunc   ;==>__FluentInput_Render


; Плашка шириной $iAddonW от $iX: заливка по форме рамки, черта в $iLineX, подпись или иконка по центру
Func __FluentInput_DrawAddon($hGfx, $sText, $iX, $iAddonW, $iW, $iH, $iLineX)
	_GDIPlus_GraphicsSetClipRect($hGfx, $iX, 0, $iAddonW, $iH)
	_FluentFill($hGfx, 0, 0, $iW, $iH, $gc_nFluentRadCtrl, _FluentArgb($g_iFluentTrack))
	_GDIPlus_GraphicsResetClip($hGfx)
	_FluentLine($hGfx, $iLineX + 0.5, 0, $iLineX + 0.5, $iH - 1, _FluentArgb($g_iFluentCtrlBorder))
	; _FluentLine сдвигает на полпикселя только Y: вертикаль задаётся концами
	Local $iIcon = __FluentInput_IconSize($sText)
	Local $iIconX = $iX + Int(($iAddonW - $iIcon) / 2), $iIconY = Int(($iH - $iIcon) / 2)
	Switch $iIcon
		Case 0
			_FluentText($hGfx, $sText, $iX, 0, $iAddonW, $iH, _FluentFont(), _FluentArgb($g_iFluentText2), 1, 1)
		Case $gc_iFluentInputIconFile
			Local $hIcon = _FluentIconFile($sText, $iIcon)
			If $hIcon Then _GDIPlus_GraphicsDrawImageRect($hGfx, $hIcon, $iIconX, $iIconY, $iIcon, $iIcon)
		Case Else
			_FluentDrawIcon($hGfx, StringTrimRight($sText, 4), $iIcon, $g_iFluentText2, $iIconX, $iIconY)
	EndSwitch
EndFunc   ;==>__FluentInput_DrawAddon


Func __FluentInput_RenderAll()
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		__FluentInput_Render($i)
	Next
EndFunc   ;==>__FluentInput_RenderAll


Func __FluentInput_Shutdown()
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		If $__g_aFluentInputs[$i][2] Then _WinAPI_DeleteObject($__g_aFluentInputs[$i][2])
		$__g_aFluentInputs[$i][2] = 0
	Next
	If $__g_hFluentInputBrush Then _WinAPI_DeleteObject($__g_hFluentInputBrush)
	$__g_hFluentInputBrush = 0
	$__g_iFluentInputBrushRgb = -1
EndFunc   ;==>__FluentInput_Shutdown


; Опрос фокуса и наведения. Фокус читается, а не ловится EN_SETFOCUS:
; модуль не зависит от обработчика WM_COMMAND приложения
Func __FluentInput_HoverTick()
	Local $iUnder = _FluentCtrlUnderCursor(), $hFocus = _WinAPI_GetFocus()
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		Local $iEdit = $__g_aFluentInputs[$i][0]
		If Not $iEdit Then ContinueLoop
		Local $bFocus = ($hFocus = GUICtrlGetHandle($iEdit))
		Local $bHover = ($iUnder = $iEdit) Or ($iUnder = $__g_aFluentInputs[$i][1])
		If $bFocus <> $__g_aFluentInputs[$i][9] Or $bHover <> $__g_aFluentInputs[$i][10] Then
			$__g_aFluentInputs[$i][9] = $bFocus
			$__g_aFluentInputs[$i][10] = $bHover
			__FluentInput_Render($i)
		EndIf
	Next
EndFunc   ;==>__FluentInput_HoverTick


; Клик по рамке или плашке: фокус в поле, текст выделен
Func __FluentInput_OnFrameClick()
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		If $__g_aFluentInputs[$i][0] And $__g_aFluentInputs[$i][1] = @GUI_CtrlId Then
			GUICtrlSetState($__g_aFluentInputs[$i][0], $GUI_FOCUS)
			GUICtrlSendMsg($__g_aFluentInputs[$i][0], $EM_SETSEL, 0, -1)
			Return
		EndIf
	Next
EndFunc   ;==>__FluentInput_OnFrameClick


; Цвета своих Edit: текст палитры, фон заливки рамки. Чужие Edit - дальше по цепочке
Func __FluentInput_CtlColor($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg
	Local $bOwn = False
	For $i = 0 To UBound($__g_aFluentInputs) - 1
		If $__g_aFluentInputs[$i][0] And GUICtrlGetHandle($__g_aFluentInputs[$i][0]) = $lParam Then $bOwn = True
	Next
	If Not $bOwn Then Return $GUI_RUNDEFMSG

	If $__g_iFluentInputBrushRgb <> $g_iFluentCtrlBg Then
		If $__g_hFluentInputBrush Then _WinAPI_DeleteObject($__g_hFluentInputBrush)
		$__g_hFluentInputBrush = _WinAPI_CreateSolidBrush(_WinAPI_SwitchColor($g_iFluentCtrlBg))
		$__g_iFluentInputBrushRgb = $g_iFluentCtrlBg
	EndIf
	_WinAPI_SetTextColor($wParam, _WinAPI_SwitchColor($g_iFluentText1))
	_WinAPI_SetBkColor($wParam, _WinAPI_SwitchColor($g_iFluentCtrlBg))
	Return $__g_hFluentInputBrush
EndFunc   ;==>__FluentInput_CtlColor
