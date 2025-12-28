# **Technischer Migrationsbericht: Portierung der MindSync-Architektur von Android auf iOS – Eine Analyse von Echtzeit-AV-Synchronisation, DSP und Hardware-Steuerung**

## **Executive Summary**

Dieser Forschungsbericht präsentiert eine erschöpfende technische Analyse und Implementierungsstrategie für die Portierung der MindSync-Anwendung von einer Android-basierten Architektur auf das iOS-Ökosystem. Die ursprüngliche Android-Version stützt sich auf spezifische Low-Level-APIs wie Camera2 für die stroboskopische Lichtsteuerung, AAudio für die latenzarme Audiosynthese und TarsosDSP für die Signalverarbeitung. Die direkte Übersetzung dieser Technologien ist aufgrund fundamentaler Unterschiede in der Betriebssystemarchitektur, dem Hardware-Abstraktionsmodell und den Sicherheitsrichtlinien von Apple nicht möglich.

Der Bericht identifiziert AVFoundation, AVAudioEngine und das Accelerate Framework (vDSP) als die notwendigen nativen Äquivalente. Er geht jedoch weit über eine bloße API-Zuordnung hinaus und adressiert kritische systemische Herausforderungen, die bei der Migration auftreten: das aggressive thermische Management von iOS-Geräten, die Komplexität der Audio-Visuellen Synchronisation unter Berücksichtigung variabler Bluetooth-Latenzen und die Nutzung der Neural Engine für digitale Signalverarbeitung (DSP). Ziel ist die Entwicklung einer robusten, hochperformanten iOS-Applikation, die neurale Entrainment-Frequenzen (Alpha, Theta, Gamma) mit mikrosekundengenauer Präzision generiert und dabei die Hardware-Integrität wahrt.

## ---

**1\. Einführung: Architektonische Paradigmenwechsel**

Die Migration einer komplexen audiovisuellen Anwendung wie MindSync von Android zu iOS erfordert mehr als nur die syntaktische Übersetzung von Java oder Kotlin zu Swift. Sie verlangt ein tiefgreifendes Verständnis der unterschiedlichen Philosophien, die den beiden Plattformen zugrunde liegen, insbesondere im Umgang mit Hardware-Ressourcen und Echtzeit-Threads.

### **1.1 Androids permissive vs. iOS' restriktive Hardware-Kontrolle**

In der Android-Welt bietet die Camera2 API Entwicklern einen vergleichsweise direkten Zugriff auf die Kamerahardware. Es ist möglich, "Repeating Requests" zu senden, die die Hardware in einem definierten Takt steuern, und das Betriebssystem greift nur selten regulierend ein, solange keine kritischen Temperaturen erreicht werden. Dies ermöglichte MindSync unter Android eine aggressive Steuerung der LED für stroboskopische Effekte.

Unter iOS hingegen fungiert AVFoundation als strenger Wächter über die Kamera-Hardware. Jeder Zugriff auf das AVCaptureDevice muss durch den mediaserverd (Media Server Daemon) laufen. Dieser Daemon priorisiert Systemstabilität und thermische Sicherheit über die Wünsche der Applikation. Wenn MindSync versucht, die LED mit 40 Hz (Gamma-Wellen) zu schalten, interpretiert iOS dies potenziell als Fehlverhalten oder als Risiko für die Hardware und kann den Zugriff drosseln oder verweigern. Die iOS-Architektur erfordert daher einen kooperativen Ansatz: Die App muss ihren Ressourcenbedarf anmelden, den thermischen Zustand (ProcessInfo.thermalState) überwachen und ihre Anforderungen dynamisch anpassen, anstatt stur Befehle zu senden.

### **1.2 Echtzeit-Audio und Threading-Modelle**

Androids AAudio wurde spezifisch entwickelt, um die Fragmentierung und Latenzprobleme früherer Android-Versionen zu lösen, indem es einen direkten Pfad ("Fast Path") zum Audiotreiber (ALSA) via MMAP bereitstellt. Es ist ein "Pull"-basiertes System, bei dem der Audio-Thread Daten anfordert.

