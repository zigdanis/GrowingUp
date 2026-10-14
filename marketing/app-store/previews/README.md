# GrowingUp — App Store Preview без конфетти — загружено в ASC

Пересъёмка по прямому поручению Даниса выполнена. Готовы **6 MP4**, по EN/RU для Dynamic Island, Face ID и Home Button medium. Каждое видео содержит настоящие кадры соответствующего симулятора, длится ровно25с/750кадров, экспортировано в30fps H264 High Level4.0 progressive, около11Mbps, stereoAAC256kbps/48kHz, MP4 faststart. Размер каждого файла — около35MB.

| Вариант | EN | RU | Экспорт | Нативный источник |
|---|---|---|---|---|
| Dynamic Island large | `dynamic-island-en-no-confetti.mp4` | `dynamic-island-ru-no-confetti.mp4` | 886×1920 | iPhone17ProMax,1320×2868 |
| Face ID large | `face-id-en-no-confetti.mp4` | `face-id-ru-no-confetti.mp4` | 886×1920 | iPhone14Plus,1284×2778 |
| Home Button medium | `home-button-se3-en-no-confetti.mp4` | `home-button-se3-ru-no-confetti.mp4` | 750×1334 | iPhoneSE3,750×1334 |

Нативные записи сделаны на iOS26.5 (23F77), Xcode26.6. UUID: DI `DD1B22DD-179E-41FE-813A-91AEAB2B522B`, FaceID `9FF8A61A-73BA-44F1-8360-76318642010E`, SE3 `F5581E72-B8D2-41EB-89D3-EA7B2939871B`. Данные сохранены в отдельных UITests stores EN/RU; личная база/AppGroup пользователя не изменялась.

Сценарий сохранён: Мия/Mia и вступительная подпись; Лео/Leo и реальный birthday popover; Манго/Mango; Тедди/Teddy; возврат свайпами, нативный редактор с фото/датой, настоящий save и финальная карточка Мии. Конфетти отключено штатной веткой accessibility Reduce Motion; исходный UI приложения не менялся. После съёмок настройки восстановлены. Устройства запускались строго по одному; все симуляторы выключены.

В SE EN тестовый teardown попадал в край первоначального монтажа. Домашний экран исключён; окончание дополнено отдельной **настоящей нативной записью Мии на том же SE3**, с тем же EN fixture. Никакие кадры других устройств, нарисованные интерфейсы, ускорение или искусственная заморозка не использовались. В остальных пяти роликах дополнительная запись не понадобилась.

Музыка «Little Days» — прежняя оригинальная композиция110BPM, математический синтез/шум без сторонних сэмплов. Все шесть AAC-дорожек побайтно совпадают с аудио исходного пилота. Данис может использовать/редактировать музыку в маркетинге GrowingUp по всему миру. Уровни проверены ранее: −20LUFS, truepeak−6,2dBFS. Агент не заявляет прослушивание: аудиовход инструмента недоступен.

Проверено: шесть успешных коротких UI-проходов без конфетти; нативные размеры; все750кадров и аудио декодируются без ошибок; параметры кодирования/faststart; полные последовательности сцен и финалы. На всех сценах просмотрены кадры, включая поздравление, редактор, сохранение и основную карточку. В конце дополнительно проверено отсутствие сигнатуры SpringBoard. Непрерывный просмотр/прослушивание человеком не заявляется.

Сам дефект конфетти **не исправлен в приложении**: создан [issue#60](https://github.com/zigdanis/GrowingUp/issues/60). Старый `dynamic-island-en.mp4` оставлен только для сравнения дефекта; его provenance — `provenance-with-confetti-pilot.json`. Текущие hashes, native timestamps, sourcecommit, UUID, дополнительные записи и exportproperties — `provenance.json`.

Все исходники, фото fixture, музыкаWAV, NativeMP4, xcresult, DerivedData, QA-кадры и рабочие скрипты сохранены вне репозитория:
`~/Library/Application Support/GrowingUp/AppStoreMedia/preview-20261013`.

Source commit `0d60b645b4bf42d98f5c294079b9e59c10a730ca`; diff касается только локальной автоматизации UI-capture. Тестовая база и часы — существующая opt-in конфигурация; исходный clock `2027-01-16T08:24:12Z` плюс реальное время. Supplemental SE EN clock записан отдельно в provenance. Копии вспомогательных скриптов — `support`; рабочие пути — в устойчивом каталоге.

14 октября 2026 по явному поручению Даниса все шесть роликов загружены через локальный Python CLI в существующий черновик GrowingUp **2.1.0** (`4dccceea-13f4-4f10-8153-d1106ec1731c`). Fresh API read-back: все шесть video assets `PREPARE_FOR_SUBMISSION`, постеры `COMPLETE`, placements `ACTIVE`. Новые ролики поставлены первыми в своих трёх группах для EN/RU. Прежние32скриншота и8превью сохранены, удалений нет. Черновик остаётся `PREPARE_FOR_SUBMISSION`; App Review, новый бинарный релиз, TestFlight, Cloud CI, push и PR не выполнялись. Подтверждения Apple и IDs — `apple-upload-receipt.json`; workflow соответствует [Apple video assets](https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-video-assets) и [asset placements](https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces). Локальные MP4 сохранены для просмотра. API подтверждает собственные размещения в целевых DI large, Face ID large и Home Button medium; наследование прочих групп не заявляется. Требования экспорта сверены по [Apple App Previews](https://developer.apple.com/app-store/app-previews/) и [App Preview Specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/).
