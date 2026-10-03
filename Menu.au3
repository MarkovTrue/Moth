#pragma compile(Out, ..\MothPortable\Menu.exe)
#pragma compile(Icon, Assets\Icons\Menu.ico)
#pragma compile(x64, True)
#pragma compile(ProductName, Moth Menu)
#pragma compile(ProductVersion, 1.40)
#pragma compile(FileVersion, 1.40)
#pragma compile(FileDescription, Moth Menu)
#pragma compile(CompanyName, MarkovTrue)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

; Окно выбора действия для пункта контекстного меню с Popup= в Moth.ini
; («Конвертировать…», «Изменить палитру…»). Аргументы как у Launcher: путь и имя пункта.
; Выбранное действие уходит в очередь Moth для всех файлов выделения. Кнопка справа
; у пункта добавляет действие в контекстное меню или убирает его оттуда (Pinned=).
; Окно и иконки в цвет меню проводника: по режиму приложений Windows, не по теме Moth.
; Пункт с Command=resizer открывает окно размеров: пресеты и под ними панель своего размера.
;
; При выделении нескольких файлов проводник запускает команду на каждый файл.
; Окно показывает первый процесс, остальные отдают ему путь через WM_COPYDATA
; (Include\CopyDataQueue.au3) и выходят.

#include <GuiEdit.au3>

#include "Common\MothExplorerMenu.au3"
#include "Include\FluentButton.au3"
#include "Include\FluentInput.au3"
#include "Include\FluentMenu.au3"
#include "Include\FluentSegment.au3"

_MothRequireX64()

; Проводник запускает процессы выделения и после выбора, поэтому окно ждёт,
; пока столько мс не будет новых путей
Global Const $gc_iQueueTail = 1500

Global $g_sPopup = '', $g_aActions[0], $g_sPinned = ''
; Группа форматов файла: закреплённые свои у каждой, по её меню проводника окно решает,
; можно ли закрепить ещё
Global $g_sFormat = ''
; Пути выделения и действия, уже отданные в Moth: опоздавший путь получает их все
Global $g_aPaths[0], $g_aPicked[0]
; Окно размеров: поля ширины, высоты и процентов, «не увеличивать» и его
; состояние, быстрый выбор процентов, режим, алгоритм; живая строка (-1 - окна размеров нет)
; и действие, которое она сейчас показывает. Пока поля меняет сама панель, их правка не обрабатывается
Global $g_iResizeW = 0, $g_iResizeH = 0, $g_iResizePct = 0, $g_iResizePercent = 0
Global $g_iResizeNoEnlarge = 0, $g_bResizeNoEnlarge = True, $g_iResizeMode = 0, $g_iResizeFilter = 0
; Размер задают проценты или точки: поле, где фокус или ввод; окно меню, в котором стоит панель.
; Серые подсказки полей по ControlID
Global $g_bResizeByPct = True, $g_hResizeGui = 0, $g_mResizeCues[]
Global $g_iResizeLive = -1, $g_sResizeAction = '', $g_bResizeSync = False, $g_bResizePanel = False
; Размер первого файла выделения, 0 - неизвестен; его читает magick identify в фоне
Global $g_iSrcW = 0, $g_iSrcH = 0, $g_iSrcPid = 0, $g_hSrcTimer = 0, $g_sSrcOut = ''


_Main()


Func _Main()
	If $CmdLine[0] < 2 Then Exit
	Local $sPath = $CmdLine[1]
	$g_sPopup = $CmdLine[2]
	If Not FileExists($sPath) Then Exit

	; Окно этого выделения уже открыто: отдаём путь ему. Если оно успело закрыться,
	; окно откроет этот процесс
	While Not _CopyDataQueue_Singleton('MothMenu', $gc_sIpcMenu)
		If _CopyDataQueue_Send($gc_sIpcMenu, $sPath & '|' & $g_sPopup) Then Exit
	WEnd

	_MothIniRequire()
	_MothLangInit()
	_MothMenu_SyncIconTheme()

	; Список по формату файла, на котором открыли меню. Окно размеров и пустым нужно:
	; в нём задают свой размер
	Local $bResizer = _MothMenu_IsResizer($g_sPopup)
	$g_sFormat = _IsDir($sPath) ? 'folder' : _FormatGroup(_GetFileExtension($sPath))
	$g_sPinned = '|' & _MothMenu_PinnedRead($gc_sMothIni, $g_sPopup, $g_sFormat) & '|'
	$g_aActions = _MothMenu_PopupActions($g_sPopup, _IsDir($sPath) ? 'folder' : _GetFileExtension($sPath))
	If $bResizer Then
		_ResizerSourceStart($sPath)
		_ResizerLoad()
		_ResizerDividers()
	ElseIf UBound($g_aActions) = 0 Then
		Exit
	EndIf

	Local $aItems = _MenuItems($bResizer)
	If $bResizer Then
		_FluentMenu_SetPanel('_ResizerPanelCreate', '_ResizerPanelApply', '_ResizerPanelClose', 1, '_ResizerPanelShift')
		_FluentMenu_SetIconDir(@ScriptDir & '\Themes\Icons')
		_FluentMenu_SetSort('_ResizerMove')
		_FluentMenu_SetAdd('_ResizerAdd')
		_FluentMenu_SetRemove('_ResizerRemove')
	EndIf

	_FluentMenu_SetButton('_OnPinToggle')
	_FluentMenu_SetPinnable(_MothMenu_PinFits($g_sFormat))
	_FluentMenu_SetPick('_OnPick')
	_ListAppend($g_aPaths, $sPath)
	; Палитра Fluent, но текст пунктов как у меню проводника: чисто белый и чёрный, а не
	; приглушённый #E6E6E6 и #1B1B1B. Тема задана здесь, поэтому окну меню - Default
	_FluentSetTheme($gc_bRegDarkTheme)
	$g_iFluentText1 = $gc_bRegDarkTheme ? 0xFFFFFF : 0x000000
	Local $iSel = _FluentMenu_Show($aItems, Default)
	If $iSel >= 0 Then _MenuPick(_MenuRowAction($iSel))

	; Файлы выделения от процессов, запущенных с опозданием, получают всё выбранное. После
	; отмены их пути тоже принимаются, иначе опоздавший процесс открыл бы окно заново
	Local $aNew, $hQuiet = TimerInit()
	Do
		$aNew = _MenuTakePaths()
		If UBound($aNew) Then
			$hQuiet = TimerInit()
			_MenuSend($aNew, $g_aPicked)
			; Пока шла отправка, опоздавшие ждали: затишье отсчитывается заново
			$hQuiet = TimerInit()
		EndIf
		Sleep(100)
	Until TimerDiff($hQuiet) > $gc_iQueueTail And _CopyDataQueue_Close(True)
