#include-once
#include <GuiImageList.au3>
#include <GuiListView.au3>
#include <GuiTreeView.au3>
#include <WinAPITheme.au3>

#include "FluentTheme.au3"

; ============================================================
; FluentNativeList – штатные ListView, TreeView и их заголовок в теме Fluent
; ============================================================
; Список получает тему Explorer, рамку FluentTheme и двойную буферизацию. Флажки списка
; в тёмной теме системой не перекрашиваются: картинки состояний заменяются частями темы
; кнопки (Windows 11) или готовыми PNG. По мотивам GUIDarkTheme (UEZ, WildByDesign, argumentum).

__FluentTheme_RegisterClass('SysListView32', '__FluentNativeList_ListView')
__FluentTheme_RegisterClass('SysTreeView32', '__FluentNativeList_TreeView')
__FluentTheme_RegisterClass('SysHeader32', '__FluentNativeList_Header')


Func __FluentNativeList_ListView($hGui, $hCtrl)
	_GUICtrlListView_SetExtendedListViewStyle($hCtrl, BitOR(_GUICtrlListView_GetExtendedListViewStyle($hCtrl), $LVS_EX_DOUBLEBUFFER))
	__FluentTheme_Frame($hCtrl, True)
	GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentText1)
	GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentCtrlBg)
	; DarkMode_DarkTheme рисует у списка неудачную рамку
	__FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? "DarkMode_Explorer" : "Explorer")
	If BitAND(_GUICtrlListView_GetExtendedListViewStyle($hCtrl), $LVS_EX_CHECKBOXES) Then _
			__FluentNativeList_CheckImages($hGui, _GUICtrlListView_GetImageList($hCtrl, 2), False)
	Return True
EndFunc   ;==>__FluentNativeList_ListView


Func __FluentNativeList_TreeView($hGui, $hCtrl)
	Local Const $TVS_EX_DOUBLEBUFFER = 0x0004
	__FluentTheme_Frame($hCtrl, False, True)
	GUICtrlSetColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentText1)
	GUICtrlSetBkColor(_WinAPI_GetDlgCtrlID($hCtrl), $g_iFluentCtrlBg)
	_FluentWinApi_TreeViewSetExStyle($hCtrl, $TVS_EX_DOUBLEBUFFER)
	; DarkMode_DarkTheme у дерева пока с ошибками отрисовки
	__FluentTheme_SetTheme($hCtrl, $g_bFluentDark ? "DarkMode_Explorer" : "Explorer")
	If BitAND(_WinAPI_GetWindowLong($hCtrl, $GWL_STYLE), $TVS_CHECKBOXES) Then _
			__FluentNativeList_CheckImages($hGui, _GUICtrlTreeView_GetStateImageList($hCtrl), True)
	Return True
EndFunc   ;==>__FluentNativeList_TreeView


Func __FluentNativeList_Header($hGui, $hCtrl)
	#forceref $hGui
	If Not $g_bFluentDark Then Return __FluentTheme_SetTheme($hCtrl, "ItemsView", "Header")
	Return __FluentTheme_SetTheme($hCtrl, __FluentTheme_Is24H2() ? "DarkMode_DarkTheme" : "DarkMode_ItemsView", "Header")
EndFunc   ;==>__FluentNativeList_Header


; Картинки флажков: [выключен, включён]. У дерева нулевое состояние - «нет флажка»,
; поэтому выключенный идёт дважды
Func __FluentNativeList_CheckImages($hGui, $hImageList, $bTree)
	If Not $hImageList Then Return
	Local $iSize = _GUIImageList_GetIconHeight($hImageList), $hOff, $hOn
	_GUIImageList_Remove($hImageList)
	If @OSBuild >= 22000 Then
		$hOff = __FluentNativeList_ThemePart($hGui, 0, $iSize)
		$hOn = __FluentNativeList_ThemePart($hGui, 5, $iSize)
	Else
		$hOff = _GDIPlus_BitmapCreateFromMemory(__FluentNativeList_UncheckedPng($iSize), True)
		$hOn = _GDIPlus_BitmapCreateFromMemory(__FluentNativeList_CheckedPng($iSize), True)
	EndIf
	_GUIImageList_Add($hImageList, $hOff)
	If $bTree Then _GUIImageList_Add($hImageList, $hOff)
	_GUIImageList_Add($hImageList, $hOn)
	_WinAPI_DeleteObject($hOff)
	_WinAPI_DeleteObject($hOn)
