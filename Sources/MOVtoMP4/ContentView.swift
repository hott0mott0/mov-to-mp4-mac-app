import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConversionViewModel()
    @State private var isFileImporterPresented = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            fileList
            Divider()
            footer
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.quickTimeMovie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFiles(urls)
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("ファイルを追加できませんでした", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "不明なエラー")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MOV → MP4")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("複数の MOV 動画をまとめて MP4 に変換します")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isFileImporterPresented = true
                } label: {
                    Label("MOV を追加", systemImage: "plus")
                }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(viewModel.isConverting)
            }

            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                Text(viewModel.outputDirectory?.path(percentEncoded: false) ?? "保存先が選択されていません")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(viewModel.outputDirectory == nil ? .secondary : .primary)
                Spacer()
                Button("保存先を選択…") {
                    viewModel.chooseOutputDirectory()
                }
                .disabled(viewModel.isConverting)
            }
            .padding(10)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 9))
        }
        .padding(22)
    }

    @ViewBuilder
    private var fileList: some View {
        if viewModel.items.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "film.stack")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
                Text("MOV 動画を追加")
                    .font(.title2.weight(.semibold))
                Text("「MOV を追加」から、変換する動画を複数選択できます。")
                    .foregroundStyle(.secondary)
                Button("ファイルを選択") {
                    isFileImporterPresented = true
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.items) { item in
                        ConversionRow(
                            item: item,
                            canRemove: !viewModel.isConverting,
                            onRemove: { viewModel.remove(item) },
                            onReveal: { viewModel.revealOutput(for: item) }
                        )
                        if item.id != viewModel.items.last?.id {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(viewModel.isConverting ? "変換しています…" : "全体の進捗")
                        Spacer()
                        Text("\(viewModel.completedCount) / \(viewModel.items.count) 完了")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: viewModel.overallProgress)
                }
                .frame(maxWidth: .infinity)

                if viewModel.isConverting {
                    Button(viewModel.isCancelling ? "キャンセル中…" : "キャンセル", role: .cancel) {
                        viewModel.cancelConversion()
                    }
                    .disabled(viewModel.isCancelling)
                } else {
                    Button("完了した項目を消去") {
                        viewModel.clearFinished()
                    }
                    .disabled(!viewModel.items.contains(where: { $0.status.isFinished }))

                    Button("変換を開始") {
                        Task { await viewModel.startConversion() }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canStart)
                }
            }
        }
        .padding(18)
    }
}

private struct ConversionRow: View {
    let item: ConversionItem
    let canRemove: Bool
    let onRemove: () -> Void
    let onReveal: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(item.fileName)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(item.status.title)
                        .foregroundStyle(statusColor)
                        .font(.caption.weight(.semibold))
                }

                if case .failed(let message) = item.status {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    ProgressView(value: item.progress)
                        .opacity(item.status == .queued ? 0.35 : 1)
                }
            }

            if item.status == .completed {
                Button(action: onReveal) {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .help("Finder に表示")
            }

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .disabled(!canRemove)
            .help("一覧から削除")
        }
        .padding(.vertical, 13)
    }

    private var statusIcon: String {
        switch item.status {
        case .queued: "clock"
        case .converting: "arrow.triangle.2.circlepath"
        case .completed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .queued: .secondary
        case .converting: .accentColor
        case .completed: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }
}
