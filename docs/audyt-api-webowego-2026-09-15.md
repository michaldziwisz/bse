# Audyt webowego API BlueSeaEye wobec naszych klientów (iOS + Android)

Data: 15.09.2026. Zlecenie: „przejrzyj webowe API https://blueseaeye.eu/ i daj znać,
czy czegoś nam jeszcze brakuje jeśli chodzi o wywołania w implementacji rozwiązania
hardware'owego po wifi". Raport przed implementacją, nic w kodzie nie zostało zmienione.

## Najważniejsze ustalenie w jednym zdaniu

Po stronie wywołań HTTP nie brakuje nam **niczego, co realny sprzęt potrafi obsłużyć**.
Frontend producenta ma trzy funkcje więcej niż my, ale wszystkie trzy uderzają w ścieżki,
których firmware nie wystawia. Brakuje nam natomiast dwóch rzeczy naprawdę użytecznych:
odczytu `/api/info` oraz parametru `disableRudder`, który w firmware istnieje i nikt
z niego dotąd nie korzysta.

## Co dokładnie badałem i czym to potwierdzam

Trzy niezależne źródła, żeby żaden wniosek nie opierał się na jednym poszlaku:

1. **Pełne źródła frontendu producenta** w repo, katalog `BSE frontend` (nie tylko
   zminifikowany `main.js`, jak przy poprzednich analizach). Autor: blazejwolanczyk,
   projekt „helm-reader / Helm reader for See the Sea", React + axios.
2. **Żywy serwer** https://blueseaeye.eu — odpytany bezpośrednio.
3. **Binarki firmware**: `firmware.bin` (build Jul 11 2026) oraz
   `firmware-backup/backup-full-4MB.bin` (starszy stan), czytane jako literały
   zakończone NUL-em, nie zwykłym szukaniem podciągu.

## Sprostowanie do samej nazwy „webowe API"

`blueseaeye.eu` **nie jest API sprzętu**. To serwer demonstracyjny: dokładnie ten sam
plik `server.js`, który leży u nas w `BSE frontend`. Symuluje kurs błądzeniem losowym
wokół północy (`setInterval` co 250 ms, wygładzanie `(course*49 + new)/50`) i **ignoruje
wszystkie parametry zapytania**. Pomiar:

```
GET https://blueseaeye.eu/api/helm        -> 200, wszystkie pola łącznie z wa
GET https://blueseaeye.eu/api/info        -> 404
GET https://blueseaeye.eu/api/nmea        -> 404
GET https://blueseaeye.eu/api/gps         -> 404
GET https://blueseaeye.eu/api/set?beta=.. -> 404
GET https://blueseaeye.eu/api/calibrate   -> 404
GET https://blueseaeye.eu/api/reboot      -> 404
```

Konsekwencja praktyczna, ważna przy każdym przyszłym teście: **serwer demo nie nadaje
się do sprawdzania niczego poza `/helm`**. Nasz tryb demonstracyjny w aplikacjach jest
więc poprawny (czyta tylko `/helm`), ale nie da się nim przetestować kalibracji,
restartu ani informacji o urządzeniu.

## Co firmware realnie wystawia

Cztery ścieżki, potwierdzone jako pełne literały w binarce:

| ścieżka | nowy firmware (Jul 11 2026) | starszy backup |
|---|---|---|
| `/api/helm` | jest | jest |
| `/api/info` | jest | jest |
| `/api/reboot` | jest | jest |
| `/api/calibrate` | jest | **brak** |
| `/api/nmea` | brak | brak |
| `/api/gps` | brak | brak |
| `/api/set` | brak | brak |

Uwaga metodyczna, bo sam się na to nabrałem w trakcie: pierwsze szukanie pokazało
w firmware `/set`, co wyglądało na potwierdzenie endpointu z frontendu. To było
**fałszywe trafienie** — podciąg literału `/settings`, który jest trasą ekranu ustawień
w przeglądarce (stoi w binarce obok `/index.htm` i `.gz`, czyli przy obsłudze plików
statycznych), a nie żadnym endpointem. Podobnie `wa` nie istnieje jako osobne pole
w firmware. Dlatego liczy się tylko test na literał zakończony NUL-em.

## Trzy funkcje frontendu, których nie mamy — i dlaczego to nie luka

Wszystkie trzy są w kodzie producenta **zdefiniowane, ale nigdzie nie wywoływane
z interfejsu**:

1. **`GET /api/nmea`** (`getNmeaReadings`) — odczyt NMEA 2000. W kodzie widoku głównego
   stoi wprost komentarz autora: `// TODO: add nmea data screen?`. Ekranu nie ma,
   firmware ścieżki nie zna.
2. **`GET /api/gps`** (`getGpsReadings`) — odczyt z wbudowanego GPS. Też bez UI,
   też nieobsługiwane przez firmware.