EndFunc   ;==>__FluentNativeList_CheckImages


; Флажок темы кнопки в состоянии $iState, картинка HBITMAP $iSize x $iSize
Func __FluentNativeList_ThemePart($hGui, $iState, $iSize)
	Local Const $BP_CHECKBOX = 3
	Local $hTheme = _WinAPI_OpenThemeData($hGui, $g_bFluentDark ? "DarkMode_Explorer::Button" : "Button")
	If @error Then Return SetError(1, 0, 0)
	Local $hDC = _WinAPI_GetDC($hGui)
	Local $hBitmap = _WinAPI_CreateCompatibleBitmap($hDC, $iSize, $iSize)
	Local $hMemDC = _WinAPI_CreateCompatibleDC($hDC)
	Local $hOld = _WinAPI_SelectObject($hMemDC, $hBitmap)
	_WinAPI_DrawThemeBackground($hTheme, $BP_CHECKBOX, $iState, $hMemDC, _WinAPI_CreateRectEx(0, 0, $iSize, $iSize))
	_WinAPI_SelectObject($hMemDC, $hOld)
	_WinAPI_ReleaseDC($hGui, $hDC)
	_WinAPI_DeleteDC($hMemDC)
	_WinAPI_CloseThemeData($hTheme)
	Return $hBitmap
EndFunc   ;==>__FluentNativeList_ThemePart


