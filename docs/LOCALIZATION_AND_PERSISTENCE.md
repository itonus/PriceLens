# Localization and Persistence

## 1. UI languages

Required:
- English
- Russian

Use Xcode String Catalogs (`.xcstrings`).

Development language: English.

Every user-facing string must be localizable.

## 2. In-app language preference

Settings:
- System
- English
- Русский

Store preference locally.

Implement language override cleanly at the root environment.

Do not duplicate whole view trees for language variants.

## 3. OCR language is separate

Even if UI is Russian, OCR should still recognize Polish shelf labels.

Scanner OCR language set should include:
- pl-PL
- en-US/en
- ru-RU/ru

## 4. Localization quality

Do not machine-literalize important purchase-decision text without review.

Required baseline translations:

| English | Russian |
|---|---|
| Point at a product | Наведите камеру на товар |
| Barcode found | Штрихкод найден |
| Reading label… | Считываю этикетку… |
| Searching Google + Allegro… | Ищу в Google и Allegro… |
| Store price | Цена в магазине |
| Best online | Лучшая цена онлайн |
| Save | Экономия |
| Good price here | Хорошая цена здесь |
| Fair price | Нормальная цена |
| Better online | В интернете выгоднее |
| Compare carefully | Проверьте предложения |
| Exact | Точное совпадение |
| High match | Высокое совпадение |
| Possible match | Возможное совпадение |
| Open | Открыть |
| Edit | Изменить |
| Add store price | Добавить цену в магазине |
| View offers | Смотреть предложения |
| Rescan | Сканировать снова |
| No connection | Нет подключения |
| Retry | Повторить |
| Type instead | Ввести вручную |
| History | История |
| Settings | Настройки |
| Clear history | Очистить историю |

Agent must complete the catalog for every introduced string.

## 5. Locale-aware money

Display money with `FormatStyle.Currency`.

Use the money object's currency code.

For PLN:
- English may display `PLN` or `zł` according to formatter behavior.
- Russian should remain clear and consistent.

Parsing must accept provider/store source formats independent of the selected UI language.

## 6. SwiftData

Persist scan history locally.

Suggested model:

```swift
@Model
final class ScanHistoryRecord {
    var id: UUID
    var createdAt: Date
    var query: String
    var barcode: String?
    var storePriceAmount: Decimal?
    var storePriceCurrency: String?
    var bestPriceAmount: Decimal?
    var bestPriceCurrency: String?
    var decisionRawValue: String?
}
```

Adjust storage representation if SwiftData/Decimal requires a compatibility wrapper in the chosen Xcode version.

## 7. History retention

Default:
- retain recent history until user clears it.

A practical cap such as 100 or 200 records is acceptable to prevent uncontrolled growth.

If capped:
- delete oldest records automatically,
- do not surprise user with aggressive expiry.

## 8. Search cache

Separate from user history.

Search cache may expire automatically.

Do not expose cache internals in normal Settings.

## 9. Privacy

Normal operation stores:
- recognized text/query,
- barcode,
- typed price,
- normalized offer summary in history.

Normal operation does not store:
- camera frames,
- captured high-resolution product photo,
- full provider HTML,
- location,
- contacts,
- advertising identifiers.

No tracking permission should be requested.

## 10. Camera usage description

Localize `NSCameraUsageDescription`.

English:
`PriceLens uses the camera to recognize product barcodes, labels, and prices for comparison.`

Russian:
`PriceLens использует камеру для распознавания штрихкодов, этикеток и цен, чтобы сравнивать предложения.`

## 11. App-specific language testing

QA must test:
- system English,
- system Russian,
- app override English,
- app override Russian,
- switching language and returning to scanner,
- formatted prices after switch,
- scanner OCR still recognizing Polish text.
