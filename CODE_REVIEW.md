# Code-Review: `r4875g1-3phase-charger.yaml`

**Stand:** 2026-08-18 (aktualisierte Fassung nach mehreren Fixes/Erweiterungen)
**Umfang:** Vollständige erneute Prüfung der aktuellen ESPHome-Konfiguration (3883 Zeilen).

Dieser Bericht ersetzt die vorherige Fassung. Bereits behobene Punkte sind kompakt am Ende dokumentiert; der Fokus liegt auf **offenen** und **neu hinzugekommenen** Punkten.

---

## Zusammenfassung

| # | Thema | Schweregrad | Status |
|---|-------|-------------|--------|
| 1 | `current_scaling_factor`-Gleichheitsvergleich (`== 15/20/30`) funktioniert praktisch nie | 🔴 Hoch | **Offen** |
| 2 | Tote Lambda-Blöcke in `number:`-Setpoints (`high_byte`/`low_byte` unbenutzt) | 🟡 Mittel | **Offen** |
| 3 | Inkonsistentes `update_interval` bei "Input Grid Voltage Module-1" (10 s statt 3 s) | 🟡 Mittel | **Offen** |
| 4 | Redundante CAN-Sendungen in `blackstart_start` | 🟢 Niedrig | **Offen** |
| 5 | Duplizierte Grenzwert-Logik (75/50/30 A) an mehreren Stellen | 🟢 Niedrig | **Offen** |
| 6 | `web_server` ohne Authentifizierung | 🟡 Mittel (Sicherheit) | **Offen** |
| 7 | Unicode-Sonderzeichen `⁄` in Name/SSID | 🟢 Niedrig | **Offen** |
| 8 | Neue Sensoren ohne `state_class`/`device_class` (Max Output Current Setpoint, FAN RPM) | 🟢 Niedrig | **Neu** |
| 9 | Fan-Handler berechnen `duty`/`duty_set`, veröffentlichen sie aber nirgends | 🟢 Niedrig | **Neu** |
| 10 | Namensinkonsistenz bei `fallback_amp_set` (Anzeigename geändert, ID nicht) | 🟢 Niedrig | **Neu** |

---

## 1. 🔴 `current_scaling_factor`-Vergleich weiterhin praktisch wirkungslos

**Fundstellen:** Zeile ~3140–3144 (`number: DC Current Setpoint`) und ~3194–3198 (`number: Fallback Current Set`).

```cpp
if (id(current_scaling_factor) == 15) { max_amps = 75; }
else if (id(current_scaling_factor) == 20) { max_amps = 50; }
else if (id(current_scaling_factor) == 30) { max_amps = 30; }
```

**Status:** In einer vorherigen Iteration wurde korrigiert, dass nur noch **Modul 1** den geteilten `current_scaling_factor` setzt (Module 2/3 schreiben jetzt nur noch in ihre eigenen Diagnose-Sensoren `sf_value_2`/`sf_value_3`). Das war ein wichtiger Fix für die Multi-Modul-Konsistenz, **behebt aber nicht das ursprüngliche Problem**: `current_scaling_factor` wird weiterhin als `1024.0 / max_current` (Fließkommazahl) berechnet und anschließend per **exakter Gleichheit** mit `15`, `20` oder `30` verglichen. Ein real ermittelter `max_current`-Wert erzeugt so gut wie nie exakt einen dieser drei Werte – die modellabhängige Strom-Obergrenze (30/50/75 A) bleibt daher weiterhin faktisch wirkungslos, sobald die Discovery einmal gelaufen ist.

**Empfehlung (unverändert):** Direkt auf `max_current_sensor_1.state` prüfen statt auf den abgeleiteten Skalierungsfaktor, z. B.:

```cpp
float max_amps = 75.0f;
if (id(max_current_sensor_1).state <= 32.0f)      max_amps = 30.0f;
else if (id(max_current_sensor_1).state <= 55.0f) max_amps = 50.0f;
```

---

## 2. 🟡 Tote Codeblöcke in `number:`-Setpoints

**Fundstellen:** `CAN Voltage Set` (Zeile ~3084–3092), `DC Current Setpoint` (`set_dc_current`), `Fallback Current Set`, `Fallback Voltage Set`.

Nach wie vor berechnet der erste `lambda:`-Schritt in jedem `on_value`-Automation-Block `scaled_value`/`high_byte`/`low_byte`, ohne die Werte zu verwenden – der eigentliche `canbus.send`-Schritt berechnet alles direkt danach erneut in einem eigenen `!lambda`-Block. Unverändert seit der letzten Prüfung.

**Empfehlung:** Den jeweils ersten, wirkungslosen `lambda:`-Schritt entfernen.

---

## 3. 🟡 "Input Grid Voltage Module-1" weiterhin mit 10 s statt 3 s

**Fundstelle:** Zeile ~2647.

Modul 2 und 3 nutzen `update_interval: 3s`, Modul 1 dieses einen Sensors weiterhin `10s`. Wahrscheinlich ein Kopierfehler, unverändert seit der letzten Prüfung.

---

## 4. 🟢 Redundante CAN-Übertragung in `blackstart_start`

Unverändert: `apply_dc_sum_power` löst über `set_dc_current.make_call()` bereits einen CAN-Sendevorgang für den Strom-Sollwert aus; `blackstart_start` sendet den Strom-Sollwert danach nochmals explizit. Funktional unschädlich, weiterhin nur als Hinweis auf unnötigen Bus-Traffic vermerkt.

---

## 5. 🟢 Duplizierte 75/50/30-A-Grenzwertlogik

