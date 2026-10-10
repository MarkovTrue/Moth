#include-once

#include <Array.au3>
#include <FileConstants.au3>
#include <ProcessConstants.au3>

#include "MothConstants.au3"
#include "..\Include\CopyDataQueue.au3"
#include "..\Include\IniString.au3"
#include "..\Include\LangFile.au3"
#include "..\Include\UpdateCheck.au3"

Global Const _
		$FORMAT_AVIF = 'avif', _
		$FORMAT_BMP = 'bmp', _
		$FORMAT_GIF = 'gif', _
		$FORMAT_HEIC = 'heic', _
		$FORMAT_HEIF = 'heif', _
		$FORMAT_JFIF = 'jfif', _
		$FORMAT_JPE = 'jpe', _
		$FORMAT_JPEG = 'jpeg', _
		$FORMAT_JPG = 'jpg', _
		$FORMAT_JXL = 'jxl', _
		$FORMAT_PNG = 'png', _
		$FORMAT_TIF = 'tif', _
		$FORMAT_TIFF = 'tiff', _
		$FORMAT_WEBP = 'webp'

; Версия всех exe Moth, менять здесь вместе с $gc_sAppVersion. Aut2Exe берёт pragma и из подключаемого файла
#pragma compile(ProductVersion, 1.43)
#pragma compile(FileVersion, 1.43)

; $gc_sMothIni - содержимое Moth.ini, а не путь
Global Const _
		$gc_sAppVersion = '1.43', _ ; сравнивается с тегом релиза на GitHub
		$gc_sAppName = 'Moth ' & $gc_sAppVersion, _
		$gc_sMothIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini'), _
		$gc_sTmpPath = @TempDir & '\Moth', _
		$gc_sImgPath = @TempDir & '\Moth\images', _
		$gc_bRegDarkTheme = _RegAppsUseDarkTheme()

; Группы форматов. Форматы группы умеют одно и то же: у группы одно меню проводника и одна
; секция [Action.*]. HEIC и HEIF порознь: они конвертируются друг в друга
Global Const $gc_aExtensionWhiteList = [ _
		$FORMAT_AVIF, _
		$FORMAT_BMP, _
		$FORMAT_GIF, _
		$FORMAT_HEIC, _
		$FORMAT_HEIF, _
		$FORMAT_JFIF, _
		$FORMAT_JPG & '.' & $FORMAT_JPE & '.' & $FORMAT_JPEG, _
		$FORMAT_JXL, _
		$FORMAT_PNG, _
		$FORMAT_TIF & '.' & $FORMAT_TIFF, _
		$FORMAT_WEBP]

