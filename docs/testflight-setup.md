# Wysyłka BSE do TestFlight z GitHub Actions (bez Maca)

Ten dokument prowadzi krok po kroku, co założyć w Apple i GitHubie, żeby workflow
`.github/workflows/ios-testflight.yml` mógł zbudować podpisaną aplikację na
runnerze macOS w chmurze i wysłać ją do TestFlight. Nie potrzebujesz fizycznego
Maca — całość robi runner GitHuba.

Repo jest publiczne, więc minuty macOS są DARMOWE. Bezpieczeństwo: patrz sekcja
na końcu — najważniejsze, że sekrety są niedostępne dla PR-ów z forków, a job
odpala się tylko ręcznie z gałęzi main.

WAŻNE: pliki .p12, .mobileprovision, .p8 oraz hasła NIGDY nie trafiają do repo.
Wklejasz je wyłącznie do GitHub Secrets. Ten dokument może być w repo (nie ma w
nim żadnych sekretów).

────────────────────────────────────────────────────────────
CZĘŚĆ A — APPLE (w przeglądarce, jednorazowo)
────────────────────────────────────────────────────────────

A1. Konto Apple Developer
    - Załóż płatny program Apple Developer (99 USD/rok) na developer.apple.com.
      TestFlight wymaga płatnego konta.
    - Zapisz swój TEAM ID: developer.apple.com → Membership details → „Team ID”
      (10 znaków, np. ABCDE12345). To będzie sekret APPLE_TEAM_ID.

A2. App ID (identyfikator aplikacji)
    - developer.apple.com → Certificates, IDs & Profiles → Identifiers → „+”.
    - Wybierz „App IDs” → „App”. Bundle ID: WPISZ DOKŁADNIE  eu.blueseaeye.bse
      (typ: Explicit). Zapisz.
    - Uprawnienia (Capabilities): BSE nie używa push/iCloud itd. Jeśli w przyszłości
      dodamy „Hotspot Configuration” (trzymanie sieci urządzenia), trzeba je tu
      zaznaczyć i odświeżyć profil — na teraz nie jest wymagane.

A3. Rekord aplikacji w App Store Connect
    - appstoreconnect.apple.com → Apps → „+” → New App.
    - Platforma: iOS. Nazwa: BlueSeaEye (lub BSE). Język podstawowy: polski.
    - Bundle ID: wybierz eu.blueseaeye.bse (z listy z A2). SKU: dowolny unikat
      (np. bse-ios). Utwórz.

A4. Certyfikat dystrybucyjny (Apple Distribution) — BEZ Maca, przez openssl
    Robimy w WSL. Generujemy klucz + CSR, wgrywamy CSR do Apple, pobieramy .cer,
    składamy w .p12.

    W WSL (katalog roboczy dowolny, np. ~/bse-signing — NIE w repo):
      mkdir -p ~/bse-signing && cd ~/bse-signing
      # 1. klucz prywatny
      openssl genrsa -out dist.key 2048
      # 2. CSR (CN/e-mail dowolne, Apple i tak nadpisze tożsamość)
      openssl req -new -key dist.key -out dist.csr \
        -subj "/emailAddress=michal@dziwisz.net/CN=BlueSeaEye Distribution/C=PL"

    - Wejdź: developer.apple.com → Certificates → „+” → wybierz
      „Apple Distribution” → Continue → wgraj plik dist.csr → Continue.
    - Pobierz wygenerowany certyfikat (distribution.cer) do ~/bse-signing.
    - Złóż klucz + certyfikat w .p12 (ustaw JAKIEŚ hasło — zapamiętaj je):
      # konwersja .cer (DER) na PEM
      openssl x509 -inform DER -in distribution.cer -out dist.crt
      # .p12 (poda o hasło eksportu — to będzie APPLE_DIST_CERT_PASSWORD)
      openssl pkcs12 -export -legacy \
        -inkey dist.key -in dist.crt -out dist.p12 -name "Apple Distribution"
      (jeśli Twój openssl nie zna -legacy, pomiń tę flagę.)

A5. Profil provisioning (App Store)
    - developer.apple.com → Profiles → „+” → Distribution → „App Store” →
      Continue.
    - App ID: eu.blueseaeye.bse. Certyfikat: ten z A4. Nazwa profilu: np.
      „BSE App Store”. Wygeneruj i pobierz plik .mobileprovision do ~/bse-signing.

A6. App Store Connect API Key (do uploadu bez Apple ID/2FA)
    - appstoreconnect.apple.com → Users and Access → zakładka „Integrations”
      → „App Store Connect API” → „+” (Generate API Key / Team Key).
    - Nazwa: np. „GitHub CI”. Rola: „App Manager” (wystarcza do wysyłki buildów).
    - Po utworzeniu zapisz:
        * Key ID   → sekret ASC_KEY_ID
        * Issuer ID (na górze listy) → sekret ASC_ISSUER_ID
        * Pobierz plik AuthKey_XXXXXX.p8 — UWAGA: pobierasz TYLKO RAZ.
          Zapisz go w ~/bse-signing.

