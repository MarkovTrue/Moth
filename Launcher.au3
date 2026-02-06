#pragma compile(Out, ..\MothPortable\Launcher.exe)
#pragma compile(Icon, ..\MothPortable\themes\Moth.ico)
#pragma compile(ProductName, Moth Launcher)
#pragma compile(LegalCopyright, © MarkovTrue)
#pragma compile(Comments, Program made by MarkovTrue)

#NoTrayIcon
#RequireAdmin

#include "Common\ExplorerIcon.au3"
#include "Common\MothCommon.au3"

If @OSArch = 'X86' Then
	MsgBox(48, $sAppName, 'Поддерживаются ОС только на X64 архитектуре.' & @CR & 'Приложение будет закрыто.')
	Exit
EndIf

Global $sPathFile = '', $sPathFileName = '', $sPathFileExtension = '', $sParams = ''

; Проверка аргументов командной строки
If $CmdLine[0] > 0 Then
	Switch $CmdLine[1]
		Case 'addToContextMenu'
			_AddToContextMenu()
			Exit
		Case 'removeFromContextMenu'
			_RemoveFromContextMenu()
			Exit
		Case Else
			; Полный путь до файла
			$sPathFile = $CmdLine[1]
			If Not FileExists($sPathFile) Then Exit
			; Имя файла
			$sPathFileName = _GetFileName($sPathFile)
			; Расширение
			$sPathFileExtension = _GetFileExtension($sPathFile)
			; Получение параметров
			If $CmdLine[0] > 1 Then
				For $i = 2 To $CmdLine[0]
					$sParams &= ' ' & $CmdLine[$i]
				Next
				$sParams = '|' & StringStripWS($sParams, 3)
			EndIf
	EndSwitch
Else
	; Выход, если запустили без аргументов
	Exit
EndIf

;~  MsgBox(48, 'Внимание', $CmdLine[0] & ' $sPathFile=' & $sPathFile & ', $sParams =[' & $sParams & ']')

If Not _IsDir($sPathFile) Then
	$sPathFileExtension = _GetFileExtension($sPathFile)
	_ArraySearch(_GetExtensionListExpanded(), $sPathFileExtension)
	If @error Then Exit
EndIf


; Логирование
If Not FileExists($sLogPathDir) Then DirCreate($sLogPathDir)
$sInfoPathFile = $sLogPathDir & '\' & @HOUR & @MIN & @SEC & @MSEC & '_' & $sPathFileName & '.txt'
FileWriteLine($sInfoPathFile, $sPathFile & $sParams)

;~ _ArrayDisplay($CmdLine, "$CmdLine")

; Запуск основного процесса
If Not ProcessExists('Moth.exe') Then Run(@ScriptDir & '\Moth.exe')


;=============================
; Добавить в контекстное меню
;=============================

Func _AddToContextMenu()

	_RemoveFromContextMenu()

	; Пример названия секции Action.JPG.JPEG или Action.PNG
	For $sExtensions In $aExtensionWhiteList
		_SetupConfig($sExtensions, _IniString_ReadSection($sMothINI, 'Action.' & StringUpper($sExtensions)))
	Next

	; Контекстное меню, показываыть для папок
	If _IniString_Read($sMothINI, 'Config', 'ContextMenuFolders') = 1 Then
		_SetupConfig('folder', _IniString_ReadSection($sMothINI, 'Action.Folder'))
	EndIf

EndFunc   ;==>_AddToContextMenu


;=================
; Удаление записей
;=================

Func _RemoveFromContextMenu()
	; Удаление ключей по шаблону
	Local $i = 1, $sRegKeyName, $sPattern = 'Moth.'

	While True
		$sRegKeyName = RegEnumKey($sRegKey, $i)
		If @error Then ExitLoop
		; Удаляем найденные ключи
		If StringLeft($sRegKeyName, 5) = $sPattern Then
			RegDelete($sRegKey & $sRegKeyName)
		Else
			$i += 1
		EndIf
	WEnd

	; Удаление конфига для конкретного расширения
	For $sExtension In _GetExtensionListExpanded()
		RegDelete('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth')
	Next

	; Удаление ключей старой версии, на всякий случай
	RegDelete('HKEY_CLASSES_ROOT\SystemFileAssociations\image\shell\moth')
	; Удаление ключей для папки старое
	RegDelete('HKEY_CLASSES_ROOT\Folder\shell\moth')
	; Удаление ключей для папки актуальное
	RegDelete('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth')

EndFunc   ;==>_RemoveFromContextMenu


;===========
; Установка
;===========

