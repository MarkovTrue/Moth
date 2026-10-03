#include-once

; ============================================================================
;  MothResize.au3
;  Команды ресайза: разбор, сборка, подписи и постфиксы. Пресет окна размеров
;  (Menu.exe, Command=resizer) - действие Moth.Resize.<команда> без своей секции
;  в Moth.ini: всё о нём выводится из команды в имени. Поэтому Moth, запущенный
;  до появления пресета, понимает его без перечитывания ini.
;  Подключается из MothCommon.au3
; ============================================================================

Global Const $gc_sResizeActionPrefix = 'Moth.Resize.'

; Алгоритм в окне размеров - назначение картинки: фото, графика, пиксель-арт.
; Значение - индекс фильтра в $gc_aResizeFilters: Lanczos, Catrom, Point
Global Const $gc_aResizeFilterGroups = [0, 2, 4]

; Пределы поля размера: проценты и стороны в точках
Global Const $gc_iResizePercentMax = 1000, $gc_iResizeSideMax = 40000

; Окно размеров: быстрый выбор процентов
Global Const $gc_aResizeQuickPercents = [10, 25, 50, 75, 150, 200]


; Команда из имени Moth.Resize.<команда>, '' - имя не такое или команда кривая
Func _ResizeActionCommand($sActionName)
	Local $aMatch = StringRegExp($sActionName, '^Moth\.Resize\.(percent_\d{1,4}_[0-5]|resize_\d{1,5}_\d{1,5}_[0-2]_[0-5](?:_1)?)$', 1)
	If @error Then Return ''
	Return $aMatch[0]
EndFunc   ;==>_ResizeActionCommand


; [проценты, ширина, высота, режим, фильтр, увеличивать]. Проценты 0 - размер в точках,
; сторона 0 - по пропорции. Картинку меньше размера в точках команда не увеличивает,
; если в конце нет _1. @error - команда не ресайза
Func _ResizeParse($sCommand)
	Local $aResize[6] = [0, 0, 0, 0, 0, False]
	Local $aSplit = StringSplit($sCommand, '_')
	If $aSplit[1] = 'percent' And $aSplit[0] = 3 Then
		$aResize[0] = Int($aSplit[2])
		$aResize[4] = Int($aSplit[3])
	ElseIf $aSplit[1] = 'resize' And ($aSplit[0] = 5 Or $aSplit[0] = 6) Then
		$aResize[1] = Int($aSplit[2])
		$aResize[2] = Int($aSplit[3])
		$aResize[3] = Int($aSplit[4])
		$aResize[4] = Int($aSplit[5])
		$aResize[5] = $aSplit[0] = 6 And $aSplit[6] = '1'
	Else
		Return SetError(1, 0, $aResize)
	EndIf
	If $aResize[0] = 0 And $aResize[1] = 0 And $aResize[2] = 0 Then Return SetError(1, 0, $aResize)
	Return $aResize
EndFunc   ;==>_ResizeParse


; Команда из параметров. С одной стороной режим только «вписать»: заполнять нечего.
; $bEnlarge - картинку меньше размера увеличивать, у процентов не нужен
Func _ResizeCommand($iPercent, $iWidth, $iHeight, $iMode, $iFilter, $bEnlarge = False)
	If $iPercent > 0 Then Return 'percent_' & $iPercent & '_' & $iFilter
	If $iWidth = 0 Or $iHeight = 0 Then $iMode = 0
	Return 'resize_' & $iWidth & '_' & $iHeight & '_' & $iMode & '_' & $iFilter & ($bEnlarge ? '_1' : '')
EndFunc   ;==>_ResizeCommand