3. **`GET /api/set?beta=<liczba>`** (`setSettings`) — ustawianie współczynnika filtra IMU.
   Ma nawet gotowe polskie tłumaczenia („Współczynnik korekcji kursu za pomocą GPS",
   „Ustaw współczynnik korekcji" plus komunikaty sukcesu i błędu), ale pole `beta`
   **nie istnieje w liście ustawień frontendu ani w jego formularzu**, a `/api/set`
   nie istnieje w firmware. To porzucony albo przyszły pomysł producenta.

Wniosek: implementowanie ich u nas teraz oznaczałoby dokładanie wywołań, które na tym
sprzęcie zwrócą 404. Nie warto, dopóki producent nie potwierdzi, że wchodzą do firmware.

## Czego brakuje nam naprawdę — dwie rzeczy

### 1. `GET /api/info` — mamy zero użycia, a firmware to obsługuje

Endpoint jest w OBU wersjach firmware i zwraca (z literałów binarki) `model`, `issued`
(data i godzina builda, u nas „Jul 11 2026" / „22:09:46"), `version` (1.0.0) oraz
flagę `mock`. Żaden nasz klient go nie odpytuje — sprawdzone, zero trafień
w kodzie iOS i Androida.

Co nam to daje:
- **Flaga `mock` rozstrzyga sprawę, która już raz nas kosztowała sesję.** W trybie
  symulacji urządzenie nie emituje `rsa`, więc aplikacja pokazuje „Ster nieznany"
  i chowa sekcję zaawansowaną. Dziś wygląda to identycznie jak awaria czujnika.
  Z `/api/info` możemy powiedzieć wprost: „urządzenie pracuje w trybie symulacji".
- **Wersja firmware pozwala warunkować funkcje.** `/api/calibrate` istnieje tylko
  w nowszym buildzie — dziś kalibracja na starszym sprzęcie po prostu zwróci błąd
  bez wyjaśnienia. Znając `issued`, można albo ukryć akcję, albo powiedzieć czemu nie działa.
- **Diagnostyka zgłoszeń.** Przy „u mnie nie działa" wersja firmware w ekranie
  informacyjnym oszczędza całą rundę pytań.

### 2. `disableRudder` — parametr istnieje w firmware, nasze klienty go nie wysyłają

Należy do query stringu `/api/helm` (w binarce siedzi w tym samym bloku co
`source`, `window`, `rsa`), występuje **tylko w nowszym firmware**, a frontend
producenta go nie używa. Nasze aplikacje wysyłają wyłącznie `time`, `source`, `window`.

Wartość dla Ciebie: dziś wyłączenie odczytu steru mamy zrobione po stronie aplikacji
(przełącznik „Odczytuj wychylenie steru", Android) — czyli sprzęt nadal liczy i wysyła
`rsa`, a my go przemilczamy. `disableRudder` gasi to u źródła. Różnica jest realna
głównie wtedy, gdy chodzi o odciążenie urządzenia, nie o samo brzmienie komunikatów.

Ograniczenie, które trzeba powiedzieć wprost: **empirycznie nie da się tego dziś
potwierdzić na Twoim egzemplarzu**, bo w trybie mock urządzenie w ogóle nie emituje
`rsa`, więc nie ma czego gaszić i nie ma punktu odniesienia. Zweryfikować da się to
tylko na sprzęcie z żywym czujnikiem steru albo na naszym własnym mocku firmware.

## Co mamy zgodne z frontendem 1:1 (sprawdzone, nie założone)

- Ścieżka i parametry `/helm`: `time` (epoch w milisekundach), `source`, `window`
  (`averageWindow * 1000`). Zgodne w obu naszych klientach.
- Sześć źródeł kursu: `cgfa`, `coga`, `hdga`, `cgf`, `cog`, `hdg` — pełny zestaw, jak w firmware.
- Kolejność szukania pól: `wa` jako wiatr, `rsa` jako ster, kurs z wybranego źródła.
- Poprawka i odwrócenie steru liczone w tym samym momencie co u producenta
  (`(rsa + korekta) * (odwrócenie ? -1 : 1)`).
- Trzy próby ponowienia przy błędzie odczytu — u nas `retrying(3)`, u producenta
  `axios-retry` z `retries: 3`. Zgodne.
- `/calibrate` i `/reboot` — mamy oba, tak samo jako zwykły GET bez treści.
- Matematyka tonu odchyłki i próg tolerancji — identyczne wykładniki.

## Jedna różnica bez znaczenia praktycznego

Frontend **pomija** parametr `window`, gdy okno uśredniania nie jest ustawione; my
wysyłamy je zawsze (wartość domyślna 3 sekundy, przycięta do zakresu 1–5). To bezpieczny
kierunek — HTTP 400 groziło za surową wartość 1–5 zamiast milisekund, a nie za samą
obecność parametru. Nie ma tu nic do naprawiania.

## Rekomendacja: co warto zrobić, w kolejności

1. **`/api/info` w obu aplikacjach** — odczyt wersji firmware i flagi trybu symulacji,
   pokazane w ustawieniach, plus wykorzystanie flagi `mock` do sensownego komunikatu
   zamiast mylącego „Ster nieznany". Najwięcej pożytku przy najmniejszym ryzyku.
   Trzeba obsłużyć starszy firmware bez `/calibrate` i sytuację, gdy `/info` zwróci 404
   (tryb demo) — brak odpowiedzi nie może wyglądać jak awaria.
2. **`disableRudder` jako świadomy przełącznik** — tylko jeśli zależy Ci na odciążeniu
   urządzenia. Wymaga zapasowej ścieżki dla starszego firmware, który parametru nie zna,
   i realnego testu na sprzęcie z czujnikiem steru.
3. **`/nmea`, `/gps`, `/set?beta`** — zostawić. Można ewentualnie zapytać Błażeja,
   czy planuje je w firmware; implementowanie teraz to kod pod 404.

## Czego ten raport NIE rozstrzyga

- Czy `disableRudder=true` faktycznie gasi `rsa` — na Twoim egzemplarzu w trybie mock
  nie ma jak tego zmierzyć.
- Jaki dokładnie kształt JSON zwraca `/api/info` na żywym sprzęcie. Znam nazwy pól
  z binarki, ale pełnej odpowiedzi nie widziałem, bo wymaga to połączenia z access
  pointem BlueSeaEye. Przed implementacją warto jedno zapytanie curl na żywo.
