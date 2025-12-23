# Feature Specification: MindSync Core App

**Feature Branch**: `001-audio-strobe-sync`  
**Created**: 2025-12-23  
**Status**: Draft  
**Input**: User description: "MindSync iOS App - Audio-synchronized stroboscopic light for altered consciousness states"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Lokale Musik mit Stroboskop-Synchronisation (Priority: P1)

Als Nutzer möchte ich einen Song aus meiner lokalen Musikbibliothek auswählen und das iPhone-Taschenlampenlicht rhythmisch zum Beat der Musik blinken lassen, um einen meditativen oder veränderten Bewusstseinszustand zu erleben.

**Why this priority**: Dies ist das zentrale Wertversprechen von MindSync – die Verbindung von persönlicher Musik mit stroboskopischem Licht. Ohne diese Kernfunktion gibt es kein Produkt. Dies validiert die technische Machbarkeit (Audio-Analyse, Taschenlampen-Steuerung) und das Nutzererlebnis.

**Independent Test**: Kann vollständig getestet werden, indem ein lokaler MP3-Song ausgewählt wird und verifiziert wird, dass die Taschenlampe rhythmisch im Takt blinkt. Liefert sofortigen Wert als "digitales Psychedelikum"-Erlebnis.

**Acceptance Scenarios**:

1. **Given** der Nutzer hat mindestens einen DRM-freien Song in der Musikbibliothek, **When** er einen Song auswählt und die Sitzung startet, **Then** beginnt die Musik zu spielen und die Taschenlampe blinkt synchron zum Beat.
2. **Given** eine laufende Sitzung, **When** der Nutzer die Sitzung stoppt (Wischgeste oder Doppeltippen), **Then** stoppt die Musik und die Taschenlampe schaltet sich sofort aus.
3. **Given** der Nutzer wählt einen Song aus, **When** die App den Song analysiert, **Then** sieht der Nutzer einen kurzen Ladebildschirm mit Fortschrittsanzeige ("Beats werden extrahiert...").

---

### User Story 2 - Sicherheits-Onboarding und Epilepsie-Warnung (Priority: P1)

Als Nutzer möchte ich beim ersten App-Start über die Risiken von stroboskopischem Licht informiert werden und bestätigen, dass ich keine photosensitive Epilepsie habe, damit ich die App sicher nutzen kann.

**Why this priority**: Sicherheit ist nicht verhandelbar. Ohne diese Funktion kann die App nicht veröffentlicht werden (App Store Guidelines, Haftung). Dies ist ein Blocker für jeden weiteren Fortschritt.

**Independent Test**: Kann getestet werden, indem die App zum ersten Mal gestartet wird und verifiziert wird, dass der Sicherheitshinweis erscheint und bestätigt werden muss, bevor man zur Hauptoberfläche gelangt.

**Acceptance Scenarios**:

1. **Given** der Nutzer öffnet die App zum ersten Mal, **When** die App startet, **Then** erscheint ein Vollbild-Haftungsausschluss über stroboskopisches Licht und photosensitive Epilepsie.
2. **Given** der Epilepsie-Warnhinweis wird angezeigt, **When** der Nutzer den Hinweis nicht bestätigt, **Then** kann er nicht auf die Hauptfunktionen der App zugreifen.
3. **Given** der Nutzer hat den Haftungsausschluss bestätigt, **When** er die App später erneut öffnet, **Then** wird der Hinweis nicht erneut angezeigt (gespeicherte Bestätigung).

---

### User Story 3 - Stimmungsbasierte Entrainment-Modi (Priority: P2)

Als Nutzer möchte ich vor einer Sitzung mein gewünschtes Ziel auswählen (Entspannung, Fokus, oder Trip), damit die App die Stroboskop-Frequenzen auf das entsprechende Gehirnwellenband abstimmt.

**Why this priority**: Dies differenziert MindSync von einfachen "Party-Strobe"-Apps und nutzt die neurowissenschaftliche Grundlage. Ohne Modi ist das Erlebnis zufällig statt zielgerichtet.

**Independent Test**: Kann getestet werden, indem verschiedene Modi ausgewählt werden und verifiziert wird, dass die Blinkfrequenz sich entsprechend ändert (Alpha ~10 Hz für Entspannung, Gamma ~40 Hz für Fokus, Theta/Mix für Trip).

