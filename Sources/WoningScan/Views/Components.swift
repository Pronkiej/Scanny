import SwiftUI
import UIKit

/// Wrapper rond UIImagePickerController om een foto te maken met de camera.
struct CameraCaptureView: UIViewControllerRepresentable {
    var onGemaakt: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onGemaakt: onGemaakt) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onGemaakt: (UIImage) -> Void
        init(onGemaakt: @escaping (UIImage) -> Void) { self.onGemaakt = onGemaakt }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onGemaakt(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

/// Invoerveld voor een lengtematen (in meters) met een knop om 'm via de AR-liniaal in te meten
/// in plaats van met de hand over te typen.
struct MeetVeld: View {
    let titel: String
    @Binding var waardeMeters: Double
    var meetTitel: String? = nil

    @State private var toonMeetScherm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(titel)
                Spacer()
                TextField("handmatig invoeren", value: $waardeMeters, format: .number.precision(.fractionLength(2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                Text("m").foregroundStyle(.secondary)
            }
            Button {
                toonMeetScherm = true
            } label: {
                Label("Meet met AR-liniaal", systemImage: "arkit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 2)
        .fullScreenCover(isPresented: $toonMeetScherm) {
            MeetScherm(titel: meetTitel ?? titel) { afstand in
                waardeMeters = (afstand * 100).rounded() / 100
            }
        }
    }
}

/// Foto-veld met thumbnail + camera-knop, gekoppeld aan de foto-opslag van een specifiek project.
struct FotoVeld: View {
    let woningId: UUID
    @Binding var bestandsnaam: String?

    @State private var toonCamera = false
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            Spacer()
            Button {
                toonCamera = true
            } label: {
                Label(thumbnail == nil ? "Foto maken" : "Vervangen", systemImage: "camera")
            }
        }
        .onAppear {
            thumbnail = ProjectStore.shared.laadFoto(bestandsnaam: bestandsnaam, woningId: woningId)
        }
        .fullScreenCover(isPresented: $toonCamera) {
            CameraCaptureView { image in
                if let naam = ProjectStore.shared.slaFotoOp(image, voor: woningId) {
                    bestandsnaam = naam
                    thumbnail = image
                }
                toonCamera = false
            }
            .ignoresSafeArea()
        }
    }
}

/// Foto-lijst met eventueel meerdere foto's (bv. per ruimte in de puntentelling): camera-knop om een
/// foto toe te voegen, tik op het kruisje op een foto om 'm te verwijderen.
struct FotoLijstVeld: View {
    let woningId: UUID
    @Binding var bestandsnamen: [String]

    @State private var toonCamera = false
    @State private var thumbnails: [String: UIImage] = [:]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(bestandsnamen, id: \.self) { naam in
                    ZStack(alignment: .topTrailing) {
                        if let thumbnail = thumbnails[naam] {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        } else {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(.quaternary)
                                .frame(width: 72, height: 72)
                        }
                        Button {
                            bestandsnamen.removeAll { $0 == naam }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.55))
                                .font(.system(size: 17))
                        }
                        .padding(3)
                    }
                }
                Button {
                    toonCamera = true
                } label: {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.quaternary)
                        .frame(width: 72, height: 72)
                        .overlay(Image(systemName: "camera.fill").foregroundStyle(.secondary))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        .onAppear { laadThumbnails() }
        .onChange(of: bestandsnamen) { _, _ in laadThumbnails() }
        .fullScreenCover(isPresented: $toonCamera) {
            CameraCaptureView { image in
                if let naam = ProjectStore.shared.slaFotoOp(image, voor: woningId) {
                    bestandsnamen.append(naam)
                    thumbnails[naam] = image
                }
                toonCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private func laadThumbnails() {
        for naam in bestandsnamen where thumbnails[naam] == nil {
            thumbnails[naam] = ProjectStore.shared.laadFoto(bestandsnaam: naam, woningId: woningId)
        }
    }
}

/// Kompas-picker: toont de live gemeten oriëntatie met de mogelijkheid om 'm handmatig te corrigeren.
struct OrientatiePicker: View {
    @Binding var orientatie: Orientatie
    @EnvironmentObject private var compass: CompassHeading

    var body: some View {
        HStack {
            Picker("Oriëntatie", selection: $orientatie) {
                ForEach(Orientatie.allCases) { optie in
                    Text(optie.rawValue).tag(optie)
                }
            }
            Button {
                compass.start()
                orientatie = compass.huidigeOrientatie
            } label: {
                Image(systemName: "location.north.line")
            }
            .buttonStyle(.borderless)
        }
    }
}
