import SwiftUI

struct SubjectInputView: View {
    @EnvironmentObject private var vm: StudyViewModel
    @State private var conceptDraft = ""

    var body: some View {
        ZStack {
            Color.cosmosBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(vm.selectedSubject.icon) \(vm.selectedSubject.label)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.cosmosText)
                                    Text(vm.selectedPurpose.detail)
                                        .font(.caption)
                                        .foregroundColor(.cosmosMuted)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    if let level = vm.selectedSchoolLevel {
                                        Text(level.label)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.cosmosTeal.opacity(0.12))
                                            .foregroundColor(.cosmosTeal)
                                            .clipShape(Capsule())
                                    }
                                    Text(vm.selectedPurpose.label)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.cosmosOrange.opacity(0.12))
                                        .foregroundColor(.cosmosOrange)
                                        .clipShape(Capsule())
                                }
                            }

                            CosmosInfoBanner(
                                title: "입력 힌트",
                                message: vm.selectedSubject.inputHint,
                                color: .cosmosTeal
                            )
                        }
                    }

                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 14) {
                            switch vm.selectedSubject {
                            case .korean:   KoreanFields(conceptDraft: $conceptDraft)
                            case .english:  EnglishFields()
                            case .math, .science, .social, .history, .japanese, .chinese, .music:
                                TextbookFields()
                            case .cs, .data_science, .data_structure, .computer_system, .networking:
                                CSFields()
                            case .other:    OtherField()
                            }
                        }
                    }

                    if vm.isExamPurpose {
                        CosmosCardSection {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("시험 대비 옵션")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.cosmosText)
                                    Spacer()
                                    Text("\(vm.daysRemaining)일 남음")
                                        .font(.caption.bold())
                                        .foregroundColor(.cosmosOrange)
                                }

                                Toggle(isOn: $vm.hasPastExam) {
                                    Label("기출 문제 보유", systemImage: "doc.on.doc")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.cosmosText)
                                }
                                .tint(.cosmosOrange)

                                if vm.hasPastExam {
                                    CosmosEditor(
                                        text: $vm.pastExam,
                                        placeholder: "기출 문제, 오답 메모, 헷갈리는 포인트를 붙여넣어 주세요.",
                                        height: 110
                                    )
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("남은 기간")
                                            .font(.caption.bold())
                                            .foregroundColor(.cosmosMuted)
                                        Spacer()
                                        Text("\(vm.daysRemaining)일")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.cosmosOrange)
                                    }
                                    Slider(
                                        value: Binding(
                                            get: { Double(vm.daysRemaining) },
                                            set: { vm.daysRemaining = Int($0) }
                                        ),
                                        in: 1...365,
                                        step: 1
                                    )
                                    .tint(.cosmosOrange)
                                }

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("학습 패턴 프리셋")
                                        .font(.caption.bold())
                                        .foregroundColor(.cosmosMuted)
                                    HStack(spacing: 8) {
                                        ForEach(StudySchedulePreset.allCases) { preset in
                                            Button {
                                                vm.applySchedulePreset(preset)
                                            } label: {
                                                Text(preset.label)
                                                    .font(.caption.bold())
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 9)
                                                    .background(Color.cosmosBg)
                                                    .foregroundColor(.cosmosText)
                                                    .clipShape(Capsule())
                                                    .overlay(Capsule().stroke(Color.cosmosBorder, lineWidth: 1))
                                            }
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("요일별 공부 시간")
                                            .font(.caption.bold())
                                            .foregroundColor(.cosmosMuted)
                                        Spacer()
                                        Text("주 \(String(format: "%.1f", vm.totalWeeklyHours))시간")
                                            .font(.caption.bold())
                                            .foregroundColor(.cosmosTeal)
                                    }

                                    ForEach(["월", "화", "수", "목", "금", "토", "일"], id: \.self) { day in
                                        HStack(spacing: 10) {
                                            Text(day)
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(.cosmosText)
                                                .frame(width: 24)
                                            Slider(
                                                value: Binding(
                                                    get: { vm.hoursPerDay[day] ?? 0 },
                                                    set: { vm.hoursPerDay[day] = $0 }
                                                ),
                                                in: 0...8,
                                                step: 0.5
                                            )
                                            .tint(.cosmosTeal)
                                            Text(String(format: "%.1fh", vm.hoursPerDay[day] ?? 0))
                                                .font(.caption.bold())
                                                .foregroundColor(.cosmosTeal)
                                                .frame(width: 40)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("세션 브리프")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.cosmosText)

                            ForEach(vm.studySummaryLines, id: \.self) { line in
                                Text(line)
                                    .font(.caption)
                                    .foregroundColor(.cosmosMuted)
                            }
                        }
                    }

                    if let err = vm.error {
                        Text(err)
                            .foregroundColor(Color(hex: "FC8181"))
                            .font(.caption)
                            .padding()
                            .background(Color(hex: "FC8181").opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    CosmosCardSection {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(vm.canCreateSession ? "입력 준비 완료" : "확인할 항목")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(vm.canCreateSession ? .cosmosTeal : .cosmosOrange)

                            if vm.canCreateSession {
                                Text("현재 입력이면 AI가 자료를 생성하기에 충분합니다.")
                                    .font(.caption)
                                    .foregroundColor(.cosmosMuted)
                            } else {
                                ForEach(vm.validationErrors, id: \.self) { issue in
                                    Text("• \(issue)")
                                        .font(.caption)
                                        .foregroundColor(.cosmosMuted)
                                }
                            }
                        }
                    }

                    CosmosButton(label: "AI 학습 자료 생성", icon: "sparkles", isDisabled: !vm.canCreateSession) {
                        Task { await vm.createSession() }
                    }
                    .padding(.bottom, 32)
                }
                .padding(20)
            }
            .overlay {
                if vm.isLoading {
                    CosmosLoadingOverlay(message: vm.loadingMessage)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle(vm.selectedSubject.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.refreshEnglishDefaults()
        }
        .onChange(of: vm.englishInput.inputType) { _ in
            vm.refreshEnglishDefaults()
        }
    }
}

