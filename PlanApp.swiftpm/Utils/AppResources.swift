import Foundation
import UIKit

/// Private marker class used to locate the bundle this code was compiled into.
private final class AppResourcesBundleToken {}

/// Zentrale Ressourcen-Suche für das App-Modul.
///
/// **Warum es diesen Typ gibt:**
/// `Bundle.module` ist *kein* Bestandteil der Foundation-API, sondern wird von
/// SwiftPM pro Target in einer generierten Datei (`resource_bundle_accessor.swift`)
/// erzeugt. Swift Playgrounds baut das App-Modul einer `.swiftpm`-App selbst und
/// kopiert den Inhalt von `Resources/` direkt in das App-Bundle – dieser Accessor
/// wird dabei nie erzeugt. Jede Verwendung von `Bundle.module` schlägt dort mit
///
///     Type 'Bundle' has no member 'module'
///
/// fehl und lässt damit den kompletten Build ("Build failed") scheitern.
///
/// `AppResources` löst das Bundle stattdessen zur Laufzeit auf und funktioniert
/// deshalb gleichermaßen in Swift Playgrounds (Ressourcen liegen im Haupt-Bundle)
/// und in Xcode/SwiftPM (Ressourcen liegen in einem verschachtelten
/// `<Paket>_<Target>.bundle`).
public enum AppResources {

    /// Alle Bundles, die die Ressourcen der App enthalten können – sortiert von
    /// der wahrscheinlichsten zur unwahrscheinlichsten Quelle.
    public static let bundles: [Bundle] = {
        var seenURLs = Set<URL>()
        var found: [Bundle] = []

        func add(_ bundle: Bundle?) {
            guard let bundle, seenURLs.insert(bundle.bundleURL).inserted else { return }
            found.append(bundle)
        }

        // Swift Playgrounds: Ressourcen landen direkt im App-Bundle.
        add(Bundle.main)
        // Bundle, in dem dieser Code selbst liegt (identisch zu `.main` in einer
        // App, abweichend sobald der Code in ein Framework eingebettet wird).
        add(Bundle(for: AppResourcesBundleToken.self))

        // Xcode/SwiftPM: Ressourcen stecken in einem eigenen Ressourcen-Bundle.
        let nestedBundleNames = [
            "PlanApp_AppModule",
            "AppModule_AppModule",
            "PlanApp_PlanApp",
            "AppModule",
            "PlanApp"
        ]

        let roots = found
        for root in roots {
            for name in nestedBundleNames {
                guard let url = root.url(forResource: name, withExtension: "bundle") else { continue }
                add(Bundle(url: url))
            }
        }

        return found
    }()

    /// Lädt ein Bild aus den App-Ressourcen.
    ///
    /// Sucht zuerst über `UIImage(named:in:compatibleWith:)` (Asset-Kataloge und
    /// lose Dateien im Bundle-Root) und fällt danach auf eine direkte
    /// Datei-Suche zurück, damit auch Ressourcen gefunden werden, die in einem
    /// Unterordner wie `Resources/` liegen.
    ///
    /// - Parameters:
    ///   - name: Dateiname mit oder ohne Endung, z. B. `"AppLogo"`.
    ///   - fileExtensions: Endungen, die bei der Datei-Suche probiert werden.
    public static func image(
        named name: String,
        fileExtensions: [String] = ["png", "PNG", "jpg", "jpeg", "heic", "pdf"]
    ) -> UIImage? {
        let baseName = (name as NSString).deletingPathExtension
        let explicitExtension = (name as NSString).pathExtension

        for bundle in bundles {
            if let image = UIImage(named: baseName, in: bundle, compatibleWith: nil) {
                return image
            }
        }

        var extensionsToTry = fileExtensions
        if !explicitExtension.isEmpty {
            extensionsToTry.removeAll { $0.caseInsensitiveCompare(explicitExtension) == .orderedSame }
            extensionsToTry.insert(explicitExtension, at: 0)
        }

        if let fileURL = Self.url(forResource: baseName, withExtensions: extensionsToTry),
           let image = UIImage(contentsOfFile: fileURL.path) {
            return image
        }

        return nil
    }

    /// Sucht eine Ressourcen-Datei in allen bekannten Bundles – inklusive des
    /// `Resources`-Unterordners, den Swift Playgrounds beim Kopieren erhalten kann.
    public static func url(forResource name: String, withExtensions extensions: [String]) -> URL? {
        let subdirectories: [String?] = [nil, "Resources"]

        for bundle in bundles {
            for subdirectory in subdirectories {
                for fileExtension in extensions {
                    if let fileURL = bundle.url(
                        forResource: name,
                        withExtension: fileExtension,
                        subdirectory: subdirectory
                    ) {
                        return fileURL
                    }
                }
            }
        }

        return nil
    }
}