; Что с чем работает. Чего здесь нет, того формат не умеет или в этом нет смысла:
; Палитра только там, где её можно сохранить без потерь: у JPEG и AVIF шум дизеринга
; раздувает файл. У GIF только палитра меньше 256 цветов: больше в нём и так не бывает.
; Метаданные без потерь - у форматов, где они бывают: в GIF и BMP их нет. AVIF без потерь
; только теряет метаданные, с ними сжимать нечего.
; TIFF - формат хранения: сжатие с потерями и палитра ему не нужны
Global Const _
		$SUPPORT_FORMATS_COMPRESSION_LOSSLESS = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSLESS_EXIF = [$FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSY = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_FOR_WEB = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COLOR_QUANTIZATION = [$FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COLOR_QUANTIZATION_SMALL = [$FORMAT_GIF, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_RESIZE = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_PNG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_WEBP = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF], _
		$SUPPORT_FORMATS_CONVERT_TO_JPG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_JFIF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_JXL = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_AVIF = [$FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_HEIC = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_HEIF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_GIF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_BMP = [$FORMAT_AVIF, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_TIF, $FORMAT_TIFF, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_TIFF = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_HEIF, $FORMAT_JFIF, $FORMAT_JPEG, $FORMAT_JPE, $FORMAT_JPG, $FORMAT_JXL, $FORMAT_PNG, $FORMAT_WEBP]

; Команды действий (Command=). Только здесь решено, что команда делает и какие форматы берёт:
; по таблице Moth выбирает обработку, меню проводника и окна - пункты формата.
; Столбцы: имя, параметры после имени (регэксп), вид, форматы. Вид: compress - сжатие,
; только у него итог «сэкономлено», анимированный WEBP оно не берёт; convert - конвертация
; в формат из имени (toJpg - jpg), порядок строк - порядок окна «Конвертировать…»;
; resize - ресайз; window - окно размеров. Строк у команды бывает несколько: берётся первая
; подходящая. Так палитра меньше 256 цветов (cq1-cq255) есть и у GIF
Global Const $gc_aCommands = [ _
		['loss', '', 'compress', $SUPPORT_FORMATS_COMPRESSION_LOSSLESS], _
		['lossy', '', 'compress', $SUPPORT_FORMATS_COMPRESSION_LOSSY], _
		['web', '', 'compress', $SUPPORT_FORMATS_COMPRESSION_FOR_WEB], _
		['cq', '(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d?)', 'compress', $SUPPORT_FORMATS_COLOR_QUANTIZATION_SMALL], _
		['cq', '\d+', 'compress', $SUPPORT_FORMATS_COLOR_QUANTIZATION], _
		['toJpg', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_JPG], _
		['toJfif', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_JFIF], _
		['toPng', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_PNG], _
		['toWebp', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_WEBP], _
		['toAvif', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_AVIF], _
		['toHeic', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_HEIC], _
		['toHeif', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_HEIF], _
		['toJxl', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_JXL], _
		['toGif', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_GIF], _
		['toBmp', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_BMP], _
		['toTiff', '', 'convert', $SUPPORT_FORMATS_CONVERT_TO_TIFF], _
		['percent', '_\d{1,4}_[0-5]', 'resize', $SUPPORT_FORMATS_RESIZE], _
		['resize', '_\d{1,5}_\d{1,5}_[0-2]_[0-5](?:_1)?', 'resize', $SUPPORT_FORMATS_RESIZE], _
		['resizer', '', 'window', $SUPPORT_FORMATS_RESIZE]]

; Встроенные действия. Всё, от чего зависит работа, задано здесь. Moth.ini хранит для них порядок
; в меню, отметки окон, пресеты окна размеров и ключи $gc_sActionIniKeys.
; Столбцы: имя, Command, FilePostfix, Icon, SaveExif, Popup - список окна выбора.
; Палитра Moth.ColorQuantization<N>, конвертация Moth.ConvertTo<формат> и пресеты
; Moth.Resize.<команда> выводятся из имени
Global Const $gc_aActionsBuiltin = [ _
		['Moth.CompressionLossless', 'loss', '', 'Lossless.ico', '', ''], _
		['Moth.CompressionLosslessMeta', 'loss', '', 'LosslessExif.ico', '1', ''], _
		['Moth.CompressionLossy', 'lossy', '_lossy', 'Lossy.ico', '', ''], _
		['Moth.CompressionWeb', 'web', '_web', 'Web.ico', '', ''], _
		['Moth.Convert', '', '', 'Convert.ico', '', __ActionConvertList()], _
		['Moth.ColorQuantization', '', '', 'Cq.ico', '', 'Moth.ColorQuantization64|Moth.ColorQuantization128|' & _
				'Moth.ColorQuantization256|Moth.ColorQuantization512|Moth.ColorQuantization1024|Moth.ColorQuantization2048'], _
		['Moth.Resizer', 'resizer', '', 'Resize.ico', '', '']]

; Ключи, которые Moth.ini может задать встроенному действию: оформление и имя нового файла
Global Const $gc_sActionIniKeys = '|ContextMenuTitle|ShortGuiTitle|FilePostfix|Icon|'


; Проверка обновлений: последний релиз GitHub, в котором лежит этот архив
Global Const $gc_sUpdateRepo = 'MarkovTrue/Moth', $gc_sUpdateAsset = 'Moth-win10-11-x64.zip'

Global Const $gc_sRegKey = 'HKEY_LOCAL_MACHINE64\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\'

; Накопитель ошибок реестра для _MothRegWrite/_MothRegDelete
Global $g_sRegErrors = ''


; Тёмная тема приложений Windows. Нет значения в реестре - светлая: RegRead вернул бы '',
; а '' = 0 в AutoIt истинно
Func _RegAppsUseDarkTheme()
	Local $iLight = RegRead('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme')
	If @error Then Return False
	Return $iLight = 0
EndFunc   ;==>_RegAppsUseDarkTheme


Func _IsFormatSupported($sExtensionFile, $sActionName)
	Local $aSupportedFormats = _GetActionSupportedFormats($sActionName)
	If Not IsArray($aSupportedFormats) Then Return False

	For $sFormat In $aSupportedFormats
		If $sExtensionFile = $sFormat Then Return True
	Next
	Return False
EndFunc   ;==>_IsFormatSupported


; Форматы по команде действия. Сжатие без потерь с метаданными (SaveExif=1) - только
; у форматов, где они бывают
Func _GetActionSupportedFormats($sActionName)
	Local $sCommand = _ActionRead($sActionName, 'Command')
	If _CommandId($sCommand) = 'loss' And _ActionRead($sActionName, 'SaveExif') = 1 Then Return $SUPPORT_FORMATS_COMPRESSION_LOSSLESS_EXIF
	Return _GetCommandSupportedFormats($sCommand)
EndFunc   ;==>_GetActionSupportedFormats


; Форматы по значению Command, Null - команды нет
Func _GetCommandSupportedFormats($sCommand)
	Local $iIndex = _CommandIndex($sCommand)
	If $iIndex < 0 Then Return Null
	Return $gc_aCommands[$iIndex][3]
EndFunc   ;==>_GetCommandSupportedFormats


; Строка команды в $gc_aCommands, -1 - команды нет. Регистр не важен, как у ключей ini
Func _CommandIndex($sCommand)
	For $i = 0 To UBound($gc_aCommands) - 1
		If StringRegExp($sCommand, '(?i)^' & $gc_aCommands[$i][0] & $gc_aCommands[$i][1] & '$') Then Return $i
	Next
	Return -1
EndFunc   ;==>_CommandIndex


; Имя команды без параметров: 'cq256' - 'cq', 'percent_50_0' - 'percent', '' - команды нет
Func _CommandId($sCommand)
	Local $iIndex = _CommandIndex($sCommand)
	Return $iIndex < 0 ? '' : $gc_aCommands[$iIndex][0]
EndFunc   ;==>_CommandId


; Вид команды: compress, convert, resize, window. '' - команды нет
Func _CommandKind($sCommand)
	Local $iIndex = _CommandIndex($sCommand)
	Return $iIndex < 0 ? '' : $gc_aCommands[$iIndex][2]
EndFunc   ;==>_CommandKind


; Формат, в который конвертирует команда: 'toJpg' - 'jpg'. '' - команда не конвертация
Func _CommandTarget($sCommand)
	Local $iIndex = _CommandIndex($sCommand)
	If $iIndex < 0 Or $gc_aCommands[$iIndex][2] <> 'convert' Then Return ''
	Return StringLower(StringTrimLeft($gc_aCommands[$iIndex][0], 2))
EndFunc   ;==>_CommandTarget


; Группа форматов расширения: 'jpeg' - 'jpg.jpe.jpeg', '' - формат не поддерживается
Func _FormatGroup($sExtension)
	For $sGroup In $gc_aExtensionWhiteList
		If StringInStr('.' & $sGroup & '.', '.' & $sExtension & '.') Then Return $sGroup
	Next
	Return ''
EndFunc   ;==>_FormatGroup


Func _GetExtensionListExpanded()
	Return StringSplit(_ArrayToString($gc_aExtensionWhiteList, '.'), '.', 2)
EndFunc   ;==>_GetExtensionListExpanded


; Тема окон Moth. Пока её не выбрали в настройках (пусто),
; окна следуют режиму приложений Windows
Func _IsDarkTheme()
	Local $sTheme = _IniString_Read($gc_sMothIni, 'Config', 'ThemeGUI')
	If $sTheme = 'Dark' Then Return True
	If $sTheme = 'Light' Then Return False
	Return $gc_bRegDarkTheme
EndFunc   ;==>_IsDarkTheme


Func _GetThemePath()
	Return @ScriptDir & '\Themes\' & (_IsDarkTheme() ? 'Dark' : 'Light')
EndFunc   ;==>_GetThemePath


; Иконки меню проводника. Меню следует режиму приложений Windows, а не теме Moth
Func _GetIconPath()
	Return @ScriptDir & '\Themes\' & ($gc_bRegDarkTheme ? 'Dark' : 'Light')
EndFunc   ;==>_GetIconPath


Func _GetFilterNameByIndx($nIndx)
	If $nIndx >= 0 And $nIndx <= UBound($gc_aResizeFilters) - 1 Then Return $gc_aResizeFilters[$nIndx]
	Return $gc_aResizeFilters[0] ; Lanczos по умолчанию
EndFunc   ;==>_GetFilterNameByIndx


; Расширение файла без точки
Func _GetFileExtension($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\.', '')
EndFunc   ;==>_GetFileExtension


; Имя файла с расширением
Func _GetFileName($sPathFile)
	Return StringRegExpReplace($sPathFile, '^.*\\', '')
EndFunc   ;==>_GetFileName


Func _IsDir($sPath)
	Return StringInStr(FileGetAttrib($sPath & '\'), 'D', 2) > 0
EndFunc   ;==>_IsDir


; Строка задания Moth «путь|действие». '' - пути нет или формат файла не поддерживается.
; Папку раскрывает сам Moth
Func _MothTaskLine($sPath, $sAction)
	If $sAction = '' Or Not FileExists($sPath) Then Return ''
	If Not _IsDir($sPath) Then
		_ArraySearch(_GetExtensionListExpanded(), _GetFileExtension($sPath))
		If @error Then Return ''
	EndIf
	Return $sPath & '|' & $sAction
EndFunc   ;==>_MothTaskLine


; Строки заданий (через @LF) в очередь Moth, Moth при необходимости запускается.
; Недоставленное (Moth не принял за $gc_iCopyDataQueueSendMs) дописывается в %TEMP%\Moth\Moth.log
Func _MothSendTasks($sLines)
	If _CopyDataQueue_Send($gc_sIpcMoth, $sLines, '"' & @ScriptDir & '\Moth.exe"') Then Return True
	Local $iSent = @extended, $sLost = ''
	For $sLine In StringSplit($sLines, @LF, $STR_NOCOUNT)
		If $sLine = '' Then ContinueLoop
		If $iSent > 0 Then
			$iSent -= 1
		Else
			$sLost &= @CRLF & '    ' & $sLine
		EndIf
	Next
	DirCreate($gc_sTmpPath)
	Local $hLog = FileOpen($gc_sTmpPath & '\Moth.log', BitOR($FO_APPEND, $FO_UTF8))
	FileWrite($hLog, '=== ' & @YEAR & '.' & @MON & '.' & @MDAY & ' ' & @HOUR & ':' & @MIN & ':' & @SEC & _
			' Moth did not accept the tasks:' & $sLost & @CRLF & @CRLF)
	FileClose($hLog)
	Return False
EndFunc   ;==>_MothSendTasks


; Файл как UTF-8 с BOM и без: FileRead без флага без BOM читает CP1251 и портит кириллицу.
; Переводы строк приводятся к CRLF: ini правят руками в разных редакторах, а Moth пишет его с CRLF
Func _ReadFileUTF8($sPath)
	Local $hFile = FileOpen($sPath, $FO_UTF8)
	If $hFile = -1 Then Return ''
	Local $sContent = FileRead($hFile)
	FileClose($hFile)
	Return StringRegExpReplace($sContent, '\r\n|\r|\n', @CRLF)
EndFunc   ;==>_ReadFileUTF8


; Перезапись файла в UTF-8 с BOM. Для Moth.ini вместо IniWrite: тот пишет кириллицу в CP1251
Func _WriteFileUTF8($sPath, $sContent)
	Local $hFile = FileOpen($sPath, BitOR($FO_OVERWRITE, $FO_UTF8))
	If $hFile = -1 Then Return SetError(1, 0, False)
	FileWrite($hFile, $sContent)
	FileClose($hFile)
	Return True
EndFunc   ;==>_WriteFileUTF8


; Без Moth.ini всё молча работало бы с пустым конфигом. Зовётся из точек входа exe,
; а не при подключении: тесты подключают модуль из папки без Moth.ini
Func _MothIniRequire()
	If FileExists(@ScriptDir & '\Moth.ini') Then Return True
	; Язык берётся из этого самого ini, поэтому здесь язык системы
	_LangFile_Load(_LangFile_Resolve(@ScriptDir & '\Lang'))
	MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'IniNotFound', _
			'Settings file not found:' & @CRLF & '%1' & @CRLF & @CRLF & 'Restore the file or reinstall the application.', _
			@ScriptDir & '\Moth.ini'))
	Exit
EndFunc   ;==>_MothIniRequire


; RegWrite/RegDelete, сбойные ключи копятся в $g_sRegErrors до _MothRegReportErrors
Func _MothRegWrite($sKeyName, $sValueName, $sType, $vValue)
	Local $iRet = RegWrite($sKeyName, $sValueName, $sType, $vValue)
	If $iRet = 0 Then $g_sRegErrors &= $sKeyName & @CRLF
	Return $iRet
EndFunc   ;==>_MothRegWrite


Func _MothRegDelete($sKeyName)
	Local $iRet = RegDelete($sKeyName)
	; 1 = удалено, 0 = ключа не было (не ошибка), остальное - сбой
	If $iRet <> 1 And $iRet <> 0 Then $g_sRegErrors &= $sKeyName & @CRLF
	Return $iRet
EndFunc   ;==>_MothRegDelete


; Показывает накопленные ошибки реестра. True, если ошибок не было.
Func _MothRegReportErrors()
	If $g_sRegErrors = '' Then Return True
	MsgBox(16, $gc_sAppName, _LangFile_Format('Errors', 'RegistryFailed', _
			'Failed to update registry keys:' & @CRLF & @CRLF & '%1' & @CRLF & 'The context menu may be displayed incorrectly.', _
			$g_sRegErrors))
	$g_sRegErrors = ''
	Return False
EndFunc   ;==>_MothRegReportErrors


; Загружает язык интерфейса из [Config] Language, пустое значение - язык системы
Func _MothLangInit()
	_LangFile_Load(_LangFile_Resolve(@ScriptDir & '\Lang', _IniString_Read($gc_sMothIni, 'Config', 'Language')))
EndFunc   ;==>_MothLangInit


Func _Lang($sSection, $sKey, $sDefault = '')
	Return _LangFile_Get($sSection, $sKey, $sDefault)
EndFunc   ;==>_Lang


; Значение действия. Встроенное задано кодом, из его секции в Moth.ini берутся только ключи
; $gc_sActionIniKeys: они перекрывают заданное. Своё действие целиком в Moth.ini. Пресет окна
; размеров (Moth.Resize.<команда>) секцию не читает вовсе, так запущенный Moth понимает пресет,
; появившийся после его старта. ShortGuiTitle по умолчанию - постфикс, без постфикса - команда
Func _ActionRead($sActionName, $sKey, $sDefault = '')
	Local $sCommand = _ResizeActionCommand($sActionName)
	If $sCommand <> '' Then
		Switch $sKey
			Case 'Command'
				Return $sCommand
			Case 'FilePostfix', 'ShortGuiTitle'
				Return _ResizePostfix($sCommand)
			Case 'Icon'
				Return _ResizeIcon($sCommand)
			Case 'ContextMenuTitle'
				Return _LangFile_Format('Resizer', 'MenuTitle', 'Size %1', _ResizeLabel($sCommand))
		EndSwitch
		Return $sDefault
	EndIf

	Local $sValue = __ActionBuiltin($sActionName, $sKey)
	If @error Or StringInStr($gc_sActionIniKeys, '|' & $sKey & '|') Then
		; Default - ключа в секции нет, пустое значение - тоже значение
		Local $sIniValue = _IniString_Read($gc_sMothIni, $sActionName, $sKey, Default)
		If Not IsKeyword($sIniValue) Then Return $sIniValue
	EndIf
	If $sValue = '' And $sKey = 'ShortGuiTitle' Then
		$sValue = _ActionRead($sActionName, 'FilePostfix')
		If $sValue = '' Then $sValue = _ActionRead($sActionName, 'Command')
	EndIf
	Return $sValue <> '' ? $sValue : $sDefault
EndFunc   ;==>_ActionRead


; Значение встроенного действия, '' - ключ ему не задан. @error - действие не встроенное
Func __ActionBuiltin($sActionName, $sKey)
	For $i = 0 To UBound($gc_aActionsBuiltin) - 1
		If $gc_aActionsBuiltin[$i][0] <> $sActionName Then ContinueLoop
		Switch $sKey
			Case 'Command'
				Return $gc_aActionsBuiltin[$i][1]
			Case 'FilePostfix'
				Return $gc_aActionsBuiltin[$i][2]
			Case 'Icon'
				Return $gc_aActionsBuiltin[$i][3]
			Case 'SaveExif'
				Return $gc_aActionsBuiltin[$i][4]
			Case 'Popup'
				Return $gc_aActionsBuiltin[$i][5]
		EndSwitch
		Return ''
	Next

	Local $aMatch = StringRegExp($sActionName, '^Moth\.ColorQuantization(\d+)$', 1)
	If Not @error Then
		Switch $sKey
			Case 'Command'
				Return 'cq' & $aMatch[0]
			Case 'FilePostfix'
				Return '_cq' & $aMatch[0]
			Case 'Icon'
				Return 'Cq.ico'
		EndSwitch
		Return ''
	EndIf

	; Конвертация - в формат любой строки convert таблицы команд, имя с тем же регистром
	$aMatch = StringRegExp($sActionName, '^Moth\.ConvertTo(\w+)$', 1)
	If Not @error And _CommandTarget('to' & $aMatch[0]) <> '' And _CommandId('to' & $aMatch[0]) == 'to' & $aMatch[0] Then
		Switch $sKey
			Case 'Command'
				Return 'to' & $aMatch[0]
			Case 'ShortGuiTitle'
				; U+2192 - стрелка вправо
				Return ChrW(0x2192) & ' ' & StringUpper($aMatch[0])
			Case 'Icon'
				Return 'Format' & ($aMatch[0] = 'Jpg' ? 'Jpeg' : $aMatch[0]) & '.ico'
		EndSwitch
		Return ''
	EndIf
	Return SetError(1, 0, '')
EndFunc   ;==>__ActionBuiltin


; Список окна «Конвертировать…»: все строки convert таблицы команд по порядку
Func __ActionConvertList()
	Local $sList = ''
	For $i = 0 To UBound($gc_aCommands) - 1
		If $gc_aCommands[$i][2] = 'convert' Then $sList &= '|Moth.ConvertTo' & StringTrimLeft($gc_aCommands[$i][0], 2)
	Next
	Return StringTrimLeft($sList, 1)
EndFunc   ;==>__ActionConvertList


; Заголовок действия в контекстном меню: ContextMenuTitle из Moth.ini перекрывает
; перевод из языкового файла, так пользовательские действия задают свои названия.
; У группы форматов бывает свой перевод: ключ <действие>.<первое расширение>, например
; Moth.CompressionLosslessMeta.JPG - у JPEG метаданные называются Exif
Func _ActionTitle($sActionName, $sExtensions = '')
	Local $sTitle = StringStripWS(_ActionRead($sActionName, 'ContextMenuTitle'), 3)
	If $sTitle <> '' Then Return $sTitle
	If $sExtensions <> '' Then
		$sTitle = _LangFile_Get('Actions', $sActionName & '.' & StringUpper(StringRegExpReplace($sExtensions, '\..*', '')), '')
		If $sTitle <> '' Then Return $sTitle
	EndIf
	Return _LangFile_Get('Actions', $sActionName, '')
EndFunc   ;==>_ActionTitle


; Проверка разрядности ОС при старте exe: утилиты в Apps только x64
Func _MothRequireX64()
	If @OSArch <> 'X86' Then Return True
	MsgBox(48, $gc_sAppName, _LangFile_Get('Errors', 'OnlyX64', _
			'Only 64-bit Windows is supported.' & @CRLF & 'The application will be closed.'))
	Exit
EndFunc   ;==>_MothRequireX64


; ============================================================
; Обновления
; ============================================================

; Пишет ключи [Config] в Moth.ini. Файл перечитывается с диска: его могли поправить,
; пока программа работала. $aPairs - [ключ, значение, ключ, значение, ...]
Func _MothConfigWrite($aPairs)
	Local $sIniPath = @ScriptDir & '\Moth.ini'
	Local $sIni = _ReadFileUTF8($sIniPath)
	For $i = 0 To UBound($aPairs) - 2 Step 2
		_IniString_Write($sIni, 'Config', $aPairs[$i], $aPairs[$i + 1])
	Next
	Return _WriteFileUTF8($sIniPath, $sIni)
EndFunc   ;==>_MothConfigWrite


; Версия из прошлой проверки, если она новее этой, иначе ''. Ini читается с диска:
; проверку мог только что закончить Launcher
Func _MothUpdateAvailable()
	Local $sLatest = _IniString_Read(_ReadFileUTF8(@ScriptDir & '\Moth.ini'), 'Config', 'LatestVersion')
	If $sLatest = '' Or _UpdateCheck_CompareVersions($gc_sAppVersion, $sLatest) >= 0 Then Return ''
	Return $sLatest
EndFunc   ;==>_MothUpdateAvailable


; Пора ли автопроверке: не выключена и с прошлой прошла неделя
Func _MothUpdateCheckDue()
	Local $sIni = _ReadFileUTF8(@ScriptDir & '\Moth.ini')
	If _IniString_Read($sIni, 'Config', 'UpdateCheck', '1') = '0' Then Return False
	Return _UpdateCheck_IsDue(_IniString_Read($sIni, 'Config', 'LastUpdateCheck'), 7)
EndFunc   ;==>_MothUpdateCheckDue


; Запускает проверку отдельным процессом (Launcher.exe checkUpdate): запрос WinINet
; синхронный, и окно не должно ждать сеть. Дескриптор процесса для _MothUpdateCheckPoll или 0
Func _MothUpdateCheckStart()
	Local $iPid = Run('"' & @ScriptDir & '\Launcher.exe" checkUpdate', @ScriptDir, @SW_HIDE)
	If Not $iPid Then Return 0
	; Права: ждать процесс и узнать код выхода
	Local Const $SYNCHRONIZE = 0x00100000
	Local $aCall = DllCall('kernel32.dll', 'handle', 'OpenProcess', _
			'dword', BitOR($SYNCHRONIZE, $PROCESS_QUERY_LIMITED_INFORMATION), 'bool', False, 'dword', $iPid)
	If @error Then Return 0
	Return $aCall[0]
EndFunc   ;==>_MothUpdateCheckStart


; Состояние проверки: -1 ещё идёт, иначе код выхода Launcher (0 - успех, остальное - @error
; _UpdateCheck_LatestRelease). По завершении дескриптор закрывается и обнуляется
Func _MothUpdateCheckPoll(ByRef $hProcess)
	If Not $hProcess Then Return 1
	Local $aWait = DllCall('kernel32.dll', 'dword', 'WaitForSingleObject', 'handle', $hProcess, 'dword', 0)
	If Not @error And $aWait[0] = 258 Then Return -1 ; WAIT_TIMEOUT: ещё работает
	Local $aCode = DllCall('kernel32.dll', 'bool', 'GetExitCodeProcess', 'handle', $hProcess, 'dword*', 0)
	Local $iCode = @error ? 1 : $aCode[2]
	DllCall('kernel32.dll', 'bool', 'CloseHandle', 'handle', $hProcess)
	$hProcess = 0
	Return $iCode
EndFunc   ;==>_MothUpdateCheckPoll


; Проверка для Launcher.exe checkUpdate: дата пишется и при сбое сети, чтобы без сети
; не стучаться при каждом запуске. Найденная версия - только при ответе GitHub
Func _MothUpdateCheckRun()
	Local $sLatest = _UpdateCheck_LatestRelease($gc_sUpdateRepo, $gc_sUpdateAsset)
	Local $iError = @error
	Local $sToday = @YEAR & '.' & @MON & '.' & @MDAY
	; Нет релиза или архива в нём - новой версии нет, пустое значение. Сбой сети - версию не трогаем
	Local $aPairs[4] = ['LastUpdateCheck', $sToday, 'LatestVersion', $sLatest]
	If $iError = 1 Then ReDim $aPairs[2]
	_MothConfigWrite($aPairs)
	Return $iError
EndFunc   ;==>_MothUpdateCheckRun


; Команды ресайза читают $gc_sMothIni: подключаются после него
#include "MothResize.au3"