────────────────────────────────────────────────────────────
CZĘŚĆ B — ZAMIANA PLIKÓW NA BASE64 (w WSL)
────────────────────────────────────────────────────────────

GitHub Secrets przyjmuje tekst, więc pliki binarne kodujemy base64. Wykonaj w
~/bse-signing (użyj `-w0`, żeby nie było zawijania wierszy):

    base64 -w0 dist.p12 > dist.p12.b64
    base64 -w0 *.mobileprovision > profile.b64
    base64 -w0 AuthKey_*.p8 > asckey.b64

Zawartość tych .b64 wkleisz jako wartości sekretów (całą linię).

────────────────────────────────────────────────────────────
CZĘŚĆ C — GITHUB: ENVIRONMENT + SEKRETY
────────────────────────────────────────────────────────────

C1. Utwórz environment `release`
    - GitHub → repo michaldziwisz/bse → Settings → Environments → „New
      environment” → nazwa: release.
    - (Zalecane) „Deployment branches and tags” → „Selected branches” → dodaj
      regułę na `main`. Dzięki temu sekretów można użyć tylko z maina.

C2. Dodaj 7 sekretów W TYM environment (Settings → Environments → release →
    „Add secret”). Nazwy MUSZĄ być dokładnie takie:

    APPLE_TEAM_ID                 = Team ID z A1 (np. ABCDE12345)
    APPLE_DIST_CERT_P12_BASE64    = zawartość dist.p12.b64
    APPLE_DIST_CERT_PASSWORD      = hasło eksportu .p12 z A4
    APPLE_PROVISIONING_PROFILE_BASE64 = zawartość profile.b64
    ASC_KEY_ID                    = Key ID z A6
    ASC_ISSUER_ID                 = Issuer ID z A6
    ASC_KEY_P8_BASE64             = zawartość asckey.b64

C3. (Bezpieczeństwo) Settings → Actions → General:
    - „Fork pull request workflows from outside collaborators” → zostaw
      „Require approval for all outside collaborators” (domyślne). Sekrety i tak
      nie idą do forków, to dodatkowa bariera.

────────────────────────────────────────────────────────────
CZĘŚĆ D — WYSYŁKA
────────────────────────────────────────────────────────────

1. Upewnij się, że wersja jest podbita (App Store Connect odrzuca powtórzony
   build number): w ios/BSE/project.yml pola MARKETING_VERSION i
   CURRENT_PROJECT_VERSION. Każdy nowy upload do TestFlight musi mieć wyższy
   CURRENT_PROJECT_VERSION (build) niż poprzedni.
2. GitHub → repo → Actions → workflow „ios-testflight” → „Run workflow”.
   - Branch: main.
   - Pole „confirm”: wpisz  tak
   - Run.
3. Job zbuduje, podpisze, wyeksportuje i wyśle build. Po ~kilku–kilkunastu
   minutach build pojawi się w App Store Connect → TestFlight (status „Processing”
   przez chwilę, potem gotowy do testów).
4. Pierwsze uruchomienie: jeśli coś nie zagra (najczęściej nazwa profilu albo
   uprawnienia klucza API), poprawimy jedną iteracją — to normalne przy pierwszym
   podejściu.

────────────────────────────────────────────────────────────
DLACZEGO TO JEST BEZPIECZNE PRZY PUBLICZNYM REPO
────────────────────────────────────────────────────────────

- Sekrety są zaszyfrowane i maskowane w logach; nie ma ich w kodzie.
- Przy publicznym repo pull request z forka NIE otrzymuje dostępu do sekretów —
  obcy nie odpali joba z Twoim kluczem Apple.
- Job odpala się tylko ręcznie (workflow_dispatch), tylko z gałęzi main i tylko
  po wpisaniu „tak” — czyli wyłącznie przez osobę z prawem zapisu do repo.
- Sekrety wiszą w environment `release` ograniczonym do maina.
- Keychain na runnerze jest tymczasowy i kasowany po buildzie; klucz .p8 jest
  usuwany zaraz po uploadzie.
- Gdyby klucz API kiedykolwiek wyciekł: unieważniasz go jednym kliknięciem w
  App Store Connect (Users and Access → Integrations) i generujesz nowy. Klucz
  API ma ograniczoną rolę (App Manager), nie daje pełnego dostępu do konta.

CO TRZYMAĆ POZA REPO (na Twoim dysku, np. ~/bse-signing):
  dist.key, dist.csr, distribution.cer, dist.crt, dist.p12, *.mobileprovision,
  AuthKey_*.p8 oraz wszystkie *.b64. To są klucze — nie commituj ich nigdzie.