iOS nutzt mit AVAudioEngine ein objektorientiertes Graphen-Modell, das auf der bewährten Core Audio Infrastruktur aufsetzt. Während Core Audio (in C/C++) extrem leistungsfähig ist, bietet die AVAudioEngine (in Swift/Obj-C) eine höhere Abstraktionsebene. Die Herausforderung für MindSync besteht darin, die Echtzeit-Garantien, die AAudio bietet, in der Swift-Welt zu replizieren. Swift ist eine Sprache mit automatischer Speicherverwaltung (ARC). In einem Echtzeit-Audio-Callback (Render Block) sind Speicherallokationen oder das Retain/Release von Objekten streng verboten, da sie zu "Priority Inversion" und Audio-Aussetzern (Glitches) führen können. Die Migration erfordert daher die Nutzung von UnsafeMutablePointer und C-ähnlichen Strukturen innerhalb von Swift, um die gleiche Performance wie unter Android zu erreichen.

## ---

**2\. Visuelle Stimulation: Von Camera2 zu AVFoundation**

Das Kernstück der visuellen Komponente von MindSync ist die Erzeugung präziser Lichtpulse im Frequenzbereich von 0,5 Hz (Delta) bis 50 Hz (Gamma), um neurale Entrainment-Effekte zu induzieren. Die Analyse der iOS-APIs zeigt, dass die naive Portierung der Android-Logik zu unzureichenden Ergebnissen führen würde.

### **2.1 Das Latenz-Problem der LED-Hardware**

Ein kritischer, oft unterschätzter Faktor ist die physikalische Trägheit der LED und der Software-Stack-Overhead. Wenn die App den Befehl device.torchMode \=.on sendet, geschieht folgendes:

1. **IPC Overhead:** Der Befehl wird an den mediaserverd gesendet (Inter-Process Communication).  
2. **Hardware-Treiber:** Der Treiber weist den ISP (Image Signal Processor) an, die Stromzufuhr zur LED zu aktivieren.  
3. **Physikalischer Ramp-Up:** Die LED benötigt Zeit, um ihre volle Helligkeit zu erreichen. Dies ist oft als Schutzmechanismus implementiert, um Stromspitzen zu vermeiden.

Untersuchungen an iPhone-Modellen zeigen, dass die Latenz zwischen Befehl und Lichtemission variieren kann. Bei Videosignalen wird dies oft kompensiert, aber bei stroboskopischen Effekten führt diese Verzögerung dazu, dass bei hohen Frequenzen (z.B. 40 Hz, also 25ms Periodendauer) die LED möglicherweise gar nicht ihre volle Helligkeit erreicht, bevor der Ausschaltbefehl kommt. Das resultierende Lichtsignal ist kein sauberes Rechtecksignal (An/Aus), sondern eine wellenförmige Helligkeitsänderung mit reduziertem Kontrast. Dies schwächt den neurobiologischen Effekt ab, da das Gehirn besonders stark auf steile Transienten reagiert.

Lösungsstrategie: AVCaptureSession als "Keep-Alive"  
Unter Android kann der Camera2-Service oft isoliert angesprochen werden. Unter iOS ist es essenziell, eine laufende AVCaptureSession zu unterhalten, selbst wenn keine Bilder aufgezeichnet werden. Eine aktive Session hält die ISP-Hardware und den Stromregler für die LED in einem "warmen", aktiven Zustand. Ohne laufende Session würde das System zwischen den Blitzen versuchen, in einen Energiesparmodus zu wechseln, was die Latenz beim nächsten Blitz ("Cold Start") drastisch erhöht.  
Die Implementierung muss daher folgende Schritte umfassen:

1. Initialisierung einer AVCaptureSession.  
2. Konfiguration eines Inputs (AVCaptureDeviceInput), auch wenn kein Output (wie AVCaptureVideoDataOutput) benötigt wird – oder Nutzung eines Dummy-Outputs, um iOS zufrieden zu stellen.  
3. Aufruf von session.startRunning(). Dies signalisiert dem System dauerhafte Bereitschaft.

