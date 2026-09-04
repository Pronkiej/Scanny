import SwiftUI

@main
struct WoningScanApp: App {
    @StateObject private var projectStore = ProjectStore.shared
    @StateObject private var referenceData = ReferenceData.shared
    @StateObject private var compass = CompassHeading.shared

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .environmentObject(projectStore)
                .environmentObject(referenceData)
                .environmentObject(compass)
        }
    }
}
