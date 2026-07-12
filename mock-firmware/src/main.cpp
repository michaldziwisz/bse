// BlueSeaEye — WŁASNY mock firmware (odtworzony kontrakt HTTP, nie kod autora).
//
// Cel (na życzenie Michała): mock, który generuje mockowe kursy ORAZ mockowe
// wychylenie steru (pole "rsa"), z możliwością włączenia/wyłączenia steru POZA
// aplikacją — tak jak zaczął to autor: parametrem /api/helm?disableRudder=true|false.
// Parametr jest STANOWY i zapamiętywany w pamięci nieulotnej (NVS/Preferences):
// przestawiasz go raz (np. curl-em), a aplikacja odczytuje /api/helm bez parametru
// i respektuje zapamiętany stan.
//
// Kontrakt HTTP odtworzony 1:1 z żywego urządzenia (build Jul 11 2026):
//   GET /api/info  -> {"device":"BlueSeaEye","model":"mobile","version":"1.0.0",
//                      "issued":"...","mock":true}
//   GET /api/helm?time=<ms>&source=<klucz>&window=<ms>
//       - source (cgfa/coga/hdga/cgf/cog/hdg) filtruje POLA KURSU do jednego;
//         brak source => wszystkie 6 pól kursu.
//       - rsa (wychylenie steru) dołączane NIEZALEŻNIE od source, o ile ster
//         włączony (disableRudder=false). To odtwarza zachowanie starego firmware,
//         w którym aplikacja (wysyłająca source=cgfa) i tak dostawała ster.
//       - window: okno uśredniania w MILISEKUNDACH; surowe 1..5 => HTTP 400
//         (tak jak sprzęt).
//   Nagłówek Access-Control-Allow-Origin: * (wszędzie), Cache-Control: no-cache
//   przy /api/helm.

#include <Arduino.h>
#include <WiFi.h>
#include <Preferences.h>
#include <ESPAsyncWebServer.h>
#include <math.h>

static const char *AP_SSID = "BlueSeaEye";
static const char *AP_PASS = "blueseaeye";

// Wersja/identyfikacja zgodna z oryginałem, by aplikacja i frontend nie widziały
// różnicy. "issued" oznaczamy jako mock, żeby było jasne, że to wersja testowa.
static const char *DEV_NAME = "BlueSeaEye";
static const char *DEV_MODEL = "mobile";
static const char *DEV_VERSION = "1.0.0";
static const char *DEV_ISSUED = "mock " __DATE__ " " __TIME__;

AsyncWebServer server(80);
Preferences prefs;

// Stan przełącznika steru. rudderEnabled == true => wysyłamy "rsa".
// Domyślnie WŁĄCZONY (jak stary firmware, w którym ster był zawsze widoczny).
bool rudderEnabled = true;

static void loadState() {
  prefs.begin("bse", false);
  // Zapamiętujemy "disableRudder" (zgodnie z nazwą parametru autora). Domyślnie
  // false => ster włączony.
  bool disableRudder = prefs.getBool("disableRudder", false);
  rudderEnabled = !disableRudder;
}

static void saveDisableRudder(bool disable) {
  rudderEnabled = !disable;
  prefs.putBool("disableRudder", disable);
}

// Interpretacja wartości parametru disableRudder: true/1/yes/on => wyłącz ster,
// false/0/no/off => włącz. Zwraca true jeśli rozpoznano wartość.
static bool parseBool(const String &v, bool &out) {
  String s = v;
  s.toLowerCase();
  if (s == "true" || s == "1" || s == "yes" || s == "on") { out = true; return true; }
  if (s == "false" || s == "0" || s == "no" || s == "off") { out = false; return true; }
  return false;
}

// Mockowy kurs: powolny dryf wokół północy (0/360), jak na żywym sprzęcie
// (~357..4 stopnia). Zależny od czasu, więc każdy odczyt jest nieco inny.
static double mockCourse() {
  double t = millis() / 1000.0;
  double c = 1.0 * sin(t * 0.15) + 2.0 * sin(t * 0.037); // ~ -3..+3
  double course = fmod(c + 360.0, 360.0);
  return course;
}