**Acceptance Scenarios**:

1. **Given** der Nutzer ist auf dem Auswahlbildschirm, **When** er "Entspannung" wählt, **Then** wird die Sitzung mit Alpha-Frequenzen (8-12 Hz) als Ziel konfiguriert.
2. **Given** der Nutzer ist auf dem Auswahlbildschirm, **When** er "Fokus" wählt, **Then** wird die Sitzung mit Gamma-Frequenzen (30-40 Hz) als Ziel konfiguriert.
3. **Given** der Nutzer ist auf dem Auswahlbildschirm, **When** er "Trip" wählt, **Then** wird die Sitzung mit Theta-Frequenzen (4-8 Hz) und variablen Mustern konfiguriert.

---

### User Story 4 - Mikrofon-Modus für Streaming-Musik (Priority: P3)

Als Nutzer möchte ich die App auch mit Musik von Streaming-Diensten (Spotify, Apple Music) verwenden können, indem die App über das Mikrofon zuhört und das Stroboskop zur gehörten Musik synchronisiert.

**Why this priority**: Erweitert die Nutzbarkeit erheblich, da die meisten Nutzer Streaming-Dienste verwenden. Weniger präzise als lokale Analyse, aber ermöglicht universelle Musiknutzung.

**Independent Test**: Kann getestet werden, indem Musik von einem externen Lautsprecher oder einem anderen Gerät abgespielt wird und verifiziert wird, dass die App über das Mikrofon den Beat erkennt und das Stroboskop synchronisiert.

**Acceptance Scenarios**:

1. **Given** der Nutzer wählt "Mikrofon-Modus", **When** externe Musik läuft, **Then** beginnt die Taschenlampe synchron zur gehörten Musik zu blinken.
2. **Given** der Mikrofon-Modus ist aktiv, **When** die externe Musik stoppt oder sehr leise wird, **Then** pausiert die Taschenlampe sanft (kein abruptes Ausschalten).
3. **Given** der Nutzer hat keine Mikrofon-Berechtigung erteilt, **When** er den Mikrofon-Modus auswählt, **Then** wird er aufgefordert, die Berechtigung zu erteilen, mit klarer Erklärung warum.

---

### User Story 5 - Bildschirm-Modus als Alternative zur Taschenlampe (Priority: P3)

Als Nutzer möchte ich den Bildschirm des iPhones als Lichtquelle verwenden können (anstelle der Taschenlampe), um farbige Stroboskop-Effekte zu erleben und thermische Probleme zu vermeiden.

**Why this priority**: Bietet eine sanftere Alternative für lichtempfindliche Nutzer und ermöglicht Farbmodulation (RGB). Löst auch das Problem der thermischen Drosselung bei langen Sitzungen.

**Independent Test**: Kann getestet werden, indem der Bildschirm-Modus aktiviert wird und verifiziert wird, dass der Bildschirm in verschiedenen Farben blinkt und die Taschenlampe dabei aus bleibt.

**Acceptance Scenarios**:

1. **Given** der Nutzer ist auf dem Einstellungsbildschirm, **When** er "Bildschirm-Modus" auswählt, **Then** verwendet die nächste Sitzung den Bildschirm statt der Taschenlampe als Lichtquelle.
2. **Given** der Bildschirm-Modus ist aktiv und ein Song läuft, **When** ein Beat erkannt wird, **Then** blinkt der Bildschirm in der gewählten Farbe (Weiß, Rot, oder RGB-Zyklus).
3. **Given** der Bildschirm-Modus ist aktiv, **When** die Sitzung läuft, **Then** bleibt die Taschenlampe ausgeschaltet und es gibt keine thermischen Warnungen.

---

### User Story 6 - Thermisches Management und Überhitzungsschutz (Priority: P2)

Als Nutzer möchte ich, dass die App automatisch die Intensität reduziert oder mich warnt, wenn das Gerät zu heiß wird, damit ich keine Schäden am Gerät oder unangenehme Unterbrechungen erlebe.

**Why this priority**: Hardware-Schutz und konsistente Nutzererfahrung. Ohne diese Funktion werden längere Sitzungen (>10 Min) unzuverlässig oder das Gerät schaltet die Taschenlampe ab.

**Independent Test**: Kann getestet werden, indem eine lange Sitzung mit hoher Intensität gestartet wird und verifiziert wird, dass die App bei erhöhter Gerätetemperatur die Intensität sanft reduziert oder zum Bildschirm-Modus wechselt.

