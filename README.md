# BSE

Natywna aplikacja iOS w SwiftUI zbudowana na podstawie istniejącego frontendu React i danych z `informacje.txt`.

## Zakres

- ekran główny z odczytem kursu, steru i wiatru
- tryb czytania kursu albo odchyłki od zadanego kursu
- synteza mowy lub ogłoszenia dla VoiceOver
- dźwiękowe sygnały odchyłki kursu
- trwałe ustawienia i ekran administracyjny

## Połączenie z urządzeniem

Aplikacja współpracuje bezpośrednio z urządzeniem BlueSeaEye pracującym w
trybie access pointa:

1. Na urządzeniu iOS połącz się z siecią Wi-Fi `BlueSeaEye` (hasło `blueseaeye`).
2. Urządzenie udostępnia API pod bramą SoftAP `http://192.168.4.1/api`.
   Adres jest konfigurowalny w zakładce Ustawienia → sekcja „Urządzenie"
   (pole „Adres urządzenia"); akceptuje samo IP/nazwę hosta lub pełny URL,
   a przycisk przywraca wartość domyślną `192.168.4.1`.
3. Aplikacja odpytuje `GET /api/helm` z parametrami:
   - `time` – znacznik czasu w milisekundach (cache-busting),
   - `source` – wybrane źródło kursu (klucz pola jak w odpowiedzi),
   - `window` – okno uśredniania w **milisekundach** (`averageWindow * 1000`,
     zakres 1000–5000).

Uwaga: urządzenie zwraca HTTP 400 dla `window` podanego w surowej wartości 1–5;
poprawny jest wyłącznie zapis w milisekundach. Parametr czasu musi nazywać się
`time` (nie `t`). Kontrakt odtworzono z wbudowanego w urządzenie frontendu.

Odpowiedź (wartości przekazane, jeśli dostępne):

- `cgfa`/`cgf` – kurs filtrowany (uśredniany / chwilowy)
- `coga`/`cog` – kurs nad ziemią (uśredniany / chwilowy)
- `hdga`/`hdg` – kurs kompasowy (uśredniany / chwilowy)
- `rsa` – wychylenie steru
- `wa` – kąt do wiatru (jeśli czujnik obecny)

### Mock referencyjny

Historyczny mock `https://blueseaeye.eu/api/helm` (ignoruje parametry query)
pozostaje dostępny do testów bez sprzętu, ale docelowym źródłem danych jest
urządzenie w sieci `BlueSeaEye`.

## Uruchomienie na Macu

1. Zainstaluj `xcodegen`.
2. Wejdź do `ios/BSE`.
3. Uruchom `xcodegen generate`.
4. Otwórz `BSE.xcodeproj` w Xcode i zbuduj aplikację na urządzenie albo symulator.

## IPA dla Sideloadly

Repo zawiera workflow GitHub Actions `ios-ipa`, który:

- generuje projekt Xcode z `project.yml`
- buduje unsigned archive dla iOS
- pakuje `BSE.app` do `BSE.ipa`
- publikuje plik jako artefakt workflow

Taki plik `.ipa` można następnie wskazać w Sideloadly do lokalnego podpisania.

## Administracja

Akcje administracyjne urządzenia (kalibracja żyroskopu, restart) są obecnie
ukryte flagą `FeatureFlags.administrationEnabled` w `RootView.swift`, ponieważ
bieżący firmware urządzenia zwraca dla `GET /api/calibrate` i `GET /api/reboot`
HTTP 404. Aby przywrócić zakładkę Administracja, ustaw tę flagę na `true`, gdy
urządzenie zacznie udostępniać te endpointy.

## Dostępność

- interfejs oparty o natywne kontrolki SwiftUI
- pełne etykiety dostępności dla głównych kontrolek
- komunikaty zgodne z VoiceOver lub AVSpeechSynthesizer
- brak zależności od gestów wymagających precyzji

## Ograniczenia tego środowiska

W tym środowisku roboczym nie ma `swift` ani `xcodebuild`, więc lokalny build i walidacja binarki iOS nie są możliwe. Generowanie `.ipa` zostało przeniesione do workflow na macOS.
