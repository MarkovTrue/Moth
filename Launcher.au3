#pragma compile(Out, ..\MothPortable\Launcher.exe)
#pragma compile(Icon, Assets\Icons\Launcher.ico)
#pragma compile(x64, True)
#pragma compile(ProductName, Moth Launcher)
#pragma compile(FileDescription, Moth Launcher)
#pragma compile(CompanyName, MarkovTrue)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

#include "Common\MothExplorerMenu.au3"

_MothRequireX64()

Global $g_sAction = '', $g_sTask = ''

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

	; Отмеченные действия окон встают после всех форматов: в меню каждого, сколько влезет
	_MothMenu_PinsUpdate()
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
		$sActionContextMenuTitle = _ActionTitle($sActionName, $sExtensions)
		If $sActionContextMenuTitle = '' Then
			MsgBox(48, $sMsgTitle, _LangFile_Format('Integration', 'NoTitle', _
					'Action "%1" skipped.' & @CRLF & 'It is missing from the settings file or has no title.', $sActionName))
			ContinueLoop
		EndIf

		; Разделитель рисуется у пункта перед ним: флаг «разделитель после»
		$bSeparator = _GetSeparator($i + 1, $aActionList, $sExtensions) > 0

		; Чего формат не умеет, того в его меню нет. Отмеченные в окне выбора действия
		; встанут перед пунктом окна, когда их разложит _MothMenu_PinsUpdate
		If Not _MothMenu_ActionFits($sActionName, $sExtensions) Then ContinueLoop

		; CommandStore общий для всех форматов: своя подпись группы - свой ключ,
		; иначе «Exif» у JPEG затёр бы «Meta» у PNG
		If $sActionContextMenuTitle <> _ActionTitle($sActionName) Then _
				$sActionName &= '.' & StringUpper(StringRegExpReplace($sExtensions, '\..*', ''))

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


; Индекс разделителя сразу за пунктом, 0 - его нет или после него пусто. Выключенные пункты
; и пункты, которых формат не умеет, пропускаются: их в меню не будет
Func _GetSeparator($iIndex, Const ByRef $aActionList, $sExtensions)
	Local $iSeparator = 0
	For $i = $iIndex To $aActionList[0][0]
		If $aActionList[$i][1] <> 1 Then ContinueLoop
		If $aActionList[$i][0] = 'Separator' Then
			If Not $iSeparator Then $iSeparator = $i
		ElseIf _MothMenu_ActionFits($aActionList[$i][0], $sExtensions) Then
			Return $iSeparator
		EndIf
	Next
	Return 0
EndFunc   ;==>_GetSeparator

