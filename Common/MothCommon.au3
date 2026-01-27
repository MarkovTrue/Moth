#include-once

#include <Array.au3>
#include <IniString.au3>

Global Const _
		$FORMAT_AVIF = 'avif', _
		$FORMAT_BMP = 'bmp', _
		$FORMAT_GIF = 'gif', _
		$FORMAT_HEIC = 'heic', _
		$FORMAT_JFIF = 'jfif', _
		$FORMAT_JPE = 'jpe', _
		$FORMAT_JPEG = 'jpeg', _
		$FORMAT_JPG = 'jpg', _
		$FORMAT_PNG = 'png', _
		$FORMAT_WEBP = 'webp'

Global Const _
		$sAppName = 'Moth 1.37', _								; заголовок программы
		$sMothINI = FileRead(@ScriptDir & '\Moth.ini'), _				; путь к файлу настроек
		$sTmpPath = @TempDir & '\Moth', _							; путь к временной папке
		$sImgPath = @TempDir & '\Moth\images', _					; путь к временной папке картинок
		$sLogPathDir = @TempDir & '\Moth\logs', _					; путь к папке списка заданий
		$bRegDarkTheme = RegRead('HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'AppsUseLightTheme') == 0 ? True : False

Global Const $aExtensionWhiteList = [ _
		$FORMAT_AVIF, _
		$FORMAT_BMP, _
		$FORMAT_GIF, _
		$FORMAT_HEIC, _
		$FORMAT_JFIF, _
		$FORMAT_JPG & '.' & $FORMAT_JPE & '.' & $FORMAT_JPEG, _
		$FORMAT_PNG, _
		$FORMAT_WEBP]

Global Const _
		$SUPPORT_FORMATS_COLOR_QUANTIZATION = [$FORMAT_PNG], _
		$SUPPORT_FORMATS_RESIZE = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_LOSSY = [$FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_COMPRESSION_FOR_WEB = [$FORMAT_GIF, $FORMAT_JFIF, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JPG, $FORMAT_PNG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_PNG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JPG, $FORMAT_WEBP], _
		$SUPPORT_FORMATS_CONVERT_TO_WEBP = [$FORMAT_JFIF, $FORMAT_JPE, $FORMAT_JPEG, $FORMAT_JPG, $FORMAT_PNG], _
		$SUPPORT_FORMATS_CONVERT_TO_JPG = [$FORMAT_AVIF, $FORMAT_BMP, $FORMAT_GIF, $FORMAT_HEIC, $FORMAT_JFIF, $FORMAT_PNG, $FORMAT_WEBP]


Global $sHKLM = 'HKEY_LOCAL_MACHINE64'
Global $sRegKey = $sHKLM & '\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\'


Func _GetExtensionListExpanded()
	Return StringSplit(_ArrayToString($aExtensionWhiteList, '.'), '.', 2)
EndFunc   ;==>_GetExtensionListExpanded


Func _IsDarkTheme()
	Local $sTheme = _IniString_Read($sMothINI, 'Config', 'ThemeGUI')
	Return $sTheme = 'System' ? $bRegDarkTheme : $sTheme = 'Dark'
EndFunc   ;==>_IsDarkTheme


Func _GetThemePath()
	Return @ScriptDir & '\themes\' & (_IsDarkTheme() ? 'dark' : 'light')
EndFunc   ;==>_GetThemePath


Func _GetIconPath()
	Local $sTheme = _IniString_Read($sMothINI, 'Config', 'ThemeIcons')

	If $sTheme = 'System' Then
		$sTheme = $bRegDarkTheme ? 'Dark' : 'Light'
	EndIf

	Return @ScriptDir & '\themes\' & StringLower($sTheme)
EndFunc   ;==>_GetIconPath


Func _GetFilterNameByIndx($nIndx)
	Switch $nIndx
		Case 0
			Return 'Lanczos'
		Case 1
			Return 'RobidouxSharp'
		Case 2
			Return 'Catrom'
		Case 3
			Return 'Mitchell'
		Case 4
			Return 'Point'
		Case 5
			Return 'Box'
	EndSwitch
	Return 'Lanczos'
EndFunc   ;==>_GetFilterNameByIndx
