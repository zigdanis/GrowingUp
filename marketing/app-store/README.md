# App Store media

- `screenshots/`: 32 загруженных PNG — четыре карточки EN/RU для DI medium,
  DI large, Face ID large и Home Button medium (SE 3). Группы и native sizes —
  `screenshots/families.json`; источник каждого набора — его `source.json`.
- `native-captures/`: сохранённые PNG и passing summaries новых локальных
  screenshot captures. DI large использует прежний утверждённый набор.
- `previews/`: шесть загруженных MP4 EN/RU для DI large, Face ID large и SE 3;
  исходные записи, монтаж, музыка и скрипты сохранены рядом.

Короткая инструкция для следующего агента:
[запись и изменение видео](previews/RECORDING.md).
PNG формируют `scripts/run-local-app-store-screenshots.py` и
`scripts/render-app-store-screenshots.py`; safe multi-group upload —
`scripts/app-store-families.py`. Производные версии сохраняй отдельно и
обновляй provenance после проверки. Загрузку в Apple выполняй только по поручению.

Receipts фиксируют draft 2.1.0 и состояние Apple на момент последней проверки;
они не означают App Review submission. Ключи, DerivedData, xcresult и venv
не входят в архив. Симуляторы запускай по одному; удержание сна требует
нового разрешения Даниса.
