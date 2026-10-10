#include-once
#include <Misc.au3>

#include "MothCommon.au3"
#include "..\Include\ExplorerIcon.au3"

; ============================================================================
;  MothExplorerMenu.au3
;  Пункты контекстного меню проводника в CommandStore. Общее для Launcher
;  (собирает меню) и Menu (окно выбора обновляет пункт последнего действия).
; ============================================================================


; Пункт меню в CommandStore: подпись «название<Tab>постфикс», команда и иконка.
; $sKey - имя ключа (с Sep, внутри группы или слот), $sActionName - действие из Moth.ini
Func _MothMenu_WriteActionKey($sKey, $sActionName, $sTitle)
	_MothRegWrite($gc_sRegKey & $sKey, '', 'REG_SZ', $sTitle & '	' & _ActionRead($sActionName, 'FilePostfix'))

	If _MothMenu_IsPopup($sActionName) Then
		; Окно выбора: Menu.exe сам соберёт пути всех выделенных файлов
		_MothRegWrite($gc_sRegKey & $sKey & '\command', '', 'REG_SZ', '"' & @ScriptDir & '\Menu.exe" "%1" ' & $sActionName)
	Else
		_MothRegWrite($gc_sRegKey & $sKey & '\command', '', 'REG_SZ', '"' & @ScriptDir & '\Launcher.exe" "%1" ' & $sActionName)
	EndIf
	_MothMenu_WriteActionIcon($sKey, $sActionName)
EndFunc   ;==>_MothMenu_WriteActionKey


; Иконка пункта: файл из темы иконок, иначе иконка из exe/dll по описанию в Icon
Func _MothMenu_WriteActionIcon($sKey, $sActionName)
	Local $sActionIcon = _ActionRead($sActionName, 'Icon')
	If $sActionIcon = '' Then Return
	Local $sActionIconPath = _GetIconPath() & '\' & $sActionIcon
	If FileExists($sActionIconPath) Then
		_MothRegWrite($gc_sRegKey & $sKey, 'Icon', 'REG_SZ', $sActionIconPath)
	Else
		Local $aIconInfo = _ExplorerIcon_Get($sActionIcon)
		_MothRegWrite($gc_sRegKey & $sKey, 'Icon', 'REG_SZ', $aIconInfo[1] & ',' & $aIconInfo[2])
	EndIf
EndFunc   ;==>_MothMenu_WriteActionIcon


; Иконки пунктов догоняют режим приложений Windows: в реестре они записаны путями
; одной из тем, и после смены режима путь меняется на другую тему. Launcher и Menu
; зовут это при каждом запуске, обход CommandStore – пара миллисекунд
Func _MothMenu_SyncIconTheme()
	Local $i = 0, $sKey, $sIcon, $sNew, $bLocked = False
	While True
		$i += 1
		$sKey = RegEnumKey($gc_sRegKey, $i)
		If @error Then ExitLoop
		If StringLeft($sKey, 5) <> 'Moth.' Then ContinueLoop
		$sIcon = RegRead($gc_sRegKey & $sKey, 'Icon')
		; Иконка темы - файл в Themes\<тема>\, иконки из системы не трогаются
		If Not StringRegExp($sIcon, '(?i)\\themes\\(dark|light)\\[^\\]+$') Then ContinueLoop
		$sNew = _GetIconPath() & '\' & StringRegExpReplace($sIcon, '^.*\\', '')
		If $sNew == $sIcon Then ContinueLoop
		; Процессы выделения стартуют разом: переписывает один, мьютекс живёт до его выхода
		If Not $bLocked Then
			If _Singleton('Moth.IconSync', 1) = 0 Then Return
			$bLocked = True
		EndIf
		_MothRegWrite($gc_sRegKey & $sKey, 'Icon', 'REG_SZ', $sNew)
	WEnd
EndFunc   ;==>_MothMenu_SyncIconTheme