### **2.2 Präzise Helligkeitssteuerung: setTorchModeOn(level:)**

Ein wesentlicher Unterschied zur einfachen Taschenlampen-App ist die Notwendigkeit der Helligkeitsmodulation. Androids Camera2 API erlaubt oft granulare Kontrolle. Unter iOS ist die Methode setTorchModeOn(level: Float) der Schlüssel.

Die einfache Zuweisung torchMode \=.on aktiviert oft nur einen Standardwert oder überlässt dem System die Wahl basierend auf der Umgebungshelligkeit. Für reproduzierbares Neural Entrainment ist dies inakzeptabel. setTorchModeOn(level:) akzeptiert einen Float-Wert zwischen 0.0 und 1.0 (oder AVCaptureDevice.maxAvailableTorchLevel).

**Kritische Beobachtung:** Der Parameter level ist nicht linear zur wahrgenommenen Helligkeit und auch nicht linear zur Leistungsaufnahme. Bei einem Wert von 1.0 (Maximum) generiert die LED signifikante Hitze. Bei einem Stroboskop-Effekt mit 50% Duty Cycle (Hälfte der Zeit an) ist die thermische Belastung immer noch enorm.

### **2.3 Thermisches Management und Drosselung (Thermal Throttling)**

Hier liegt das größte Risiko der Migration. iOS überwacht die Gerätetemperatur penibel über ProcessInfo.processInfo.thermalState. Es gibt vier Zustände: .nominal, .fair, .serious und .critical.

Wenn MindSync die LED im Stroboskop-Modus betreibt, steigt die Temperatur des Kameramoduls schnell an.

* **Android:** Lässt das Gerät oft heiß werden, bis Hardware-Schutzschaltungen greifen.  
* **iOS:** Das Betriebssystem greift *softwareseitig* ein, lange bevor die Hardware gefährdet ist. Wenn der Status .serious erreicht, kann iOS den torchLevel stillschweigend begrenzen oder den Torch-Modus komplett deaktivieren. Ein Aufruf von setTorchModeOn wirft dann eine Exception oder wird ignoriert.

Implementierung einer thermischen Regelschleife:  
Die iOS-App darf nicht blind feuern. Sie muss den thermalState aktiv überwachen (via Key-Value Observing oder Notification Center) und die Parameter anpassen.

| Thermal State | Empfohlene Strategie für MindSync |
| :---- | :---- |
| .nominal | Volle Funktionalität. maxAvailableTorchLevel kann genutzt werden. |
| .fair | Reduktion des torchLevel auf maximal 0.5. Duty Cycle ggf. verringern. |
| .serious | Drastische Reduktion auf torchLevel 0.1 oder Abschaltung der visuellen Stimulation (Fallback auf Audio/Haptik). Warnung an Nutzer. |
| .critical | Sofortige Einstellung aller thermisch relevanten Prozesse. |

Diese Logik existiert in der Android-Version vermutlich nicht in dieser Form, ist aber für eine stabile iOS-App unerlässlich, um Abstürze oder Systeminterventionen zu verhindern.

### **2.4 Timing-Architektur: DispatchSourceTimer vs. CADisplayLink**

Die Generierung der exakten Frequenz ist für Brainwave Entrainment entscheidend. Eine Abweichung (Jitter) kann den Effekt zunichtemachen.

**Analyse der Optionen:**

1. **Timer (ehemals NSTimer):** Dieser Timer läuft auf dem RunLoop des Hauptthreads. Wenn die UI aktualisiert wird (z.B. Scrollen, Animationen), wird der Timer blockiert oder verzögert. Die Genauigkeit liegt im Bereich von 50-100ms, was für 40 Hz (25ms Intervall) völlig unzureichend ist.  
2. **CADisplayLink:** Dieser Timer feuert synchron zur Bildwiederholrate (V-Sync) des Displays (meist 60 Hz oder 120 Hz bei ProMotion).  
   * *Problem:* Er ist an die Framerate gebunden. Um 10 Hz zu erzeugen, feuert man alle 6 Frames (bei 60 Hz). Aber um z.B. 14 Hz zu erzeugen, müsste man alle 4,28 Frames feuern, was unmöglich ist. Dies führt zu Aliasing und unregelmäßigen Mustern.  
