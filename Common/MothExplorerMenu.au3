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
	Local $sActionIconPath = _GetIconPath() & '\' & _ThemeIconName($sActionIcon)
	If FileExists($sActionIconPath) Then
		_MothRegWrite($gc_sRegKey & $sKey, 'Icon', 'REG_SZ', $sActionIconPath)
	Else
		Local $aIconInfo = _ExplorerIcon_Get($sActionIcon)
		_MothRegWrite($gc_sRegKey & $sKey, 'Icon', 'REG_SZ', $aIconInfo[1] & ',' & $aIconInfo[2])
	EndIf
EndFunc   ;==>_MothMenu_WriteActionIcon


; Иконки пунктов догоняют режим приложений Windows: в реестре они записаны путями
; одной из тем, и после смены режима путь меняется на другую тему. Путь до 1.40
; (themes\dark\lossless_exif.ico) заодно получает новые имена папки и файла. Launcher
; и Menu зовут это при каждом запуске, обход CommandStore – пара миллисекунд
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
		$sNew = _GetIconPath() & '\' & _ThemeIconName(StringRegExpReplace($sIcon, '^.*\\', ''))
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
; Окна выбора (Popup= в Moth.ini)
; ============================================================
; Пункт с Popup открывает окно со списком действий (Menu.exe). Действия, отмеченные
; в окне (Pinned=), стоят в меню перед этим пунктом, своим блоком, по алфавиту.
; Это ключи <Popup>.Pin<N>.<формат>, свои у каждого формата. В SubCommands формата
; стоят только существующие: на ссылке на ключ, которого нет, проводник обрывает
; весь список. Поэтому отметка в окне переписывает эти ключи и их кусок в SubCommands,
; остальное меню не трогается.
; Окно размеров (Command=resizer) устроено так же: Popup - его пресеты Moth.Resize.<команда>,
; список пополняет само окно. Пустой список окно не прячет: в нём можно задать свой размер.

; Пункт открывает окно Menu.exe: список действий или окно размеров
Func _MothMenu_IsPopup($sAction)
	Return _IniString_Read($gc_sMothIni, $sAction, 'Popup') <> '' Or _MothMenu_IsResizer($sAction)
EndFunc   ;==>_MothMenu_IsPopup


Func _MothMenu_IsResizer($sAction)
	Return _IniString_Read($gc_sMothIni, $sAction, 'Command') = 'resizer'
EndFunc   ;==>_MothMenu_IsResizer


; Действия окна, которые умеет формат. $sExtensions - группа форматов
; ('jpg.jpe.jpeg'), расширение файла или 'folder': папку каждый файл проверит сам Moth.
; $sIni - содержимое Moth.ini, если список в нём новее загруженного при старте
Func _MothMenu_PopupActions($sPopup, $sExtensions, $sIni = Default)
	If IsKeyword($sIni) Then $sIni = $gc_sMothIni
	Local $aExt = StringSplit($sExtensions, '.', 2), $aActions[0], $sAction
	For $sItem In StringSplit(_IniString_Read($sIni, $sPopup, 'Popup'), '|', 2)
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


; Раскладывает отмеченные действия $sPinned ('A|B') по ключам во всех форматах:
; по алфавиту, у окна размеров - в порядке его списка.
; $sIni - как у _MothMenu_PopupActions: окно размеров только что дописало пресет
Func _MothMenu_PopupPinsUpdate($sPopup, $sPinned, $sIni = Default)
	Local $aGroups = $gc_aExtensionWhiteList
	If _IniString_Read($gc_sMothIni, 'Config', 'ContextMenuFolders') = 1 Then _ArrayAdd($aGroups, 'folder')
	Local $aPinned = _MothMenu_SortByTitle(StringSplit($sPinned, '|', 2))
	If _MothMenu_IsResizer($sPopup) Then
		ReDim $aPinned[0]
		; Список целиком: у папки форматы не проверяются
		For $sAction In _MothMenu_PopupActions($sPopup, 'folder', $sIni)
			If StringInStr('|' & $sPinned & '|', '|' & $sAction & '|') Then _ArrayAdd($aPinned, $sAction)
		Next
	EndIf


	Local $aActions, $iN
	For $sExtensions In $aGroups
		$aActions = _MothMenu_PopupActions($sPopup, $sExtensions, $sIni)
		$iN = 0
		If __MothMenu_PopupInMenu($sPopup, $sExtensions) Then
			For $sAction In $aPinned
				If Not __MothMenu_PinWanted($sAction, $aActions, $sExtensions) Then ContinueLoop
				$iN += 1
				_MothRegDelete($gc_sRegKey & _MothMenu_PopupPinKey($sPopup, $iN, $sExtensions))
				_MothMenu_WriteActionKey(_MothMenu_PopupPinKey($sPopup, $iN, $sExtensions), $sAction, _ActionTitle($sAction))
			Next
		EndIf
		For $i = $iN + 1 To UBound($aActions)
			_MothRegDelete($gc_sRegKey & _MothMenu_PopupPinKey($sPopup, $i, $sExtensions))
		Next
		__MothMenu_PopupSubCommandsUpdate($sPopup, $sExtensions, $iN)
	Next