Unverändert an drei Stellen dupliziert: `DC Current Setpoint`, `Fallback Current Set` (beide mit dem unter Punkt 1 beschriebenen Vergleichsfehler) sowie der harte `75.0f`-Cap in `apply_dc_sum_power`. Sollte langfristig in ein gemeinsames Script/eine gemeinsame Funktion ausgelagert werden.

---

## 6. 🟡 `web_server` weiterhin ohne Authentifizierung

**Fundstelle:** Abschnitt `web_server:` (`version: 3`).

Unverändert: kein `auth:` mit `username`/`password`. Empfehlung wie zuvor, falls das Gerät nicht in einem strikt vertrauenswürdigen Netzsegment betrieben wird.

---

## 7. 🟢 Unicode-Sonderzeichen `⁄` in Name/SSID

Unverändert in `esphome.friendly_name` und `wifi.ap.ssid` vorhanden (U+2044 statt normalem `/`). Weiterhin nur als Hinweis, falls unbeabsichtigt.

---

## 8. 🟢 Neu: Zusätzliche Sensoren ohne `device_class`/`state_class`

Bei der letzten Ergänzung um `device_class`/`state_class` (Spannung/Strom/Leistung/Temperatur/Energie) wurden zwei seither neu hinzugekommene Sensor-Gruppen nicht erfasst:

- **`Max Output Current Setpoint Module-1/2/3`** (Zeile ~2830–2876): hat weder `device_class: current` noch `state_class: measurement`.
- **`FAN RPM Module-1/2/3`** (Zeile ~2879–2907): keine `device_class` (HA kennt keine native RPM-Klasse) und kein `state_class: measurement`.

**Empfehlung:**

```yaml
# Max Output Current Setpoint Module-x
device_class: current
state_class: measurement

# FAN RPM Module-x
state_class: measurement
```

---

## 9. 🟢 Neu: Fan-Handler berechnen `duty`/`duty_set`, nutzen sie aber nicht

**Fundstellen:** CAN-Handler `0x1081827E`/`0x1082827E`/`0x1083827E` (Zeile ~1801–1868).

```cpp
float duty = (static_cast<float>(duty_raw) / 25600.0f) * 100.0f;
float duty_set = (static_cast<float>(duty_set_raw) / 25600.0f) * 100.0f;

// Publish the sensor states
id(fan_rpm_1).publish_state(rpm);
```

`duty` und `duty_set` werden berechnet, aber nirgends veröffentlicht oder anderweitig verwendet – es existiert kein entsprechender Duty-Cycle-Sensor. Entweder war ein "Fan Duty Module-x"-Sensor beabsichtigt und wurde vergessen, oder die beiden Variablen sind toter Code.

**Empfehlung:** Falls die Lüfter-Ansteuerungs-Prozentwerte für Diagnose interessant sind, zwei zusätzliche Template-Sensoren (`fan_duty_x`, `fan_duty_set_x`) ergänzen und `publish_state` aufrufen; andernfalls die Berechnung entfernen.

---

## 10. 🟢 Neu: Namensinkonsistenz bei `fallback_amp_set`

Der Anzeigename wurde zu `"Fallback Current Set"` geändert, die Entity-ID ist aber weiterhin `fallback_amp_set` geblieben – im Gegensatz zum parallelen `CAN Amp Set` → `DC Current Setpoint` (`id: set_dc_current`), wo Name **und** ID konsistent umbenannt wurden. Rein kosmetisch/für die Wartbarkeit, aber uneinheitlich.

---

## Bereits behobene Punkte (zur Nachverfolgung, keine Details mehr nötig)

- ✅ Übertemperatur-Abschaltung hat jetzt Hysterese (90 °C Trip / 80 °C Reset) und einen Lockout-Mechanismus pro Modul (`overtemp_lockout_1..3`); individuelle ON-Buttons und `blackstart_start` respektieren den Lockout.
- ✅ `device_class`/`state_class` für die ursprünglich identifizierten Spannungs-, Strom-, Leistungs-, Temperatur- und Energie-Sensoren ergänzt (mit Ausnahme der unter Punkt 8 neu hinzugekommenen Sensoren).
- ✅ Nach der Umbenennung `amp_scaling_factor` → `current_scaling_factor` behobene Inkonsistenz: nur noch Modul 1 aktualisiert den geteilten Skalierungsfaktor; Module 2/3 schreiben nur noch in ihre eigenen Diagnose-Sensoren (`sf_value_2`/`sf_value_3`), ohne den globalen Wert zu überschreiben.
- ✅ Tippfehler in Log-Meldung ("Module 1:New" → "Module 1: New") korrigiert.
- ✅ Fehlende Kommentare für neue FAN-RPM- und "Info: Operating Hours"-Sensoren sowie deren CAN-Handler im bestehenden Stil ergänzt.
- ✅ `state_class`/`device_class` für die drei "Info: Operating Hours"-Sensoren von `measurement` auf `duration`/`total_increasing` korrigiert (monoton steigender Zähler).
- ✅ Keine verwaisten Referenzen auf alte IDs (`can_amp_set`, `amp_scaling_factor`, `set_max_output_current_sensor_x`, `sf_value`) mehr vorhanden.

---

## Priorisierte Handlungsempfehlung

1. **Punkt 1** (Gleichheitsvergleich) weiterhin die höchste Priorität – betrifft die tatsächliche Sicherheits-relevante Strombegrenzung pro Modultyp und wurde bisher nicht behoben, nur die Multi-Modul-Konsistenz drumherum.
2. **Punkt 6** (Web-Server-Auth) je nach Netzwerksegmentierung nachrüsten.
3. Punkte 8/9 (neue Sensoren) bei Gelegenheit ergänzen, da sie recht einfach nachzuziehen sind.
4. Restliche Punkte (2–5, 7, 10) können im Rahmen normaler Wartung/Refactorings adressiert werden.