3. **DispatchSourceTimer (GCD):** Dies ist der Goldstandard für diese Anforderung unter iOS.  
   * Er läuft auf einer beliebigen DispatchQueue (vorzugsweise einer Hintergrund-Queue mit hoher Priorität .userInteractive).  
   * Er ist unabhängig vom RunLoop und der UI.  
   * Mit dem Flag .strict konfiguriert, versucht das System, das Timing so exakt wie möglich einzuhalten ("Best Effort").

Empfohlene Architektur:  
MindSync sollte einen DispatchSourceTimer verwenden, der auf einer dedizierten seriellen Queue läuft. Dieser Timer triggert die Ein- und Ausschaltvorgänge der LED. Um die Blockierung des Threads durch lockForConfiguration() zu minimieren, sollte der Lock idealerweise über die gesamte Dauer der Stroboskop-Sequenz gehalten werden. Apple rät davon ab ("Holding the lock unnecessarily allows other apps to change settings"), aber für eine dedizierte Session ist es oft der einzige Weg, um Latenzen von 20-30ms pro Schaltvorgang zu vermeiden. Ein Kompromiss ist das Sperren für kurze Bursts.

## ---

**3\. Audiosynthese: Migration von AAudio zu AVAudioEngine**

Die auditive Stimulation mittels binauraler Beats oder isochroner Töne erfordert eine präzise Wellenformgenerierung. Unter Android nutzte MindSync AAudio für Low-Latency-Output. Unter iOS ist AVAudioEngine das Mittel der Wahl.

### **3.1 Die Architektur der AVAudioEngine**

AVAudioEngine stellt einen Graphen aus Nodes dar. Für MindSync benötigen wir keine Datei-Playback-Nodes (AVAudioPlayerNode), sondern einen Generator, der Sinuswellen in Echtzeit berechnet. Seit iOS 12/13 steht hierfür der AVAudioSourceNode zur Verfügung.

Der AVAudioSourceNode akzeptiert einen Closure (Block), der vom Audio-Thread des Systems aufgerufen wird, wann immer neue PCM-Daten (Pulse Code Modulation) benötigt werden.

**Vergleich AAudio vs. AVAudioEngine:**

* **AAudio:** Manuelles Management von Puffern, Formatkonvertierung (falls Hardware nicht nativ unterstützt), Schreiben in Streams. Sehr nah an der Hardware ("Metal").  
* **AVAudioEngine:** Automatische Formatkonvertierung, Mixing, Routing. Der Entwickler konzentriert sich rein auf die algorithmische Befüllung des Puffers.

### **3.2 Implementierung des Render-Blocks (Swift)**

Die Herausforderung in Swift ist die "Real-Time Safety". Der Garbage Collector (in Java) oder ARC (in Swift) können unvorhersehbare Pausen verursachen. Innerhalb des Render-Blocks dürfen keine Operationen stattfinden, die den Thread blockieren könnten:

* Keine Speicherallokation (malloc, Array(), Klassen-Instanziierung).  
* Keine Locks (objc\_sync\_enter, NSLock).  
* Keine Objective-C Message Sends (da diese dynamisch aufgelöst werden).  
* Kein Swift-Runtime-Overhead (z.B. dynamische Casts).

Technische Umsetzung:  
Der Render-Block erhält Pointer auf die Ausgabepuffer (UnsafeMutableAudioBufferListPointer). Wir müssen direkt in diese Speicherbereiche schreiben.

Swift

