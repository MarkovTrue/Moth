#include-once
#include <GDIPlus.au3>
#include <GUIConstantsEx.au3>
#include <GuiImageList.au3>
#include <Math.au3>
#include <SendMessage.au3>
#include <StaticConstants.au3>
#include <WinAPI.au3>
#include <WinAPIGdi.au3>
#include <WinAPIIcons.au3>
#include <WinAPIRes.au3>
#include <WinAPIShellEx.au3>
#include <WinAPISysWin.au3>
#include <WindowsConstants.au3>

#include "FluentSubclass.au3"

; ============================================================
; Fluent – интерфейс в духе Windows 11 для окон AutoIt
; ============================================================
; Семейство переносимых модулей, каждый файл подключается сам по себе и тянет
; нужные ему соседние. Всё семейство разом – Fluent.au3.
;
;   FluentCore      палитра, GDI+, шрифты, иконки, наведение, маршрутизатор сообщений
;   FluentSubclass  сабклассы окон: машинные фильтры и учёт
;   FluentWinApi    недокументированные вызовы тёмной темы, DWM, DPI
;   FluentTheme     тёмная и светлая тема окна и штатных контролов
;   FluentButton, FluentCheck, FluentInput, FluentSegment, FluentMenu – рисованные контролы (Pic + GDI+)
;   FluentNative*   штатные контролы Windows под тему: Button, Edit, List, Tab, UpDown,
;                   Date, Static, Slider, Status, Toolbar, MenuBar
;   FluentMsgBox    MsgBox в теме окна
;
; Порядок в приложении: _FluentInit → _FluentSetTheme → создание контролов →
; _FluentTheme_Apply. При выходе _FluentShutdown.
; Штатные контролы в тёмной теме – по мотивам GUIDarkTheme 3.0 (WildByDesign, UEZ,
; argumentum, pixelsearch, NoNameCode, ahmet, MattyD, ioa747, Nine и другие).

; --- Палитра, RGB. Заполняет _FluentSetTheme, читают модули и приложение ---
Global $g_bFluentDark = False
Global $g_iFluentBg          ; фон окна
Global $g_iFluentCard        ; поверхность карточки или панели
Global $g_iFluentCardBorder
Global $g_iFluentCtrlBg      ; заливка поля ввода и кнопки
Global $g_iFluentCtrlBorder
Global $g_iFluentCtrlUnder   ; усиленная нижняя грань поля
Global $g_iFluentText1       ; основной текст
Global $g_iFluentText2       ; подписи строк
Global $g_iFluentText3       ; пояснения под полями
Global $g_iFluentTrack       ; дорожка сегментов
Global $g_iFluentTrackBorder
Global $g_iFluentAccent, $g_iFluentAccentEdge, $g_iFluentAccentHot, $g_iFluentOnAccent
Global $g_iFluentDivider
Global $g_iFluentKeyBg, $g_iFluentKeyBorder
Global $g_iFluentSegSelBg, $g_iFluentSegSelBorder, $g_iFluentSegSelText
Global $g_iFluentHover       ; подсветка контрола под курсором
; Штатные контролы: рамки полей, кнопки, вкладки, меню окна, строка состояния
Global $g_iFluentFrame, $g_iFluentFrameHot
Global $g_iFluentBtnBg, $g_iFluentBtnHot, $g_iFluentBtnPressed, $g_iFluentBtnBorder
Global $g_iFluentTab, $g_iFluentMenuHot, $g_iFluentMenuSel
Global $g_iFluentStatusBg, $g_iFluentChannel, $g_iFluentScrollCorner
Global $g_iFluentMsgTop, $g_iFluentMsgBottom

; Радиусы скругления: поле и кнопка, дорожка сегментов, карточка.
; Мелкие: на контроле высотой 28 крупное скругление съедает угол
Global Const $gc_nFluentRadCtrl = 3, $gc_nFluentRadTrack = 4, $gc_nFluentRadCard = 4

; --- Состояние модуля ---
Global $__g_hFluentGui = 0
Global $__g_sFluentFont = "Segoe UI", $__g_nFluentFontSize = 9
; Типографическая шкала от кегля приложения: пояснения на ступень мельче, заголовок крупнее
Global $__g_nFluentSizeSmall = 8, $__g_nFluentSizeBody = 9, $__g_nFluentSizeTitle = 12.5
Global $__g_sFluentIconDir = ""
Global $__g_bFluentGdip = False, $__g_bFluentHover = False
Global $__g_hFluentMeasureBmp = 0, $__g_hFluentMeasureGfx = 0
Global $__g_hFluentCursorCB = 0
Global $__g_oFluentFonts[], $__g_oFluentIcons[]
; Контрол под курсором на текущем такте опроса и кэш высоты строки шрифта окна
Global $__g_iFluentHoverCtrl = 0, $__g_iFluentGdiLineH = 0
; Хуки модулей по событию ('hover', 'render', 'shutdown' и событиям темы) и обработчики сообщений
Global $__g_oFluentHooks[], $__g_oFluentMsg[]


; ============================================================
; Жизненный цикл и палитра
; ============================================================

; Поднимает GDI+, служебный контекст для измерения текста и опрос наведения
Func _FluentInit($hGui, $sFont = "Segoe UI", $nFontSize = 9, $sIconDir = "")
	$__g_hFluentGui = $hGui
	$__g_sFluentFont = $sFont
	$__g_nFluentFontSize = $nFontSize
	$__g_sFluentIconDir = $sIconDir
	$__g_nFluentSizeBody = $nFontSize
	$__g_nFluentSizeSmall = $nFontSize - 1
	$__g_nFluentSizeTitle = $nFontSize + 3.5
	__FluentGdipStart()

	; Ширина текста меряется на служебном контексте: контрола под рукой может не быть.
	; Повторный вызов не должен терять прежний контекст, а кэш высоты строки - от другого окна
	If $__g_hFluentMeasureGfx Then _GDIPlus_GraphicsDispose($__g_hFluentMeasureGfx)
	If $__g_hFluentMeasureBmp Then _GDIPlus_BitmapDispose($__g_hFluentMeasureBmp)
	$__g_iFluentGdiLineH = 0
	$__g_hFluentMeasureBmp = _GDIPlus_BitmapCreateFromScan0(8, 8)
	$__g_hFluentMeasureGfx = _GDIPlus_ImageGetGraphicsContext($__g_hFluentMeasureBmp)
	_GDIPlus_GraphicsSetTextRenderingHint($__g_hFluentMeasureGfx, 5)

	If Not $__g_bFluentHover Then AdlibRegister("__FluentHoverTick", 70)
	$__g_bFluentHover = True
