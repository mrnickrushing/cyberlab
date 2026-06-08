import SwiftUI

struct NotesView: View {
    @EnvironmentObject var cacheManager: CacheManager
    @State private var notes: [Note] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var showAdd = false
    private let client = APIClient.shared

    var filtered: [Note] {
        notes.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.body.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView().tint(.cyberGreen)
                    } else if let error {
                        ErrorView(message: error) { Task { await loadNotes() } }
                    } else if filtered.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.system(size: 40)).foregroundColor(.cyberGreen.opacity(0.3))
                            Text(notes.isEmpty ? "No notes yet" : "No results")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    } else {
                        List {
                            ForEach(filtered) { note in
                                NavigationLink(destination: NoteDetailView(note: note, onDelete: { Task { await loadNotes() } })) {
                                    NoteRow(note: note)
                                }
                                .listRowBackground(Color.cyberSurface)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        Task { await deleteNote(note) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .navigationTitle("Lab Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(.cyberGreen)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddNoteView { Task { await refresh() } }
            }
            .refreshable { await refresh() }
        }
        .task { await loadNotes() }
    }

    /// Stale-while-revalidate: paint cached notes immediately, then fetch fresh.
    private func loadNotes() async {
        let cached = cacheManager.cachedNotes()
        if !cached.isEmpty {
            notes = cached
            isLoading = false
        } else {
            isLoading = true
        }
        error = nil
        do {
            let fresh: [Note] = try await client.request(Endpoints.notes())
            notes = fresh
            cacheManager.store(fresh)
        } catch {
            if notes.isEmpty {
                self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
        isLoading = false
    }

    private func refresh() async {
        cacheManager.store([Note]())
        await loadNotes()
    }

    private func deleteNote(_ note: Note) async {
        try? await client.requestVoid(Endpoints.deleteNote(note.id))
        cacheManager.store(notes.filter { $0.id != note.id })
        await loadNotes()
    }
}

struct NoteRow: View {
    let note: Note
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(note.createdAt.formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
            }
            Text(note.body)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(2)
            if let tags = note.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyberGreen.opacity(0.8))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.cyberGreen.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct NoteDetailView: View {
    let note: Note
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    private let client = APIClient.shared

    var body: some View {
        ZStack {
            Color.cyberBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isEditing {
                        TextField("Title", text: $editTitle)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.cyberSurface)
                            .cornerRadius(8)
                        TextEditor(text: $editBody)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(minHeight: 200)
                            .padding()
                            .background(Color.cyberSurface)
                            .cornerRadius(8)
                        Button("Save") {
                            Task {
                                let req = UpdateNoteRequest(title: editTitle, body: editBody, tags: note.tags)
                                _ = try? await client.request(Endpoints.updateNote(note.id, req)) as Note
                                isEditing = false
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyberGreen)
                        .foregroundColor(.black)
                        .cornerRadius(8)
                    } else {
                        Text(note.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        Text(note.createdAt.formattedFullDate)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                        Divider().background(Color.cyberBorder)
                        Text(note.body)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                        if let tags = note.tags, !tags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.cyberGreen)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button { isEditing.toggle(); editTitle = note.title; editBody = note.body } label: {
                        Image(systemName: isEditing ? "xmark" : "pencil").foregroundColor(.cyberGreen)
                    }
                    Button(role: .destructive) {
                        Task {
                            try? await client.requestVoid(Endpoints.deleteNote(note.id))
                            onDelete(); dismiss()
                        }
                    } label: {
                        Image(systemName: "trash").foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss
    let onCreated: () -> Void
    @State private var title = ""
    @State private var body_text = ""
    @State private var tagsText = ""
    @State private var isLoading = false
    private let client = APIClient.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cyberBackground.ignoresSafeArea()
                Form {
                    Section("Note") {
                        TextField("Title", text: $title)
                        TextEditor(text: $body_text)
                            .frame(minHeight: 120)
                    }
                    Section("Tags (comma separated)") {
                        TextField("recon, web, critical", text: $tagsText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(title.isEmpty || isLoading)
                }
            }
        }
    }

    private func save() async {
        isLoading = true
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let req = CreateNoteRequest(title: title, body: body_text, targetId: nil, tags: tags.isEmpty ? nil : tags)
        _ = try? await client.request(Endpoints.createNote(req)) as Note
        onCreated(); dismiss()
        isLoading = false
    }
}
