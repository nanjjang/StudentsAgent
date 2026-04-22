import SwiftUI

private let contentTabs: [(key: String, label: String, icon: String, color: Color)] = [
    ("concept",  "개념 설명", "lightbulb.fill",        .cosmosOrange),
    ("summary",  "개념 요약", "list.bullet.rectangle", .cosmosTeal),
    ("outline",  "내용 정리", "doc.text.fill",          Color(hex: "A78BFA")),
    ("start",    "공부 시작", "play.circle.fill",       Color(hex: "FBBF24")),
    ("selfcheck","셀프 체크", "checkmark.circle.fill",  Color(hex: "60A5FA")),
    ("problems", "추천 문제", "checkmark.seal.fill",    Color(hex: "34D399")),
    ("direction","학습 방향", "arrow.up.right.circle.fill", Color(hex: "F472B6")),
]

struct StudyContentView: View {
    @EnvironmentObject private var vm: StudyViewModel
    @State private var selectedTab = "concept"

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Topic chip ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let level = vm.session?.schoolLevel {
                            Text("\(level.icon) \(level.label)")
                                .font(.caption.bold())
                                .foregroundColor(.cosmosOrange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.cosmosOrange.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        Text(vm.session?.topicDescription ?? "")
                            .font(.caption)
                            .foregroundColor(.cosmosMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .background(Color.cosmosSurface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.cosmosBorder), alignment: .bottom)

                // ── Tab strip ──
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(contentTabs, id: \.key) { tab in
                            let hasContent = getContent(tab.key) != nil
                            if hasContent || tab.key != "direction" {
                                ContentTabButton(tab: tab, isSelected: selectedTab == tab.key) {
                                    selectedTab = tab.key
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(Color.cosmosSurface)
                .overlay(Rectangle().frame(height: 1).foregroundColor(.cosmosBorder), alignment: .bottom)

                // ── Content ──
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let text = getContent(selectedTab), !text.isEmpty {
                            Text(text)
                                .font(.system(size: 15))
                                .foregroundColor(.cosmosText)
                                .lineSpacing(7)
                                .textSelection(.enabled)
                                .padding(20)
                        } else {
                            CosmosEmptyState(
                                title: "내용 없음",
                                systemImage: "doc.questionmark",
                                description: "AI가 이 섹션을 아직 생성하지 않았습니다."
                            )
                            .padding(.top, 30)
                        }
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(vm.session?.subject.label ?? "학습 자료")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                ToolbarNavButton(icon: "calendar.badge.plus", label: "계획표") {
                    Task { await vm.generatePlan() }
                }
                Spacer()
                ToolbarNavButton(icon: "network", label: "마인드맵") {
                    Task { await vm.fetchMindMap() }
                }
                Spacer()
                ToolbarNavButton(icon: "bell.badge.fill", label: "알림") {
                    vm.path.append(.notifications)
                }
            }
        }
        .overlay {
            if vm.isLoading { CosmosLoadingOverlay(message: vm.loadingMessage) }
        }
    }

    private func getContent(_ key: String) -> String? {
        switch key {
        case "concept":   return vm.session?.content?.conceptExplanation.nilIfEmpty
        case "summary":   return vm.session?.content?.conceptSummary.nilIfEmpty
        case "outline":   return vm.session?.content?.contentOutline.nilIfEmpty
        case "start":     return vm.session?.content?.studyStartGuide.nilIfEmpty
        case "selfcheck": return vm.session?.content?.selfCheckQuiz.nilIfEmpty
        case "problems":  return vm.session?.content?.recommendedProblems.nilIfEmpty
        case "direction": return vm.session?.content?.studyDirection?.nilIfEmpty
        default:          return nil
        }
    }
}

private struct ContentTabButton: View {
    let tab: (key: String, label: String, icon: String, color: Color)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? tab.color.opacity(0.2) : Color.cosmosCard)
            .foregroundColor(isSelected ? tab.color : .cosmosMuted)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? tab.color.opacity(0.5) : Color.cosmosBorder, lineWidth: 1))
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private struct ToolbarNavButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 18))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(.cosmosOrange)
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