EndFunc   ;==>_FluentInit


; Освобождает ресурсы модулей (хук 'shutdown'), кэши и GDI+
Func _FluentShutdown()
	If $__g_bFluentHover Then AdlibUnRegister("__FluentHoverTick")
	$__g_bFluentHover = False
	__FluentHookRun('shutdown')
	__FluentIconCacheClear()
	__FluentFontCacheClear()

	If $__g_hFluentCursorCB Then
		DllCallbackFree($__g_hFluentCursorCB)
		$__g_hFluentCursorCB = 0
	EndIf
	If $__g_hFluentMeasureGfx Then _GDIPlus_GraphicsDispose($__g_hFluentMeasureGfx)
	If $__g_hFluentMeasureBmp Then _GDIPlus_BitmapDispose($__g_hFluentMeasureBmp)
	$__g_hFluentMeasureGfx = 0
	$__g_hFluentMeasureBmp = 0

	If $__g_bFluentGdip Then
		_GDIPlus_Shutdown()
		$__g_bFluentGdip = False
	EndIf
EndFunc   ;==>_FluentShutdown


Func _FluentGui()
	Return $__g_hFluentGui
EndFunc   ;==>_FluentGui


; Палитра Windows 11. $iAccent – акцент 0xRRGGBB, 0 – фирменный синий Fluent
Func _FluentSetTheme($bDark, $iAccent = 0)
	$g_bFluentDark = $bDark
	If $iAccent = 0 Then $iAccent = 0x0F6CBD

	If $bDark Then
		$g_iFluentBg = 0x202020
		$g_iFluentCard = 0x2B2B2B
		$g_iFluentCardBorder = 0x3A3A3A
		$g_iFluentCtrlBg = 0x333333
		$g_iFluentCtrlBorder = 0x454545
		$g_iFluentCtrlUnder = 0x5A5A5A
		$g_iFluentText1 = 0xE6E6E6 ; чисто белый слишком ярок
		$g_iFluentText2 = 0xCFCFCF
		$g_iFluentText3 = 0x9B9B9B
		$g_iFluentTrack = 0x2F2F2F
		$g_iFluentTrackBorder = 0x3F3F3F
		$g_iFluentDivider = 0x3D3D3D
		$g_iFluentKeyBg = 0x3A3A3A
		$g_iFluentKeyBorder = 0x4C4C4C
		$g_iFluentSegSelBg = 0x4A4A4A
		$g_iFluentSegSelBorder = 0x5A5A5A
		$g_iFluentSegSelText = 0xFFFFFF
		$g_iFluentHover = 0x3C3C3C
		$g_iFluentFrame = 0x6B6B6B
		$g_iFluentFrameHot = 0xB0B0B0
		$g_iFluentBtnBg = 0x333333
		$g_iFluentBtnHot = 0x454545
		$g_iFluentBtnPressed = 0x666666
		$g_iFluentBtnBorder = 0x9B9B9B
		$g_iFluentTab = 0x303030
		$g_iFluentMenuHot = 0x303030
		$g_iFluentMenuSel = 0x272727
		$g_iFluentStatusBg = 0x1C1C1C
		$g_iFluentChannel = 0x5E5E5E
		$g_iFluentScrollCorner = 0x171717
	Else
		$g_iFluentBg = 0xF3F3F3
		$g_iFluentCard = 0xFFFFFF
		$g_iFluentCardBorder = 0xE3E3E3
		$g_iFluentCtrlBg = 0xFFFFFF
		$g_iFluentCtrlBorder = 0xD8D8D8
		$g_iFluentCtrlUnder = 0x9A9A9A
		$g_iFluentText1 = 0x1B1B1B
		$g_iFluentText2 = 0x4A4A4A
		$g_iFluentText3 = 0x7C7C7C
		$g_iFluentTrack = 0xEBEBEB
		$g_iFluentTrackBorder = 0xDADADA
		$g_iFluentDivider = 0xE6E6E6
		$g_iFluentKeyBg = 0xFFFFFF
		$g_iFluentKeyBorder = 0xCECECE
		$g_iFluentSegSelBg = 0xFFFFFF
		$g_iFluentSegSelBorder = 0xC4C4C4
		$g_iFluentSegSelText = 0x1B1B1B
		$g_iFluentHover = 0xE4E4E4
		$g_iFluentFrame = 0x3F3F3F
		$g_iFluentFrameHot = 0xB0B0B0
		$g_iFluentBtnBg = 0xF4F4F4
		$g_iFluentBtnHot = 0xE0EFF9
		$g_iFluentBtnPressed = 0xCCE4F7
		$g_iFluentBtnBorder = 0xBCBCBC
		$g_iFluentTab = 0xDBDBDB
		$g_iFluentMenuHot = 0xE5E5E5
		$g_iFluentMenuSel = 0xEFEFEF
		$g_iFluentStatusBg = 0x1C1C1C
		$g_iFluentChannel = 0xCFCFCF
		$g_iFluentScrollCorner = 0xF0F0F0
	EndIf
	; Диалог MsgBox тёмный только в тёмной теме: светлый рисует сама Windows
	$g_iFluentMsgTop = 0x323232
	$g_iFluentMsgBottom = 0x202020

	$g_iFluentAccent = $iAccent
	$g_iFluentAccentEdge = __FluentShade($iAccent, $bDark ? 1.18 : 0.82)
	$g_iFluentAccentHot = __FluentShade($iAccent, $bDark ? 1.12 : 1.10)
	$g_iFluentOnAccent = 0xFFFFFF

	; Иконки кэшируются по цвету, шрифты – нет: при смене темы чистим только иконки
	__FluentIconCacheClear()
