import SwiftUI

struct KaliTerminalWrapperView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Segmented picker
            Picker("", selection: $selectedTab) {
                Text("Web Terminal").tag(0)
                Text("Commands").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.08))

            Divider().background(Color.cyberGreen.opacity(0.2))

            Group {
                if selectedTab == 0 {
                    KaliTerminalView()
                } else {
                    KaliCommandView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
    }
}