; PNG флажка «включён» тёмной темы (Windows 10): размеры 13, 16, 20, 26, 32, 40, 52, прочие - 16
Func __FluentNativeList_CheckedPng($iSize)
	Local $sBase64 = ""
	Switch $iSize
		Case 13
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcYOepp4t4AAADpSURBVCjPY2RgYGAwSG9o0IrMz2fjFRBgwAF+ff7w4c7mBQtO9RYWMpuVTJigm1BezszOwcGABzCzc3CI6lpYMDAwMDBGHXj/Hp8N2GxkIkUDAwMDAxuvgAATMQrvbF6Awieo6Uh9AgMDIyNuTY8ObMDQIGHqyKDiE49b06/PHxiONCTi1cDAwMDAgsxR8U1gYGBgYFjjq8hgkN6AVQMDAwMDY8LZ//+xBCsDGy/uQGX69fnDByzBijeemJnZODgkTBwciI2nm2tnzGB+cfbgQTZeAQF+BQ0NfEnp1+cPHy4v6Og4O6WyEgBYG0pIgbNupgAAAABJRU5ErkJggg=='
		Case 20
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcZJn563moAAAEdSURBVDjLY2RgYFDilVZUs66f3yqkpq/GxivAw0AieHRg46FTvQXtX58/vMXII6Vg5bfs/A42XgFeBgrAr88fPm2KNPRktmlYMFNI3UCbgULAzM7BLqRuoMGYcPb/fwYqgV+fP3xkYqAiYOMV4KeqgQwMDAyDw8B3ty4wbIo0xCrHQo5h+4oCGZz61lPuQmTDhNQMiDdwU6Qhw7tbF0g2DKeBNo3zGfYVB8INJdYwBgYGBpwJ+92tCwz7igMZDNLqGS7MbCTKMLwGkuoyogwcHAn71+cPH6hq4LtbFy5Qy7BHBzZsYOSRUlDwW3b+PBuvgACFRdeHTZGGhsy/Pn/4cH/XypU8UgoK/AoaGuQY9PryiRO7cz09vzx/8AAAGLWDCCvF1IEAAAAASUVORK5CYII='
		Case 26
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcaCxCI0dwAAAF1SURBVEjH7da9a8JAGAbwJ1pSh1iyFGqmG5wKHaQgDh10c7FTF7e4uCr4D+heyKpOuhQculgH6WICTgU1q0Uwk41Dy0EChVvs0JamBa3mQyj0mY/8eLjcy8vhI4JEyGm+VIrnZJmPiiI8xF4YhjlSVb1Rq9lPhgEAHADEc7KcrCiKV+BnmEXpw3W5POu125wgEXJ5M5n4jTixbj6RCCcrinJ8lkohoIQPIxEA4K5687kQIwQBhlmUcvJotcIeEsKe8g+tu2z0i2kMq4W1Zw78QTJgNsVFrRVMIyeSbQ4gxIj/0C7IRkhvVNHNJ8As6hnZCMVz8tcHHZgbZCMkSATZ5uAb5hYBgF9HkL0w0C9mwEffh7sbZKufwdnMLbJVI2czcHCF7PRgBYn8kVnHLEqDRuyFYYRmd61W0JA5UtX9LSfMovT1ebk8OU+nPxcJv9ctc6xpYQB4edT1+X2nw0dFkT8SRa/tmEXp9LZeH1YLBXOsaQDwBivy2deCjE70AAAAAElFTkSuQmCC'
		Case 32
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxccGixiVqgAAAGaSURBVFjD7dcxaMJQFIXhk6Skdgh9tAiZSqcigmARxKFD7OTYVad2EbcguDdduolxjEu3bNLSyUy+oSAIgUyBdJKCNJMG7ORipxSxFKOGBIp3CiHh/wgXwmOwNGJOktIVWRZzksQLhCDEmc88zzUptfV22zUp9e8z/kW+oarpsiwjgrF1VR0263UA4KKOA0AyUyjwAiHjgWEwYk6SSp1+HzFMr1oscvlGq3V8nkrFAeAFQpgKnU7DXrhNFpONK+5/ARYxzx7wfwG2rmLYrMcDsDQFw2YdE8eKHmBpCqzOA04usrhuPkcLWI6XOn3wAokOsE08EOC1fLl2mbaNBwKcFW9g6yrelLvQ4wBwsO6BbPX+JwQAV8pTaPFAgL8QYcQDA1YRE8fC5N3aOb4RYBURRhwAmFtzsdj0pQ/6AjEn7RzfGrD/G4YKmM88L674fOZ57PIxKepxTUpZW2+34wLYuqpyX5+jES8QkswUClHHna6mcQAwHhhGlIhfh1Mf4ZqU8gIhR6eiyB0mEmEv3HjQ6w0eazWnq2n+/W+c6MNyCJEgYgAAAABJRU5ErkJggg=='
		Case 40
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxccOPkCF0wAAAHRSURBVFjD7dg9a8JAGAfwRwPBgkKwFNRB4mKhUAgIxTHZHFrM0KVbXdKtDv0Ams3NrPoBBMEh0kVdVCh0Em4SdPEIVDtJwAwiFDtZ0mCLUaNXmv8UuOF+PPeS4/GAJaEEz0f5dDoqiKI/zLJwgEyHCE0HCKGSLBsTjM1jntUHHWAY7iGfv7jLZuGI6VcUBZVleTHT9S8gHWCYVLndDsY5DgjIdIhQQxKExUzXKQCAxGOhEOVFEQjJyWkoRNE+39trs+nxR1j29nk0AgLTkASBunoqFoPnZCytNYuZrntJxQEARHlR9Nz3lksgOF4gPC7QBbpAkoDGGEPtOga1mxh5QGOMoSEJYEwweRU04/wRFlLlNjnAdTh/mCUDuCvOUeA+cLaAq9O3ySbfF852BTc5ifvE2QKuJvoNuW+cLaB5wnVIJ3C2l/gnpFM4AICtXtRWECzBEdzW14y1kk7hdroHzSCncFsvsfsedIH/CmhtGJKU6QAhr9ZWVWKBQ4S8WqdeJxWISrJMGROM6QDDnF0mkyTh+hVFGbWq1b/RAv5YzOejVrVK0T7fsSvZryjKSz6T+dZEt/xjWU7K5YJxjjtUc9MYY6x1VFXrqOp7r9s1j30CYTArpz88OJ4AAAAASUVORK5CYII='
		Case 52
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAADQAAAA0CAYAAADFeBvrAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcdEaKrvmEAAAKqSURBVGje7dq/b9pAFAfwh6kIg1FQJseDdQOKGIkcdWI4MjUDwWsnPFGWSo3yB4QsmdJmbhbK0ipTnKZD1ErNZYoUQTErQuqFARypRZawFIklXeqKumkbwPiX/N18guGjOz/7WS8CfwknYizgQoFbw5hdRiiWSCbBxYyGum70KdXqhHROa7VBW1Xv+13EusDyCGUr1SonYgweTpcoytX+1pbRp3R8PTp+kcrL8vrL4+NFlE6Dx7OI0ulUXpZvv2naoN1q/QFK5WU5W6lWowvxOPgk0YV4XMhJktGj1ERFzGO2+bbZdPs+meX+ev90ddXoU8oAADzePjjwKwYAIJZIJrO71SoAQGRpJZPZfNdsQgByVsrlmFS+WISARMCFAsOtebs8TxJOxJhhlxEKCojlEWL8XAzuKw4MBCwhKASFoBAUghzNoK3C520JukSZ6v+PvIY5K+VgNNRh0G6BgCX/7tA45mfD6d8jZ8VknlUgU9rxJ8hOjOsguzGuguaBcQ00L8zUoKv9F/BGjID6uuIpzNQg86GnHu5OhJo3ZmrQ+isFYonkRCgnMFODllYy8OTw/MEopzAzFYWHopzEzFzl/odyGgMAEJEbd3e2l+HSDgg5yXGMbaD7ULFE0nGMrQ9W6/FzA2P7m4IV5TTG1iM3HqNHwehT4ETs+GvVXDpWlkfA8ij8phCCQpAfQaOhrgcFMxrqOmOdxPBzjB6ljFYnJCggrUEI0yUnJ0EBdU5rNUZrEKI1/L9L3XNFGbRVNXCjMVFz4fb7zY2AJcmPoMu9cln7cnEBMDaN'
			$sBase64 &= 'NWirqtG/vuZEjP0ykTUa6vrlXrnc+VCrmWtRS5Omfv14dMTyCHl9Zk6rE/Lp+caGuTO/2od/9DaZVL5Y5ESMWd4jI5o9SrUGIV2iKFrjd4iZH07DnAm7lTVAAAAAAElFTkSuQmCC'
		Case Else
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcZFLatj+oAAAEPSURBVDjLY2RgYGDQiioo0IrKz+eRVFBgIAK8u3XhwrWlEybc2bJwIaOKb0KCTcP8+QxkgFO9hYWMfsvPnxdSMzAgx4Avzx48YEw4+/8/AwWAiYFCQJIBdzYvYPj1+QN5BlyY2cBwbdlEBjZeAdINuDCzgeHRgY0MHrP24/fCl2cPGNb4KjJ8ef4Aq2Z02zEM4JFSYDBIq2fYkebI8OX5A4KaGRgYGFjQBVR8ExgYGBgYNkUaMvBIKuDVzMDAwIAzHby7eYGBR0oBr2asLoABIXXiEifTl+cPHpCbiN7dvHCBmYGBkVHaysODHAPOTq6oYH59+cSJL88fPuSRVFDgFJGQIDYTXZjZ0HBz3cyZABhkZ7hwets3AAAAAElFTkSuQmCC'
	EndSwitch
	Return _FluentWinApi_Base64Decode($sBase64)