EndFunc   ;==>_FluentSetTheme


; Перерисовывает все рисованные контролы (хук 'render'): после смены палитры
; и после темы окна, которая перекрашивает все Static, в том числе Pic контролов
Func _FluentRenderAll()
	__FluentHookRun('render')
EndFunc   ;==>_FluentRenderAll


; ============================================================
; Сообщения окна
; ============================================================

; У AutoIt на сообщение один обработчик GUIRegisterMsg, поэтому тема, контролы и приложение
; регистрируют свои здесь. Зовутся по порядку регистрации, первый ответ, отличный
; от $GUI_RUNDEFMSG, уходит системе. Обработчик с сигнатурой ($hWnd, $iMsg, $wParam, $lParam)
Func _FluentMsg_Register($iMsg, $sFunc)
	Local $aList[0]
	If MapExists($__g_oFluentMsg, $iMsg) Then $aList = $__g_oFluentMsg[$iMsg]
	For $sItem In $aList
		If $sItem = $sFunc Then Return
	Next
	ReDim $aList[UBound($aList) + 1]
	$aList[UBound($aList) - 1] = $sFunc
	$__g_oFluentMsg[$iMsg] = $aList
	If UBound($aList) = 1 Then GUIRegisterMsg($iMsg, "__FluentMsgDispatch")
EndFunc   ;==>_FluentMsg_Register


Func _FluentMsg_Unregister($iMsg, $sFunc)
	If Not MapExists($__g_oFluentMsg, $iMsg) Then Return
	Local $aOld = $__g_oFluentMsg[$iMsg], $aList[0]
	For $sItem In $aOld
		If $sItem = $sFunc Then ContinueLoop
		ReDim $aList[UBound($aList) + 1]
		$aList[UBound($aList) - 1] = $sItem
	Next
	If UBound($aList) Then
		$__g_oFluentMsg[$iMsg] = $aList
	Else
		MapRemove($__g_oFluentMsg, $iMsg)
		GUIRegisterMsg($iMsg, "")
	EndIf
EndFunc   ;==>_FluentMsg_Unregister


Func __FluentMsgDispatch($hWnd, $iMsg, $wParam, $lParam)
	If Not MapExists($__g_oFluentMsg, $iMsg) Then Return $GUI_RUNDEFMSG
	Local $aList = $__g_oFluentMsg[$iMsg], $vRet
	For $sFunc In $aList
		$vRet = Call($sFunc, $hWnd, $iMsg, $wParam, $lParam)
		; 0xDEAD/0xBEEF - функции нет или не та сигнатура
		If @error = 0xDEAD And @extended = 0xBEEF Then ContinueLoop
		; Сравнение строгое: число 0 при обычном <> совпало бы со строкой GUI_RUNDEFMSG
		If Not (IsString($vRet) And $vRet == $GUI_RUNDEFMSG) Then Return $vRet
	Next
	Return $GUI_RUNDEFMSG
EndFunc   ;==>__FluentMsgDispatch


; ============================================================
; Примитивы рисования
; ============================================================

Func _FluentArgb($iRgb, $iAlpha = 255)
	Return BitAND($iRgb, 0xFFFFFF) + $iAlpha * 0x1000000
EndFunc   ;==>_FluentArgb


; Холст под контрол: битмап нужного размера, залитый фоном. Контекст отдаёт через $hGfx
Func _FluentCanvas($iW, $iH, $iBgArgb, ByRef $hGfx)
	Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($iW, $iH)
	$hGfx = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsSetSmoothingMode($hGfx, 4)     ; AntiAlias – скругления
	_GDIPlus_GraphicsSetTextRenderingHint($hGfx, 5) ; ClearTypeGridFit
	_GDIPlus_GraphicsSetInterpolationMode($hGfx, 7) ; HighQualityBicubic
	; Half обязателен: при None центр крайнего пикселя лежит на границе холста,
	; правый нижний угол выходит квадратным, а рамка размазывается на две строки
	_GDIPlus_GraphicsSetPixelOffsetMode($hGfx, 4)   ; Half
	_GDIPlus_GraphicsClear($hGfx, $iBgArgb)
	Return $hBitmap
EndFunc   ;==>_FluentCanvas


; Ставит нарисованный холст в Pic и освобождает предыдущий HBITMAP
Func _FluentCanvasApply($iCtrl, ByRef $hOldBitmap, $hCanvas, $hGfx)
	Local $hBitmap = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hCanvas)
	_GDIPlus_GraphicsDispose($hGfx)
	_GDIPlus_BitmapDispose($hCanvas)
	If Not $hBitmap Then Return

	; Static ComCtl32 v6 хранит копию 32-битной картинки: возвращённая прежняя
	; и наша $hOldBitmap – разные объекты, освобождаются обе
	Local $hPrev = _SendMessage(GUICtrlGetHandle($iCtrl), $STM_SETIMAGE, $IMAGE_BITMAP, $hBitmap, _
			0, "wparam", "handle", "handle")
	If $hPrev Then _WinAPI_DeleteObject($hPrev)

	If $hOldBitmap Then _WinAPI_DeleteObject($hOldBitmap)
	$hOldBitmap = $hBitmap
EndFunc   ;==>_FluentCanvasApply


; Путь прямоугольника со скруглёнными углами. Радиус 0 – прямые углы
Func _FluentPathRR($nX, $nY, $nW, $nH, $nR)
	Local $hPath = _GDIPlus_PathCreate()
	If $nR <= 0 Then
		_GDIPlus_PathAddRectangle($hPath, $nX, $nY, $nW, $nH)
		Return $hPath
	EndIf

	Local $nD = $nR * 2
	_GDIPlus_PathAddArc($hPath, $nX, $nY, $nD, $nD, 180, 90)
	_GDIPlus_PathAddArc($hPath, $nX + $nW - $nD, $nY, $nD, $nD, 270, 90)
	_GDIPlus_PathAddArc($hPath, $nX + $nW - $nD, $nY + $nH - $nD, $nD, $nD, 0, 90)
	_GDIPlus_PathAddArc($hPath, $nX, $nY + $nH - $nD, $nD, $nD, 90, 90)
	_GDIPlus_PathCloseFigure($hPath)
	Return $hPath
