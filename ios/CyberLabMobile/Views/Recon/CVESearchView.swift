import SwiftUI

struct CVESearchView: View {
    @StateObject private var search = CVESearch()
    @State private var query = ""
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                inputSection
                if search.isSearching { ProgressView().tint(.cyberGreen).padding() }
                resultsList
            }
        }
        .navigationTitle("CVE Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var inputSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "ant.circle").foregroundColor(.cyberGreen)
                TextField("openssl, log4j, apache…", text: $query)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: query) { _, newValue in
                        search.search(keyword: newValue)
                    }
            }
            .padding(12)
            .background(Color.cyberBackground)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cyberBorder, lineWidth: 1))

            if let err = search.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11)).foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.cyberSurface)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if search.results.isEmpty && !search.isSearching {
                    Text("$ search the NIST National Vulnerability Database")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.cyberGreen.opacity(0.4))
                        .padding(.top, 30)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(search.results) { cve in
                    cveCard(cve)
                }
            }
            .padding()
        }
    }

    private func cveCard(_ cve: CVEResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    if let url = cve.nvdURL { openURL(url) }
                } label: {
                    Text(cve.id)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyberCyan)
                        .underline()
                }
                Spacer()
                if let score = cve.cvss {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(cvssColor(score)).cornerRadius(6)
                }
            }
            Text(cve.summary)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(4)
            Text("Published \(cve.published)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyberSurface)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyberBorder, lineWidth: 1))
    }

    private func cvssColor(_ score: Double) -> Color {
        if score >= 7.0 { return .red }
        if score >= 4.0 { return .orange }
        return .cyberGreen
    }
}
