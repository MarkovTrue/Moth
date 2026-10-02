#pragma compile(Out, ..\MothPortable\Launcher.exe)
#pragma compile(Icon, Assets\Icons\Icon.ico)
#pragma compile(x64, True)
#pragma compile(ProductName, Moth Launcher)
#pragma compile(ProductVersion, 1.40)
#pragma compile(FileVersion, 1.40)
#pragma compile(FileDescription, Moth Launcher)
#pragma compile(CompanyName, MarkovTrue)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

#include "Common\MothExplorerMenu.au3"

_MothRequireX64()

Global $g_sAction = '', $g_sTask = ''
; Окна выбора, попавшие в меню: их отмеченные действия раскладываются после всех форматов
Global $g_sPopups = ''

; Проверка аргументов командной строки
If $CmdLine[0] > 0 Then
	Switch $CmdLine[1]
		Case 'addToContextMenu'
			_MothIniRequire()
			_MothLangInit()
			_AddToContextMenu()
			_MothRegReportErrors()
			Exit
		Case 'removeFromContextMenu'
			; Ini может и не быть: тогда язык системы
			_MothLangInit()
			_RemoveFromContextMenu()
			_MothRegReportErrors()
			Exit
		Case 'checkUpdate'
			; Проверка новой версии для Moth и окна настроек. Отдельным процессом: запрос
			; синхронный, а окна не должны ждать сеть. Код выхода - итог проверки
			If Not FileExists(@ScriptDir & '\Moth.ini') Then Exit 1
			Exit _MothUpdateCheckRun()
		Case Else
			; Launcher.exe <путь> <действие>: задание в очередь Moth. Launcher ждёт, пока Moth
			; его примет, код выхода 1 - не принял
			For $i = 2 To $CmdLine[0]
				$g_sAction &= ' ' & $CmdLine[$i]
			Next
			$g_sTask = _MothTaskLine($CmdLine[1], StringStripWS($g_sAction, 3))
			If $g_sTask = '' Then Exit
			If Not _MothSendTasks($g_sTask) Then Exit 1
			; Moth уже работает, а иконки меню тем временем догоняют режим Windows
			_MothMenu_SyncIconTheme()
			Exit
	EndSwitch
Else
	Exit
EndIf


; ============================================================
; Контекстное меню
; ============================================================

; Меню пересобирается с нуля: секции [Action.PNG], [Action.JPG.JPE.JPEG] и т.д.
Func _AddToContextMenu()
	_RemoveFromContextMenu()

	For $sExtensions In $gc_aExtensionWhiteList
		_SetupConfig($sExtensions, _MothMenu_FormatList($sExtensions))
	Next

	If _IniString_Read($gc_sMothIni, 'Config', 'ContextMenuFolders') = 1 Then
		_SetupConfig('folder', _IniString_ReadSection($gc_sMothIni, 'Action.Folder'))
	EndIf

	For $sPopup In StringSplit($g_sPopups, '|', 2)
		If $sPopup = '' Then ContinueLoop
		_MothMenu_PopupPinsUpdate($sPopup, _IniString_Read($gc_sMothIni, $sPopup, 'Pinned'))
	Next
EndFunc   ;==>_AddToContextMenu


Func _RemoveFromContextMenu()
	; Пункты Moth.* в CommandStore. После удаления тот же индекс указывает на следующий ключ
	Local $i = 1, $sRegKeyName
	While True
		$sRegKeyName = RegEnumKey($gc_sRegKey, $i)
		If @error Then ExitLoop
		If StringLeft($sRegKeyName, 5) = 'Moth.' Then
			_MothRegDelete($gc_sRegKey & $sRegKeyName)
		Else
			$i += 1
		EndIf
	WEnd

	For $sExtension In _GetExtensionListExpanded()
		_MothRegDelete('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth')
	Next

	; Ключи прежних версий: меню на все картинки и на Folder
	_MothRegDelete('HKEY_CLASSES_ROOT\SystemFileAssociations\image\shell\moth')
	_MothRegDelete('HKEY_CLASSES_ROOT\Folder\shell\moth')
	_MothRegDelete('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth')
EndFunc   ;==>_RemoveFromContextMenu


