import SwiftUI

@main
struct StudyAgentsApp: App {
    @StateObject private var vm = StudyViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(vm)
        }
    }
}
