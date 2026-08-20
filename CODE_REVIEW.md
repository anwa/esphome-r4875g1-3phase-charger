# Code-Review: `r4875g1-3phase-charger.yaml`

**Stand:** 2026-08-19 (aktualisierte Fassung nach Umbenennung "Module" → "Unit", Display-Migration auf `mipi_spi`, CAN-Pin-Wechsel und neuer "Fan Minimum Speed"-Funktion)
**Umfang:** Vollständige erneute Prüfung der aktuellen ESPHome-Konfiguration (3977 Zeilen).

Dieser Bericht ersetzt die vorherige Fassung. Bereits behobene Punkte sind kompakt am Ende dokumentiert; der Fokus liegt auf **offenen** und **neu hinzugekommenen** Punkten.

---

## Zusammenfassung

| # | Thema | Schweregrad | Status |
|---|-------|-------------|--------|
| 2 | Duplizierte Grenzwert-Logik (75/50/30 A) an mehreren Stellen | 🟢 Niedrig | **Offen** |
| 3 | Redundante CAN-Sendungen in `blackstart_start` | 🟢 Niedrig | **Offen** |
| 4 | `web_server` weiterhin ohne Authentifizierung | 🟡 Mittel (Sicherheit) | **Offen** |
| 6 | Fan-Handler berechnen `duty`/`duty_set`, veröffentlichen sie aber nirgends | 🟢 Niedrig | **Offen** |

---

## 2. 🟢 Duplizierte 75/50/30-A-Grenzwertlogik

Unverändert an drei Stellen dupliziert: `Set DC Current Limit`, `Set DC Current Limit Fallback` (beide mit dem unter Punkt 1 beschriebenen Vergleichsfehler) sowie der harte `75.0f`-Cap in `apply_dc_sum_power`. Sollte langfristig in ein gemeinsames Script/eine gemeinsame Funktion ausgelagert werden.

---

## 3. 🟢 Redundante CAN-Übertragung in `blackstart_start`

Unverändert: `apply_dc_sum_power` löst über `set_dc_current_limit.make_call()` bereits einen CAN-Sendevorgang für den Strom-Sollwert aus; `blackstart_start` sendet den Strom-Sollwert danach nochmals explizit. Funktional unschädlich, weiterhin nur als Hinweis auf unnötigen Bus-Traffic vermerkt.

---

## 4. 🟡 `web_server` weiterhin ohne Authentifizierung

**Fundstelle:** Abschnitt `web_server:` (Zeile 124, `version: 3`).

Unverändert: kein `auth:` mit `username`/`password`. Empfehlung wie zuvor, falls das Gerät nicht in einem strikt vertrauenswürdigen Netzsegment betrieben wird.

---

## 6. 🟢 Fan-Handler berechnen `duty`/`duty_set`, nutzen sie aber nicht

**Fundstellen:** CAN-Handler `0x1081827E`/`0x1082827E`/`0x1083827E` (Zeile ~1819–1905).

```cpp
float duty = (static_cast<float>(duty_raw) / 25600.0f) * 100.0f;
float duty_set = (static_cast<float>(duty_set_raw) / 25600.0f) * 100.0f;

// Publish the sensor states
id(fan_rpm_1).publish_state(rpm);
```

`duty` und `duty_set` werden weiterhin berechnet, aber nirgends veröffentlicht oder anderweitig verwendet – es existiert kein entsprechender Duty-Cycle-Sensor.

**Empfehlung:** Falls die Lüfter-Ansteuerungs-Prozentwerte für Diagnose interessant sind, zwei zusätzliche Template-Sensoren (`fan_duty_x`, `fan_duty_set_x`) ergänzen und `publish_state` aufrufen; andernfalls die Berechnung entfernen. Interessanterweise passt `duty_set` inhaltlich gut zur neuen "Set Fan Minimum Speed"-Funktion – könnte als Rückmeldekanal genutzt werden, ob das Modul den gesendeten Minimal-Duty-Wert tatsächlich übernommen hat.

---

## Bereits behobene Punkte (zur Nachverfolgung, keine Details mehr nötig)

- ✅ Übertemperatur-Abschaltung hat Hysterese (90 °C Trip / 80 °C Reset) und einen Lockout-Mechanismus pro Unit (`overtemp_lockout_1..3`); individuelle ON-Buttons und `blackstart_start` respektieren den Lockout.
- ✅ `device_class`/`state_class` für die ursprünglich identifizierten Spannungs-, Strom-, Leistungs-, Temperatur- und Energie-Sensoren ergänzt.
- ✅ Nur noch Unit 1 aktualisiert den geteilten `current_scaling_factor`; Unit 2/3 schreiben nur noch in ihre eigenen Diagnose-Sensoren (`sf_value_2`/`sf_value_3`).
- ✅ **Tote Lambda-Blöcke in den `number:`-Setpoints entfernt:** Die früher wirkungslosen `high_byte`/`low_byte`-Berechnungen wurden durch sinnvolle Logging-/Validierungs-`lambda`-Blöcke ersetzt (`Set DC Voltage Limit`, `Set DC Current Limit`, `Set DC Current Limit Fallback`, `Fallback Voltage Set`).
- ✅ **Inkonsistentes `update_interval` bei "Input Grid Voltage Unit-1" behoben:** läuft jetzt wie Unit-2/3 mit `3s` statt `10s`.
- ✅ **Unicode-Sonderzeichen `⁄` entfernt:** `friendly_name` und Fallback-AP-SSID verwenden jetzt reines ASCII (`HG|DG|Technik|Charger-3Ph`, `3PhCharger Fallback Hotspot`).
- ✅ Konsistente Umbenennung "Module" → "Unit" über die gesamte Datei (Kommentare, IDs, Entity-Namen) durchgeführt, keine verwaisten Referenzen gefunden.
- ✅ Display-Migration von `ili9xxx` auf `mipi_spi` (mit explizit gesetzter `data_rate: 40MHz`, um die bisherige Performance beizubehalten) – Konfiguration wirkt vollständig und konsistent zur vorherigen Transform-Logik.
- ✅ Neue "Set Fan Minimum Speed"-Funktion (Zeile ~3108–3167) ist sauber dokumentiert und ohne toten Code implementiert.
- ✅ Namensinkonsistenz beim Strom-Fallback behoben: `Fallback Amp Set` → `Set DC Current Limit Fallback` mit passend umbenannter ID `set_dc_current_limit_fallback`.
- ✅ Keine verwaisten Referenzen auf alte IDs (`can_amp_set`, `amp_scaling_factor`, `set_max_output_current_sensor_x`, `sf_value`, `can_voltage_set`) mehr vorhanden.

---

## Priorisierte Handlungsempfehlung

1. **Punkt 4** (Web-Server-Auth) je nach Netzwerksegmentierung nachrüsten.
2. Punkte 2, 3, 6 können im Rahmen normaler Wartung/Refactorings adressiert werden.
