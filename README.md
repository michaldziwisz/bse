# BSE

Natywna aplikacja iOS w SwiftUI zbudowana na podstawie istniejącego frontendu React i danych z `informacje.txt`.

## Zakres

- ekran główny z odczytem kursu, steru i wiatru
- tryb czytania kursu albo odchyłki od zadanego kursu
- synteza mowy lub ogłoszenia dla VoiceOver
- dźwiękowe sygnały odchyłki kursu
- trwałe ustawienia i ekran administracyjny

## Endpoint testowy

- `https://blueseaeye.eu/api/helm`
- mock ignoruje parametry query, ale aplikacja wysyła `window` i `source` zgodnie z opisem

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

## Dostępność

- interfejs oparty o natywne kontrolki SwiftUI
- pełne etykiety dostępności dla głównych kontrolek
- komunikaty zgodne z VoiceOver lub AVSpeechSynthesizer
- brak zależności od gestów wymagających precyzji

## Ograniczenia tego środowiska

W tym środowisku roboczym nie ma `swift` ani `xcodebuild`, więc lokalny build i walidacja binarki iOS nie są możliwe. Generowanie `.ipa` zostało przeniesione do workflow na macOS.
