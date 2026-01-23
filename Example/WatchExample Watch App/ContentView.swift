import SwiftUI
import SceneKit

struct ContentView: View {
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        SceneView(
            scene: viewModel.scene,
            delegate: viewModel.renderer
        )
        .ignoresSafeArea()
        .onAppear {
            viewModel.loadModelIfNeeded()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