private struct KoreanFields: View {
    @EnvironmentObject private var vm: StudyViewModel
    @Binding var conceptDraft: String

    var body: some View {
        VStack(spacing: 12) {
            CosmosField(
                label: "작가 및 작품 이름",
                placeholder: "예) 이상 - 날개",
                text: $vm.koreanInput.textName
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("필요한 개념")
                    .font(.caption.bold())
                    .foregroundColor(.cosmosMuted)
                    .textCase(.uppercase)

                HStack {
                    TextField("예) 반어법, 시점, 의식의 흐름", text: $conceptDraft)
                        .foregroundColor(.cosmosText)
                        .padding(12)
                        .background(Color.cosmosBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.cosmosBorder))

                    Button {
                        let concept = conceptDraft.trimmed
                        guard !concept.isEmpty else { return }
                        vm.toggleConcept(concept)
                        conceptDraft = ""
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cosmosOrange)
                    }
                }

                if !vm.koreanInput.concepts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(vm.koreanInput.concepts, id: \.self) { concept in
                                HStack(spacing: 4) {
                                    Text(concept)
                                        .font(.caption)
                                        .foregroundColor(.cosmosOrange)
                                    Button {
                                        vm.removeConcept(concept)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.cosmosOrange.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.cosmosOrange.opacity(0.4), lineWidth: 1))
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EnglishFields: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        VStack(spacing: 12) {
            Picker("유형", selection: $vm.englishInput.inputType) {
                Text("모의고사").tag("mock_exam")
                Text("교과서").tag("textbook")
            }
            .pickerStyle(.segmented)
            .colorMultiply(.cosmosOrange)

            if vm.englishInput.inputType == "mock_exam" {
                let exam = Binding(
                    get: { vm.englishInput.mockExam ?? EnglishMockExamInput() },
                    set: { vm.englishInput.mockExam = $0 }
                )

                HStack(spacing: 12) {
                    CosmosStepper(
                        label: "학년",
                        value: Binding(
                            get: { exam.wrappedValue.grade },
                            set: { exam.wrappedValue.grade = $0 }
                        ),
                        range: 1...6
                    )
                    CosmosStepper(
                        label: "월",
                        value: Binding(
                            get: { exam.wrappedValue.month },
                            set: { exam.wrappedValue.month = $0 }
                        ),
                        range: 1...12
                    )
                }

                CosmosStepper(
                    label: "년도",
                    value: Binding(
                        get: { exam.wrappedValue.year },
                        set: { exam.wrappedValue.year = $0 }
                    ),
                    range: 2010...2035
                )

                CosmosField(
                    label: "지문 번호",
                    placeholder: "예) 18, 20, 23",
                    text: Binding(
                        get: { exam.wrappedValue.questionNumbers.map(String.init).joined(separator: ", ") },
                        set: { value in
                            exam.wrappedValue.questionNumbers = value
                                .split(separator: ",")
                                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                        }
                    )
                )
            } else {
                let textbook = Binding(
                    get: { vm.englishInput.textbook ?? EnglishTextbookInput() },
                    set: { vm.englishInput.textbook = $0 }
                )

                CosmosField(
                    label: "출판사",
                    placeholder: "예) 능률 / YBM",
                    text: Binding(
                        get: { textbook.wrappedValue.publisher },
                        set: { textbook.wrappedValue.publisher = $0 }
                    )
                )
                CosmosField(
                    label: "저자",
                    placeholder: "예) 김성곤",
                    text: Binding(
                        get: { textbook.wrappedValue.author },
                        set: { textbook.wrappedValue.author = $0 }
                    )
                )

                HStack(spacing: 12) {
                    CosmosStepper(
                        label: "학년",
                        value: Binding(
                            get: { textbook.wrappedValue.grade },
                            set: { textbook.wrappedValue.grade = $0 }
                        ),
                        range: 1...6
                    )
                    CosmosStepper(
                        label: "학기",
                        value: Binding(
                            get: { textbook.wrappedValue.semester },
                            set: { textbook.wrappedValue.semester = $0 }
                        ),
                        range: 1...2
                    )
                }

                CosmosField(
                    label: "단원",
                    placeholder: "예) Unit 3. Reading Skills",
                    text: Binding(
                        get: { textbook.wrappedValue.chapter },
                        set: { textbook.wrappedValue.chapter = $0 }
                    )
                )
                CosmosField(
                    label: "세부 범위",
                    placeholder: "예) 본문 / 대화문 / 어휘 정리",
                    text: Binding(
                        get: { textbook.wrappedValue.section },
                        set: { textbook.wrappedValue.section = $0 }
                    )
                )
            }
        }
    }
}

private struct TextbookFields: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        VStack(spacing: 12) {
            CosmosField(label: "출판사", placeholder: "예) 미래엔", text: $vm.textbookInput.publisher)
            CosmosField(label: "저자", placeholder: "예) 홍길동", text: $vm.textbookInput.author)