; ============================================================
; Окна выбора (Popup)
; ============================================================
; Пункт с Popup открывает окно со списком действий (Menu.exe). Списки встроенных окон
; задаёт код ($gc_aActionsBuiltin), своих - Moth.ini. Действия, отмеченные
; в окне, стоят в меню перед этим пунктом, своим блоком, по алфавиту. Отметки свои
; у каждой группы форматов (Pinned.PNG=), общий Pinned= - для групп без своего ключа.
; Это ключи <Popup>.Pin<N>.<формат>, свои у каждого формата. В SubCommands формата
; стоят только существующие: на ссылке на ключ, которого нет, проводник обрывает
; весь список. Поэтому отметка в окне переписывает ключи Pin и их места в SubCommands,
; остальное меню не трогается.
; Во вложенном меню проводник показывает не больше $gc_iMothMenuItemsMax пунктов, лишние
; молча отбрасывает с конца. Пункты меню и окон остаются всегда, отмеченные встают
; на свободные места сверху вниз: не влезли - их нет в меню, а окно не даёт отметить ещё.
; Окно размеров (Command=resizer) устроено так же: Popup - его пресеты Moth.Resize.<команда>,
; список пополняет само окно. Пустой список окно не прячет: в нём можно задать свой размер.

Global Const $gc_iMothMenuItemsMax = 16


; Пункт открывает окно Menu.exe: список действий или окно размеров
Func _MothMenu_IsPopup($sAction)
	Return _ActionRead($sAction, 'Popup') <> '' Or _MothMenu_IsResizer($sAction)
EndFunc   ;==>_MothMenu_IsPopup


Func _MothMenu_IsResizer($sAction)
	Return _ActionRead($sAction, 'Command') = 'resizer'
EndFunc   ;==>_MothMenu_IsResizer


; Список окна 'A|B'. У окна размеров это пресеты в Moth.ini, их пополняет само окно:
; читаются из $sIni. Остальные списки - _ActionRead
Func _MothMenu_PopupList($sPopup, $sIni = Default)
	If Not _MothMenu_IsResizer($sPopup) Then Return _ActionRead($sPopup, 'Popup')
	If IsKeyword($sIni) Then $sIni = $gc_sMothIni
	Return _IniString_Read($sIni, $sPopup, 'Popup')
EndFunc   ;==>_MothMenu_PopupList


; Пункт нужен в меню группы форматов: окно выбора - если в нём есть действие для формата,
; остальное - если формат его умеет по таблице команд. Окно размеров и без пресетов нужно:
; в нём задают свой размер. Папку каждый файл проверит сам Moth
Func _MothMenu_ActionFits($sAction, $sExtensions)
	If _MothMenu_IsPopup($sAction) And Not _MothMenu_IsResizer($sAction) Then _
			Return UBound(_MothMenu_PopupActions($sAction, $sExtensions)) > 0
	If $sExtensions = 'folder' Then Return True
	Return _IsFormatSupported(StringRegExpReplace($sExtensions, '\..*', ''), $sAction)
EndFunc   ;==>_MothMenu_ActionFits


; Действия окна, которые умеет формат. $sExtensions - группа форматов
; ('jpg.jpe.jpeg'), расширение файла или 'folder': папку каждый файл проверит сам Moth.
; $sIni - содержимое Moth.ini, если список в нём новее загруженного при старте
Func _MothMenu_PopupActions($sPopup, $sExtensions, $sIni = Default)
	Local $aExt = StringSplit($sExtensions, '.', 2), $aActions[0], $sAction
	For $sItem In StringSplit(_MothMenu_PopupList($sPopup, $sIni), '|', 2)
		$sAction = StringStripWS($sItem, 3)
		If StringLeft($sAction, 5) <> 'Moth.' Then ContinueLoop
		If $sExtensions <> 'folder' And Not _IsFormatSupported($aExt[0], $sAction) Then ContinueLoop
		ReDim $aActions[UBound($aActions) + 1]
		$aActions[UBound($aActions) - 1] = $sAction
	Next
	Return $aActions
EndFunc   ;==>_MothMenu_PopupActions


; Ключ N-го отмеченного действия. Свой у каждой группы форматов:
; отмеченные действия умеют не все форматы
Func _MothMenu_PopupPinKey($sPopup, $iN, $sExtensions)
	Return $sPopup & '.Pin' & $iN & '.' & StringReplace($sExtensions, '.', '_')
EndFunc   ;==>_MothMenu_PopupPinKey