// Beispielhafte Struktur für den Render-Block  
let renderBlock: AVAudioSourceNodeRenderBlock \= { \_, \_, frameCount, audioBufferList \-\> OSStatus in  
    let ablPointer \= UnsafeMutableAudioBufferListPointer(audioBufferList)  
      
    // Annahme: Stereo-Output, Non-Interleaved (Planar)  
    let bufferL \= UnsafeMutableBufferPointer\<Float\>(ablPointer)  
    let bufferR \= UnsafeMutableBufferPointer\<Float\>(ablPointer\[1\])  
      
    for frame in 0..\<Int(frameCount) {  
        // Berechnung des Samples für den aktuellen Zeitpunkt  
        let sampleL \= sin(currentPhaseL)  
        let sampleR \= sin(currentPhaseR)  
          
        bufferL\[frame\] \= sampleL  
        bufferR\[frame\] \= sampleR  
          
        // Phaseninkrementierung für den nächsten Schritt  
        currentPhaseL \+= phaseIncrementL  
        currentPhaseR \+= phaseIncrementR  
          
        // Wrap-Around bei 2\*Pi  
        if currentPhaseL \> twoPi { currentPhaseL \-= twoPi }  
        if currentPhaseR \> twoPi { currentPhaseR \-= twoPi }  
    }  
    return noErr  
}

Die Variablen currentPhaseL, phaseIncrementL etc. müssen von außen ("Capture List") in den Block gereicht werden. Da es sich um *Value Types* handeln muss (wegen Thread Safety), werden oft Pointer auf Structs verwendet, die außerhalb des Blocks leben.

### **3.3 Binaurale Beats: Mathematische Grundlagen**

Für einen Binauralen Beat im Theta-Bereich (z.B. 6 Hz) bei einer Trägerfrequenz von 200 Hz:

* Linkes Ohr: 200 Hz  
* Rechtes Ohr: 206 Hz

Das Gehirn synthetisiert die Differenz (6 Hz) im Nucleus olivaris superior.  
Die Berechnung des Phaseninkrements ($\\Delta\\phi$) pro Sample ist:

$$\\Delta\\phi \= \\frac{2 \\pi \\cdot f}{f\_{sample}}$$

wobei $f\_{sample}$ typischerweise 44.100 Hz oder 48.000 Hz beträgt.  
**Wichtig:** MindSync muss sicherstellen, dass AVAudioEngine mit der nativen Samplerate der Hardware läuft, um unnötige Resampling-Schritte zu vermeiden, die CPU kosten und Qualität mindern könnten.

### **3.4 Das Bluetooth-Latenz-Problem und Kompensation**

Ein massives Problem bei der Nutzung von drahtlosen Kopfhörern (AirPods etc.) ist die Latenz. Während das Licht (Stroboskop) vom Gerät instantan emittiert wird, benötigt das Audio-Signal via Bluetooth A2DP (Advanced Audio Distribution Profile) oft 150ms bis 300ms, bis es das Ohr erreicht.

Dies führt zu einer Desynchronisation: Der Nutzer sieht den Blitz, hört aber den korrespondierenden Ton erst eine Viertelsekunde später. Für Neural Entrainment, das auf synchronen Reizen basiert, ist dies fatal.

Lösung: Der Visuelle Delay-Puffer  
Da wir die Audio-Latenz physikalisch nicht eliminieren können, müssen wir das Licht verzögern, um Synchronizität wiederherzustellen.

1. **Messung:** AVAudioSession.sharedInstance().outputLatency liefert einen dynamischen Schätzwert der aktuellen Latenz (inklusive Hardware-Buffer und Bluetooth-Übertragung).  
2. **Pufferung:** Wir implementieren einen Ringpuffer (Circular Buffer) für die Licht-Steuerbefehle.  
   * Der "Master Clock" generiert Ereignisse (z.B. "Blitz An") zum Zeitpunkt T.  
   * Das Audio-System verarbeitet dies sofort (und die Latenz verzögert es physikalisch auf T \+ Latenz).  
   * Das Licht-System schreibt das Ereignis in den Ringpuffer.  
   * Ein Konsument liest aus dem Ringpuffer mit einem Versatz, der der gemessenen Latenz entspricht, und triggert dann erst die Torch.

