import Foundation
import Combine

/// Globaler, beobachtbarer Laufzeitstatus der App.
///
/// Im Gegensatz zu `ServiceContainer` (zentrale Services) und `UserPreferences`
/// (persistente Benutzereinstellungen) ist `AppState` dafür gedacht, flüchtige
/// UI- und Sitzungszustände zu kapseln, z. B.:
/// - aktuelle Navigation oder aktiver Bildschirm
/// - laufende Vorgänge (z. B. Ladevorgänge)
/// - globale Fehlermeldungen oder Hinweise für die UI
///
/// Die Klasse ist derzeit absichtlich leer und wird bei Bedarf um passende
/// `@Published`-Eigenschaften erweitert.
final class AppState: ObservableObject {
    // Wird bei neuen Anforderungen um konkrete, flüchtige Zustände ergänzt.
}
