import SwiftUI

struct TaskCommentsSheet: View {
    let task: DeskTask
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [TaskComment] = []
    @State private var draft = ""
    @State private var feedback = ""
    @State private var isBusy = false
    @State private var editingId: String? = nil
    @State private var editDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("评论 / 复盘").font(.headline)
                    Text(task.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("完成") { dismiss() }
            }

            if !feedback.isEmpty {
                Text(feedback).font(.caption).foregroundStyle(.red)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if comments.isEmpty {
                        Text("暂无评论").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(comments) { c in
                        VStack(alignment: .leading, spacing: 4) {
                            if editingId == c.id {
                                TextEditor(text: $editDraft)
                                    .font(.caption)
                                    .frame(minHeight: 48, maxHeight: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(.separator, lineWidth: 1)
                                    )
                                HStack {
                                    Button("取消") {
                                        editingId = nil
                                        editDraft = ""
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.plain)
                                    Spacer()
                                    Button("保存") {
                                        Task { await saveEdit(c.id) }
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isBusy || editDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            } else {
                                Text(c.body).font(.caption)
                                HStack {
                                    Text(c.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("编辑") {
                                        editingId = c.id
                                        editDraft = c.body
                                    }
                                    .font(.caption2)
                                    .buttonStyle(.plain)
                                    Button("删除") {
                                        Task { await deleteComment(c.id) }
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            TextEditor(text: $draft)
                .font(.caption)
                .frame(minHeight: 60, maxHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.separator, lineWidth: 1)
                )

            Button(isBusy ? "提交中…" : "添加评论") {
                Task { await addComment() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .frame(width: 420, height: 480)
        .task { await load() }
    }

    private func load() async {
        do {
            comments = try await NasApiClient.shared.listComments(taskId: task.id)
            feedback = ""
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func addComment() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await NasApiClient.shared.createComment(taskId: task.id, body: body)
            draft = ""
            await load()
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func saveEdit(_ id: String) async {
        let body = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await NasApiClient.shared.updateComment(taskId: task.id, commentId: id, body: body)
            editingId = nil
            editDraft = ""
            await load()
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func deleteComment(_ id: String) async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await NasApiClient.shared.deleteComment(taskId: task.id, commentId: id)
            if editingId == id {
                editingId = nil
                editDraft = ""
            }
            await load()
        } catch {
            feedback = error.localizedDescription
        }
    }
}
