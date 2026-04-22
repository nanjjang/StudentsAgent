import SwiftUI

// MARK: - Design tokens (Cosmos Dark)
extension Color {
    static let cosmosBg      = Color(hex: "070B14")
    static let cosmosSurface = Color(hex: "111827")
    static let cosmosCard    = Color(hex: "1C2535")
    static let cosmosOrange  = Color(hex: "FF6B35")
    static let cosmosTeal    = Color(hex: "4ECDC4")
    static let cosmosText    = Color(hex: "F1F5F9")
    static let cosmosMuted   = Color(hex: "64748B")
    static let cosmosBorder  = Color(hex: "2D3748")

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >>  8) & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }
}

struct HomeView: View {
    @EnvironmentObject private var vm: StudyViewModel
    @State private var appeared = false
    @State private var currentAPIBaseURL = APIService.shared.baseURL
    @State private var showServerSettings = false

    var body: some View {
        NavigationStack(path: $vm.path) {
            ZStack {
                Color.cosmosBg.ignoresSafeArea()

                // Gradient orbs
                OrbBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // ── Brand ──
                        VStack(spacing: 16) {
                            GlowOrb(size: 90)
                                .padding(.top, 60)

                            VStack(spacing: 6) {
                                Text("StudyAgents")
                                    .font(.system(size: 38, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.cosmosOrange, .cosmosTeal],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                Text("AI 기반 맞춤 학습 도우미")
                                    .font(.subheadline)
                                    .foregroundColor(.cosmosMuted)
                            }

                            // Chip
                            Label("초·중·고 전용", systemImage: "graduationcap.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Color.cosmosOrange.opacity(0.15))
                                .foregroundColor(.cosmosOrange)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.cosmosOrange.opacity(0.4), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("앱 연결 주소", systemImage: "antenna.radiowaves.left.and.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.cosmosTeal)
                                    Text(currentAPIBaseURL)
                                        .font(.caption.monospaced())
                                        .foregroundColor(.cosmosText)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.85)
                                }
                                Spacer()
                                Button("변경") {
                                    showServerSettings = true
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.cosmosTeal.opacity(0.14))
                                .foregroundColor(.cosmosTeal)
                                .clipShape(Capsule())
                            }

                            Text("시뮬레이터는 localhost를 써도 되지만, 실제 아이폰에서는 맥북의 로컬 IP를 입력해야 합니다.")
                                .font(.caption)
                                .foregroundColor(.cosmosMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(Color.cosmosCard.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.cosmosBorder, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 30)

                        // ── Feature cards ──
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(featureItems, id: \.title) { item in
                                CosmosFeatureCard(item: item)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 36)

                        // ── CTA ──
                        VStack(spacing: 14) {
                            Button {
                                vm.path.append(.purposeSubject)
                            } label: {
                                HStack(spacing: 10) {
                                    Text("학습 시작하기")
                                        .font(.headline)
                                    Image(systemName: "arrow.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(colors: [.cosmosOrange, Color(hex: "FF9A5C")],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .cosmosOrange.opacity(0.4), radius: 16, y: 6)
                            }

                            Text("14개 과목 · Gemini 검색 · 맞춤 계획")
                                .font(.caption)
                                .foregroundColor(.cosmosMuted)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 48)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: AppStep.self) { step in
                switch step {
                case .purposeSubject:  PurposeSubjectView()
                case .subjectInput:    SubjectInputView()
                case .loading:         LoadingView()
                case .content:         StudyContentView()
                case .plan:            StudyPlanView()
                case .mindmap:         MindMapView()
                case .notifications:   NotificationView()
                default:               EmptyView()
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showServerSettings) {
            ServerSettingsSheet(currentAPIBaseURL: $currentAPIBaseURL)
        }
    }

    private let featureItems: [FeatureItem] = [
        .init(icon: "globe.americas.fill",    title: "Gemini 검색", desc: "공식 API 기반 자료 수집", color: .cosmosOrange),
        .init(icon: "lightbulb.fill",         title: "개념 설명", desc: "쉬운 풀이",        color: .cosmosTeal),
        .init(icon: "doc.text.fill",          title: "내용 정리", desc: "체계적 요약",      color: Color(hex: "A78BFA")),
        .init(icon: "calendar",               title: "계획표",    desc: "맞춤 일정",        color: Color(hex: "34D399")),
        .init(icon: "network",                title: "마인드맵",  desc: "시각적 정리",      color: Color(hex: "F472B6")),
        .init(icon: "bell.fill",              title: "알림",      desc: "매일 리마인더",    color: Color(hex: "FBBF24")),
    ]
}

// MARK: - Sub-components

struct FeatureItem {
    let icon: String
    let title: String
    let desc: String
    let color: Color
}

struct CosmosFeatureCard: View {
    let item: FeatureItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(item.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.cosmosText)
                Text(item.desc)
                    .font(.caption)
                    .foregroundColor(.cosmosMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cosmosCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.cosmosBorder, lineWidth: 1)
        )
    }
}

struct GlowOrb: View {
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cosmosOrange.opacity(0.5), .clear],
                        center: .center, startRadius: 0, endRadius: size
                    )
                )
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulse ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulse)

