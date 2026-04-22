import Foundation
import SwiftUI

enum StudySchedulePreset: CaseIterable, Identifiable {
    case balanced
    case weekdays
    case weekend

    var id: Self { self }

    var label: String {
        switch self {
        case .balanced: return "균형형"
        case .weekdays: return "주중 집중"
        case .weekend:  return "주말 집중"
        }
    }

    var hours: [String: Double] {
        switch self {
        case .balanced:
            return ["월": 2, "화": 2, "수": 2, "목": 2, "금": 2, "토": 3, "일": 2]
        case .weekdays:
            return ["월": 3, "화": 3, "수": 3, "목": 3, "금": 2, "토": 1, "일": 1]
        case .weekend:
            return ["월": 1, "화": 1, "수": 1, "목": 1, "금": 1, "토": 4, "일": 4]
        }
    }
}

enum AppStep: Hashable {
    case home
    case purposeSubject
    case subjectInput
    case loading
    case content
    case plan
    case mindmap
    case notifications
}

@MainActor
final class StudyViewModel: ObservableObject {

    // MARK: - Navigation
    @Published var path: [AppStep] = []

    // MARK: - User inputs
    @Published var selectedPurpose: StudyPurpose = .general
    @Published var selectedSchoolLevel: SchoolLevel?
    @Published var selectedSubject: Subject = .math

    @Published var koreanInput = KoreanInput()
    @Published var englishInput = EnglishInput()
    @Published var textbookInput = TextbookInput()
    @Published var csInput = CSInput()
    @Published var otherDesc = ""
    @Published var pastExam = ""
    @Published var hasPastExam = false

    // Plan inputs
    @Published var daysRemaining = 14
    @Published var hoursPerDay: [String: Double] = [
        "월": 2, "화": 2, "수": 2, "목": 2, "금": 2, "토": 3, "일": 1
    ]

    // MARK: - Results
    @Published var session: StudySession?
    @Published var mindmapText = ""
    @Published var examAnalysis = ""

    // MARK: - Notification
    @Published var notifMessage = "오늘의 학습을 시작해볼까요? 핵심 개념부터 25분만 집중해보세요."
    @Published var notifTime = Date()
    @Published var notifDays: [String] = ["월", "화", "수", "목", "금"]
    @Published var notifEnabled = false

    // MARK: - State
    @Published var isLoading = false
    @Published var error: String?
    @Published var loadingMessage = "AI가 학습 자료를 생성하는 중..."

    private let api = APIService.shared
    private let notif = LocalNotificationService.shared

    var isExamPurpose: Bool {
        selectedPurpose == .exam_prep || selectedPurpose == .certification
    }

    var totalWeeklyHours: Double {
        hoursPerDay.values.reduce(0, +)
    }

    var studySummaryLines: [String] {
        let topic: String

        switch selectedSubject {
        case .korean:
            topic = koreanInput.textName.trimmedOrNil ?? "작품/지문 입력 대기"
        case .english:
            if englishInput.inputType == "mock_exam" {
                let exam = preparedEnglishInput().mockExam ?? EnglishMockExamInput()
                let nums = exam.questionNumbers.isEmpty
                    ? "지문 번호 입력 대기"
                    : exam.questionNumbers.map(String.init).joined(separator: ", ")
                topic = "\(exam.year)년 \(exam.month)월 모의고사 · \(nums)"
            } else {
                let textbook = preparedEnglishInput().textbook ?? EnglishTextbookInput()
                topic = "\(textbook.publisher.trimmedOrNil ?? "출판사") \(textbook.author.trimmedOrNil ?? "") · \(textbook.chapter.trimmedOrNil ?? "단원")"
            }
        case .math, .science, .social, .history, .japanese, .chinese, .music:
            topic = textbookInput.chapter.trimmedOrNil ?? "단원 입력 대기"
        case .cs, .data_science, .data_structure, .computer_system, .networking:
            topic = csInput.chapter.trimmedOrNil ?? "단원 입력 대기"
        case .other:
            topic = otherDesc.trimmedOrNil ?? "학습 내용 입력 대기"
        }

        let rhythm = isExamPurpose
            ? "\(daysRemaining)일 · 주 \(String(format: "%.1f", totalWeeklyHours))시간"
            : "개념 정리와 학습 구조화"

        return [
            selectedSchoolLevel.map { "\($0.icon) \($0.label)" } ?? "학교급 선택 대기",
            "\(selectedPurpose.icon) \(selectedPurpose.label)",
            "\(selectedSubject.icon) \(selectedSubject.label)",
            topic,
            rhythm
        ]
    }