EndFunc   ;==>_FluentPathRR


; Заливка скруглённого прямоугольника. Супервыборка не нужна: снимок окна
; показал одинаково сглаженные четыре угла и при прямой заливке
Func _FluentFill($hGfx, $nX, $nY, $nW, $nH, $nR, $iArgb)
	If $nW < 1 Or $nH < 1 Then Return
	Local $hPath = _FluentPathRR($nX, $nY, $nW, $nH, $nR)
	Local $hBrush = _GDIPlus_BrushCreateSolid($iArgb)
	_GDIPlus_GraphicsFillPath($hGfx, $hPath, $hBrush)
	_GDIPlus_BrushDispose($hBrush)
	_GDIPlus_PathDispose($hPath)
EndFunc   ;==>_FluentFill


; Рамка внутри заданного прямоугольника: путь сдвинут на полпикселя,
; иначе перо шириной 1 ложится половиной за границу и мылит край
Func _FluentStroke($hGfx, $nX, $nY, $nW, $nH, $nR, $iArgb, $nWidth = 1)
	If $nW < 1 Or $nH < 1 Then Return
	Local $hPath = _FluentPathRR($nX + 0.5, $nY + 0.5, $nW - 1, $nH - 1, $nR)
	Local $hPen = _GDIPlus_PenCreate($iArgb, $nWidth)
	_GDIPlus_GraphicsDrawPath($hGfx, $hPath, $hPen)
	_GDIPlus_PenDispose($hPen)
	_GDIPlus_PathDispose($hPath)
EndFunc   ;==>_FluentStroke


Func _FluentBox($hGfx, $nX, $nY, $nW, $nH, $nR, $iFillArgb, $iStrokeArgb)
	_FluentFill($hGfx, $nX, $nY, $nW, $nH, $nR, $iFillArgb)
	_FluentStroke($hGfx, $nX, $nY, $nW, $nH, $nR, $iStrokeArgb)
EndFunc   ;==>_FluentBox


Func _FluentLine($hGfx, $nX1, $nY1, $nX2, $nY2, $iArgb)
	Local $hPen = _GDIPlus_PenCreate($iArgb, 1)
	_GDIPlus_GraphicsDrawLine($hGfx, $nX1, $nY1 + 0.5, $nX2, $nY2 + 0.5, $hPen)
	_GDIPlus_PenDispose($hPen)
EndFunc   ;==>_FluentLine


; $iAlign: 0 слева, 1 по центру, 2 справа. $iTrim: 0 без обрезки, 3 многоточие
Func _FluentText($hGfx, $sText, $nX, $nY, $nW, $nH, $hFont, $iArgb, $iAlign = 0, $iLineAlign = 1, $iTrim = 0)
	Local $tLayout = _GDIPlus_RectFCreate($nX, $nY, $nW, $nH)
	Local $hFormat = _GDIPlus_StringFormatCreate(0x1000) ; NoWrap
	_GDIPlus_StringFormatSetAlign($hFormat, $iAlign)
	_GDIPlus_StringFormatSetLineAlign($hFormat, $iLineAlign)
	If $iTrim Then DllCall("gdiplus.dll", "int", "GdipSetStringFormatTrimming", _
			"handle", $hFormat, "int", $iTrim)

	Local $hBrush = _GDIPlus_BrushCreateSolid($iArgb)
	_GDIPlus_GraphicsDrawStringEx($hGfx, $sText, $hFont, $tLayout, $hFormat, $hBrush)
	_GDIPlus_BrushDispose($hBrush)
	_GDIPlus_StringFormatDispose($hFormat)
EndFunc   ;==>_FluentText


; Строка со вставками клавиш: в «{SHIFT} + Правый клик» SHIFT рисуется клавишей,
; остальное - текстом. По вертикали по центру $nH. $hGfx = 0 - только мерит.
; Возвращает занятую ширину
Func _FluentTextKeys($hGfx, $sText, $nX, $nY, $nH, $hFont, $iArgb)
	Local Const $iGap = 5, $iKeyH = 16
	Local $hKeyFont = _FluentFont($__g_nFluentSizeSmall)
	Local $aParts = StringRegExp($sText, '\{[^}]*\}|[^{]+', 3)
	If @error Then Return 0

	; Текст рисуется как обычная подпись, с полем GDI+ слева, а место под него - по мерке
	; без полей. Мерка с полями у длинной фразы завышена, и зазор перед клавишей выходил
	; шире, чем после неё. Мерка - тем же Graphics, что рисует: от подсказки рендера зависит
	; ширина. Поле меряется по одному знаку
	Local $hMeasure = $hGfx ? $hGfx : $__g_hFluentMeasureGfx
	Local $hFormat = __FluentFormatTypographic()
	Local $iPad = Floor((_FluentTextW("x", $hFont) - __FluentTextTypoW($hMeasure, "x", $hFont, $hFormat)) / 2)
	Local $nCx = $nX, $sPart, $iW, $nTop, $nTextX
	For $i = 0 To UBound($aParts) - 1
		$sPart = StringStripWS($aParts[$i], 3)
		If $sPart = "" Then ContinueLoop
		If $nCx > $nX Then $nCx += $iGap
		If StringLeft($sPart, 1) = "{" Then
			$sPart = StringStripWS(StringMid($sPart, 2, StringLen($sPart) - 2), 3)
			$iW = _Max(19, _FluentTextW($sPart, $hKeyFont) + 12)
			If $hGfx Then
				$nTop = $nY + Int(($nH - $iKeyH) / 2)
				_FluentBox($hGfx, $nCx, $nTop, $iW, $iKeyH, 2, _FluentArgb($g_iFluentKeyBg), _FluentArgb($g_iFluentKeyBorder))
				; Нижняя грань толще: вставка читается клавишей, а не полем ввода
				_FluentLine($hGfx, $nCx + 2, $nTop + $iKeyH - 2, $nCx + $iW - 2, $nTop + $iKeyH - 2, _FluentArgb($g_iFluentKeyBorder))
				; Строку GDI+ центрирует с запасом под выносные элементы, и надпись клавиши
				; без них, SHIFT или CTRL, всплывает к верхней грани. Опускаем на 2 px
				_FluentText($hGfx, $sPart, $nCx, $nTop + 2, $iW, $iKeyH - 1, $hKeyFont, $iArgb, 1, 1)
			EndIf
		Else
			; Первая строка встаёт вровень с соседними подписями, следующие - поле левее
			$nTextX = ($nCx = $nX) ? $nCx : $nCx - $iPad
			$iW = __FluentTextTypoW($hMeasure, $sPart, $hFont, $hFormat) + (($nCx = $nX) ? $iPad : 0)
			If $hGfx Then _FluentText($hGfx, $sPart, $nTextX, $nY, $iW + $iPad * 2 + 4, $nH, $hFont, $iArgb, 0, 1)
		EndIf
		$nCx += $iW
	Next
	_GDIPlus_StringFormatDispose($hFormat)
	Return $nCx - $nX