; Меню Moth одной группы форматов (или папки) по её секции [Action.*]
Func _SetupConfig($sExtensions, $aActionList)
	Local $sMsgTitle = _LangFile_Format('Integration', 'Title', 'Integration of "%1"', StringUpper($sExtensions))
	If Not IsArray($aActionList) Or $aActionList[0][0] < 1 Then
		MsgBox(48, $sMsgTitle, _LangFile_Format('Integration', 'NoSection', 'The settings file has no section "%1"', _
				'Action.' & StringUpper($sExtensions)))
		Return
	EndIf

	Local $sActionName, $sActionContextMenuTitle, $sSubCommands = '', $bSeparator

	For $i = 1 To $aActionList[0][0]
		If $aActionList[$i][1] <> 1 Then ContinueLoop

		$sActionName = $aActionList[$i][0]
		If StringLeft($sActionName, 5) <> 'Moth.' Then
			If $sActionName <> 'Separator' Then MsgBox(48, $sMsgTitle, _
					_LangFile_Format('Integration', 'BadName', 'Action skipped, invalid name:' & @CRLF & '"%1"', $sActionName))
			ContinueLoop
		EndIf

		; Заголовок из языкового файла, ContextMenuTitle в ini его перекрывает
		$sActionContextMenuTitle = _ActionTitle($sActionName)
		If $sActionContextMenuTitle = '' Then
			MsgBox(48, $sMsgTitle, _LangFile_Format('Integration', 'NoTitle', _
					'Action "%1" skipped.' & @CRLF & 'It is missing from the settings file or has no title.', $sActionName))
			ContinueLoop
		EndIf

		; Разделитель рисуется у пункта перед ним: флаг «разделитель после»
		$bSeparator = _GetSeparator($i + 1, $aActionList) > 0

		; Группа (Group=Moth.ConvertToWebp|...) раскрывается вложенным меню
		Local $sGroup = _IniString_Read($gc_sMothIni, $sActionName, 'Group')
		If $sGroup <> '' Then
			Local $sGroupKey = _SetupGroup($sActionName, $sExtensions, $sGroup, $bSeparator)
			If $sGroupKey <> '' Then $sSubCommands &= $sGroupKey & ';'
			ContinueLoop
		EndIf

		; Окно выбора (Popup=Moth.ConvertToJpg|...): отмеченные в нём действия встанут
		; перед пунктом, когда их разложит _MothMenu_PopupPinsUpdate. Окно размеров
		; и без пресетов нужно: в нём задают свой размер
		If _MothMenu_IsPopup($sActionName) Then
			If UBound(_MothMenu_PopupActions($sActionName, $sExtensions)) = 0 And Not _MothMenu_IsResizer($sActionName) Then ContinueLoop
			If Not StringInStr('|' & $g_sPopups, '|' & $sActionName & '|') Then $g_sPopups &= $sActionName & '|'
		EndIf

		If $bSeparator Then
			; Ключ с разделителем и без - разные пункты: у первого в имени Sep
			$sActionName &= 'Sep'
			; CommandFlags: 0x40 - SeparatorAfter
			_MothRegWrite($gc_sRegKey & $sActionName, 'CommandFlags', 'REG_DWORD', '0x40')
		EndIf

		$sSubCommands &= $sActionName & ';'
		_MothMenu_WriteActionKey($sActionName, $aActionList[$i][0], $sActionContextMenuTitle)
	Next

	Local $bTop = _IniString_Read($gc_sMothIni, 'Config', 'ContextMenuTopPosition') = 1
	Local $bExtended = _IniString_Read($gc_sMothIni, 'Config', 'ContextMenuExtended') = 1
	For $sRoot In _MothMenu_Roots($sExtensions)
		_MothRegWrite($sRoot, 'Icon', 'REG_SZ', @ScriptDir & '\Moth.exe')
		_MothRegWrite($sRoot, 'MUIVerb', 'REG_SZ', 'Moth')
		; Player: команда на каждый выделенный файл, без ограничения в 15 файлов
		If $sExtensions <> 'folder' Then _MothRegWrite($sRoot, 'MultiSelectModel', 'REG_SZ', 'Player')
		_MothRegWrite($sRoot, 'SubCommands', 'REG_SZ', $sSubCommands)
		If $bTop Then _MothRegWrite($sRoot, 'Position', 'REG_SZ', 'Top')
		; Extended - только по Shift+ПКМ
		If $bExtended Then _MothRegWrite($sRoot, 'Extended', 'REG_SZ', '')
	Next
EndFunc   ;==>_SetupConfig


; Вложенное меню: пункт с собственными SubCommands в CommandStore. Состав у каждого
; формата свой: в группу попадают только действия, которые этот формат умеет
; (у PNG нет «в PNG»). Ключ группы отдельный на формат, ключи пунктов - Moth.InGroup.*,
; подписи внутри группы короче ([ActionsInGroup] в языковом файле).
; Возвращает имя ключа группы или '', если в ней ничего не осталось
Func _SetupGroup($sGroupAction, $sExtensions, $sGroup, $bSeparator)
	Local $aExt = StringSplit($sExtensions, '.', 2), $sCommands = '', $sKey, $sSub
	For $sItem In StringSplit($sGroup, '|', 2)
		$sSub = StringStripWS($sItem, 3)
		If StringLeft($sSub, 5) <> 'Moth.' Then ContinueLoop
		; Папка раскрывается в файлы разных форматов: каждый файл проверит сам Moth
		If $sExtensions <> 'folder' And Not _IsFormatSupported($aExt[0], $sSub) Then ContinueLoop
		$sKey = 'Moth.InGroup.' & StringTrimLeft($sSub, 5)
		_MothMenu_WriteActionKey($sKey, $sSub, _LangFile_Get('ActionsInGroup', $sSub, _ActionTitle($sSub)))
		$sCommands &= $sKey & ';'
	Next
	If $sCommands = '' Then Return ''

	$sKey = $sGroupAction & '.' & StringReplace($sExtensions, '.', '_') & ($bSeparator ? 'Sep' : '')
	_MothRegWrite($gc_sRegKey & $sKey, 'MUIVerb', 'REG_SZ', _ActionTitle($sGroupAction))
	_MothRegWrite($gc_sRegKey & $sKey, 'SubCommands', 'REG_SZ', $sCommands)
	If $bSeparator Then _MothRegWrite($gc_sRegKey & $sKey, 'CommandFlags', 'REG_DWORD', '0x40')
	_MothMenu_WriteActionIcon($sKey, $sGroupAction)
	Return $sKey
EndFunc   ;==>_SetupGroup


; Индекс разделителя сразу за пунктом, 0 - его нет. Выключенные пункты между ними пропускаются
Func _GetSeparator($iIndex, Const ByRef $aActionList)
	For $i = $iIndex To $aActionList[0][0]
		If $aActionList[$i][1] <> 1 Then ContinueLoop
		Return ($aActionList[$i][0] = 'Separator') ? $i : 0
	Next
	Return 0
EndFunc   ;==>_GetSeparator

