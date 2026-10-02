#include-once

; ============================================================================
;  MothConstants.au3
;  Что умеет движок: команды, фильтры, режимы. Пользователь это не настраивает,
;  его настройки - в Moth.ini. Подключается из MothCommon.au3
; ============================================================================

; Команды движка (_CompressFile в Moth.au3 и 'resizer' - окно размеров Menu.exe). cq, percent и resize
; с числами, поэтому комбо в редакторе редактируемое
Global Const $gc_sCommandList = 'loss|lossy|web|toJpg|toJfif|toWebp|toPng|toJxl|toAvif|toHeic|toGif|toBmp|resizer|cq64|cq128|cq256|cq512|cq1024|cq2048|percent_50_0|resize_1000_1000_0_0'

; Фильтры ресайза, индекс - последнее число команды (percent_50_0 - Lanczos).
; Фото - Lanczos или RobidouxSharp, графика - Catrom или Mitchell, пиксель-арт - Point или Box
Global Const $gc_aResizeFilters = ['Lanczos', 'RobidouxSharp', 'Catrom', 'Mitchell', 'Point', 'Box']

; Режимы ресайза по пикселям, индекс - в команде resize_W_H_<режим>_<фильтр>
Global Const $gc_aResizeModes = ['Вписать', 'Заполнить', 'Заполнить и обрезать']

; Проценты в списке Resizer
Global Const $gc_sResizePercents = '10|20|30|40|50|60|70|90|200'

; Рекомендуемые размеры палитры для cq
Global Const $gc_sColorQuantStandards = '16|32|64|128|256|512|1024|2048|4096'

Global Const $gc_sThemeOptions = 'Dark|Light|System'

; Канонические пункты контекстного меню в порядке показа. Меню формата - те из них,
; что проходят _IsFormatSupported
Global Const $gc_aMenuActions = [ _
		'Moth.CompressionLossless', _
		'Moth.CompressionLossy', _
		'Moth.CompressionWeb', _
		'Moth.ColorQuantization512', _
		'Moth.ColorQuantization2048', _
		'Moth.Resizer', _
		'Moth.ConvertToJpg', _
		'Moth.ConvertToJfif', _
		'Moth.ConvertToPng', _
		'Moth.ConvertToWebp', _
		'Moth.ConvertToJxl', _
		'Moth.ConvertToAvif', _
		'Moth.ConvertToHeic', _
		'Moth.ConvertToGif', _
		'Moth.ConvertToBmp']

; Действия для папки: 'folder' нет в $SUPPORT_FORMATS_*
Global Const $gc_aFolderActions = [ _
		'Moth.CompressionLossless', _
		'Moth.ConvertToJpg', _
		'Moth.ConvertToJfif', _
		'Moth.ConvertToPng', _
		'Moth.ConvertToWebp', _
		'Moth.ConvertToJxl', _
		'Moth.ConvertToAvif', _
		'Moth.ConvertToHeic', _
		'Moth.ConvertToGif', _
		'Moth.ConvertToBmp']

; Его нельзя убрать из меню формата
Global Const $gc_sMandatoryAction = 'Moth.CompressionLossless'

; Окна-приёмники CopyDataQueue: очередь заданий Moth и первое окно Menu
; (пути остальных файлов выделения)
Global Const $gc_sIpcMoth = 'Moth.Queue.7F3A'
Global Const $gc_sIpcMenu = 'Moth.Menu.7F3A'