EndFunc   ;==>_FluentTextKeys


; Копия GenericTypographic: без полей по краям строки, без переноса, по вертикали по центру
Func __FluentFormatTypographic()
	Local $aCall = DllCall("gdiplus.dll", "int", "GdipStringFormatGetGenericTypographic", "handle*", 0)
	If @error Or $aCall[0] Then Return _GDIPlus_StringFormatCreate(0x1000)
	Local $hGeneric = $aCall[1]
	; Общий объект GDI+ не трогаем: правим и удаляем копию
	$aCall = DllCall("gdiplus.dll", "int", "GdipCloneStringFormat", "handle", $hGeneric, "handle*", 0)
	If @error Or $aCall[0] Then Return _GDIPlus_StringFormatCreate(0x1000)
	Local $hFormat = $aCall[2]
	$aCall = DllCall("gdiplus.dll", "int", "GdipGetStringFormatFlags", "handle", $hFormat, "int*", 0)
	If Not @error And $aCall[0] = 0 Then DllCall("gdiplus.dll", "int", "GdipSetStringFormatFlags", "handle", $hFormat, "int", BitOR($aCall[2], 0x1000))
	_GDIPlus_StringFormatSetLineAlign($hFormat, 1)
	Return $hFormat
EndFunc   ;==>__FluentFormatTypographic


Func __FluentTextTypoW($hGfx, $sText, $hFont, $hFormat)
	If Not $hGfx Then Return 0
	Local $aInfo = _GDIPlus_GraphicsMeasureString($hGfx, $sText, $hFont, _GDIPlus_RectFCreate(0, 0, 4000, 100), $hFormat)
	If Not IsArray($aInfo) Then Return 0
	Return Ceiling(DllStructGetData($aInfo[0], "Width"))
EndFunc   ;==>__FluentTextTypoW


; Высота строки шрифта окна средствами GDI: ей меряет строки штатный Edit,
; поэтому многострочному полю нужна она, а не высота из GDI+
Func _FluentGdiLineHeight()
	If $__g_iFluentGdiLineH Then Return $__g_iFluentGdiLineH
	If Not $__g_hFluentGui Then Return 15
	Local $hDC = _WinAPI_GetDC($__g_hFluentGui)
	If Not $hDC Then Return 15

	Local $hOld = 0
	Local $hFont = _SendMessage($__g_hFluentGui, $WM_GETFONT, 0, 0, 0, "wparam", "lparam", "handle")
	If $hFont Then $hOld = _WinAPI_SelectObject($hDC, $hFont)
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, "Ag")
	If $hOld Then _WinAPI_SelectObject($hDC, $hOld)
	_WinAPI_ReleaseDC($__g_hFluentGui, $hDC)

	Local $iH = IsDllStruct($tSize) ? DllStructGetData($tSize, "Y") : 0
	If $iH < 1 Then Return 15
	$__g_iFluentGdiLineH = $iH
	Return $iH
EndFunc   ;==>_FluentGdiLineHeight


; Ширина строки шрифтом штатного контрола $iCtrl средствами GDI: так её рисует Static.
; GDI+ даёт строку шире на поля, и метка по её мерке оставляет зазор за текстом
Func _FluentGdiTextW($sText, $iCtrl)
	Local $hCtrl = GUICtrlGetHandle($iCtrl)
	If Not $hCtrl Then Return 0
	Local $hDC = _WinAPI_GetDC($hCtrl)
	If Not $hDC Then Return 0

	Local $hOld = 0
	Local $hFont = _SendMessage($hCtrl, $WM_GETFONT, 0, 0, 0, "wparam", "lparam", "handle")
	If $hFont Then $hOld = _WinAPI_SelectObject($hDC, $hFont)
	Local $tSize = _WinAPI_GetTextExtentPoint32($hDC, $sText)
	If $hOld Then _WinAPI_SelectObject($hDC, $hOld)
	_WinAPI_ReleaseDC($hCtrl, $hDC)
	Return IsDllStruct($tSize) ? DllStructGetData($tSize, "X") : 0
EndFunc   ;==>_FluentGdiTextW


Func _FluentTextW($sText, $hFont)
	If Not $__g_hFluentMeasureGfx Then Return 0
	Local $tLayout = _GDIPlus_RectFCreate(0, 0, 4000, 100)
	Local $hFormat = _GDIPlus_StringFormatCreate(0x1000)
	Local $aInfo = _GDIPlus_GraphicsMeasureString($__g_hFluentMeasureGfx, $sText, $hFont, $tLayout, $hFormat)
	_GDIPlus_StringFormatDispose($hFormat)
	If Not IsArray($aInfo) Then Return 0
	Return Ceiling(DllStructGetData($aInfo[0], "Width"))
EndFunc   ;==>_FluentTextW


; ============================================================
; Шрифты
; ============================================================

