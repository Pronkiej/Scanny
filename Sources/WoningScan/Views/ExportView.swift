import SwiftUI
import UIKit

struct ExportView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss

    @State private var exportUrl: URL?
    @State private var foutmelding: String?
    @State private var toonDeelvenster = false

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.up.on.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)

                Text("Exporteer '\(woning.naam)'")
                    .font(.headline)

                Text("Maakt één .zip-bestand met alle gescande gegevens (JSON + CSV per categorie) en foto's. Deel 'm via AirDrop, Mail, of bewaar 'm in Bestanden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let foutmelding {
                    Text(foutmelding).foregroundStyle(.red).font(.caption)
                }

                Button {
                    genereerExport()
                } label: {
                    Label("Genereer export", systemImage: "doc.zipper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Exporteren")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
            }
            .sheet(isPresented: $toonDeelvenster) {
                if let exportUrl {
                    DeelVenster(items: [exportUrl])
                }
            }
        }
    }

    private func genereerExport() {
        do {
            let url = try DataExporter.exporteer(woning)
            exportUrl = url
            toonDeelvenster = true
            foutmelding = nil
        } catch {
            foutmelding = "Export mislukt: \(error.localizedDescription)"
        }
    }
}

/// Wrapper rond UIActivityViewController (het systeem-deelvenster van iOS).
struct DeelVenster: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
