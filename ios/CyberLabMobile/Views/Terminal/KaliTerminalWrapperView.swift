import SwiftUI

struct KaliTerminalWrapperView: View {
    var body: some View {
        NavigationStack {
            KaliTerminalView()
                .ignoresSafeArea()
                .navigationBarHidden(true)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