            Image(systemName: "book.closed.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(
                    LinearGradient(colors: [.cosmosOrange, .cosmosTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .onAppear { pulse = true }
    }
}

struct OrbBackground: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.cosmosOrange.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.cosmosTeal.opacity(0.06))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(x: 120, y: 200)
        }
        .ignoresSafeArea()
    }
}

struct LoadingView: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.cosmosOrange)
                Text(vm.loadingMessage)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.cosmosMuted)
                    .font(.subheadline)
                    .padding(.horizontal)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("처리 중")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ServerSettingsSheet: View {
    @Binding var currentAPIBaseURL: String
    @Environment(\.dismiss) private var dismiss
    @State private var draftURL: String
    @State private var statusMessage = ""
    @State private var statusColor = Color.cosmosMuted
    @State private var isTesting = false

    init(currentAPIBaseURL: Binding<String>) {
        self._currentAPIBaseURL = currentAPIBaseURL
        self._draftURL = State(initialValue: currentAPIBaseURL.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.cosmosBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("서버 연결 설정")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundColor(.cosmosText)
                            Text("앱이 붙을 백엔드 주소를 저장하고 바로 테스트할 수 있습니다.")
                                .font(.subheadline)
                                .foregroundColor(.cosmosMuted)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("API Base URL")
                                .font(.caption.bold())
                                .foregroundColor(.cosmosMuted)
                                .textCase(.uppercase)

                            TextField("http://192.168.0.23:8000/api/v1", text: $draftURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .foregroundColor(.cosmosText)
                                .padding(14)
                                .background(Color.cosmosCard)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.cosmosBorder, lineWidth: 1)
                                )

                            Text("`/api/v1`를 빼고 입력해도 자동으로 붙습니다.")
                                .font(.caption)
                                .foregroundColor(.cosmosMuted)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            quickFillButton("시뮬레이터용 localhost 사용", value: "http://localhost:8000/api/v1")
                            quickFillButton("기기용 예시 주소 넣기", value: "http://192.168.0.23:8000/api/v1")
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("연결 팁")
                                .font(.headline)
                                .foregroundColor(.cosmosText)
                            tipRow("시뮬레이터는 `http://localhost:8000/api/v1`를 그대로 써도 됩니다.")
                            tipRow("실제 아이폰은 맥북과 같은 Wi-Fi에 연결한 뒤 맥북 로컬 IP를 입력해야 합니다.")
                            tipRow("백엔드는 `uvicorn`으로 먼저 켜져 있어야 합니다.")
                        }
                        .padding(16)
                        .background(Color.cosmosCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.cosmosBorder, lineWidth: 1)
                        )

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(statusColor)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(statusColor.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        VStack(spacing: 12) {
                            Button {
                                Task { await testConnection() }
                            } label: {
                                HStack {
                                    if isTesting {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text(isTesting ? "연결 확인 중..." : "연결 테스트")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.cosmosTeal)
                                .foregroundColor(.cosmosBg)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .disabled(isTesting)

                            Button {
                                let normalized = APIService.normalizedBaseURL(draftURL)
                                APIService.shared.updateBaseURL(normalized)
                                currentAPIBaseURL = APIService.shared.baseURL
                                statusColor = .cosmosOrange
                                statusMessage = "저장 완료: \(currentAPIBaseURL)"
                            } label: {
                                Text("이 주소로 저장")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.cosmosOrange)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }

                            Button {
                                APIService.shared.resetBaseURL()
                                currentAPIBaseURL = APIService.shared.baseURL
                                draftURL = currentAPIBaseURL
                                statusColor = .cosmosMuted
                                statusMessage = "기본 연결 주소로 되돌렸습니다."
                            } label: {
                                Text("기본값으로 복원")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.cosmosCard)
                                    .foregroundColor(.cosmosText)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.cosmosBorder, lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(.cosmosTeal)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func quickFillButton(_ label: String, value: String) -> some View {
        Button {
            draftURL = value
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline.weight(.bold))
                Spacer()
                Image(systemName: "arrow.down.left")
            }
            .padding(14)
            .background(Color.cosmosCard)
            .foregroundColor(.cosmosText)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.cosmosBorder, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func tipRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.cosmosTeal)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.cosmosMuted)
        }
    }

    @MainActor
    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }

        let normalized = APIService.normalizedBaseURL(draftURL)
        APIService.shared.updateBaseURL(normalized)
        currentAPIBaseURL = APIService.shared.baseURL

        do {
            let health = try await APIService.shared.healthCheck()
            statusColor = .cosmosTeal
            statusMessage = "연결 성공: \(health.service) (\(health.status))"
        } catch {
            statusColor = .cosmosOrange
            statusMessage = error.localizedDescription
        }
    }
}
