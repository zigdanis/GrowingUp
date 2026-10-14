# Как повторить App Store Preview

Здесь лежат шесть загруженных EN/RU MP4, `sources/` с использованными нативными
записями и монтажом, `support/` со скриптами и музыкой. SHA256 и подтверждение
Apple — в `provenance.json` и `apple-upload-receipt.json`.

## Изменить монтаж без новой записи

Из корня репозитория, Python с Pillow; ffmpeg/ffprobe должны быть в PATH:

```sh
python3 marketing/app-store/previews/support/rebuild.py di en \
  --output "$HOME/Library/Logs/GrowingUpMedia/revised-di-en.mp4" --plan
```

Правь `sources/<di|face-id|home-button>/<en|ru>/edit.json`; убери `--plan` для
экспорта. `render.py` сохраняет реальную скорость, накладывает вступительную
подпись и WAV, экспортирует 25 секунд / 750 кадров / 30 fps, H.264 + AAC.
Для SE размер 750×1334, для DI/Face ID — 886×1920. Новая версия пишется отдельно.
Музыку можно изменить в `support/music/compose.py` (нужен NumPy).

## Если нужна новая запись

1. На Mac выбери отдельный совместимый simulator, держи включённым только один.
   Использовали iOS 26.5: 17 Pro Max, 14 Plus, SE 3. Caffeinate сейчас запрещён
   Данисом; запускать его можно только после нового разрешения.
2. UI-сценарий — `GrowingUpUITests/AppStoreScreenshotTests.swift`:
   `testPrepareAppPreview` создаёт вымышленные EN/RU данные, затем
   `testRecordAppPreviewWithoutConfetti` проходит Mia → Leo с popover → Mango →
   Teddy → редактор → save → Mia. Включи `GROWINGUP_APP_STORE_CAPTURE=1`, locale
   `en`/`ru`, фото `docs/app-store-demo-photos`, отдельный DerivedData вне repo.
3. `record-no-confetti.py` пишет нативный HEVC через simctl одновременно с одним
   UI-тестом; `PREVIEW_MARK` связывает сцены и запись. Конфетти отключали штатным
   Reduce Motion только на task simulator, затем восстанавливали настройку.
   Старые UUID/рабочие пути в batch-скриптах — параметры прежней сессии; замени
   их на свои. Не запускай `capture-remaining.py` вслепую.
4. `assemble.py` показывает принцип выбора сцен по markers. Исключай startup,
   teardown и SpringBoard. Для SE EN понадобилась отдельная настоящая финальная
   запись Mia (`record-end-card.py`); она сохранена рядом с основным source.
5. Проверь decode, размер, 750 кадров, сцены и финал; осмотри кадры. Upload только
   после поручения: `upload-previews.py` и `finalize-readback.py` используют CLI
   App Asset Library. Перед запуском обнови draft/catalog и рабочие пути;
   сохраняй screenshots и старые previews. Ключи в Git не класть.

Полный отчёт прежнего запуска — [README.md](README.md), проблема конфетти —
[issue #60](https://github.com/zigdanis/GrowingUp/issues/60).