            HStack(spacing: 12) {
                CosmosStepper(label: "학년", value: $vm.textbookInput.grade, range: 1...6)
                CosmosStepper(
                    label: "학기",
                    value: Binding(
                        get: { vm.textbookInput.semester ?? 1 },
                        set: { vm.textbookInput.semester = $0 }
                    ),
                    range: 1...2
                )
            }

            CosmosField(label: "단원", placeholder: "예) 3단원. 생태계와 환경", text: $vm.textbookInput.chapter)
        }
    }
}

private struct CSFields: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        VStack(spacing: 12) {
            CosmosField(label: "출판사", placeholder: "예) 와이비엠", text: $vm.csInput.publisher)
            CosmosField(label: "저자", placeholder: "예) 이영준", text: $vm.csInput.author)

            HStack(spacing: 12) {
                CosmosStepper(label: "학년", value: $vm.csInput.grade, range: 1...6)
                CosmosStepper(
                    label: "학기",
                    value: Binding(
                        get: { vm.csInput.semester ?? 1 },
                        set: { vm.csInput.semester = $0 }
                    ),
                    range: 1...2
                )
            }

            CosmosField(label: "단원", placeholder: "예) 3. 알고리즘과 프로그래밍", text: $vm.csInput.chapter)
        }
    }
}

private struct OtherField: View {
    @EnvironmentObject private var vm: StudyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("학습 내용")
                .font(.caption.bold())
                .foregroundColor(.cosmosMuted)
                .textCase(.uppercase)
            CosmosEditor(
                text: $vm.otherDesc,
                placeholder: "예) 독서 토론 준비, 논술 자료 정리, 발표 주제 조사",
                height: 110
            )
        }
    }
}

struct CosmosCardSection<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .background(Color.cosmosCard)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.cosmosBorder, lineWidth: 1))
    }
}

struct CosmosEditor: View {
    @Binding var text: String
    let placeholder: String
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmed.isEmpty {
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.cosmosMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
            }

            TextEditor(text: $text)
                .frame(height: height)
                .foregroundColor(.cosmosText)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color.cosmosBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cosmosBorder))
        }
    }
}

struct CosmosLoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.cosmosBg.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView().tint(.cosmosOrange).scaleEffect(1.5)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.cosmosText)
                    .font(.subheadline)
                    .padding(.horizontal, 24)
            }
            .padding(32)
            .background(Color.cosmosCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cosmosBorder))
        }
    }
}
