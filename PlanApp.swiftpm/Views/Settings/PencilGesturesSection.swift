import SwiftUI

/// Bedienhinweise zu Apple Pencil Pro und den Gesten auf der Zeichenfläche.
struct PencilGesturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.scribble")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.blue)
                Text("Apple Pencil Pro & Gesten")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 12) {
                hintRow(
                    icon: "hand.tap",
                    tint: .blue,
                    title: "Notizen öffnen",
                    text: "Tippe auf ein Fach im Stundenplan, um die handschriftliche Zeichenfläche nahtlos zu öffnen."
                )

                hintRow(
                    icon: "pencil.tip",
                    tint: .orange,
                    title: "Apple Pencil Stift & Radierer",
                    text: "In der Zeichenfläche wird nur mit dem Apple Pencil gezeichnet. Der Standard-Radierer entfernt gezeichnete Pixel präzise."
                )

                hintRow(
                    icon: "hand.draw",
                    tint: .green,
                    title: "Verschieben & Größe ändern",
                    text: "Die Zeichenfläche lässt sich mit Fingern flüssig verschieben und über den runden Griff unten vergrößern oder verkleinern. Textfelder: 1× tippen = auswählen & verschieben, 2× tippen = Text bearbeiten. Rückgängig/Wiederholen gilt auch für Textfelder."
                )

                hintRow(
                    icon: "lineweight",
                    tint: .teal,
                    title: "Squeeze-Palette: Dicke ändern",
                    text: "Apple Pencil Pro zusammendrücken, dann den Dicken-Knopf halten und vom Kreis weg ziehen (dicker) oder zum Kreis hin (dünner). Beim Halten zeigen Hilfslinien die beiden Richtungen – sie verschwinden nach den ersten erfolgreichen Anpassungen."
                )

                hintRow(
                    icon: "line.diagonal",
                    tint: .purple,
                    title: "Gerade Linien",
                    text: "Stift oder Marker am Ende eines Strichs etwa 2 Sekunden still halten: Der Strich rastet als gerade Linie ein, der Apple Pencil Pro bestätigt das mit einem kurzen Vibrieren."
                )

                hintRow(
                    icon: "keyboard",
                    tint: .gray,
                    title: "Text auf der Zeichenfläche",
                    text: "Textfelder nutzen die normale Systemtastatur von iPadOS. In Swift Playgrounds kann die Systemtastatur gelegentlich ausbleiben – in der installierten App (z. B. per Sideloadly) funktioniert sie zuverlässig."
                )
            }
        }
        .padding(16)
        .lightCard(cornerRadius: 16, strokeOpacity: 0.25)
    }

    private func hintRow(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .regular, design: .default))
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