EndFunc   ;==>_Main


; Клик с Ctrl: пункт уходит в работу, окно остаётся, подпись пункта тускнеет
Func _OnPick($iRow)
	If _MenuPick(_MenuRowAction($iRow)) Then _MenuMarks()
EndFunc   ;==>_OnPick


; Метки окна у действий, отданных в работу. Живая строка помечена, пока собирает отданный размер
Func _MenuMarks()
	For $i = 0 To UBound($g_aActions) - 1
		_FluentMenu_SetMarked($i, _ListIndex($g_aPicked, $g_aActions[$i]) >= 0)
	Next
	If $g_iResizeLive >= 0 Then _FluentMenu_SetMarked($g_iResizeLive, _
			$g_sResizeAction <> '' And _ListIndex($g_aPicked, $g_sResizeAction) >= 0)
EndFunc   ;==>_MenuMarks


; Действие строки окна: у живой строки окна размеров - собранное панелью
Func _MenuRowAction($iRow)
	If $iRow = $g_iResizeLive Then Return $g_sResizeAction
	Return $g_aActions[$iRow]
EndFunc   ;==>_MenuRowAction


; Действие уходит в Moth для всех путей выделения, что уже пришли. Уже отданное не повторяется.
; Применённый размер встаёт в живую строку следующего окна. False - действия нет
Func _MenuPick($sAction)
	If $sAction = '' Then Return False
	If _ListIndex($g_aPicked, $sAction) >= 0 Then Return True
	_ListAppend($g_aPicked, $sAction)
	_MenuTakePaths()
	Local $aAction[1] = [$sAction]
	_MenuSend($g_aPaths, $aAction)
	If $g_iResizeLive >= 0 Then _ResizerApplied($sAction)
	Return True
EndFunc   ;==>_MenuPick


; Пути, которые прислали другие процессы выделения, со строкой «путь|пункт»: путь чужого
; пункта отбрасывается. Пути копятся в $g_aPaths, возвращаются новые
Func _MenuTakePaths()
	Local $aNew[0], $aSplit
	For $sLine In _CopyDataQueue_Take()
		$aSplit = StringSplit($sLine, '|')
		If $aSplit[0] < 2 Or $aSplit[2] <> $g_sPopup Then ContinueLoop
		_ListAppend($g_aPaths, $aSplit[1])
		_ListAppend($aNew, $aSplit[1])
	Next
	Return $aNew
EndFunc   ;==>_MenuTakePaths


; Каждое действие для каждого пути. Путь, который не подошёл, строки не даёт; без строк
; Moth не запускается
Func _MenuSend(Const ByRef $aPaths, Const ByRef $aActions)
	Local $sTasks = '', $sLine
	For $sPath In $aPaths
		For $sAction In $aActions
			$sLine = _MothTaskLine($sPath, $sAction)
			If $sLine <> '' Then $sTasks &= @LF & $sLine
		Next
	Next
	If $sTasks <> '' Then _MothSendTasks(StringTrimLeft($sTasks, 1))
EndFunc   ;==>_MenuSend


; Пункты окна для _FluentMenu_Show: [подпись, файл иконки, индекс, закреплён].
; Подпись как у пункта в контекстном меню: название и постфикс нового файла. У пресета
; размеров короткая: «Изменить размер» уже в заголовке пункта меню. В окне размеров
; последняя строка - живая, пункт меню из полей панели
Func _MenuItems($bResizer)
	Local $iCount = UBound($g_aActions) + ($bResizer ? 1 : 0)
	Local $iCols = $bResizer ? 5 : 4
	Local $aItems[$iCount][$iCols], $aIcon
	For $i = 0 To UBound($g_aActions) - 1
		$aItems[$i][0] = _ActionItemText($g_aActions[$i])
		$aIcon = _ActionIcon($g_aActions[$i])
		$aItems[$i][1] = $aIcon[0]
		$aItems[$i][2] = $aIcon[1]
		$aItems[$i][3] = StringInStr($g_sPinned, '|' & $g_aActions[$i] & '|') > 0
		; Пресет окна размеров можно убрать крестиком
		If $bResizer Then $aItems[$i][4] = False
	Next
	If Not $bResizer Then Return $aItems

	; Ширина окна - по длинной подписи живой строки: окно одно и то же при любом
	; последнем размере, а строка при вводе не обрезается. Образец - с режимом и алгоритмом
	; в постфиксе, название - самое длинное из «WxH», «по ширине W» и «по высоте H».
	; Свою подпись строка получит при сборке панели
	$g_iResizeLive = $iCount - 1
	Local $aLive = _ResizerLiveItem($gc_sResizeActionPrefix & 'resize_2048_1536_2_2')
	Local $iTab = StringInStr($aLive[0], @TAB), $sTitle = StringLeft($aLive[0], $iTab - 1), $sOther
	For $sCommand In StringSplit('resize_2048_0_0_2|resize_0_1536_0_2', '|', 2)
		$sOther = _ActionTitle($gc_sResizeActionPrefix & $sCommand)
		If StringLen($sOther) > StringLen($sTitle) Then $sTitle = $sOther
	Next
	$aLive[0] = $sTitle & StringMid($aLive[0], $iTab)
	For $j = 0 To 3
		$aItems[$g_iResizeLive][$j] = $aLive[$j]
	Next
	Return $aItems
EndFunc   ;==>_MenuItems