; Отмеченные действия окна в меню группы форматов, 'A|B'. Ключ группы - как имя
; её секции Action: Pinned.PNG, Pinned.JPG.JPE.JPEG, Pinned.Folder. Нет ключа - общий Pinned:
; так эталон задаёт отметки по умолчанию. Без общего нет ключа - нет и отметок
Func _MothMenu_PinnedRead($sIni, $sPopup, $sExtensions)
	Local $sPinned = _IniString_Read($sIni, $sPopup, __MothMenu_PinnedKey($sExtensions), '|')
	If $sPinned == '|' Then $sPinned = _IniString_Read($sIni, $sPopup, 'Pinned')
	Return $sPinned
EndFunc   ;==>_MothMenu_PinnedRead


; Пишет отмеченные действия окна для группы форматов. Общий Pinned сначала расходится
; по ключам групп, у которых своего нет, и удаляется: правка в одном формате не трогает
; остальные. Группа получает, что умеет, если окно стоит в её меню. Пустой список - без ключа
Func _MothMenu_PinnedWrite(ByRef $sIni, $sPopup, $sExtensions, $sPinned)
	Local $sCommon = _IniString_Read($sIni, $sPopup, 'Pinned', '|'), $sKey, $sOwn
	If Not ($sCommon == '|') Then
		For $sGroup In _MothMenu_PinGroups()
			$sKey = __MothMenu_PinnedKey($sGroup)
			If Not (_IniString_Read($sIni, $sPopup, $sKey, '|') == '|') Then ContinueLoop
			If Not __MothMenu_InFormatMenu($sPopup, $sGroup) Then ContinueLoop
			$sOwn = ''
			For $sAction In _MothMenu_PopupActions($sPopup, $sGroup, $sIni)
				If StringInStr('|' & $sCommon & '|', '|' & $sAction & '|') Then $sOwn &= '|' & $sAction
			Next
			If $sOwn <> '' Then _IniString_Write($sIni, $sPopup, $sKey, StringTrimLeft($sOwn, 1))
		Next
		_IniString_Delete($sIni, $sPopup, 'Pinned')
	EndIf
	If $sPinned = '' Then
		_IniString_Delete($sIni, $sPopup, __MothMenu_PinnedKey($sExtensions))
	Else
		_IniString_Write($sIni, $sPopup, __MothMenu_PinnedKey($sExtensions), $sPinned)
	EndIf
EndFunc   ;==>_MothMenu_PinnedWrite


; Группы форматов со своими отметками: все поддерживаемые и папка
Func _MothMenu_PinGroups()
	Local $aGroups = $gc_aExtensionWhiteList
	_ArrayAdd($aGroups, 'folder')
	Return $aGroups
EndFunc   ;==>_MothMenu_PinGroups


Func __MothMenu_PinnedKey($sExtensions)
	Return 'Pinned.' & ($sExtensions = 'folder' ? 'Folder' : StringUpper($sExtensions))
EndFunc   ;==>__MothMenu_PinnedKey


; Раскладывает отмеченные действия всех окон по ключам Pin во всех форматах и ставит их
; в SubCommands перед пунктами окон. Прочие ключи Pin удаляются.
; $sIni - как у _MothMenu_PopupActions: окно только что поменяло Pinned или список
Func _MothMenu_PinsUpdate($sIni = Default)
	If IsKeyword($sIni) Then $sIni = $gc_sMothIni
	Local $aGroups = $gc_aExtensionWhiteList
	If _IniString_Read($gc_sMothIni, 'Config', 'ContextMenuFolders') = 1 Then _ArrayAdd($aGroups, 'folder')
	Local $aLayout, $sSub, $sOld, $oKeep[]
	For $sExtensions In $aGroups
		$aLayout = __MothMenu_PinsLayout($sExtensions, $sIni)
		If @error Then ContinueLoop
		$sSub = ''
		For $i = 0 To UBound($aLayout) - 1
			$sSub &= $aLayout[$i][0] & ';'
			If $aLayout[$i][1] = '' Then ContinueLoop
			_MothRegDelete($gc_sRegKey & $aLayout[$i][0])
			_MothMenu_WriteActionKey($aLayout[$i][0], $aLayout[$i][1], _ActionTitle($aLayout[$i][1], $sExtensions))
			$oKeep[$aLayout[$i][0]] = True
		Next
		For $sRoot In _MothMenu_Roots($sExtensions)
			$sOld = RegRead($sRoot, 'SubCommands')
			If @error Or $sOld = '' Then ContinueLoop
			If $sOld <> $sSub Then _MothRegWrite($sRoot, 'SubCommands', 'REG_SZ', $sSub)
		Next
	Next
	__MothMenu_PinsCleanup($oKeep)
