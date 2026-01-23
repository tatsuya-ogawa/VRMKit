import SwiftUI

@main
struct VisionExampleApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(appModel)
        }

        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

@Observable
@MainActor
final class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    var immersiveSpaceState: ImmersiveSpaceState = .closed

    enum ImmersiveSpaceState {
        case closed, inTransition, open
    }
}