Circular Buffer Implementierung:  
Ein Array fester Größe fungiert als Puffer. Ein Schreib-Zeiger (Head) bewegt sich vorwärts, ein Lese-Zeiger (Tail) folgt ihm mit einem Abstand, der der Latenz entspricht.

$$\\text{ReadIndex} \= (\\text{WriteIndex} \- \\text{DelaySamples} \+ \\text{BufferSize}) \\% \\text{BufferSize}$$  
Diese Technik ist essenziell für die iOS-Version, da iPhone-Nutzer überproportional häufig Bluetooth-Kopfhörer verwenden.

## ---

**4\. Signalverarbeitung (DSP): Von TarsosDSP zu vDSP (Accelerate)**

TarsosDSP ist eine Java-Bibliothek für Audioanalyse (Pitch Detection, Onset Detection). iOS bietet hierfür das Accelerate Framework, das direkten Zugriff auf die Vektor-Einheiten (SIMD) der CPU bietet.

### **4.1 Performance-Vorteile von vDSP**

Während TarsosDSP in der Java Virtual Machine läuft und auf JIT-Kompilierung angewiesen ist, sind vDSP-Funktionen handoptimierte Assembler-Routinen. Auf modernen Apple Silicon Chips (A-Series) nutzen diese die NEON-Einheiten oder sogar die AMX (Apple Matrix Co-processor) Einheiten. Eine FFT (Fast Fourier Transformation) mit vDSP ist um Faktoren schneller und energieeffizienter als jede High-Level-Implementierung.

### **4.2 Analyse der Umgebungsmusik (FFT)**

MindSync analysiert vermutlich Umgebungsmusik, um Lichteffekte darauf abzustimmen.  
Der Ablauf in vDSP unterscheidet sich von TarsosDSP durch höhere Komplexität im Setup:

1. **Datenvorbereitung:** Audiodaten kommen meist als Interleaved Samples (LRLR...). vDSP benötigt "Split Complex" Format (DSPSplitComplex), also getrennte Arrays für Real- und Imaginärteile. Die Funktion vDSP\_ctoz (Complex to Zero) konvertiert dies.  
2. **Fensterung (Windowing):** Um spektrale Leckeffekte (Spectral Leakage) zu minimieren, muss das Zeitsignal mit einer Fensterfunktion multipliziert werden. TarsosDSP macht das oft implizit. In vDSP muss man ein Hanning- oder Blackman-Fenster explizit generieren (vDSP\_hann\_window) und mittels vDSP\_vmul auf die Daten anwenden.  
3. **FFT Ausführung:** vDSP\_fft\_zrip führt die eigentliche Transformation durch.  
4. **Magnituden:** Das Ergebnis sind komplexe Zahlen. Um das Frequenzspektrum zu erhalten, müssen die Beträge berechnet werden (vDSP\_zvmags).

### **4.3 Beat Detection (Onset Detection) Algorithmen**

Die Erkennung des Taktes (Beat) ist für die Lichtsynchronisation zentral. Es gibt zwei Hauptansätze:

A. Energie-basierte Erkennung (Time Domain):  
Dies ist der einfachste und schnellste Ansatz. Man berechnet die Energie des Signals (RMS \- Root Mean Square) und sucht nach plötzlichen Anstiegen.

* **vDSP:** vDSP\_rmsqv berechnet den RMS-Wert eines Vektors extrem schnell.  
* **Algorithmus:**  
  1. Berechne RMS für den aktuellen Puffer (z.B. 1024 Samples).  
  2. Führe diesen Wert in einen "Moving Average" Puffer ein, der die durchschnittliche Energie der letzten Sekunde repräsentiert (lokale Energie).  
  3. Vergleiche: Ist Aktueller RMS \> (Durchschnitt \* Threshold\_Faktor)?  
  4. Wenn ja \-\> Beat erkannt.  
  5. Hysterese: Ignoriere weitere Beats für z.B. 150ms, um Doppelauslösungen zu vermeiden.

