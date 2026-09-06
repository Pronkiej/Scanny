import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var nieuweWoningNaam = ""
    @State private var toonNieuwProject = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.projecten) { woning in
                    NavigationLink(value: woning.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(woning.naam.isEmpty ? "Naamloos project" : woning.naam)
                                .font(.headline)
                            Text(woning.adres)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(woning.aantalElementen) elementen · laatst gewijzigd \(woning.laatstGewijzigd.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        store.verwijder(store.projecten[index])
                    }
                }
            }
            .navigationTitle("WoningScan")
            .navigationDestination(for: UUID.self) { id in
                if let index = store.projecten.firstIndex(where: { $0.id == id }) {
                    WoningDetailView(woningId: store.projecten[index].id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        toonNieuwProject = true
                    } label: {
                        Label("Nieuw project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $toonNieuwProject) {
                NieuwProjectScherm { woning in
                    store.opslaan(woning)
                }
            }
            .overlay {
                if store.projecten.isEmpty {
                    ContentUnavailableView(
                        "Nog geen opnames",
                        systemImage: "house",
                        description: Text("Tik op + om een nieuwe woningopname te starten.")
                    )
                }
            }
        }
    }
}

private struct NieuwProjectScherm: View {
    var onAanmaken: (Woning) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var naam = ""
    @State private var adres = ""
    @State private var projectTypes: Set<ProjectType> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Woninggegevens") {
                    TextField("Naam / referentie", text: $naam)
                    TextField("Adres", text: $adres)
                }
                Section {
                    ForEach(ProjectType.allCases) { type in
                        Button {
                            if projectTypes.contains(type) {
                                projectTypes.remove(type)
                            } else {
                                projectTypes.insert(type)
                            }
                        } label: {
                            HStack {
                                Text(type.rawValue)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: projectTypes.contains(type) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(projectTypes.contains(type) ? Color.accentColor : Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Projecttype")
                } footer: {
                    Text("Kies één of beide - dit bepaalt welke onderdelen je in dit project ziet.")
                }
            }
            .navigationTitle("Nieuw project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleren") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aanmaken") {
                        var woning = Woning()
                        woning.naam = naam
                        woning.adres = adres
                        woning.projectTypes = projectTypes
                        onAanmaken(woning)
                        dismiss()
                    }
                    .disabled(naam.isEmpty || projectTypes.isEmpty)
                }
            }
        }
    }
}