**Acceptance Scenarios**:

1. **Given** eine Sitzung mit Taschenlampen-Modus läuft, **When** das Gerät sich erwärmt, **Then** reduziert die App sanft die durchschnittliche Helligkeit der Taschenlampe.
2. **Given** das Gerät erreicht kritische Temperatur, **When** die App dies erkennt, **Then** wird eine diskrete Benachrichtigung angezeigt und der Modus auf Bildschirm umgeschaltet.
3. **Given** der Nutzer startet eine neue Sitzung, **When** das Gerät bereits warm ist, **Then** empfiehlt die App den Bildschirm-Modus oder eine niedrigere Intensität.

---

### Edge Cases

- Was passiert, wenn der Nutzer einen DRM-geschützten Song aus Apple Music auswählt? → Klare Fehlermeldung mit Erklärung und Vorschlag für Mikrofon-Modus.
- Was passiert, wenn die Analyse keine klaren Beats findet (z.B. Ambient-Musik)? → Fallback auf sanfte, gleichmäßige Pulsation basierend auf RMS-Energie.
- Was passiert, wenn der Nutzer das Telefon während einer Sitzung fallen lässt? → Automatischer Stopp über Beschleunigungsmesser-Erkennung.
- Was passiert, wenn die Taschenlampe von iOS zwangsweise deaktiviert wird (Überhitzung)? → Graceful Fallback auf Bildschirm-Modus mit Nutzerbenachrichtigung.
- Was passiert, wenn der Nutzer Kopfhörer anschließt/trennt während einer Sitzung? → Audio-Route-Wechsel ohne Unterbrechung der Synchronisation.
- Was passiert, wenn der Nutzer einen Anruf erhält während einer Sitzung? → Automatisches Pausieren und sanftes Fortsetzen nach dem Anruf.

## Requirements *(mandatory)*

### Functional Requirements

**Audio-Analyse & Wiedergabe**

- **FR-001**: System MUSS DRM-freie lokale Audio-Dateien (MP3, AAC, WAV) aus der Musikbibliothek des Nutzers lesen und analysieren können.
- **FR-002**: System MUSS Beat-Positionen (Transients) aus dem Audio-Signal extrahieren können.
- **FR-003**: System MUSS das Tempo (BPM) eines Songs ermitteln können.
- **FR-004**: System MUSS Audio während einer Sitzung mit synchroner Timing-Präzision (±50ms) wiedergeben.
- **FR-005**: System MUSS Audio-Analyse vor der Wiedergabe durchführen (Pre-Processing statt Echtzeit) für präzise Synchronisation.

**Mikrofon-Modus**

- **FR-006**: System MUSS Mikrofon-Audio in Echtzeit analysieren können, um Beats und Energie zu erkennen.
- **FR-007**: System MUSS Mikrofon-Berechtigung sauber anfordern mit nutzerfreundlicher Erklärung.

**Licht-Steuerung**

- **FR-008**: System MUSS die iPhone-Taschenlampe mit variabler Intensität (0.0-1.0) steuern können.
- **FR-009**: System MUSS den Bildschirm als alternative Lichtquelle mit Vollbild-Farbwechseln nutzen können.
- **FR-010**: System MUSS Licht-Impulse präzise (±20ms) zu Beat-Positionen synchronisieren.
- **FR-011**: System MUSS verschiedene Wellenformen unterstützen (Rechteck für harte Beats, Sinus für sanfte Pulsation).

**Frequenz-Zuordnung (Entrainment)**

- **FR-012**: System MUSS musikalisches Tempo (BPM) auf Ziel-Gehirnwellenfrequenzen (Hz) abbilden können mit ganzzahligen Multiplikatoren.
- **FR-013**: System MUSS drei Haupt-Modi unterstützen: Alpha (8-12 Hz), Theta (4-8 Hz), Gamma (30-40 Hz).
- **FR-014**: System MUSS die Blinkfrequenz auf sichere Bereiche begrenzen (nicht 3-30 Hz ohne explizite Nutzerbestätigung).

**Sicherheit**