B. Spektrale Flussdichte (Frequency Domain):  
Präziser, aber rechenintensiver. Man vergleicht das Frequenzspektrum des aktuellen Frames mit dem des vorherigen. Starke Änderungen in den tiefen Frequenzen (Bass) deuten auf einen Beat hin.

* Hierfür wird die oben beschriebene FFT-Pipeline genutzt. Man subtrahiert die Magnituden des aktuellen Frames von denen des vorherigen Frames (nur positive Änderungen). Die Summe dieser Differenzen ist der "Spectral Flux".

Für eine Echtzeit-App auf einem Mobilgerät ist die **energie-basierte Erkennung** oft der bessere Kompromiss aus Latenz und Genauigkeit, solange die Musik rhythmisch klar strukturiert ist. TarsosDSP bietet komplexe Algorithmen; für iOS empfiehlt sich der Start mit einer sauberen vDSP-RMS-Implementierung, da diese weniger CPU-Last erzeugt und somit thermischen Spielraum für die Torch lässt.

## ---

**5\. Haptisches Feedback: Core Haptics als Game Changer**

Die haptische Komponente wurde in der Android-Version (vermutlich über die einfache Vibrator API) eher stiefmütterlich behandelt. iOS bietet mit **Core Haptics** (ab iPhone 8\) eine Technologie, die präzise, wellenform-basierte Vibrationen erlaubt.

### **5.1 Synchronisation von Tastsinn und Gehirnwellen**

Taktile Stimulation kann das auditive und visuelle Entrainment verstärken. Core Haptics erlaubt es, Vibrationen zu erzeugen, die exakt der Frequenz der binauralen Beats folgen.

Continuous Events:  
Anstatt nur kurz zu vibrieren ("Bzzzt"), kann Core Haptics einen kontinuierlichen Reiz erzeugen, dessen Intensität und "Schärfe" (Sharpness) in Echtzeit moduliert werden können.

* Ein 10 Hz Alpha-Beat kann von einer sanften, pulsierenden Vibration begleitet werden, die sinusförmig an- und abschwillt.  
* Dies wird über CHHapticEventParameter gesteuert (.hapticIntensity, .hapticSharpness).

Dynamic Parameters:  
Während das Audio-Pattern läuft, kann die App CHHapticDynamicParameter an den CHHapticAdvancedPatternPlayer senden, um die Vibration ohne Unterbrechung zu verändern. Dies ist analog zur Änderung der Frequenz im AVAudioSourceNode.

### **5.2 AHAP: Das Dateiformat für Haptik**

Apple Haptic Audio Pattern (AHAP) ist ein JSON-ähnliches Format zur Definition von haptischen Mustern. MindSync kann komplexe Entrainment-Sessions als AHAP-Dateien vordefinieren, die dann synchron zum Audio abgespielt werden. Dies entlastet den Code von imperativen Vibrationsbefehlen und erlaubt Sound-Designern, die Haptik separat zu entwerfen.

## ---

**6\. Systemintegration und Architektur**

Die Zusammenführung dieser Subsysteme (Torch, Audio, DSP, Haptik) erfordert eine robuste Architektur.

### **6.1 Der Session Controller (Master Clock)**

Es darf nicht mehrere unabhängige Timer geben (einen für Licht, einen für Audio). Ein zentraler SessionController muss die Zeitbasis bilden.

* Er läuft auf einer Hintergrund-Queue.  
* Er berechnet den aktuellen Zustand der Session (z.B. "Minute 5: Wir sind jetzt bei 7 Hz Theta").  
* Er aktualisiert die Parameter der Subsysteme (Audio-Frequenz, Licht-Frequenz, Haptik-Intensität).

### **6.2 Umgang mit Hintergrund-Aktivität**

Eine Audio-Entrainment-App wird oft mit geschlossenen Augen oder bei ausgeschaltetem Bildschirm genutzt.