// Mockowe wychylenie steru: oscyluje w zakresie ~ -30..+30 stopni.
static double mockRudder() {
  double t = millis() / 1000.0;
  return 25.0 * sin(t * 0.11) + 5.0 * sin(t * 0.29);
}

static void addCourseField(String &json, bool &first, const char *key, double val) {
  if (!first) json += ",";
  first = false;
  char buf[32];
  snprintf(buf, sizeof(buf), "\"%s\":%.7f", key, val);
  json += buf;
}

static void handleHelm(AsyncWebServerRequest *request) {
  // window: jeśli podane, surowe 1..5 => 400 (jak sprzęt). Aplikacja wysyła
  // averageWindow*1000 (1000..5000), więc normalnie przechodzi.
  if (request->hasParam("window")) {
    long w = request->getParam("window")->value().toInt();
    if (w >= 1 && w <= 5) {
      request->send(400, "text/plain", "invalid window");
      return;
    }
  }

  // Stanowy przełącznik steru: jeśli w zapytaniu jest disableRudder, ustaw i
  // ZAPAMIĘTAJ stan. Kolejne odczyty (bez parametru) go respektują.
  if (request->hasParam("disableRudder")) {
    bool disable;
    if (parseBool(request->getParam("disableRudder")->value(), disable)) {
      saveDisableRudder(disable);
    }
  }

  const char *courseKeys[] = {"cgfa", "coga", "hdga", "cgf", "cog", "hdg"};
  String source;
  if (request->hasParam("source")) source = request->getParam("source")->value();

  double course = mockCourse();

  String json = "{";
  bool first = true;

  if (source.length() > 0) {
    // source filtruje pola kursu do jednego (jeśli klucz prawidłowy).
    bool known = false;
    for (auto k : courseKeys) {
      if (source == k) { known = true; break; }
    }
    if (known) {
      addCourseField(json, first, source.c_str(), course);
    }
  } else {
    for (auto k : courseKeys) {
      addCourseField(json, first, k, course);
    }
  }

  // rsa dołączane NIEZALEŻNIE od source, o ile ster włączony.
  if (rudderEnabled) {
    if (!first) json += ",";
    first = false;
    char buf[24];
    snprintf(buf, sizeof(buf), "\"rsa\":%.7f", mockRudder());
    json += buf;
  }

  json += "}";

  AsyncWebServerResponse *response =
      request->beginResponse(200, "application/json", json);
  response->addHeader("Access-Control-Allow-Origin", "*");
  response->addHeader("Cache-Control", "no-cache");
  request->send(response);
}

static void handleInfo(AsyncWebServerRequest *request) {
  char json[160];
  snprintf(json, sizeof(json),
           "{\"device\":\"%s\",\"model\":\"%s\",\"version\":\"%s\",\"issued\":\"%s\",\"mock\":true}",
           DEV_NAME, DEV_MODEL, DEV_VERSION, DEV_ISSUED);
  AsyncWebServerResponse *response =
      request->beginResponse(200, "application/json", json);
  response->addHeader("Access-Control-Allow-Origin", "*");
  request->send(response);
}

void setup() {
  Serial.begin(115200);
  delay(200);
  loadState();

  WiFi.mode(WIFI_AP);
  WiFi.softAP(AP_SSID, AP_PASS);
  IPAddress ip = WiFi.softAPIP(); // domyślnie 192.168.4.1
  Serial.printf("BlueSeaEye mock AP \"%s\" @ %s\n", AP_SSID, ip.toString().c_str());
  Serial.printf("rudder: %s\n", rudderEnabled ? "ENABLED" : "DISABLED");

  server.on("/api/info", HTTP_GET, handleInfo);
  server.on("/api/helm", HTTP_GET, handleHelm);

  // Prosty root, żeby wejście przeglądarką coś zwracało (aplikacja nie używa).
  server.on("/", HTTP_GET, [](AsyncWebServerRequest *req) {
    String s = "BlueSeaEye mock. rudder=";
    s += rudderEnabled ? "on" : "off";
    s += "\nGET /api/helm?disableRudder=true|false aby przelaczyc ster.";
    req->send(200, "text/plain", s);
  });

  server.onNotFound([](AsyncWebServerRequest *req) {
    req->send(404, "text/plain", "not found");
  });

  server.begin();
}

void loop() {
  delay(1000);
}
