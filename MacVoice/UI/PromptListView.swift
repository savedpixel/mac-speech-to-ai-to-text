import SwiftUI

struct PromptListView: View {
    var promptStore: PromptStore
    @Binding var selectedPromptID: UUID?

    var body: some View {
        List(promptStore.prompts, id: \.id, selection: $selectedPromptID) { prompt in
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Text(prompt.name)
                            .font(.body)
                        if prompt.isBuiltIn {
                            Text("Built-in")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(prompt.systemPrompt.prefix(60))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if prompt.id == promptStore.selectedPromptID {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .tag(prompt.id)
            .contextMenu {
                Button("Set as Default") {
                    promptStore.selectedPromptID = prompt.id
                }
                if !prompt.isBuiltIn {
                    Divider()
                    Button("Delete", role: .destructive) {
                        promptStore.delete(id: prompt.id)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: addPrompt) {
                    Image(systemName: "plus")
                }
                .help("Add Prompt")
            }
        }
        .onAppear {
            if selectedPromptID == nil, let first = promptStore.prompts.first {
                selectedPromptID = first.id
            }
        }
    }

    private func addPrompt() {
        let newPrompt = CleanupPrompt(
            id: UUID(),
            name: "New Prompt",
            systemPrompt: "Clean up the following transcription:",
            isBuiltIn: false
        )
        promptStore.add(newPrompt)
        selectedPromptID = newPrompt.id
    }
}

struct PromptEditorView: View {
    let prompt: CleanupPrompt
    var promptStore: PromptStore

    @State private var name: String = ""
    @State private var systemPrompt: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt Editor")
                    .font(.headline)
                Spacer()
                if prompt.id == promptStore.selectedPromptID {
                    Label("Default", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tint)
                } else {
                    Button("Set as Default") {
                        promptStore.selectedPromptID = prompt.id
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .disabled(prompt.isBuiltIn)

            Text("System Prompt")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextEditor(text: $systemPrompt)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(prompt.isBuiltIn)

            if !prompt.isBuiltIn {
                HStack {
                    Spacer()
                    Button("Save") {
                        var updated = prompt
                        updated.name = name
                        updated.systemPrompt = systemPrompt
                        promptStore.update(updated)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name == prompt.name && systemPrompt == prompt.systemPrompt)
                }
            }
        }
        .padding()
        .frame(minWidth: 350)
        .onAppear { loadPrompt() }
        .onChange(of: prompt.id) { _, _ in loadPrompt() }
    }

    private func loadPrompt() {
        name = prompt.name
        systemPrompt = prompt.systemPrompt
    }
}
