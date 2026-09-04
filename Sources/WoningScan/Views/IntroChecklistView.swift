import SwiftUI

/// De vragenlijst die aan het begin van een opname wordt gesteld: is er een zolder/kelder,
/// en grenst het dak/de vloer in zijn geheel aan buitenlucht/kruipruimte/een andere ruimte.
struct IntroChecklistView: View {
    let woningId: UUID
    @EnvironmentObject private var store: ProjectStore
    @Environment(\.dismiss) private var dismiss
    @State private var checklist = IntroChecklist()

    private var woning: Woning {
        store.projecten.first(where: { $0.id == woningId }) ?? Woning(id: woningId)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bovenzijde") {
                    Toggle("Heeft dit huis een zolder of vliering?", isOn: Binding(
                        get: { checklist.heeftZolderOfVliering ?? false },
                        set: { checklist.heeftZolderOfVliering = $0 }
                    ))
                    Picker("Grenst het dak/plafond aan", selection: $checklist.bovenGrenstAan) {
                        Text("Nog niet ingevuld").tag(GrenstAanKeuze?.none)
                        ForEach(GrenstAanKeuze.allCases) { keuze in
                            Text(keuze.rawValue).tag(GrenstAanKeuze?.some(keuze))
                        }
                    }
                }

                Section("Onderzijde") {
                    Toggle("Heeft dit huis een kelder?", isOn: Binding(
                        get: { checklist.heeftKelder ?? false },
                        set: { checklist.heeftKelder = $0 }
                    ))
                    Picker("Grenst de vloer aan", selection: $checklist.onderGrenstAan) {
                        Text("Nog niet ingevuld").tag(GrenstAanKeuze?.none)
                        ForEach(GrenstAanKeuze.allCases) { keuze in
                            Text(keuze.rawValue).tag(GrenstAanKeuze?.some(keuze))
                        }
                    }
                }

                Section("Notities") {
                    TextEditor(text: $checklist.notities)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Start-checklist")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sluiten") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Opslaan") {
                        var bijgewerkt = woning
                        bijgewerkt.introChecklist = checklist
                        store.opslaan(bijgewerkt)
                        dismiss()
                    }
                }
            }
            .onAppear { checklist = woning.introChecklist }
        }
    }
}