; Иконка пункта окна: [файл, индекс]. Те же, что у пунктов меню проводника
Func _ActionIcon($sAction)
	Local $aIcon[2] = ['', 0]
	Local $sIcon = _ActionRead($sAction, 'Icon')
	If $sIcon = '' Then Return $aIcon
	If FileExists(_GetIconPath() & '\' & _ThemeIconName($sIcon)) Then
		$aIcon[0] = _GetIconPath() & '\' & _ThemeIconName($sIcon)
	Else
		Local $aInfo = _ExplorerIcon_Get($sIcon)
		$aIcon[0] = $aInfo[1]
		$aIcon[1] = $aInfo[2]
	EndIf
	Return $aIcon
EndFunc   ;==>_ActionIcon


; Подпись пункта окна: название и постфикс нового файла
Func _ActionItemText($sAction)
	Return _ActionTitle($sAction) & @TAB & _ActionRead($sAction, 'FilePostfix')
EndFunc   ;==>_ActionItemText


; ============================================================
; Действия в контекстном меню
; ============================================================

; Кнопка в открытом окне: действие сразу добавляется в меню формата файла или убирается
; из него, у других форматов меню своё. Ini перечитывается с диска: его могли поправить,
; пока окно открыто
Func _OnPinToggle($iIndex, $bOn)
	If $g_iResizeLive >= 0 Then Return _ResizerPinToggle($iIndex, $bOn)
	Local $sIniPath = @ScriptDir & '\Moth.ini'
	Local $sIni = _ReadFileUTF8($sIniPath)
	Local $sAction = $g_aActions[$iIndex], $sPinned = ''
	For $sItem In StringSplit(_MothMenu_PinnedRead($sIni, $g_sPopup, $g_sFormat), '|', 2)
		If $sItem <> '' And $sItem <> $sAction Then $sPinned &= '|' & $sItem
	Next
	If $bOn Then $sPinned &= '|' & $sAction
	$sPinned = StringTrimLeft($sPinned, 1)

	_MothMenu_PinnedWrite($sIni, $g_sPopup, $g_sFormat, $sPinned)
	If Not _WriteFileUTF8($sIniPath, $sIni) Then _
			MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'SaveFailed', 'Failed to save the settings file:' & @CRLF & '%1', $sIniPath))
	_MenuPinsUpdate($sIni)
EndFunc   ;==>_OnPinToggle


; Меню проводника по свежему ini. Меню формата файла заполнено - закрепить новое
; нельзя, в меню оно бы не попало. Открепить можно всегда
Func _MenuPinsUpdate($sIni)
	_MothMenu_PinsUpdate($sIni)
	_MothRegReportErrors()
	_FluentMenu_SetPinnable(_MothMenu_PinFits($g_sFormat, $sIni))
EndFunc   ;==>_MenuPinsUpdate


; ============================================================
; Окно размеров
; ============================================================
; Пресеты - Popup пункта как есть, действия Moth.Resize.<команда>; Full HD и 2K там с самого
; начала. Стрелки меняют порядок, в нём же закреплённые стоят в меню проводника. Под списком
; живая строка - пункт меню проводника, собранный из полей панели: клик или Enter отдают
; размер в Moth, стрелка вверх добавляет его в конец списка. Булавки только у списка:
; закрепляют размер уже там. Строку заполняет последний применённый размер (Last).
; Клик с Ctrl отдаёт размер в Moth, не закрывая окна: так берут несколько. Shift тащит окно.

; Крестик сразу убирает пресет из списка и из меню (_ResizerRemove).
; Панель: поля процентов, ширины и высоты; под ними быстрый выбор процентов либо режим
; с «не увеличивать»; внизу алгоритм. Размер задают поля, которые правили последними:
; ввод в проценты очищает точки, и наоборот. Пустая сторона - по пропорции. Пустые поля
; подсказывают, сколько выйдет у первого файла выделения.

; Список окна по старому Moth.ini: закреплённые по алфавиту, как в меню проводника,
; за ними стандартные разрешения ($gc_aResizeQuickSizes, вписать), кроме убранных
; крестиком ($sHidden). Закреплённое разрешение стоит среди закреплённых
Func _ResizerOrder($aActions, $sPinned, $sHidden = '')
	Local $aList[0], $sAction
	For $sAction In $aActions
		If StringInStr($sPinned, '|' & $sAction & '|') Then _ListAppend($aList, $sAction)
	Next
	$aList = _MothMenu_SortByTitle($aList)
	For $i = 0 To UBound($gc_aResizeQuickSizes) - 1
		$sAction = $gc_sResizeActionPrefix & _ResizeCommand(0, $gc_aResizeQuickSizes[$i][0], $gc_aResizeQuickSizes[$i][1], 0, 0)
		If StringInStr($sPinned, '|' & $sAction & '|') Or StringInStr('|' & $sHidden & '|', '|' & $sAction & '|') Then ContinueLoop
		_ListAppend($aList, $sAction)
	Next
	Return $aList
EndFunc   ;==>_ResizerOrder


; Черта над живой строкой: пресеты отдельно от собираемого пункта. У пустого списка
; черта перед первой строкой не видна, первый добавленный пресет её сдвинет
Func _ResizerDividers()
	Local $aRows[1] = [UBound($g_aActions)]
	_FluentMenu_SetDividers($aRows)
EndFunc   ;==>_ResizerDividers


Func _ListAppend(ByRef $aList, $sItem)
	ReDim $aList[UBound($aList) + 1]
	$aList[UBound($aList) - 1] = $sItem
EndFunc   ;==>_ListAppend


; Список, закреплённые и последний применённый размер. Ini без Last - старого вида,
; он переводится на новый (_ResizerMigrate)
Func _ResizerLoad()
	Local $sIni = $gc_sMothIni
	If _IniString_Read($sIni, $g_sPopup, 'Last', '|') == '|' Then $sIni = _ResizerMigrate()
	$g_sPinned = '|' & _MothMenu_PinnedRead($sIni, $g_sPopup, $g_sFormat) & '|'
	$g_aActions = _ResizerListRead($sIni)
	$g_sResizeAction = _IniString_Read($sIni, $g_sPopup, 'Last')
	If _ResizeActionCommand($g_sResizeAction) = '' Then $g_sResizeAction = ''
EndFunc   ;==>_ResizerLoad