EndFunc   ;==>__FluentNativeList_CheckedPng


; PNG флажка «выключен» тёмной темы (Windows 10): размеры 13, 16, 20, 26, 32, 40, 52, прочие - 16
Func __FluentNativeList_UncheckedPng($iSize)
	Local $sBase64 = ""
	Switch $iSize
		Case 13
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAAA0AAAANCAYAAABy6+R8AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcfHO4soF4AAAC3SURBVCjP7dIhDoMwGMXx1y0kX1pDFUdBsgRDgsb3BmThAuwEQyAmwWOruQQWjdxn2lROTbKR6f31+7knAKCqqrYsy1pKGWMn7z3P8zyM43gVxpguSZLaWosQwp6B1hp5nmNd11YMw/Ds+z5mZnyLiNA0DZ+klIcAAIQQoJSKT/ihP3oj7z0T0aGx1hrOOT5HUURpml62bfv4CCJCURRYluUhAMAYc8+yzCildr/nnGNrbTdN0+0FDuRGAoicao0AAAAASUVORK5CYII='
		Case 20
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcgFyEgU+oAAAD6SURBVDjL7dUhboRAFMbxB2smYAjJJMi5AVuSCYaEEEwlvQHFoirgEpDUYcsNukdoBWNIaBUWLBkzBjJiRNW6ihIq+R/gl++ppwEAYIxJnudvhJCrYRgW7Kzv+1vbti+c81nDGJOqqr4YYxZjDKSUuzCEEHieB1EUibIsH7SiKN6XZUkYY3CkOI7BcZwPnVKaDMMAR+u6DgghVx0Adp/5W1JKME3T0uGfO8ETPME/gdu2CYTQYehuXFzXfbRtm0zTdAj0fR+EELfLOI6fWZalSinEOQel1O5lYRhCEASirusn7f4C0jR9pZQme5et6yrmef5umuaZcz7/AC65XdIkaSqyAAAAAElFTkSuQmCC'
		Case 26
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABoAAAAaCAYAAACpSkzOAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcgMfMt1hcAAAEzSURBVEjH7dahbsJAAIfxf28VCyTNnbgqRPWh5uo4LB5FxfEEm8Iu6AqCR3RJXTXo4wmmeqYGTUXPlGAaZkaCL12ypN8L/Ozn4DfOeTCbzd6n06kaDAYULSrL8pTnuc6ybF2W5QkAHACQUiql1IYQQvM8h7W2jQPGGIQQaJrGJknycTwevxzOeRDH8be1lqZp2hp5xKIogud5drVavb0opTaj0Sjc7XZPQwDger2iKAqEYfjqui7IeDyWxpinIveqqoIxBlJKRTjnQRfIIzYcDinBH9VDPdRDPdRD/xK6XC6WUtoZwBjD+Xw+Ea11IoRAF9h9Uowxmuz3++3tdrNRFD0VY4xhsVigaRqbZdnaAYDJZKKWy2W3u/U4kPP5/FMIIX3fD9pAdV1brXVyOBy294H8AUHOkTVbUaKIAAAAAElFTkSuQmCC'
		Case 32
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxciEmN8xecAAAF/SURBVFjD7ZexiqtAFIb/mFsYheA8gt0y8wDZLpIpAuNL2KTe7JOsWy23tMgjjEWQ4EJe4UxpLqRMoY1ikeJWguUWidvMVw2HA/8Hc5p/hhFCiEgp9SaEiDzPC/BAuq5riKjM8/yTiMphPhseSZKkSqm3vu9BRGia5pH5YIwhDEMwxqC1TrMseweAP+Pw8/mM0+mEvu/xLDabDeI43gNAlmXvcyFEtNvtvoqiwPF4xP1+xzO5XC5wXRdSylci+p4nSfLhed7L4XDAVFyvV6xWKyyXy8ARQkRVVWFK+r6HMQZCiMjxPC949MH9hLqu4ft+4OCXsQJWwApYAStgBayAFbACTtd1TRAEkwczxtC2beMQUck5h+u6kwqEYQgiKh2t9edisYCUcrJwKSUYY8jzPJ3fbrd/vu8HUsrXobk8C9d1sd1usV6vobVOi6L4Oy6nH0qpfV3XqKrqKeV0+OpxOZ2Nlzjn6ziO95zzyPf9h15m27aNMabUWqfGmO9h/h/YFp4sUeI9ggAAAABJRU5ErkJggg=='
		Case 40
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAACgAAAAoCAYAAACM/rhtAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxciKdJ3LMMAAAIZSURBVFjD7dg9q9pQAMbx5/oC1SDEIXAzeZIxLiG+cDFLuxWXOqiLiwX3+g2u2br1gqAfoZQsdnDoVC5IoAbfBuMgmDgJOphB5YBLJ0UunVXo+U+Bs/zI4SzPA96UTCbfp9PpT9lstiAIAsEV8jxv7Hne2DRNY7PZeJdnD6ePaDTKl8vlRj6f/4Ib1u12X0zTNA6Hg38GRqNRvtFo/CaEqJRS9Ho9uK4L13WvghJFEbquQ9M0AIDrumPDMD4cDgc/CACVSuVrJpMpbLdbtNttzGYz+L5/tb+22+3gOA6GwyEURYEoio/hcPjdZDL5FRQEgdTr9e8A0Gw2rwp7G6UUs9kMqVQKiqI8TafT12C1Wv1GCFEHgwFGoxFuHaUUoVAIsixjv9/7AUmSVACwLAv30mKxAABks9lCIJFIqACwWq3uBnh6nIIgkADuPAZkQAZkQAZkQAZkQAZkQAZkQAZkwP8aeBoMJUm6G5QoiqeFYRywbbsDALIs3w1Q13UAwHK5HAf6/f5PAMjlcuB5/ua4eDx+HjJN0zSCm83G4ziOVxTlSVEUOI4DSunNcLVaDZFIBN1u98WyrB9BAJjP539UVf0oiuKjruvgeR6+72O3210FJssyNE1DsVhELBaD67rjVqv1+Xg80vOIznEcXyqVnvP5fP2WV/zPEf0yQRBIqVR6JoSohBD1Gqj1eu3Ztt2xbbvjOM7r5dlfsTLTT1G4ptgAAAAASUVORK5CYII='
		Case 52
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAADQAAAA0CAYAAADFeBvrAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcjAxDX1FQAAAKhSURBVGje7dqxbtpQGAXgg5tICBYzGMmejEd7SRPIksFXYmAMDwCK2apkaRZeIkOmsDAkFi+QPgDIlpLFCDWLPWKzxKo9xIuRxw7RRYQmkSpVAlf3bFw83E/31z+dAj6IpmmkXq+fappGqtWqXCqVeGwxy+UyiaIocF3Xsm3bDILg6b3vCpsHgiDIFxcXt6qqEuxwHMe5N03zMo7j4EMQIcQwDON6/TXm8znCMESWZVsFFItFiKIIRVFWZ2maJnd3d99t2zb/ABFCjPPz81v6++HhAZPJZOuQzVQqFTSbTRweHq7Obm5uDIoq0DG7urr6WSqV+CzLMBqN4Pv+Lk8carUaut0uisUi0jRN+v3+1ziOAw4A1scsDxgA8H0fo9EIAFAul3k6XZwsyweNRqMNALPZLBeYddTj4+NqK6uqSjhCyBn9YDweI29Zv3Oj0TjlNE0jdJslSZI7UJZlmM/nAABVVQknCIIMAGEYIq+hd69WqzJHl8Guree/fSW6HDj8Z2EgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBmIgBvrHoOVymQCvPYC8ht49TdOEo00MURRzC5IkCQAQRVHAua5rAYCiKLl8pUqlglqtBgDwPM/iHMf5Qf9sNpu5A63f2bIsk/M8z6KvdHJystLmIYqirCoyjuPcLxaLJw4ABoNBjy6HTqeTC5SiKOh0OqtlYJrmJQB8AV67aC8vL7+Oj4/b+/v7ODo6As/zO9HCem+jtVottNtt7O3tAQCGw+E3z/NsYKNepuu60ev13tTLfN/H'
			$sBase64 &= '8/PzTtTLJEl6Mz2f1stoBEGQDcO4pv2fXY3rutZgMOh9WgBcjyzLB7qun2maRgRBkMvl8lYrmmmaJnEcB67rWtPp9J6O2GZ+A6oXHMXfWhlTAAAAAElFTkSuQmCC'
		Case Else
			$sBase64 &= 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IB2cksfwAAAARnQU1BAACxjwv8YQUAAAAgY0hSTQAAeiYAAICEAAD6AAAAgOgAAHUwAADqYAAAOpgAABdwnLpRPAAAAAlwSFlzAAAOwwAADsMBx2+oZAAAAAd0SU1FB+oDAxcfO0smFTUAAADBSURBVDjL7cyhDYNAGIbhD1qFqzhxijsmYAOQDZcQgkIg2IDK7oBou0HrCYIEsGxQNvjPkYBlgK5wpJbXP68FAEqpWxRFJWNMwCCt9dT3/XMcx885DMMijuNHXdcgIhMPzrmf5/nbcZyLVVXVt21bf55n7ElKiSRJtO267m4MAEQExpiw8WfH4BgAgL2uq5ZS7oaccxDRdAJgpWl6JSJs22aEPc9DlmVomuZuAUAQBIVSqhRC+CaDZVl013XPYRheP/vGQ/mk4/+CAAAAAElFTkSuQmCC'
	EndSwitch
	Return _FluentWinApi_Base64Decode($sBase64)
EndFunc   ;==>__FluentNativeList_UncheckedPng