- **FR-015**: System MUSS einen obligatorischen Epilepsie-Warnhinweis beim ersten Start anzeigen, der bestätigt werden muss.
- **FR-016**: System MUSS die Gerätetemperatur überwachen und bei Überhitzung die Intensität automatisch reduzieren.
- **FR-017**: System MUSS bei erkanntem Gerät-Fall (Beschleunigungsmesser) die Sitzung automatisch stoppen.
- **FR-018**: System MUSS große, gestenbasierte Steuerelemente bieten für Nutzung mit geschlossenen Augen.

**Nutzererfahrung**

- **FR-019**: System MUSS im Dunkelmodus erscheinen, um die Nachtsicht des Nutzers zu erhalten.
- **FR-020**: System MUSS Sitzungsdaten lokal speichern (gewählte Modi, letzte Songs, Sitzungsdauer).
- **FR-021**: System MUSS einen Analyse-Fortschritt anzeigen, während ein Song vorverarbeitet wird.

### Key Entities

- **Session (Sitzung)**: Eine abgeschlossene oder laufende Stroboskop-Erfahrung; Attribute: Startzeit, Dauer, gewählter Modus, verwendete Audioquelle, durchschnittliche Intensität.
- **AudioTrack (Audio-Spur)**: Ein analysierbarer Song; Attribute: Titel, Künstler, Dauer, BPM, Beat-Map (Array von Zeitstempeln), Spektral-Profil.
- **LightScript (Licht-Skript)**: Die berechnete Sequenz von Licht-Ereignissen; Attribute: Zeitstempel, Intensität, Dauer, Wellenform.
- **UserPreferences (Nutzereinstellungen)**: Persistente Einstellungen; Attribute: bevorzugter Modus, bevorzugte Lichtquelle, Intensitätspräferenz, Sicherheitsbestätigung erteilt.
- **EntrainmentMode (Synchronisations-Modus)**: Definition eines Zielzustands; Attribute: Name, Ziel-Frequenzband (Hz), Beschreibung, empfohlene Musikgenres.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Nutzer können innerhalb von 60 Sekunden vom App-Start bis zur laufenden Stroboskop-Sitzung mit eigenem Song gelangen.
- **SC-002**: Die Beat-Synchronisation ist für Nutzer wahrnehmbar korrekt in mindestens 85% der getesteten Songs (subjektive Bewertung "synchron" oder "meist synchron").
- **SC-003**: 90% der Testsitzungen (10+ Minuten) laufen ohne unerwartete Unterbrechungen oder Fehler durch.
- **SC-004**: Nutzer bewerten das Erlebnis als "deutlich anders als zufälliges Blinken" (4+ von 5 Sternen für "Synchronisationsqualität" in Umfragen).
- **SC-005**: Die App erhält keine Ablehnungen im App Store aufgrund von Sicherheitsbedenken oder medizinischen Claims.
- **SC-006**: Das Gerät überhitzt nicht kritisch (keine iOS-Zwangsabschaltung der Taschenlampe) bei standardmäßigen Sitzungen (≤15 Minuten, mittlere Intensität).
- **SC-007**: Nutzer mit verschiedenen Musikgenres (elektronisch, klassisch, Pop, Ambient) können die App erfolgreich nutzen.
- **SC-008**: Die App startet und ist nutzungsbereit innerhalb von 3 Sekunden auf Zielgeräten (iPhone 12 oder neuer).

## Assumptions

Die folgenden Annahmen wurden getroffen, wo die ursprüngliche Beschreibung keine expliziten Details enthielt:

- **Zielplattform**: iOS 17+ (wie in der Verfassung definiert), primär iPhone.
- **Audioquellen**: Zunächst nur DRM-freie lokale Dateien und Mikrofon; keine direkte Streaming-Integration in Phase 1.
- **Sitzungsdauer**: Typische Sitzungen dauern 5-20 Minuten; das System optimiert für diesen Bereich.
- **Nutzerposition**: Der Nutzer liegt oder sitzt mit geschlossenen Augen; das Telefon ist stabil positioniert (nicht in der Hand).
- **Umgebung**: Dunkler, ruhiger Raum für optimale Wirkung.
- **Keine Cloud-Synchronisation**: Alle Daten bleiben lokal auf dem Gerät (Datenschutz-First).
- **Kein Account-System**: Die App funktioniert ohne Registrierung oder Login.
- **Wellness-Positionierung**: Die App wird als Wellness/Meditation-Tool vermarktet, nicht als medizinisches Gerät.