; Старый вид: первым в Popup - последний применённый размер, за ним закреплённые
; и недавние, окно показывало список _ResizerOrder. Новый: Popup - список окна, последний
; применённый - в Last, Hidden не нужен. Порядок закреплённых тот же, меню проводника
; не трогается. Возвращает новый ini
Func _ResizerMigrate()
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	If _IniString_Read($sIni, $g_sPopup, 'Last', '|') <> '|' Then Return $sIni
	Local $aOld = _ResizerListRead($sIni)
	Local $aList = _ResizerOrder($aOld, '|' & _IniString_Read($sIni, $g_sPopup, 'Pinned') & '|', _
			_IniString_Read($sIni, $g_sPopup, 'Hidden'))
	_IniString_Write($sIni, $g_sPopup, 'Popup', _ResizerJoin($aList))
	_IniString_Write($sIni, $g_sPopup, 'Last', UBound($aOld) ? $aOld[0] : '')
	_IniString_Delete($sIni, $g_sPopup, 'Hidden')
	_ResizerSave($sIni)
	Return $sIni
EndFunc   ;==>_ResizerMigrate


; Пресеты из Popup по порядку, без повторов и чужих действий
Func _ResizerListRead($sIni)
	Local $aList[0]
	For $sItem In StringSplit(_IniString_Read($sIni, $g_sPopup, 'Popup'), '|', 2)
		$sItem = StringStripWS($sItem, 3)
		If _ResizeActionCommand($sItem) = '' Or _ListIndex($aList, $sItem) >= 0 Then ContinueLoop
		_ListAppend($aList, $sItem)
	Next
	Return $aList
EndFunc   ;==>_ResizerListRead


; Индекс строки в списке, -1 - нет
Func _ListIndex(Const ByRef $aList, $sAction)
	For $i = 0 To UBound($aList) - 1
		If $aList[$i] = $sAction Then Return $i
	Next
	Return -1
EndFunc   ;==>_ListIndex


Func _ResizerJoin(Const ByRef $aList)
	Local $sList = ''
	For $sItem In $aList
		$sList &= ($sList = '' ? '' : '|') & $sItem
	Next
	Return $sList
EndFunc   ;==>_ResizerJoin