; Шрифт GDI+ из кэша. $bSemi – Segoe UI Semibold, если он есть
Func _FluentFont($nSize = 0, $bSemi = False)
	If $nSize = 0 Then $nSize = $__g_nFluentFontSize
	Local $sKey = $nSize & "|" & ($bSemi ? 1 : 0)
	; В кэше пара [шрифт, семейство]: семейство нужно живым, пока жив шрифт
	If MapExists($__g_oFluentFonts, $sKey) Then
		Local $aCached = $__g_oFluentFonts[$sKey]
		Return $aCached[0]
	EndIf

	Local $sName = $bSemi ? "Segoe UI Semibold" : $__g_sFluentFont
	Local $hFamily = _GDIPlus_FontFamilyCreate($sName)
	If @error Or Not $hFamily Then $hFamily = _GDIPlus_FontFamilyCreate($__g_sFluentFont)
	Local $hFont = _GDIPlus_FontCreate($hFamily, $nSize, 0)

	Local $aPair[2] = [$hFont, $hFamily]
	$__g_oFluentFonts[$sKey] = $aPair
	Return $hFont
EndFunc   ;==>_FluentFont


; Установлен ли шрифт: по списку шрифтов в реестре
Func _FluentFontExists($sName)
	Local Const $sKey = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
	Local $i = 1, $sValName
	While True
		$sValName = RegEnumVal($sKey, $i)
		If @error Then ExitLoop
		; Значения вида "Segoe UI (TrueType)", "Segoe UI Bold (TrueType)"
		If StringRegExp($sValName, "(?i)^\Q" & $sName & "\E(\s|\(|$)") Then Return True
		$i += 1
	WEnd
	Return False
EndFunc   ;==>_FluentFontExists


; Первый установленный шрифт из списка, иначе $sDefault
Func _FluentFontFindBest(Const ByRef $aCandidates, $sDefault = "MS Shell Dlg 2")
	For $sCand In $aCandidates
		If _FluentFontExists($sCand) Then Return $sCand
	Next
	Return $sDefault
EndFunc   ;==>_FluentFontFindBest


; Лучший из Segoe UI, Tahoma, MS Shell Dlg 2 – шрифтом окна. Возвращает имя шрифта
Func _FluentFontApply($hGui, $iSize = 9, $iWeight = 400, $iAttrib = 0)
	Local $aCandidates[3] = ["Segoe UI", "Tahoma", "MS Shell Dlg 2"]
	Local $sFont = _FluentFontFindBest($aCandidates)
	GUISetFont($iSize, $iWeight, $iAttrib, $sFont, $hGui)
	Return $sFont
EndFunc   ;==>_FluentFontApply


; ============================================================
; Иконки
; ============================================================

; Иконка PNG из папки _FluentInit, перекрашенная в $iRgb, из кэша. Имя – без расширения
Func _FluentIcon($sName, $iSize, $iRgb)
	Local $sKey = $sName & "|" & $iSize & "|" & Hex($iRgb, 6)
	If MapExists($__g_oFluentIcons, $sKey) Then Return $__g_oFluentIcons[$sKey]

	Local $sPath = $__g_sFluentIconDir & "\" & $sName & ".png"
	If Not FileExists($sPath) Then Return 0
	Local $hSrc = _GDIPlus_ImageLoadFromFile($sPath)
	If @error Or Not $hSrc Then Return 0

	Local $hTinted = __FluentTintCopy($hSrc, $iSize, $iRgb)
	_GDIPlus_ImageDispose($hSrc)
	If Not $hTinted Then Return 0

	$__g_oFluentIcons[$sKey] = $hTinted
	Return $hTinted
EndFunc   ;==>_FluentIcon


; Иконка из файла .ico как есть, без перекраски, из кэша: у неё свои цвета (темы приложения)
Func _FluentIconFile($sPath, $iSize)
	Local $sKey = "file|" & $sPath & "|" & $iSize
	If MapExists($__g_oFluentIcons, $sKey) Then Return $__g_oFluentIcons[$sKey]
	If Not FileExists($sPath) Then Return 0
	Local $hIcon = _WinAPI_LoadImage(0, $sPath, $IMAGE_ICON, $iSize, $iSize, $LR_LOADFROMFILE)
	If Not $hIcon Then Return 0
	Local $hBitmap = _GDIPlus_BitmapCreateFromHICON32($hIcon)
	_WinAPI_DestroyIcon($hIcon)
	If Not $hBitmap Then Return 0
	$__g_oFluentIcons[$sKey] = $hBitmap
	Return $hBitmap
EndFunc   ;==>_FluentIconFile


Func _FluentDrawIcon($hGfx, $sName, $iSize, $iRgb, $nX, $nY)
	Local $hIcon = _FluentIcon($sName, $iSize, $iRgb)
	If Not $hIcon Then Return
	_GDIPlus_GraphicsDrawImage($hGfx, $hIcon, $nX, $nY)
EndFunc   ;==>_FluentDrawIcon


; PNG как есть, без перекраски (логотип)
Func _FluentDrawImage($hGfx, $sPath, $nX, $nY, $nW, $nH)
	If Not FileExists($sPath) Then Return
	Local $hImg = _GDIPlus_ImageLoadFromFile($sPath)
	If @error Or Not $hImg Then Return
	_GDIPlus_GraphicsDrawImageRect($hGfx, $hImg, $nX, $nY, $nW, $nH)
	_GDIPlus_ImageDispose($hImg)
EndFunc   ;==>_FluentDrawImage


