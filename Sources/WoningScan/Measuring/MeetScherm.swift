import SwiftUI

/// Volledig-scherm meetweergave: legt de AR-camera over met instructies en een knop om de laatst
/// gemeten afstand te bevestigen en terug te geven aan het invoerformulier waarvandaan dit is geopend.
struct MeetScherm: View {
    let titel: String
    var onBevestig: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var laatsteMeting: Double?
    @State private var resetTrigger = 0

    var body: some View {
        ZStack(alignment: .top) {
            ARMeasureView(onMeasured: { afstand in
                laatsteMeting = afstand
            }, resetTrigger: resetTrigger)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    Spacer()
                    Text(titel)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.5), in: Capsule())
                    Spacer()
                    Color.clear.frame(width: 28, height: 28)
                }
                .padding()

                Spacer()

                VStack(spacing: 12) {
                    if let laatsteMeting {
                        Text(String(format: "%.2f m", laatsteMeting))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    } else {
                        Text("Tik twee punten aan om te meten")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 16) {
                        Button {
                            laatsteMeting = nil
                            resetTrigger += 1
                        } label: {
                            Label("Opnieuw", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)

                        Button {
                            if let laatsteMeting {
                                onBevestig(laatsteMeting)
                                dismiss()
                            }
                        } label: {
                            Label("Gebruik meting", systemImage: "checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(laatsteMeting == nil)
                    }
                }
                .padding()
                .background(.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding()
            }
        }
        .statusBarHidden()
    }
}