; Живая строка - пункт меню проводника из текущих полей:
; [подпись, файл иконки, индекс иконки, '' - без булавки, доступен]. Закрепляют размер
; в списке, сюда вместо булавки стрелка «добавить». Пока размера нет, строка серая
; и подсказывает, что ввести
Func _ResizerLiveItem($sAction)
	Local $aItem[5] = [_LangFile_Get('Resizer', 'LiveEmpty', 'Enter a size to build a menu item'), _
			_GetIconPath() & '\' & _ResizeModeIcon(0), 0, '', False]
	If $sAction = '' Then Return $aItem
	Local $aIcon = _ActionIcon($sAction)
	$aItem[0] = _ActionItemText($sAction)
	$aItem[1] = $aIcon[0]
	$aItem[2] = $aIcon[1]
	$aItem[4] = True
	Return $aItem
EndFunc   ;==>_ResizerLiveItem


; Размер первого файла читает magick identify, окно его не ждёт
Func _ResizerSourceStart($sPath)
	If _IsDir($sPath) Then Return
	$g_iSrcPid = Run('"' & @ScriptDir & '\Apps\magick.exe" identify -ping -quiet -format "%w %h %[orientation]" "' & $sPath & '[0]"', _
			'', @SW_HIDE, $STDOUT_CHILD)
	If Not $g_iSrcPid Then Return
	$g_hSrcTimer = TimerInit()
	AdlibRegister('_ResizerSourcePoll', 50)
EndFunc   ;==>_ResizerSourceStart


; Ответ identify: ширина, высота и поворот по Exif. Moth поворачивает картинку до
; ресайза, поэтому у повёрнутой на 90° стороны меняются местами. Открытая панель
; сразу пересчитывает подсказки и живую строку
Func _ResizerSourcePoll()
	$g_sSrcOut &= StdoutRead($g_iSrcPid)
	If Not @error Then
		If TimerDiff($g_hSrcTimer) < 5000 Then Return
		ProcessClose($g_iSrcPid)
	EndIf
	AdlibUnRegister('_ResizerSourcePoll')
	Local $aMatch = StringRegExp($g_sSrcOut, '^\s*(\d+) (\d+) ?(\w*)', 1)
	If @error Or Int($aMatch[0]) = 0 Or Int($aMatch[1]) = 0 Then Return
	; Поворот 5-8: LeftTop, RightTop, RightBottom, LeftBottom
	Local $bTurn = StringLeft($aMatch[2], 4) = 'Left' Or StringLeft($aMatch[2], 5) = 'Right'
	$g_iSrcW = Int($aMatch[$bTurn ? 1 : 0])
	$g_iSrcH = Int($aMatch[$bTurn ? 0 : 1])
	If Not $g_bResizePanel Then Return
	_ResizerLiveUpdate()
EndFunc   ;==>_ResizerSourcePoll


; Панель в окне меню, ($iX, $iY) - её угол. Поля, режим и алгоритм - от последнего пресета
Func _ResizerPanelCreate($hGui, $iX, $iY, $iW)
	$g_hResizeGui = $hGui
	Local Const $iPad = 8, $iGap = 6, $iRowH = 28
	Local $sLast = _ResizeActionCommand($g_sResizeAction)
	Local $aLast = _ResizeParse($sLast)
	; Три строки: поля; быстрый выбор процентов или режим - смотря чем задан размер; алгоритм.
	; Высота окна при смене второй строки та же
	Local $aRowY[3] = [$iY + $iPad, 0, 0]
	$aRowY[1] = $aRowY[0] + $iRowH + $iGap
	$aRowY[2] = $aRowY[1] + $iRowH + $iGap

	; Быстрый выбор процентов ставит значение в поле. Подсвечен вариант, совпавший с полем
	Local $sTexts = ''
	For $iPercent In $gc_aResizeQuickPercents
		$sTexts &= '|' & $iPercent & '%'
	Next
	$g_iResizePercent = _FluentSegment_Create(StringTrimLeft($sTexts, 1), '', $iX, $aRowY[1], $iRowH, -1, '_OnEvent_ResizeQuick')

	; Режим со своими иконками, алгоритм - со сборными: как у пункта в проводнике
	Local $iLastGroup = _ResizeFilterGroup($aLast[4])
	$sTexts = ''
	Local $sTips = ''
	For $iMode = 0 To 2
		$sTexts &= '|' & _ResizeModeName($iMode)
	Next
	$g_iResizeMode = _FluentSegment_Create(StringTrimLeft($sTexts, 1), _ResizerSegIcons(0, False), $iX, $aRowY[1], _
			$iRowH, $aLast[3], '_ResizerLiveUpdate')
	_FluentSegment_SetTips($g_iResizeMode, _LangFile_Get('Resizer', 'ModeFitTip', 'The whole picture fits into the size') & '|' & _
			_LangFile_Get('Resizer', 'ModeFillTip', 'The picture covers the size, the extra stays') & '|' & _
			_LangFile_Get('Resizer', 'ModeCropTip', 'The picture covers the size, the extra is cut off'))

	$sTexts = ''
	For $iGroup = 0 To UBound($gc_aResizeFilterGroups) - 1
		$sTexts &= '|' & _ResizeFilterGroupName($iGroup)
		$sTips &= '|' & _GetFilterNameByIndx($gc_aResizeFilterGroups[$iGroup])
	Next
	$g_iResizeFilter = _FluentSegment_Create(StringTrimLeft($sTexts, 1), _ResizerSegIcons($aLast[3], True), $iX, $aRowY[2], _
			$iRowH, $iLastGroup, '_ResizerLiveUpdate')
	_FluentSegment_SetTips($g_iResizeFilter, StringTrimLeft($sTips, 1))

	; Панель не уже сегментов: быстрый выбор и алгоритм во всю панель, режим - до кнопки
	; «не увеличивать» в конце своей строки
	$iW = _Max($iW, _FluentSegment_Width($g_iResizeMode) + $iGap + $iRowH)
	$iW = _Max($iW, _FluentSegment_Width($g_iResizePercent))
	$iW = _Max($iW, _FluentSegment_Width($g_iResizeFilter))
	_FluentSegment_SetWidth($g_iResizePercent, $iW)
	_FluentSegment_SetWidth($g_iResizeMode, $iW - $iGap - $iRowH)
	_FluentSegment_SetWidth($g_iResizeFilter, $iW)

	; «Не увеличивать» выключено, включено - только если последний размер в точках не увеличивал картинку
	$g_bResizeNoEnlarge = ($aLast[1] Or $aLast[2]) And Not $aLast[5]
	$g_iResizeNoEnlarge = _FluentButton_Create('', 'NoEnlarge', 16, $iX + $iW - $iRowH, $aRowY[1], _
			$iRowH, $iRowH, $FLUENTBUTTON_ICON)
	GUICtrlSetTip($g_iResizeNoEnlarge, _LangFile_Get('Resizer', 'NoEnlarge', 'Do not enlarge'))
	GUICtrlSetOnEvent($g_iResizeNoEnlarge, '_OnEvent_ResizeNoEnlarge')

	; Поля на три равные части: проценты, ширина, высота. Слева знак или иконка поля, число
	; прижато вправо, название поля - в подсказке
	Local $iThirdW = Int(($iW - $iGap * 2) / 3), $iStyle = BitOR($ES_NUMBER, $ES_RIGHT)
	$g_iResizePct = _FluentInput_Create($iX, $aRowY[0], $iThirdW, $iRowH, '%', '', $iStyle)
	$g_iResizeW = _FluentInput_Create($iX + $iThirdW + $iGap, $aRowY[0], $iThirdW, $iRowH, 'FieldWidth.png', '', $iStyle)
	$g_iResizeH = _FluentInput_Create($iX + $iW - $iThirdW, $aRowY[0], $iThirdW, $iRowH, 'FieldHeight.png', '', $iStyle)
	Local $aFields[3][2] = [[$g_iResizePct, _LangFile_Get('Resizer', 'FieldPercent', 'Percent')], _
			[$g_iResizeW, _LangFile_Get('Resizer', 'FieldWidth', 'Width')], [$g_iResizeH, _LangFile_Get('Resizer', 'FieldHeight', 'Height')]]
	For $i = 0 To 2
		GUICtrlSetTip($aFields[$i][0], $aFields[$i][1])
		GUICtrlSetTip(_FluentInput_Frame($aFields[$i][0]), $aFields[$i][1])
	Next
	GUICtrlSetLimit($g_iResizeW, 5)
	GUICtrlSetLimit($g_iResizeH, 5)
	GUICtrlSetLimit($g_iResizePct, 4)

	; Без последнего размера окно начинается с 50%
	$g_bResizeByPct = $aLast[0] Or $sLast = ''
	If $aLast[0] Then
		_ResizerSetFields(Default, Default, $aLast[0])
	ElseIf $sLast <> '' Then
		_ResizerSetFields($aLast[1] ? $aLast[1] : '', $aLast[2] ? $aLast[2] : '', Default)
	Else
		_ResizerSetFields(Default, Default, 50)
	EndIf

	_FluentMsg_Register($WM_COMMAND, '_OnEvent_ResizeInput')
	$g_bResizePanel = True
	_ResizerShowRow()
	_ResizerLiveUpdate()

	; Фокус в поле, которым задан размер, текст выделен: новый набирается поверх
	Local $iFocus = $g_bResizeByPct ? $g_iResizePct : $g_iResizeW
	GUICtrlSetState($iFocus, $GUI_FOCUS)
	GUICtrlSendMsg($iFocus, $EM_SETSEL, 0, -1)
	Local $aPanel[3] = [$iW, $aRowY[2] + $iRowH + $iPad - $iY, $iFocus]
	Return $aPanel
EndFunc   ;==>_ResizerPanelCreate


Func _ResizerPanelClose()
	$g_bResizePanel = False
	_FluentMsg_Unregister($WM_COMMAND, '_OnEvent_ResizeInput')
	_FluentButton_Delete($g_iResizeNoEnlarge)
	_FluentInput_Delete($g_iResizeW)
	_FluentInput_Delete($g_iResizeH)
	_FluentInput_Delete($g_iResizePct)
	_FluentSegment_Delete($g_iResizePercent)
	_FluentSegment_Delete($g_iResizeMode)
	_FluentSegment_Delete($g_iResizeFilter)
EndFunc   ;==>_ResizerPanelClose


; Пресет добавили или убрали, панель в окне сдвинулась на $iDY: контролы едут за ней
Func _ResizerPanelShift($iDY)
	Local $aSegments[3] = [$g_iResizePercent, $g_iResizeMode, $g_iResizeFilter], $aPos
	For $iCtrl In $aSegments
		$aPos = ControlGetPos($g_hResizeGui, '', $iCtrl)
		If IsArray($aPos) Then _FluentSegment_SetPos($iCtrl, $aPos[0], $aPos[1] + $iDY)
	Next
	Local $aInputs[3] = [$g_iResizeW, $g_iResizeH, $g_iResizePct]
	For $iCtrl In $aInputs
		$aPos = ControlGetPos($g_hResizeGui, '', _FluentInput_Frame($iCtrl))
		If IsArray($aPos) Then _FluentInput_SetPos($iCtrl, $aPos[0], $aPos[1] + $iDY)
	Next
	$aPos = ControlGetPos($g_hResizeGui, '', $g_iResizeNoEnlarge)
	If IsArray($aPos) Then _FluentButton_SetPos($g_iResizeNoEnlarge, $aPos[0], $aPos[1] + $iDY)
EndFunc   ;==>_ResizerPanelShift


; Вторая строка - смотря чем задан размер: у процентов быстрый выбор, у точек режим
; и «не увеличивать»
Func _ResizerShowRow()
	Local $aSize[2] = [$g_iResizeMode, $g_iResizeNoEnlarge]
	For $iCtrl In $aSize
		GUICtrlSetState($iCtrl, $g_bResizeByPct ? $GUI_HIDE : $GUI_SHOW)
	Next
	GUICtrlSetState($g_iResizePercent, $g_bResizeByPct ? $GUI_SHOW : $GUI_HIDE)
EndFunc   ;==>_ResizerShowRow


; Размер задали процентами или точками: поля другого вида очищаются и подсказывают
; серым, вторая строка меняется
Func _ResizerSetByPct($bByPct)
	If $bByPct Then
		_ResizerSetFields('', '', Default)
	Else
		_ResizerSetFields(Default, Default, '')
	EndIf
	If $bByPct = $g_bResizeByPct Then Return
	$g_bResizeByPct = $bByPct
	_ResizerShowRow()
EndFunc   ;==>_ResizerSetByPct


; Enter в окне - как клик по живой строке
Func _ResizerPanelApply()
	If $g_sResizeAction <> '' Then _FluentMenu_End($g_iResizeLive)
EndFunc   ;==>_ResizerPanelApply


; Фокус в поле переключает размер на его вид сразу, как вкладка. Правка поля очищает
; поля другого вида, живая строка пересобирается. Стёртое поле ничего не очищает:
; его стирают, чтобы набрать заново
Func _OnEvent_ResizeInput($hWnd, $iMsg, $wParam, $lParam)
	#forceref $hWnd, $iMsg, $lParam
	Local $iCtrl = BitAND($wParam, 0xFFFF)
	If $iCtrl <> $g_iResizePct And $iCtrl <> $g_iResizeW And $iCtrl <> $g_iResizeH Then Return $GUI_RUNDEFMSG
	Switch BitAND(BitShift($wParam, 16), 0xFFFF)
		Case $EN_SETFOCUS
			_ResizerFocusMode($iCtrl = $g_iResizePct)
		Case $EN_CHANGE
			If $g_bResizeSync Then Return $GUI_RUNDEFMSG
			If GUICtrlRead($iCtrl) <> '' Then _ResizerSetByPct($iCtrl = $g_iResizePct)
			_ResizerLiveUpdate()
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_OnEvent_ResizeInput


; Фокус ушёл в поле другого вида: размер теперь с него, вторая строка меняется. Пустые поля
; этого вида получают то, что подсказывали серым, - живая строка показывает тот же размер.
; Без подсказки (размер файла не прочитан) проценты начинаются с 50
Func _ResizerFocusMode($bByPct)
	If $bByPct = $g_bResizeByPct Then Return
	$g_bResizeByPct = $bByPct
	If $bByPct Then
		If GUICtrlRead($g_iResizePct) = '' Then _ResizerSetFields(Default, Default, _ResizerCueValue($g_iResizePct, 50))
	ElseIf GUICtrlRead($g_iResizeW) = '' And GUICtrlRead($g_iResizeH) = '' Then
		_ResizerSetFields(_ResizerCueValue($g_iResizeW), _ResizerCueValue($g_iResizeH), Default)
	EndIf
	_ResizerShowRow()
	_ResizerLiveUpdate()
EndFunc   ;==>_ResizerFocusMode


; Число из серой подсказки поля: «≈48» даёт 48, «авто» - $vDefault
Func _ResizerCueValue($iCtrl, $vDefault = '')
	If Not MapExists($g_mResizeCues, $iCtrl) Then Return $vDefault
	Local $sDigits = StringRegExpReplace($g_mResizeCues[$iCtrl], '\D', '')
	Return $sDigits = '' ? $vDefault : Int($sDigits)
EndFunc   ;==>_ResizerCueValue


; Поля панели меняет сама панель: их правка не обрабатывается. Default - поле не трогать
Func _ResizerSetFields($vWidth, $vHeight, $vPercent)
	$g_bResizeSync = True
	Local $aFields[3][2] = [[$g_iResizeW, $vWidth], [$g_iResizeH, $vHeight], [$g_iResizePct, $vPercent]]
	For $i = 0 To 2
		If Not IsKeyword($aFields[$i][1]) And GUICtrlRead($aFields[$i][0]) <> String($aFields[$i][1]) Then _
				GUICtrlSetData($aFields[$i][0], $aFields[$i][1])
	Next
	$g_bResizeSync = False
EndFunc   ;==>_ResizerSetFields


; «Не увеличивать» включается и выключается
Func _OnEvent_ResizeNoEnlarge()
	$g_bResizeNoEnlarge = Not $g_bResizeNoEnlarge
	_ResizerLiveUpdate()
EndFunc   ;==>_OnEvent_ResizeNoEnlarge


; Быстрый выбор: проценты встают в поле
Func _OnEvent_ResizeQuick($iCtrl)
	Local $iSel = _FluentSegment_GetSel($iCtrl)
	If $iSel < 0 Then Return
	_ResizerSetFields(Default, Default, $gc_aResizeQuickPercents[$iSel])
	_ResizerLiveUpdate()
EndFunc   ;==>_OnEvent_ResizeQuick


; Размер из полей, которыми он задан: [проценты, ширина, высота]. @error - размера нет
; или он за пределами
Func _ResizerFields()
	Local $aSize[3] = [0, 0, 0]
	If $g_bResizeByPct Then
		$aSize[0] = Int(GUICtrlRead($g_iResizePct))
		If $aSize[0] = 0 Or $aSize[0] > $gc_iResizePercentMax Then Return SetError(1, 0, $aSize)
		Return $aSize
	EndIf
	$aSize[1] = Int(GUICtrlRead($g_iResizeW))
	$aSize[2] = Int(GUICtrlRead($g_iResizeH))
	If $aSize[1] = 0 And $aSize[2] = 0 Then Return SetError(1, 0, $aSize)
	If $aSize[1] > $gc_iResizeSideMax Or $aSize[2] > $gc_iResizeSideMax Then Return SetError(1, 0, $aSize)
	Return $aSize
EndFunc   ;==>_ResizerFields


; Поля панели изменились: пустые поля подсказывают свои значения, быстрый выбор
; подсвечивает совпавший процент, живая строка пересобирается. Пустое или неверное
; поле строку не трогает: она держит прежний размер. Повторяет она пресет из списка -
; стрелка «добавить» недоступна. $iCtrl - от обработчика сегмента
Func _ResizerLiveUpdate($iCtrl = 0)
	#forceref $iCtrl
	Local $aSize = _ResizerFields()
	Local $bValid = Not @error
	Local $iMode = _FluentSegment_GetSel($g_iResizeMode), $iGroup = _FluentSegment_GetSel($g_iResizeFilter)
	; У процентов режима нет: алгоритм в иконке - при вписывании
	_FluentSegment_SetIcons($g_iResizeFilter, _ResizerSegIcons($aSize[0] ? 0 : $iMode, True))
	_FluentButton_SetOn($g_iResizeNoEnlarge, $g_bResizeNoEnlarge)
	If $bValid Then $g_sResizeAction = $gc_sResizeActionPrefix & _ResizeCommand($aSize[0], $aSize[1], $aSize[2], $iMode, _
			$gc_aResizeFilterGroups[$iGroup], Not $g_bResizeNoEnlarge)

	Local $nPercent = _ResizerCues(), $iPercent = -1
	For $i = 0 To UBound($gc_aResizeQuickPercents) - 1
		If $nPercent = $gc_aResizeQuickPercents[$i] Then $iPercent = $i
	Next
	_FluentSegment_SetSel($g_iResizePercent, $iPercent)

	Local $iSame = -1
	For $i = 0 To UBound($g_aActions) - 1
		If $g_sResizeAction <> '' And $g_aActions[$i] = $g_sResizeAction Then $iSame = $i
	Next
	_FluentMenu_SetAddable($g_sResizeAction <> '' And $iSame < 0)

	Local $aLive = _ResizerLiveItem($g_sResizeAction)
	_FluentMenu_SetItem($g_iResizeLive, $aLive[0], $aLive[1], $aLive[2], $aLive[3], $aLive[4])
	_MenuMarks()
EndFunc   ;==>_ResizerLiveUpdate


; Иконки сегментов: у режимов - свои, без значка алгоритма; у алгоритмов - сборные,
; как у пункта в проводнике, с выбранным режимом $iMode
Func _ResizerSegIcons($iMode, $bFilter)
	Local $sIcons = ''
	For $i = 0 To 2
		$sIcons &= '|' & _GetIconPath() & '\' & ($bFilter ? _ResizeModeIcon($iMode, $i) : _ResizeModeIcon($i))
	Next
	Return StringTrimLeft($sIcons, 1)
EndFunc   ;==>_ResizerSegIcons


; Поля зависят друг от друга: пустое подсказывает серым, сколько выйдет у первого
; файла выделения. Сторона даёт другую сторону и проценты, обе стороны - проценты,
; если пропорция как у картинки; проценты дают пустые ширину и высоту. Подсказка
; не значение: у файлов другого размера выйдет другое. Возвращает проценты:
; введённые или посчитанные, 0 - не посчитать
Func _ResizerCues()
	Local $iPct = Int(GUICtrlRead($g_iResizePct)), $iW = Int(GUICtrlRead($g_iResizeW)), $iH = Int(GUICtrlRead($g_iResizeH))
	Local $sAuto = _LangFile_Get('Resizer', 'Auto', 'auto')
	Local $vW = $sAuto, $vH = $sAuto, $nPct = 0
	If $g_iSrcW > 0 Then
		If $iW And Not $iH Then
			$vH = Round($g_iSrcH * $iW / $g_iSrcW)
			$nPct = $iW / $g_iSrcW * 100
		ElseIf $iH And Not $iW Then
			$vW = Round($g_iSrcW * $iH / $g_iSrcH)
			$nPct = $iH / $g_iSrcH * 100
		ElseIf $iW And $iH Then
			If Round($g_iSrcH * $iW / $g_iSrcW) = $iH Or Round($g_iSrcW * $iH / $g_iSrcH) = $iW Then $nPct = $iW / $g_iSrcW * 100
		ElseIf $iPct Then
			$vW = Round($g_iSrcW * $iPct / 100)
			$vH = Round($g_iSrcH * $iPct / 100)
		EndIf
	EndIf
	; Дробные проценты - округлённые, со знаком U+2248 «примерно»
	Local $sPct = ''
	If $nPct And Not $iPct Then $sPct = Abs($nPct - Round($nPct)) < 0.05 ? Round($nPct) : ChrW(0x2248) & Round($nPct)
	_ResizerCue($g_iResizeW, $vW)
	_ResizerCue($g_iResizeH, $vH)
	_ResizerCue($g_iResizePct, $sPct)
	Return $iPct ? $iPct : $nPct
EndFunc   ;==>_ResizerCues


; Серая подсказка в пустом поле, видна и с кареткой. Текст уходит в UTF-16 как есть:
; _GUICtrlEdit_SetCueBanner гонит его через ANSI, и «≈» становится «?»
Func _ResizerCue($iCtrl, $vText)
	If MapExists($g_mResizeCues, $iCtrl) And $g_mResizeCues[$iCtrl] == String($vText) Then Return
	$g_mResizeCues[$iCtrl] = String($vText)
	Local $tText = DllStructCreate('wchar[' & StringLen($vText) + 1 & ']')
	DllStructSetData($tText, 1, $vText)
	_SendMessage(GUICtrlGetHandle($iCtrl), $EM_SETCUEBANNER, True, $tText, 0, 'wparam', 'struct*')
EndFunc   ;==>_ResizerCue


; Булавка пресета: булавки есть только у списка, у живой строки - стрелка «добавить»
Func _ResizerPinToggle($iIndex, $bOn)
	_ResizerPin($g_aActions[$iIndex], $bOn)
EndFunc   ;==>_ResizerPinToggle


; Закрепляет размер в меню проводника формата файла или открепляет. Ini перечитывается
; с диска: пока окно было открыто, булавки могли поменяться
Func _ResizerPin($sAction, $bOn)
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	Local $sPinned = _ResizerListRemove(_MothMenu_PinnedRead($sIni, $g_sPopup, $g_sFormat), '|' & $sAction & '|')
	If $bOn Then $sPinned &= ($sPinned = '' ? '' : '|') & $sAction
	$g_sPinned = '|' & $sPinned & '|'
	_MothMenu_PinnedWrite($sIni, $g_sPopup, $g_sFormat, $sPinned)
	_ResizerSave($sIni, True)
EndFunc   ;==>_ResizerPin


; Применённый размер запоминается для живой строки, список не меняется
Func _ResizerApplied($sAction)
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	_IniString_Write($sIni, $g_sPopup, 'Last', $sAction)
	_ResizerSave($sIni)
EndFunc   ;==>_ResizerApplied


; Стрелка передвинула пресет, окно уже показывает новый порядок. Меню проводника
; перекладывается: в каком-то формате оба могут быть закреплены
Func _ResizerMove($iFrom, $iTo)
	Local $sAction = $g_aActions[$iFrom]
	$g_aActions[$iFrom] = $g_aActions[$iTo]
	$g_aActions[$iTo] = $sAction
	_ResizerListSave(True)
EndFunc   ;==>_ResizerMove


; Размер живой строки встаёт в конец списка, если его там нет. $iRow - от стрелки окна
Func _ResizerAdd($iRow = Default)
	#forceref $iRow
	If $g_sResizeAction = '' Or _ListIndex($g_aActions, $g_sResizeAction) >= 0 Then Return
	_ListAppend($g_aActions, $g_sResizeAction)
	Local $aIcon = _ActionIcon($g_sResizeAction)
	_FluentMenu_InsertItem($g_iResizeLive, _ActionItemText($g_sResizeAction), $aIcon[0], $aIcon[1], _
			StringInStr($g_sPinned, '|' & $g_sResizeAction & '|') > 0, False)
	$g_iResizeLive += 1
	_ResizerListSave()
	_ResizerLiveUpdate()
EndFunc   ;==>_ResizerAdd


; Список окна в Popup. Ini перечитывается с диска. $bPins - порядок закреплённых
; поменялся, меню проводника перекладывается
Func _ResizerListSave($bPins = False)
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	_IniString_Write($sIni, $g_sPopup, 'Popup', _ResizerJoin($g_aActions))
	_ResizerSave($sIni, $bPins)
EndFunc   ;==>_ResizerListSave


; Крестик убрал пресет из окна: он уходит из Popup и закреплённых всех форматов. Ini
; перечитывается с диска. Живая строка могла повторять его - теперь его можно добавить снова
Func _ResizerRemove($iRow)
	Local $sAction = $g_aActions[$iRow]
	For $i = $iRow To UBound($g_aActions) - 2
		$g_aActions[$i] = $g_aActions[$i + 1]
	Next
	ReDim $g_aActions[UBound($g_aActions) - 1]
	$g_iResizeLive -= 1

	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini'), $sOld, $sPinned, $bPins = False
	For $sGroup In _MothMenu_PinGroups()
		$sOld = _MothMenu_PinnedRead($sIni, $g_sPopup, $sGroup)
		$sPinned = _ResizerListRemove($sOld, '|' & $sAction & '|')
		If $sPinned == $sOld Then ContinueLoop
		_MothMenu_PinnedWrite($sIni, $g_sPopup, $sGroup, $sPinned)
		$bPins = True
	Next
	$g_sPinned = '|' & _MothMenu_PinnedRead($sIni, $g_sPopup, $g_sFormat) & '|'
	_IniString_Write($sIni, $g_sPopup, 'Popup', _ResizerJoin($g_aActions))
	_ResizerSave($sIni, $bPins)
	_ResizerLiveUpdate()
EndFunc   ;==>_ResizerRemove



; Список через «|» без пунктов из $sRemove (тоже через «|», с «|» по краям)
Func _ResizerListRemove($sList, $sRemove)
	Local $sResult = ''
	For $sItem In StringSplit($sList, '|', 2)
		$sItem = StringStripWS($sItem, 3)
		If $sItem = '' Or StringInStr($sRemove, '|' & $sItem & '|') Then ContinueLoop
		$sResult &= ($sResult = '' ? '' : '|') & $sItem
	Next
	Return $sResult
EndFunc   ;==>_ResizerListRemove



; Ini на диск. $bPins - закреплённые изменились, меню проводника перекладывается
; по свежему ini: новых пресетов в загруженном при старте нет
Func _ResizerSave($sIni, $bPins = False)
	Local $sIniPath = @ScriptDir & '\Moth.ini'
	If Not _WriteFileUTF8($sIniPath, $sIni) Then
		MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'SaveFailed', 'Failed to save the settings file:' & @CRLF & '%1', $sIniPath))
		Return
	EndIf
	If Not $bPins Then Return
	_MenuPinsUpdate($sIni)
EndFunc   ;==>_ResizerSave