EndFunc   ;==>_MothMenu_PinsUpdate


; Есть ли в меню формата место ещё под одно отмеченное действие
Func _MothMenu_PinFits($sExtensions, $sIni = Default)
	If IsKeyword($sIni) Then $sIni = $gc_sMothIni
	Return UBound(__MothMenu_PinsLayout($sExtensions, $sIni)) < $gc_iMothMenuItemsMax
EndFunc   ;==>_MothMenu_PinFits


; Меню формата по SubCommands его корня: пункты без ключей Pin, перед каждым окном
; его отмеченные действия, пока меню не дойдёт до $gc_iMothMenuItemsMax пунктов.
; Возвращает [ключ, действие]: у ключа Pin действие, у прочих пунктов ''.
; @error - у формата нет меню Moth
Func __MothMenu_PinsLayout($sExtensions, $sIni)
	Local $aRoots = _MothMenu_Roots($sExtensions), $aItems[0]
	Local $sSub = RegRead($aRoots[0], 'SubCommands')
	If @error Or $sSub = '' Then
		Local $aNone[0][2]
		Return SetError(1, 0, $aNone)
	EndIf
	For $sItem In StringSplit($sSub, ';', 2)
		If $sItem = '' Or StringRegExp($sItem, '\.Pin\d+\.') Then ContinueLoop
		_ArrayAdd($aItems, $sItem)
	Next

	Local $iRoom = $gc_iMothMenuItemsMax - UBound($aItems)
	Local $aLayout[UBound($aItems) + ($iRoom > 0 ? $iRoom : 0)][2], $iCount = 0, $sPopup, $aActions, $iN
	For $sItem In $aItems
		$sPopup = __MothMenu_ItemPopup($sItem)
		If $sPopup <> '' Then
			$aActions = _MothMenu_PopupActions($sPopup, $sExtensions, $sIni)
			$iN = 0
			For $sAction In __MothMenu_PopupPinned($sPopup, $sExtensions, $sIni)
				If $iRoom <= 0 Then ExitLoop
				If Not __MothMenu_PinWanted($sAction, $aActions, $sExtensions) Then ContinueLoop
				$iN += 1
				$iRoom -= 1
				$aLayout[$iCount][0] = _MothMenu_PopupPinKey($sPopup, $iN, $sExtensions)
				$aLayout[$iCount][1] = $sAction
				$iCount += 1
			Next
		EndIf
		$aLayout[$iCount][0] = $sItem
		$aLayout[$iCount][1] = ''
		$iCount += 1
	Next
	ReDim $aLayout[$iCount][2]
	Return $aLayout
EndFunc   ;==>__MothMenu_PinsLayout


; Окно пункта SubCommands: у 'Moth.Convert' и 'Moth.ConvertSep' - 'Moth.Convert', '' - не окно
Func __MothMenu_ItemPopup($sItem)
	If _MothMenu_IsPopup($sItem) Then Return $sItem
	If StringRight($sItem, 3) = 'Sep' And _MothMenu_IsPopup(StringTrimRight($sItem, 3)) Then Return StringTrimRight($sItem, 3)
	Return ''
EndFunc   ;==>__MothMenu_ItemPopup


; Отмеченные действия окна в меню формата по порядку: по алфавиту, у окна размеров -
; в порядке его списка
Func __MothMenu_PopupPinned($sPopup, $sExtensions, $sIni)
	Local $sPinned = _MothMenu_PinnedRead($sIni, $sPopup, $sExtensions)
	If Not _MothMenu_IsResizer($sPopup) Then Return _MothMenu_SortByTitle(StringSplit($sPinned, '|', 2))
	Local $aPinned[0]
	; Список целиком: у папки форматы не проверяются
	For $sAction In _MothMenu_PopupActions($sPopup, 'folder', $sIni)
		If StringInStr('|' & $sPinned & '|', '|' & $sAction & '|') Then _ArrayAdd($aPinned, $sAction)
	Next
	Return $aPinned