; Иконка 16x16 по центру прозрачной картинки 20x20 в ImageList: поля вокруг иконки,
; как у пунктов меню. Источник – .ico или файл с ресурсами (exe, dll). Индекс или -1
Func _FluentImageListAddIcon($hImageList, $sIconSource, $iIconIndex = 0)
	Local $hBitmap = _WinAPI_CreateBitmap(20, 20, 1, 32, 0)
	Local $hDC = _WinAPI_CreateCompatibleDC(0)
	Local $hOld = _WinAPI_SelectObject($hDC, $hBitmap)

	Local $hBrush = _WinAPI_GetStockObject($NULL_BRUSH)
	Local $hOldBrush = _WinAPI_SelectObject($hDC, $hBrush)
	_WinAPI_PatBlt($hDC, 0, 0, 20, 20, $DSTINVERT)
	_WinAPI_SelectObject($hDC, $hOldBrush)

	Local $hIcon
	If StringRight($sIconSource, 4) = ".ico" Then
		$hIcon = _WinAPI_LoadImage(0, $sIconSource, $IMAGE_ICON, 16, 16, $LR_LOADFROMFILE)
	Else
		; Ровно 16x16 из ресурсов, без масштабирования
		$hIcon = _WinAPI_ShellExtractIcon($sIconSource, $iIconIndex, 16, 16)
	EndIf

	If Not $hIcon Then
		_WinAPI_SelectObject($hDC, $hOld)
		_WinAPI_DeleteDC($hDC)
		_WinAPI_DeleteObject($hBitmap)
		Return -1
	EndIf

	_WinAPI_DrawIconEx($hDC, 2, 2, $hIcon, 16, 16, 0, 0, $DI_NORMAL)

	_WinAPI_DestroyIcon($hIcon)
	_WinAPI_SelectObject($hDC, $hOld)
	_WinAPI_DeleteDC($hDC)

	Local $iIndex = _GUIImageList_Add($hImageList, $hBitmap)
	_WinAPI_DeleteObject($hBitmap)
	Return $iIndex
EndFunc   ;==>_FluentImageListAddIcon


; ============================================================
; Наведение, раскладка, курсор
; ============================================================

; Контрол под курсором на текущем такте опроса, общий для всех модулей
Func _FluentCtrlUnderCursor()
	Return $__g_iFluentHoverCtrl
EndFunc   ;==>_FluentCtrlUnderCursor


; X курсора относительно левого края контрола, -1 если курсор вне контрола
Func _FluentCursorLocalX($iCtrl)
	Local $hGui = __FluentCtrlGui($iCtrl)
	Local $aPos = ControlGetPos($hGui, "", $iCtrl)
	If @error Or Not IsArray($aPos) Then Return -1
	Local $aCursor = GUIGetCursorInfo($hGui)
	If @error Or Not IsArray($aCursor) Then Return -1
	Return $aCursor[0] - $aPos[0]
EndFunc   ;==>_FluentCursorLocalX


; Отправляет контрол в самый низ порядка перекрытия. Созданные раньше контролы
; AutoIt кладёт поверх поздних, и подложка (рамка поля, шапка) перехватывала бы
; клики у лежащих на ней Edit и кнопок. Звать после создания всего, что на подложке
Func _FluentSendToBack($iCtrl)
	_WinAPI_SetWindowPos(GUICtrlGetHandle($iCtrl), $HWND_BOTTOM, 0, 0, 0, 0, _
			BitOR($SWP_NOSIZE, $SWP_NOMOVE, $SWP_NOACTIVATE))
EndFunc   ;==>_FluentSendToBack


; Текущий размер контрола [ширина, высота]: после ресайза его задал докинг
Func _FluentCtrlSize($iCtrl)
	Local $aSize[2] = [0, 0]
	Local $aPos = ControlGetPos(__FluentCtrlGui($iCtrl), "", $iCtrl)
	If @error Or Not IsArray($aPos) Then Return $aSize
	$aSize[0] = $aPos[2]
	$aSize[1] = $aPos[3]
	Return $aSize
EndFunc   ;==>_FluentCtrlSize


; Докинг «стоит на месте». Назначивший свой докинг обязан после ресайза
; вызвать _Fluent*SyncSize, иначе картинка останется прежнего размера
Func _FluentDockFixed($iCtrl)
	GUICtrlSetResizing($iCtrl, $GUI_DOCKLEFT + $GUI_DOCKTOP + $GUI_DOCKWIDTH + $GUI_DOCKHEIGHT)
EndFunc   ;==>_FluentDockFixed


; Курсор-рука над контролом. GUICtrlSetCursor на Pic не действует, поэтому на WM_SETCURSOR
; отвечает сабкласс. На x64 он машинный: через AutoIt-колбэк шёл бы и WM_PAINT контрола,
; а это риск вечного цикла перерисовки (FluentSubclass.au3)
Func _FluentHandCursor($iCtrl)
	_WinAPI_SetWindowSubclass(GUICtrlGetHandle($iCtrl), __FluentCursorProcPtr(), 1, 0)
EndFunc   ;==>_FluentHandCursor


Func _FluentHandCursorRemove($iCtrl)
	_WinAPI_RemoveWindowSubclass(GUICtrlGetHandle($iCtrl), __FluentCursorProcPtr(), 1)
EndFunc   ;==>_FluentHandCursorRemove


; ============================================================
; Внутреннее
; ============================================================

; GDI+ поднимается один раз на всё семейство
Func __FluentGdipStart()
	If $__g_bFluentGdip Then Return
	_GDIPlus_Startup()
	$__g_bFluentGdip = True
EndFunc   ;==>__FluentGdipStart


; Хуки модулей: событие → список функций без аргументов. Модуль регистрирует свои при подключении
Func __FluentHookAdd($sEvent, $sFunc)
	Local $aList[0]
	If MapExists($__g_oFluentHooks, $sEvent) Then $aList = $__g_oFluentHooks[$sEvent]
	For $sItem In $aList
		If $sItem = $sFunc Then Return
	Next
	ReDim $aList[UBound($aList) + 1]
	$aList[UBound($aList) - 1] = $sFunc
	$__g_oFluentHooks[$sEvent] = $aList
EndFunc   ;==>__FluentHookAdd


Func __FluentHookRun($sEvent)
	If Not MapExists($__g_oFluentHooks, $sEvent) Then Return
	Local $aList = $__g_oFluentHooks[$sEvent]
	For $sFunc In $aList
		Call($sFunc)
	Next
EndFunc   ;==>__FluentHookRun


; Окно, которому принадлежит контрол: рисованные контролы живут не только в главном
Func __FluentCtrlGui($iCtrl)
	Return _WinAPI_GetParent(GUICtrlGetHandle($iCtrl))
EndFunc   ;==>__FluentCtrlGui


; Такт опроса наведения: контрол под курсором ищется один раз на все модули
Func __FluentHoverTick()
	$__g_iFluentHoverCtrl = __FluentFindCtrlUnderCursor()
	__FluentHookRun('hover')
EndFunc   ;==>__FluentHoverTick