Func _SetupConfig($sExtensions, $aActionList)
	If Not IsArray($aActionList) Then
		MsgBox(48, 'Интеграция формата "' & StringUpper($sExtensions) & '"', 'В файле настроек нет секции "Action.' & StringUpper($sExtensions) & '"')
		Return
	EndIf

	Local $sActionName, $sActionContextMenuTitle, $sActionCommand, $sActionFilePostfix, $sActionIcon
	Local $sActionIconPath, $sSubCommands = ''

	For $i = 1 To $aActionList[0][0]
		; Пропустим, если значение не равно единице
		If $aActionList[$i][1] <> 1 Then ContinueLoop

		; Moth.CompressionLossless
		$sActionName = $aActionList[$i][0]
		; Title=Сжатие без потерь
		$sActionContextMenuTitle = StringStripWS(_IniString_Read($sMothINI, $sActionName, 'ContextMenuTitle'), 3)
		; Command=lossy
		$sActionCommand = _IniString_Read($sMothINI, $sActionName, 'Command')
		; FilePostfix=_lossy
		$sActionFilePostfix = _IniString_Read($sMothINI, $sActionName, 'FilePostfix')
		; Icon=resize.ico
		$sActionIcon = _IniString_Read($sMothINI, $sActionName, 'Icon')

		; Пропустим, если название команды не соответствует шаблону
		If StringLeft($sActionName, 5) <> 'Moth.' Then
			If $sActionName <> 'Separator' Then MsgBox(48, 'Интеграция формата "' & StringUpper($sExtensions) & '"', 'Конфиг пропущен, недопустимое название' & @CR & '"' & $sActionName & '"')
			ContinueLoop
		EndIf

		; Пропустим
		If $sActionContextMenuTitle = '' Then
			MsgBox(48, 'Интеграция формата "' & StringUpper($sExtensions) & '"', 'Конфиг ' & '"' & $sActionName & '" пропущен' & @CR & 'Его нет в файле настроек, либо заполнен не корректно')
			ContinueLoop
		EndIf

		; Чек, надо ли нарисовать разделитель. Чекаем следующий пункт в списке, чтобы нарисовать сепаратор в этом
		$nSeparatorIndx = _GetSeparator($i + 1, $aActionList)
		If $nSeparatorIndx > 0 Then
			; Если сепаратор добавлен, то нам надо отличать ActionName в котором есть сепаратор от ActionName в котором его нет
			; Поэтому дла ActionName с сепаратором добавляем постфикс к названию
			$sActionName = $sActionName & 'Sep'
			; SeparatorBefore = 0x20, SeparatorAfter = 0x40
			RegWrite($sRegKey & $sActionName, 'CommandFlags', 'REG_DWORD', '0x40')
		EndIf

		; По пути соберем список команд в строку
		$sSubCommands &= $sActionName & ';'

		RegWrite($sRegKey & $sActionName, '', 'REG_SZ', $sActionContextMenuTitle & '	' & $sActionFilePostfix)

		If $sActionCommand = 'resizer' Then
			RegWrite($sRegKey & $sActionName & '\command', '', 'REG_SZ', '"' & @ScriptDir & '\Apps\singleinstance.exe" "%1" "' & @ScriptDir & '\Resiser.exe" $files --si-timeout 400')
		Else
			RegWrite($sRegKey & $sActionName & '\command', '', 'REG_SZ', '"' & @ScriptDir & '\Launcher.exe" "%1" ' & $aActionList[$i][0])
		EndIf

		; Зарядим иконки
		If $sActionIcon <> '' Then

			$sActionIconPath = _GetIconPath() & '\' & $sActionIcon

			If FileExists($sActionIconPath) Then
				RegWrite($sRegKey & $sActionName, 'Icon', 'REG_SZ', $sActionIconPath)
			Else
				$aIconInfo = _FileGetIcon($sActionIcon)
				RegWrite($sRegKey & $sActionName, 'Icon', 'REG_SZ', $aIconInfo[1] & ',' & $aIconInfo[2])
			EndIf
		EndIf

	Next

	If $sExtensions = 'folder' Then
		RegWrite('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth', 'Icon', 'REG_SZ', @ScriptDir & '\Moth.exe')
		RegWrite('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth', 'MUIVerb', "REG_SZ", 'Moth')
		RegWrite('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth', 'SubCommands', "REG_SZ", $sSubCommands)

		; Контекстное меню, показывать только по Shift+ПКМ
		If _IniString_Read($sMothINI, 'Config', 'ContextMenuExtended') = 1 Then
			RegWrite('HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Directory\shell\moth', 'Extended', "REG_SZ", '')
		EndIf
	Else

		For $sExtension In StringSplit($sExtensions, '.', 2)
			RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'Icon', "REG_SZ", @ScriptDir & '\Moth.exe')
			RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'MUIVerb', "REG_SZ", 'Moth')
			RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'MultiSelectModel', "REG_SZ", 'Player')
			RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'SubCommands', "REG_SZ", $sSubCommands)

			; Контекстное меню, показывать всегда вверху списка
			If _IniString_Read($sMothINI, 'Config', 'ContextMenuTopPosition') = 1 Then
				RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'Position', "REG_SZ", 'Top')
			EndIf

			; Контекстное меню, показывать только по Shift+ПКМ
			If _IniString_Read($sMothINI, 'Config', 'ContextMenuExtended') = 1 Then
				RegWrite('HKEY_CLASSES_ROOT\SystemFileAssociations\.' & $sExtension & '\shell\moth', 'Extended', "REG_SZ", '')
			EndIf
		Next
	EndIf

EndFunc   ;==>_SetupConfig


Func _GetSeparator($nIndx, $aActionList)
	Local $nCount = $aActionList[0][0]

	; Идём по списку вниз, надо найти сепаратор, даже если пункты перед ним выключены
	For $i = $nIndx To $nCount
		If $aActionList[$i][1] <> 1 Then ContinueLoop
		Return ($aActionList[$i][0] = 'Separator') ? $i : 0
	Next

	Return 0
EndFunc   ;==>_GetSeparator