EndFunc   ;==>__MothMenu_PopupPinned


; Удаляет ключи Pin всех окон, которых нет в $oKeep. Их номера не ограничены длиной
; списка: после удаления пресетов хвост длиннее нынешнего Popup
Func __MothMenu_PinsCleanup(ByRef $oKeep)
	Local $i = 1, $sKey
	While True
		$sKey = RegEnumKey($gc_sRegKey, $i)
		If @error Then ExitLoop
		; После удаления тот же индекс указывает на следующий ключ
		If StringLeft($sKey, 5) = 'Moth.' And StringRegExp($sKey, '\.Pin\d+\.') And Not MapExists($oKeep, $sKey) Then
			_MothRegDelete($gc_sRegKey & $sKey)
		Else
			$i += 1
		EndIf
	WEnd
EndFunc   ;==>__MothMenu_PinsCleanup


; Корневые ключи меню Moth группы форматов: у каждого расширения свой, у папки один
Func _MothMenu_Roots($sExtensions)
	If $sExtensions = 'folder' Then
		Local $aFolder[1] = ['HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth']
		Return $aFolder
	EndIf
	Local $aRoots = StringSplit($sExtensions, '.', 2)
	For $i = 0 To UBound($aRoots) - 1
		$aRoots[$i] = 'HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $aRoots[$i] & '\shell\moth'
	Next
	Return $aRoots
EndFunc   ;==>_MothMenu_Roots


; Отмеченное действие попадает в меню формата, если он его умеет и оно не стоит
; в меню отдельным пунктом (иначе вышло бы два одинаковых)
Func __MothMenu_PinWanted($sAction, ByRef $aActions, $sExtensions)
	If $sAction = '' Or _ActionTitle($sAction) = '' Then Return False
	If _ArraySearch($aActions, $sAction) = -1 Then Return False
	Return Not __MothMenu_InFormatMenu($sAction, $sExtensions)
EndFunc   ;==>__MothMenu_PinWanted


; Действие включено в списке [Action.*] группы форматов
Func __MothMenu_InFormatMenu($sAction, $sExtensions)
	Local $aList = _MothMenu_FormatList($sExtensions)
	For $i = 1 To $aList[0][0]
		If $aList[$i][0] = $sAction And $aList[$i][1] = 1 Then Return True
	Next
	Return False
EndFunc   ;==>__MothMenu_InFormatMenu


; Секция [Action.*] группы форматов: [Action.JPG.JPE.JPEG], [Action.Folder]
Func _MothMenu_FormatList($sExtensions)
	If $sExtensions = 'folder' Then Return _IniString_ReadSection($gc_sMothIni, 'Action.Folder')
	Return _IniString_ReadSection($gc_sMothIni, 'Action.' & StringUpper($sExtensions))
EndFunc   ;==>_MothMenu_FormatList


; Действия по алфавиту заголовков. Числа сравниваются как числа: «Палитра 512 цветов»
; раньше «Палитра 1024 цвета»
Func _MothMenu_SortByTitle($aActions)
	Local $iCount = UBound($aActions)
	If $iCount < 2 Then Return $aActions
	Local $aSort[$iCount][2]
	For $i = 0 To $iCount - 1
		$aSort[$i][0] = __MothMenu_NaturalKey(_ActionTitle($aActions[$i]))
		$aSort[$i][1] = $aActions[$i]
	Next
	_ArraySort($aSort)
	For $i = 0 To $iCount - 1
		$aActions[$i] = $aSort[$i][1]
	Next
	Return $aActions
EndFunc   ;==>_MothMenu_SortByTitle


; Ключ сортировки: числа дополнены нулями до одной длины
Func __MothMenu_NaturalKey($sText)
	Local $aParts = StringRegExp($sText, '\d+|\D+', 3), $sKey = ''
	If @error Then Return $sText
	For $sPart In $aParts
		$sKey &= StringIsDigit($sPart) ? StringRight('0000000000' & $sPart, 10) : $sPart
	Next
	Return $sKey
EndFunc   ;==>__MothMenu_NaturalKey
