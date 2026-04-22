import SwiftUI

struct PurposeSubjectView: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    CosmosSection(title: "학교급", subtitle: "현재 어디에 해당하나요?") {
                        VStack(spacing: 10) {
                            ForEach(SchoolLevel.allCases) { level in
                                SchoolLevelRow(level: level, isSelected: vm.selectedSchoolLevel == level) {
                                    vm.selectedSchoolLevel = level
                                }
                            }
                        }
                    }

                    Divider().overlay(Color.cosmosBorder)

                    // ── Purpose ──
                    CosmosSection(title: "학습 목적", subtitle: "어떤 이유로 공부하나요?") {
                        VStack(spacing: 10) {
                            ForEach(StudyPurpose.allCases) { p in
                                PurposeRow(purpose: p, isSelected: vm.selectedPurpose == p) {
                                    vm.selectedPurpose = p
                                }
                            }
                        }
                    }

                    Divider().overlay(Color.cosmosBorder)

                    // ── Subject ──
                    CosmosSection(title: "과목 선택", subtitle: "공부할 과목을 선택하세요") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Subject.allCases) { s in
                                SubjectCell(subject: s, isSelected: vm.selectedSubject == s) {
                                    vm.selectedSubject = s
                                }
                            }
                        }
                    }

                    CosmosInfoBanner(
                        title: "선택한 과목 입력 힌트",
                        message: vm.selectedSubject.inputHint,
                        color: .cosmosTeal
                    )

                    // ── Next ──
                    CosmosButton(label: "다음 단계", icon: "arrow.right", isDisabled: vm.selectedSchoolLevel == nil) {
                        vm.path.append(.subjectInput)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("학습 설정")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SchoolLevelRow: View {
    let level: SchoolLevel
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        switch level {
        case .elementary: return Color(hex: "FBBF24")
        case .middle:     return .cosmosTeal
        case .high:       return .cosmosOrange
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(isSelected ? 0.25 : 0.1))
                        .frame(width: 44, height: 44)
                    Text(level.icon)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.cosmosText)
                    Text(level.detail)
                        .font(.caption)
                        .foregroundColor(.cosmosMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accent)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.1) : Color.cosmosCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent.opacity(0.6) : Color.cosmosBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Purpose row

struct PurposeRow: View {
    let purpose: StudyPurpose
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        switch purpose {
        case .exam_prep:     return .cosmosOrange
        case .certification: return .cosmosTeal
        case .background:    return Color(hex: "A78BFA")
        case .general:       return Color(hex: "34D399")
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(isSelected ? 0.25 : 0.1))
                        .frame(width: 44, height: 44)
                    Text(purpose.icon)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(purpose.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.cosmosText)
                    Text(purpose.detail)
                        .font(.caption)
                        .foregroundColor(.cosmosMuted)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accent)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? accent.opacity(0.1) : Color.cosmosCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? accent.opacity(0.6) : Color.cosmosBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Subject cell

struct SubjectCell: View {
    let subject: Subject
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(subject.icon)
                    .font(.title2)
                Text(subject.label)
                    .font(.caption.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .cosmosOrange : .cosmosText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.cosmosOrange.opacity(0.15) : Color.cosmosCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.cosmosOrange : Color.cosmosBorder, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}

// MARK: - Shared design components

struct CosmosSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.cosmosText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.cosmosMuted)
            }
            content()
        }
    }
}

struct CosmosButton: View {
    let label: String
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                    .font(.system(size: 16, weight: .bold))
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                LinearGradient(
                    colors: isDisabled
                        ? [Color.cosmosBorder, Color.cosmosBorder.opacity(0.9)]
                        : [.cosmosOrange, Color(hex: "FF9A5C")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: (isDisabled ? Color.cosmosBorder : .cosmosOrange).opacity(0.35), radius: 12, y: 5)
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.75 : 1)
    }
}

struct CosmosField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.cosmosMuted)
                .textCase(.uppercase)
            TextField(placeholder, text: $text)
                .foregroundColor(.cosmosText)
                .padding(14)
                .background(Color.cosmosCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.cosmosBorder, lineWidth: 1)
                )
        }
    }
}

struct CosmosStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.cosmosMuted)
            Spacer()
            HStack(spacing: 0) {
                Button {
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.bold())
                        .frame(width: 36, height: 36)
                        .background(Color.cosmosBg)
                }
                Text("\(value)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.cosmosText)
                    .frame(width: 40)
                Button {
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.bold())
                        .frame(width: 36, height: 36)
                        .background(Color.cosmosBg)
                }
            }
            .background(Color.cosmosCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cosmosBorder, lineWidth: 1))
        }
    }
}

struct CosmosInfoBanner: View {
    let title: String
    let message: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(color)
            Text(message)
                .font(.caption)
                .foregroundColor(.cosmosMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.3), lineWidth: 1))
    }
}

struct CosmosEmptyState: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.cosmosMuted)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.cosmosText)
            Text(description)
                .font(.caption)
                .foregroundColor(.cosmosMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 20)
    }
}
