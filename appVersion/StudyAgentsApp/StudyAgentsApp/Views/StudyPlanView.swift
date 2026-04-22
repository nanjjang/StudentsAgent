import SwiftUI

struct StudyPlanView: View {
    @EnvironmentObject private var vm: StudyViewModel
    @State private var viewMode: ViewMode = .timeline

    enum ViewMode: String, CaseIterable { case timeline = "타임라인"; case table = "표" }

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()

            VStack(spacing: 0) {
                if let plan = vm.session?.plan {
                    // ── Stats bar ──
                    HStack(spacing: 0) {
                        StatPill(label: "총 기간", value: "\(plan.totalDays)일", color: .cosmosOrange)
                        Divider().frame(height: 32).overlay(Color.cosmosBorder)
                        StatPill(label: "목적", value: plan.purpose.label, color: .cosmosTeal)
                        Divider().frame(height: 32).overlay(Color.cosmosBorder)
                        StatPill(label: "항목", value: "\(plan.planItems.count)개", color: Color(hex: "A78BFA"))
                    }
                    .padding(.vertical, 12)
                    .background(Color.cosmosSurface)
                    .overlay(Rectangle().frame(height: 1).foregroundColor(.cosmosBorder), alignment: .bottom)

                    // ── Mode picker ──
                    Picker("보기", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // ── Content ──
                    ScrollView {
                        if viewMode == .timeline {
                            TimelineView(items: plan.planItems)
                                .padding(16)
                        } else {
                            TableView(markdown: plan.calendarView)
                                .padding(16)
                        }
                    }
                } else {
                    CosmosEmptyState(
                        title: "계획표 없음",
                        systemImage: "calendar.badge.exclamationmark",
                        description: "학습 자료 화면 하단의 계획표 버튼을 탭해 생성해보세요."
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("학습 계획표 📅")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, weight: .black)).foregroundColor(color)
            Text(label).font(.system(size: 10)).foregroundColor(.cosmosMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineView: View {
    let items: [StudyPlanItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                HStack(alignment: .top, spacing: 14) {
                    // Day indicator + connector line
                    VStack(spacing: 0) {
                        ZStack {
                            Circle()
                                .fill(dayColor(item.dayOfWeek).opacity(0.2))
                                .frame(width: 40, height: 40)
                            Text(item.dayOfWeek)
                                .font(.system(size: 13, weight: .black))
                                .foregroundColor(dayColor(item.dayOfWeek))
                        }
                        if idx < items.count - 1 {
                            Rectangle()
                                .fill(Color.cosmosBorder)
                                .frame(width: 2, height: 40)
                        }
                    }

                    // Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.date)
                                .font(.caption)
                                .foregroundColor(.cosmosMuted)
                            Spacer()
                            Label(String(format: "%.1fh", item.studyHours), systemImage: "clock")
                                .font(.caption.bold())
                                .foregroundColor(.cosmosTeal)
                        }

                        Text(item.topics.joined(separator: " · "))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.cosmosText)

                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(item.tasks.prefix(3), id: \.self) { task in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.cosmosOrange.opacity(0.6))
                                        .frame(width: 5, height: 5)
                                    Text(task)
                                        .font(.caption)
                                        .foregroundColor(.cosmosMuted)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.cosmosCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cosmosBorder, lineWidth: 1))
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func dayColor(_ day: String) -> Color {
        switch day {
        case "월": return .cosmosOrange
        case "화": return Color(hex: "F472B6")
        case "수": return .cosmosTeal
        case "목": return Color(hex: "A78BFA")
        case "금": return Color(hex: "34D399")
        case "토": return Color(hex: "FBBF24")
        case "일": return Color(hex: "FC8181")
        default:   return .cosmosMuted
        }
    }
}

private struct TableView: View {
    let markdown: String

    var body: some View {
        ScrollView(.horizontal) {
            Text(markdown)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.cosmosText)
                .padding(16)
                .background(Color.cosmosCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cosmosBorder))
        }
    }
}