; Постфикс нового файла: размер, в конце режим и алгоритм, если они не по умолчанию.
; _per50, _per50_pix, _res1920x1080, _res800x800_crop_vec, _res1920x, _resx1080.
; Сторона 0 - как в геометрии ImageMagick: пусто. С одной стороной режим только «вписать»
Func _ResizePostfix($sCommand)
	Local $aResize = _ResizeParse($sCommand)
	If @error Then Return ''
	Local $aMode[3] = ['', '_fill', '_crop'], $aGroup[3] = ['', '_vec', '_pix']
	Local $sGroup = $aGroup[_ResizeFilterGroup($aResize[4])]
	If $aResize[0] Then Return '_per' & $aResize[0] & $sGroup
	Local $sMode = ($aResize[1] And $aResize[2]) ? $aMode[$aResize[3]] : ''
	Return '_res' & ($aResize[1] ? $aResize[1] : '') & 'x' & ($aResize[2] ? $aResize[2] : '') & $sMode & $sGroup
EndFunc   ;==>_ResizePostfix


; Размер пресета: «50%», «1920x1080», «по ширине 1920». Режим и алгоритм
; в подписи не пишутся: их видно по иконке и постфиксу. Размер в точках без увеличения -
; со стрелкой вниз в конце
Func _ResizeLabel($sCommand)
	Local $aResize = _ResizeParse($sCommand)
	If @error Then Return ''
	Local $sLabel
	If $aResize[0] Then
		$sLabel = $aResize[0] & '%'
	ElseIf $aResize[2] = 0 Then
		$sLabel = _LangFile_Format('Resizer', 'Width', 'to width %1', $aResize[1])
	ElseIf $aResize[1] = 0 Then
		$sLabel = _LangFile_Format('Resizer', 'Height', 'to height %1', $aResize[2])
	Else
		; Латинская x без пробелов, как в постфиксе _res1920x1080
		$sLabel = $aResize[1] & 'x' & $aResize[2]
	EndIf
	; U+2193 - стрелка вниз
	If ($aResize[1] Or $aResize[2]) And Not $aResize[5] Then $sLabel &= ' ' & ChrW(0x2193)

	Return $sLabel
EndFunc   ;==>_ResizeLabel


Func _ResizeIcon($sCommand)
	Local $aResize = _ResizeParse($sCommand)
	If @error Then Return ''
	Return _ResizeModeIcon($aResize[3], _ResizeFilterGroup($aResize[4]))
EndFunc   ;==>_ResizeIcon


; Иконка из Themes\dark|light: режим - вписать, заполнить, заполнить и обрезать;
; у графики и пикселей значок алгоритма в углу, у фото значка нет
Func _ResizeModeIcon($iMode, $iGroup = 0)
	Local $aIcon[3] = ['Resize', 'Fill', 'Trim'], $aGroup[3] = ['', 'Graphics', 'Pixels']
	Return $aIcon[$iMode] & $aGroup[$iGroup] & '.ico'
EndFunc   ;==>_ResizeModeIcon


Func _ResizeModeName($iMode)
	Local $aName[3] = [_LangFile_Get('Resizer', 'ModeFit', 'Fit'), _LangFile_Get('Resizer', 'ModeFill', 'Fill'), _
			_LangFile_Get('Resizer', 'ModeCrop', 'Crop')]
	Return $aName[$iMode]
EndFunc   ;==>_ResizeModeName


; Группа алгоритма по фильтру: 0 фото, 1 графика, 2 пиксели. Фильтры из $gc_aResizeFilters
; идут парами по назначению, и заданный в ini RobidouxSharp попадает к фото
Func _ResizeFilterGroup($iFilter)
	Local $iGroup = Int($iFilter / 2)
	Return $iGroup < UBound($gc_aResizeFilterGroups) ? $iGroup : UBound($gc_aResizeFilterGroups) - 1
EndFunc   ;==>_ResizeFilterGroup


Func _ResizeFilterGroupName($iGroup)
	Local $aName[3] = [_LangFile_Get('Resizer', 'FilterPhoto', 'Photo'), _LangFile_Get('Resizer', 'FilterGraphics', 'Graphics'), _
			_LangFile_Get('Resizer', 'FilterPixels', 'Pixels')]
	Return $aName[$iGroup]
EndFunc   ;==>_ResizeFilterGroupName