* **Audio:** Muss im Hintergrund weiterlaufen. Dazu muss in den Project Capabilities "Audio, AirPlay, and Picture in Picture" aktiviert sein und die AVAudioSession Kategorie auf .playback gesetzt werden.  
* **Licht (Torch):** Hier gibt es eine harte Restriktion unter iOS. **Die Taschenlampe darf nicht leuchten, wenn die App im Hintergrund ist.** Das System schaltet sie zwangsweise ab.  
* **Strategie:** Die App muss auf UIApplication.didEnterBackgroundNotification reagieren.  
  * Licht-Controller stoppen.  
  * Audio sanft weiterlaufen lassen oder faden (je nach User-Preference).  
  * Haptik stoppen (da das Gerät meist weggelegt wird).  
  * Beim Wiederkehren (willEnterForeground) muss die Torch-Session neu initialisiert werden (Achtung vor der "Cold Start" Latenz\!).

## ---

**7\. Sicherheit und Regulatorik**

### **7.1 Photosensitive Epilepsie**

Die App generiert Stroboskop-Effekte. iOS bietet keine systemweite Warnung hierfür. Die App muss beim ersten Start einen rechtlich wasserdichten Disclaimer anzeigen ("Health & Safety Warning").  
Es sollte ein "Kill Switch" implementiert werden: Wenn der Nutzer das Display berührt oder das Gerät schüttelt (detektiert via Core Motion), müssen Licht und Ton sofort stoppen.

### **7.2 Hardware-Schutz (Duty Cycle Limitierung)**

Um Überhitzung zu vermeiden, sollte softwareseitig ein maximaler Duty Cycle implementiert werden.

* Gamma (40 Hz): Kurze Blitze sind effektiver und kühler als lange. Ein Duty Cycle von 10-20% (Licht an für 2-5ms) ist oft ausreichend für den visuellen Effekt und schont die LED drastisch im Vergleich zu 50%.

## ---

**8\. Fazit**

Die Migration von MindSync auf iOS ist technisch anspruchsvoll, da sie den Wechsel von einer "direkten Steuerung" (Android) zu einer "orchestrierten Anfrage" (iOS) erfordert.

* **Visuell:** AVCaptureDevice mit setTorchModeOn(level:) und striktem thermischen Monitoring ersetzt Camera2.  
* **Audio:** AVAudioSourceNode in AVAudioEngine ersetzt AAudio, bietet aber ähnliche Low-Latency-Performance bei korrekter Swift-Pointer-Nutzung. Die Bluetooth-Latenzkompensation via Circular Buffer ist ein kritisches neues Feature für die iOS-UX.  
* **DSP:** vDSP (Accelerate) bietet massive Performance-Vorteile gegenüber TarsosDSP, erfordert aber komplexeres Boilerplate-Code-Setup für FFTs.  
* **Haptik:** Core Haptics bietet die Chance, die App signifikant aufzuwerten und ein immersiveres Erlebnis als auf Android zu bieten.

Durch die Beachtung dieser plattformspezifischen Eigenheiten wird die iOS-Version von MindSync keine bloße Portierung, sondern eine technologisch verfeinerte Evolution des Produkts darstellen.

## **Referenztabelle: Technologie-Mapping**

| Funktion | Android Technologie | iOS Äquivalent | Kritischer Faktor |
| :---- | :---- | :---- | :---- |
| **Licht-Steuerung** | Camera2 API (setRepeatingRequest) | AVCaptureDevice (setTorchModeOnWithLevel) | Thermisches Throttling & Latenz-Puffern |
| **Audio-Synthese** | AAudio (C++) | AVAudioEngine / AVAudioSourceNode (Swift) | Real-Time Safety im Render Block |
| **Signalverarbeitung** | TarsosDSP (Java) | Accelerate Framework / vDSP | Komplexes FFT-Setup, SIMD-Performance |
| **Timing** | Handler / Java Timer | DispatchSourceTimer (GCD) | Unabhängigkeit vom UI-RunLoop |
| **Haptik** | Vibrator API | Core Haptics (CHHapticEngine) | Synchronisation mit Audio |
| **Hintergrund** | Service | Background Modes (Audio) | Torch-Abschaltung im Hintergrund beachten |