; Опрашивается окно, реально лежащее под курсором: опрос одного главного не видел бы
; контролы других окон и подсвечивал бы контрол под перекрывающим его окном
Func __FluentFindCtrlUnderCursor()
	; GetCursorPos напрямую: _WinAPI_GetMousePos на каждом такте дёргал бы Opt дважды
	Local $tPoint = DllStructCreate($tagPOINT)
	DllCall("user32.dll", "bool", "GetCursorPos", "struct*", $tPoint)
	If @error Then Return 0
	Local $hWnd = _WinAPI_WindowFromPoint($tPoint)
	If Not $hWnd Then Return 0
	Local $aCursor = GUIGetCursorInfo(_WinAPI_GetAncestor($hWnd, $GA_ROOT))
	If @error Or Not IsArray($aCursor) Then Return 0
	Return $aCursor[4]
EndFunc   ;==>__FluentFindCtrlUnderCursor


; Процедура сабкласса курсора: машинная, а на x86 - колбэк AutoIt
Func __FluentCursorProcPtr()
	Local $pNative = _FluentSubclass_HandCursor()
	If $pNative Then Return $pNative
	If $__g_hFluentCursorCB = 0 Then
		$__g_hFluentCursorCB = DllCallbackRegister("__FluentCursorProc", "lresult", _
				"hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
	EndIf
	Return DllCallbackGetPtr($__g_hFluentCursorCB)
EndFunc   ;==>__FluentCursorProcPtr


Func __FluentCursorProc($hWnd, $iMsg, $wParam, $lParam, $iId, $dwData)
	#forceref $iId, $dwData
	If $iMsg = $WM_SETCURSOR Then
		_WinAPI_SetCursor(_WinAPI_LoadCursor(0, $IDC_HAND))
		Return 1
	EndIf
	Return _FluentSubclass_DefProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc   ;==>__FluentCursorProc


; Копия картинки в один цвет: RGB зануляется матрицей и задаётся строкой
; смещения, альфа исходника сохраняется, и силуэт остаётся сглаженным
Func __FluentTintCopy($hImage, $iSize, $iColor)
	Local $hBmp = _GDIPlus_BitmapCreateFromScan0($iSize, $iSize)
	If @error Or Not $hBmp Then Return 0
	Local $hGfx = _GDIPlus_ImageGetGraphicsContext($hBmp)
	; PNG уже нарисован в целевом размере: копируем пиксель в пиксель
	_GDIPlus_GraphicsSetInterpolationMode($hGfx, 5) ; NearestNeighbor
	_GDIPlus_GraphicsSetPixelOffsetMode($hGfx, 3) ; None

	Local $nR = BitAND(BitShift($iColor, 16), 0xFF) / 255
	Local $nG = BitAND(BitShift($iColor, 8), 0xFF) / 255
	Local $nB = BitAND($iColor, 0xFF) / 255

	; Матрица 5x5 построчно, структура создаётся нулевой: R', G', B' = 0, строка 5 - цвет
	Local $tMatrix = DllStructCreate("float m[25]")
	DllStructSetData($tMatrix, "m", 1, 19) ; A' = A
	DllStructSetData($tMatrix, "m", $nR, 21)
	DllStructSetData($tMatrix, "m", $nG, 22)
	DllStructSetData($tMatrix, "m", $nB, 23)
	DllStructSetData($tMatrix, "m", 1, 25)

	Local $aAttr = DllCall("gdiplus.dll", "int", "GdipCreateImageAttributes", "handle*", 0)
	If @error Or $aAttr[0] <> 0 Then
		_GDIPlus_GraphicsDispose($hGfx)
		_GDIPlus_BitmapDispose($hBmp)
		Return 0
	EndIf
	Local $hAttr = $aAttr[1]
	DllCall("gdiplus.dll", "int", "GdipSetImageAttributesColorMatrix", "handle", $hAttr, _
			"int", 0, "bool", True, "struct*", $tMatrix, "ptr", 0, "int", 0)
	DllCall("gdiplus.dll", "int", "GdipDrawImageRectRectI", "handle", $hGfx, "handle", $hImage, _
			"int", 0, "int", 0, "int", $iSize, "int", $iSize, _
			"int", 0, "int", 0, "int", _GDIPlus_ImageGetWidth($hImage), "int", _GDIPlus_ImageGetHeight($hImage), _
			"int", 2, "handle", $hAttr, "ptr", 0, "ptr", 0)
	DllCall("gdiplus.dll", "int", "GdipDisposeImageAttributes", "handle", $hAttr)
	_GDIPlus_GraphicsDispose($hGfx)
	Return $hBmp
EndFunc   ;==>__FluentTintCopy


; Осветление ($nFactor > 1) или затемнение ($nFactor < 1) цвета
Func __FluentShade($iRgb, $nFactor)
	Local $iR = _Min(255, Int(BitAND(BitShift($iRgb, 16), 0xFF) * $nFactor))
	Local $iG = _Min(255, Int(BitAND(BitShift($iRgb, 8), 0xFF) * $nFactor))
	Local $iB = _Min(255, Int(BitAND($iRgb, 0xFF) * $nFactor))
	Return BitShift($iR, -16) + BitShift($iG, -8) + $iB
EndFunc   ;==>__FluentShade


Func __FluentIconCacheClear()
	For $sKey In MapKeys($__g_oFluentIcons)
		If $__g_oFluentIcons[$sKey] Then _GDIPlus_BitmapDispose($__g_oFluentIcons[$sKey])
	Next
	Local $oEmpty[]
	$__g_oFluentIcons = $oEmpty
EndFunc   ;==>__FluentIconCacheClear


Func __FluentFontCacheClear()
	For $sKey In MapKeys($__g_oFluentFonts)
		Local $aPair = $__g_oFluentFonts[$sKey]
		If $aPair[0] Then _GDIPlus_FontDispose($aPair[0])
		If $aPair[1] Then _GDIPlus_FontFamilyDispose($aPair[1])
	Next
	Local $oEmpty[]
	$__g_oFluentFonts = $oEmpty
EndFunc   ;==>__FluentFontCacheClear