    var validationErrors: [String] {
        var issues: [String] = []

        if selectedSchoolLevel == nil {
            issues.append("초등, 중등, 고등 중 현재 학교급을 선택해주세요.")
        }

        switch selectedSubject {
        case .korean:
            if koreanInput.textName.trimmedOrNil == nil {
                issues.append("국어 작품 또는 지문 이름을 입력해주세요.")
            }
            if koreanInput.concepts.isEmpty {
                issues.append("국어에서 다루고 싶은 개념을 하나 이상 추가해주세요.")
            }

        case .english:
            let input = preparedEnglishInput()
            if input.inputType == "mock_exam" {
                if input.mockExam?.questionNumbers.isEmpty != false {
                    issues.append("영어 모의고사 지문 번호를 입력해주세요.")
                }
            } else {
                let textbook = input.textbook ?? EnglishTextbookInput()
                if textbook.publisher.trimmedOrNil == nil || textbook.author.trimmedOrNil == nil {
                    issues.append("영어 교과서의 출판사와 저자를 입력해주세요.")
                }
                if textbook.chapter.trimmedOrNil == nil {
                    issues.append("영어 교과서 단원을 입력해주세요.")
                }
                if textbook.section.trimmedOrNil == nil {
                    issues.append("영어 교과서 세부 범위를 입력해주세요.")
                }
            }

        case .math, .science, .social, .history, .japanese, .chinese, .music:
            if textbookInput.publisher.trimmedOrNil == nil || textbookInput.author.trimmedOrNil == nil {
                issues.append("교과서 과목은 출판사와 저자가 필요합니다.")
            }
            if textbookInput.chapter.trimmedOrNil == nil {
                issues.append("학습할 단원을 입력해주세요.")
            }

        case .cs, .data_science, .data_structure, .computer_system, .networking:
            if csInput.publisher.trimmedOrNil == nil || csInput.author.trimmedOrNil == nil {
                issues.append("정보과학 과목은 출판사와 저자가 필요합니다.")
            }
            if csInput.chapter.trimmedOrNil == nil {
                issues.append("학습할 단원을 입력해주세요.")
            }

        case .other:
            if otherDesc.trimmedOrNil == nil {
                issues.append("학습 내용을 자유롭게 설명해주세요.")
            }
        }

        if hasPastExam && pastExam.trimmedOrNil == nil {
            issues.append("기출 분석을 선택했다면 내용도 함께 입력해주세요.")
        }

        if isExamPurpose {
            if daysRemaining < 1 {
                issues.append("남은 기간은 1일 이상이어야 합니다.")
            }
            if !hoursPerDay.values.contains(where: { $0 > 0 }) {
                issues.append("최소 하루 이상의 공부 시간을 설정해주세요.")
            }
        }

        return issues
    }

    var canCreateSession: Bool {
        validationErrors.isEmpty
    }

    var notificationErrors: [String] {
        var issues: [String] = []

        if notifMessage.trimmedOrNil == nil {
            issues.append("알림 메시지를 입력해주세요.")
        }
        if notifDays.isEmpty {
            issues.append("알림을 받을 요일을 하나 이상 선택해주세요.")
        }

        return issues
    }

    // MARK: - Session creation

