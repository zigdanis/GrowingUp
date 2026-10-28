# App Store media

- Текущие наборы перечислены в `screenshots/families.json`: шесть карточек
  EN/RU для Dynamic Island medium, Face ID large, Home Button medium (SE 3)
  и внешнего экрана Duo. Источник и хеши каждого набора — его `source.json`.
- `native-captures/*-20261028/`: настоящие PNG с MacPro, passing summaries
  и замеры времени для выбранного кадра фейерверка.
- `previews/` и прежние папки скриншотов: архив предыдущих материалов.
  Наличие MP4 в Git не означает, что видео размещено в App Store.

Короткая инструкция для следующего агента:
[запись и изменение видео](previews/RECORDING.md).
PNG формируют `scripts/run-local-app-store-screenshots.py` и
`scripts/render-app-store-screenshots.py`; safe multi-group upload —
`scripts/app-store-families.py`. Производные версии сохраняй отдельно и
обновляй provenance после проверки. Загрузку в Apple выполняй только по поручению.

Обзор текущих материалов и receipts: [native capture report](../../docs/app-store-native-families.md).
Receipts с датой `20261028` относятся к draft 2.2.2; старые receipts описывают
предыдущие версии. Это не App Review submission. Ключи, DerivedData, xcresult
и venv не входят в архив. Симуляторы запускай по одному из постоянного
общего пула; не удаляй их после съёмки. Удержание сна требует нового разрешения Даниса.