EndFunc   ;==>_MothMenu_PopupPinsUpdate


; Ставит в SubCommands формата $iN ключей отмеченных действий перед пунктом окна,
; прежние ключи окна убирает
Func __MothMenu_PopupSubCommandsUpdate($sPopup, $sExtensions, $iN)
	Local $sPrefix = $sPopup & '.Pin', $sSub, $sNew
	For $sRoot In _MothMenu_Roots($sExtensions)
		$sSub = RegRead($sRoot, 'SubCommands')
		If @error Or $sSub = '' Then ContinueLoop
		$sNew = ''
		For $sItem In StringSplit($sSub, ';', 2)
			If $sItem = '' Or StringLeft($sItem, StringLen($sPrefix)) = $sPrefix Then ContinueLoop
			If $sItem = $sPopup Or $sItem = $sPopup & 'Sep' Then
				For $i = 1 To $iN
					$sNew &= _MothMenu_PopupPinKey($sPopup, $i, $sExtensions) & ';'
				Next
			EndIf
			$sNew &= $sItem & ';'
		Next
		If $sNew <> $sSub Then _MothRegWrite($sRoot, 'SubCommands', 'REG_SZ', $sNew)
	Next
EndFunc   ;==>__MothMenu_PopupSubCommandsUpdate


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


; Окно включено в меню формата
Func __MothMenu_PopupInMenu($sPopup, $sExtensions)
	Local $aList = _MothMenu_FormatList($sExtensions)
	For $i = 1 To $aList[0][0]
		If $aList[$i][0] = $sPopup And $aList[$i][1] = 1 Then Return True
	Next
	Return False
EndFunc   ;==>__MothMenu_PopupInMenu


; Отмеченное действие попадает в меню формата, если он его умеет и оно не стоит
; в меню отдельным пунктом (иначе вышло бы два одинаковых)
Func __MothMenu_PinWanted($sAction, ByRef $aActions, $sExtensions)
	If $sAction = '' Or _ActionTitle($sAction) = '' Then Return False
	If _ArraySearch($aActions, $sAction) = -1 Then Return False
	Local $aList = _MothMenu_FormatList($sExtensions)
	For $i = 1 To $aList[0][0]
		If $aList[$i][0] = $sAction And $aList[$i][1] = 1 Then Return False
	Next
	Return True
EndFunc   ;==>__MothMenu_PinWanted


; Секция [Action.*] группы форматов. Группа могла вырасти: в Moth.ini до 1.40 была [Action.HEIC],
; теперь [Action.HEIC.HEIF]. Нет секции группы - читается секция её первого расширения
Func _MothMenu_FormatList($sExtensions)
	If $sExtensions = 'folder' Then Return _IniString_ReadSection($gc_sMothIni, 'Action.Folder')
	Local $aList = _IniString_ReadSection($gc_sMothIni, 'Action.' & StringUpper($sExtensions))
	If $aList[0][0] > 0 Or Not StringInStr($sExtensions, '.') Then Return $aList
	Return _IniString_ReadSection($gc_sMothIni, 'Action.' & StringUpper(StringLeft($sExtensions, StringInStr($sExtensions, '.') - 1)))
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