    func createSession() async {
        guard canCreateSession else {
            error = validationErrors.first
            return
        }

        isLoading = true
        loadingMessage = "Gemini가 검색 기반 자료를 정리하는 중입니다...\n잠시만 기다려주세요."
        error = nil

        let body = buildSessionCreate()

        do {
            let result = try await api.createSession(body)
            session = result
            pushStep(.content)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Plan

    func generatePlan() async {
        guard let sessionId = session?.id else { return }

        isLoading = true
        loadingMessage = "학습 계획을 생성하는 중..."
        error = nil

        do {
            let plan = try await api.generateCustomPlan(
                sessionId: sessionId,
                days: daysRemaining,
                hoursPerDay: normalizedHoursPerDay()
            )
            session?.plan = plan
            pushStep(.plan)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Mind Map

    func fetchMindMap() async {
        guard let sessionId = session?.id else { return }

        isLoading = true
        loadingMessage = "마인드맵을 생성하는 중..."
        error = nil

        do {
            let response = try await api.getMindMap(sessionId: sessionId)
            mindmapText = response.mindmap
            pushStep(.mindmap)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Exam Analysis

    func analyzeExam() async {
        guard let sessionId = session?.id else { return }
        guard let content = pastExam.trimmedOrNil else {
            error = "분석할 기출 내용을 입력해주세요."
            return
        }

        isLoading = true
        loadingMessage = "기출문제를 분석하는 중..."
        error = nil

        do {
            let analysis = try await api.analyzeExam(sessionId: sessionId, content: content)
            examAnalysis = analysis
            if var current = session, let content = current.content {
                current = StudySession(
                    id: current.id,
                    purpose: current.purpose,
                    schoolLevel: current.schoolLevel,
                    subject: current.subject,
                    topicDescription: current.topicDescription,
                    content: StudyContent(
                        sessionId: content.sessionId,
                        topic: content.topic,
                        conceptExplanation: content.conceptExplanation,
                        conceptSummary: content.conceptSummary,
                        contentOutline: content.contentOutline,
                        studyStartGuide: content.studyStartGuide,
                        selfCheckQuiz: content.selfCheckQuiz,
                        recommendedProblems: content.recommendedProblems,
                        studyDirection: analysis
                    ),
                    plan: current.plan,
                    notificationsEnabled: current.notificationsEnabled
                )
                session = current
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Notifications

    func enableNotifications() async {
        guard notificationErrors.isEmpty else {
            error = notificationErrors.first
            return
        }

        let granted = await notif.requestPermission()
        guard granted, let sessionId = session?.id else {
            error = "알림 권한이 필요합니다. 설정에서 허용해주세요."
            return
        }

        error = nil

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: notifTime)
        let minute = calendar.component(.minute, from: notifTime)
        let weekdays = LocalNotificationService.toWeekdays(notifDays)

        notif.scheduleDaily(
            identifier: sessionId,
            title: "StudyAgents",
            body: notifMessage.trimmed,
            hour: hour,
            minute: minute,
            weekdays: weekdays
        )

        let request = NotificationScheduleRequest(
            message: notifMessage.trimmed,
            time: String(format: "%02d:%02d", hour, minute),
            days: notifDays
        )

        do {
            try await api.setNotification(sessionId: sessionId, req: request)
            notifEnabled = true
            session?.notificationsEnabled = true
        } catch {
            notifEnabled = true
            session?.notificationsEnabled = true
            self.error = "기기 알림은 저장됐지만 서버 동기화에 실패했습니다. \(error.localizedDescription)"
        }
    }

    func disableNotifications() async {
        guard let sessionId = session?.id else { return }

        notif.cancel(identifier: sessionId)
        notifEnabled = false
        session?.notificationsEnabled = false

        do {
            try await api.cancelNotification(sessionId: sessionId)
        } catch {
            self.error = "기기 알림은 꺼졌지만 서버 동기화에 실패했습니다. \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    func applySchedulePreset(_ preset: StudySchedulePreset) {
        hoursPerDay = preset.hours
    }

    func refreshEnglishDefaults() {
        englishInput = preparedEnglishInput()
    }

    func toggleConcept(_ concept: String) {
        let cleaned = concept.trimmed
        guard !cleaned.isEmpty else { return }

        if koreanInput.concepts.contains(cleaned) {
            koreanInput.concepts.removeAll { $0 == cleaned }
        } else {
            koreanInput.concepts.append(cleaned)
        }
    }

    func removeConcept(_ concept: String) {
        koreanInput.concepts.removeAll { $0 == concept }
    }

    func reset() {
        path = []
        selectedPurpose = .general
        selectedSchoolLevel = nil
        selectedSubject = .math
        session = nil
        mindmapText = ""
        examAnalysis = ""
        error = nil
        koreanInput = KoreanInput()
        englishInput = EnglishInput()
        textbookInput = TextbookInput()
        csInput = CSInput()
        otherDesc = ""
        pastExam = ""
        hasPastExam = false
        daysRemaining = 14
        hoursPerDay = ["월": 2, "화": 2, "수": 2, "목": 2, "금": 2, "토": 3, "일": 1]
        notifMessage = "오늘의 학습을 시작해볼까요? 핵심 개념부터 25분만 집중해보세요."
        notifDays = ["월", "화", "수", "목", "금"]
        notifEnabled = false
    }

    private func pushStep(_ step: AppStep) {
        if path.last != step {
            path.append(step)
        }
    }

    private func buildSessionCreate() -> StudySessionCreate {
        var body = StudySessionCreate(
            purpose: selectedPurpose,
            schoolLevel: selectedSchoolLevel ?? .middle,
            subject: selectedSubject
        )

        switch selectedSubject {
        case .korean:
            body.koreanInput = KoreanInput(
                textName: koreanInput.textName.trimmed,
                concepts: koreanInput.concepts.map(\.trimmed).filter { !$0.isEmpty }
            )

        case .english:
            body.englishInput = preparedEnglishInput()

        case .math, .science, .social, .history, .japanese, .chinese, .music:
            body.textbookInput = TextbookInput(
                publisher: textbookInput.publisher.trimmed,
                author: textbookInput.author.trimmed,
                grade: textbookInput.grade,
                semester: textbookInput.semester,
                chapter: textbookInput.chapter.trimmed
            )

        case .cs, .data_science, .data_structure, .computer_system, .networking:
            body.csInput = CSInput(
                publisher: csInput.publisher.trimmed,
                author: csInput.author.trimmed,
                grade: csInput.grade,
                semester: csInput.semester,
                chapter: csInput.chapter.trimmed,
                relatedFiles: csInput.relatedFiles.map(\.trimmed).filter { !$0.isEmpty }
            )

        case .other:
            body.otherDescription = otherDesc.trimmed
        }

        if hasPastExam, let content = pastExam.trimmedOrNil {
            body.pastExamContent = content
        }

        if isExamPurpose {
            body.daysRemaining = daysRemaining
            body.studyHoursPerDay = normalizedHoursPerDay()
        }

        return body
    }

    private func preparedEnglishInput() -> EnglishInput {
        var input = englishInput

        if input.inputType == "mock_exam" {
            var exam = input.mockExam ?? EnglishMockExamInput()
            exam.questionNumbers = exam.questionNumbers.filter { $0 > 0 }
            input.mockExam = exam
            input.textbook = nil
        } else {
            let textbook = input.textbook ?? EnglishTextbookInput()
            input.textbook = EnglishTextbookInput(
                publisher: textbook.publisher.trimmed,
                author: textbook.author.trimmed,
                grade: textbook.grade,
                semester: textbook.semester,
                chapter: textbook.chapter.trimmed,
                section: textbook.section.trimmed
            )
            input.mockExam = nil
        }

        return input
    }

    private func normalizedHoursPerDay() -> [String: Double] {
        let orderedDays = ["월", "화", "수", "목", "금", "토", "일"]
        return Dictionary(uniqueKeysWithValues: orderedDays.map { day in
            (day, min(max(hoursPerDay[day] ?? 0, 0), 12))
        })
    }
}
