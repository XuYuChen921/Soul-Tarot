import SwiftUI
import SwiftData

struct AIWorkspaceView: View {
    @Query(sort: \ConsultationRecord.updatedAt, order: .reverse) private var records: [ConsultationRecord]

    private var pending: [ConsultationRecord] {
        records.filter { $0.archivedAt == nil && [.ready, .draft, .failed].contains($0.aiStatus) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("本地 AI 整理")
                        .font(.largeTitle.bold())
                    Text("只处理你主动打开并提交的转写，结果必须人工批准。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(text: "不上传云端", color: .green)
            }
            .padding([.horizontal, .top])

            if pending.isEmpty {
                EmptyStateView(icon: "wand.and.stars", title: "没有待处理资料", message: "先在“咨询资料”中新建记录并粘贴文字转写。")
            } else {
                List(pending) { record in
                    NavigationLink {
                        RecordDetailView(record: record)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(record.clientCode) · \(record.serviceName)").font(.headline)
                                Text(record.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusBadge(text: record.aiStatus.rawValue, color: record.aiStatus.color)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("AI 整理")
    }
}
