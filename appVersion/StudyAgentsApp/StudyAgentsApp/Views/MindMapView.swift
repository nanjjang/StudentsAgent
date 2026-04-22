import SwiftUI

struct MindMapView: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()
            OrbBackground()

            if vm.mindmapText.isEmpty {
                CosmosEmptyState(
                    title: "마인드맵 없음",
                    systemImage: "network",
                    description: "학습 자료 화면에서 마인드맵을 생성해보세요."
                )
            } else {
                ScrollView([.vertical, .horizontal]) {
                    CosmosMapRenderer(text: vm.mindmapText)
                        .padding(24)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("마인드맵 🗺️")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: vm.mindmapText) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.cosmosOrange)
                }
            }
        }
    }
}

private struct CosmosMapRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parseLines(text), id: \.id) { line in
                CosmosMapLine(line: line)
            }
        }
    }

    private func parseLines(_ text: String) -> [MapLine] {
        text.components(separatedBy: "\n")
            .enumerated()
            .map { MapLine(id: $0.offset, raw: $0.element) }
    }
}

private struct MapLine: Identifiable {
    let id: Int
    let raw: String

    var level: Int {
        if raw.hasPrefix("# ")   { return 0 }
        if raw.hasPrefix("## ")  { return 1 }
        if raw.hasPrefix("### ") { return 2 }
        let sp = raw.prefix(while: { $0 == " " }).count
        if raw.trimmingCharacters(in: .whitespaces).hasPrefix("- ") { return 3 + sp / 2 }
        return -1
    }

    var text: String {
        raw.replacingOccurrences(of: "^#{1,6} ", with: "", options: .regularExpression)
           .replacingOccurrences(of: "^\\s*- ", with: "", options: .regularExpression)
           .trimmingCharacters(in: .whitespaces)
    }

    var color: Color {
        switch level {
        case 0: return .cosmosOrange
        case 1: return .cosmosTeal
        case 2: return Color(hex: "A78BFA")
        default: return .cosmosText
        }
    }
}

private struct CosmosMapLine: View {
    let line: MapLine

    var body: some View {
        guard line.level >= 0, !line.text.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            HStack(alignment: .center, spacing: 10) {
                Spacer().frame(width: CGFloat(max(0, line.level - 1)) * 20)

                if line.level >= 3 {
                    Circle()
                        .fill(line.color.opacity(0.6))
                        .frame(width: 5, height: 5)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(line.color.opacity(line.level == 0 ? 1 : 0.7))
                        .frame(width: dotSize, height: dotSize)
                }

                Text(line.text)
                    .font(labelFont)
                    .foregroundColor(line.color)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(.vertical, line.level == 0 ? 6 : 2)
        )
    }

    private var dotSize: CGFloat {
        switch line.level {
        case 0: return 12
        case 1: return 9
        case 2: return 7
        default: return 5
        }
    }

    private var labelFont: Font {
        switch line.level {
        case 0: return .system(size: 20, weight: .black, design: .rounded)
        case 1: return .system(size: 16, weight: .bold)
        case 2: return .system(size: 14, weight: .semibold)
        default: return .system(size: 12)
        }
    }
}
