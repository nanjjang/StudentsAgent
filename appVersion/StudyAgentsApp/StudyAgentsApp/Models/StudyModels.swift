import Foundation

// MARK: - Enums

enum StudyPurpose: String, Codable, CaseIterable, Identifiable {
    case exam_prep, certification, background, general
    var id: String { rawValue }
    var label: String {
        switch self {
        case .exam_prep:     return "시험 공부"
        case .certification: return "자격증"
        case .background:    return "배경지식 넓히기"
        case .general:       return "일반 학습"
        }
    }
    var icon: String {
        switch self {
        case .exam_prep:     return "📝"
        case .certification: return "🏆"
        case .background:    return "📚"
        case .general:       return "✏️"
        }
    }
    var detail: String {
        switch self {
        case .exam_prep:     return "내신·수능·모의고사 대비"
        case .certification: return "국가·민간 자격증 준비"
        case .background:    return "개념 구조와 배경지식 확장"
        case .general:       return "자유 주제 학습과 정리"
        }
    }
}

enum SchoolLevel: String, Codable, CaseIterable, Identifiable {
    case elementary, middle, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .elementary: return "초등"
        case .middle:     return "중등"
        case .high:       return "고등"
        }
    }
    var icon: String {
        switch self {
        case .elementary: return "🧒"
        case .middle:     return "🧑‍🎓"
        case .high:       return "🎓"
        }
    }
    var detail: String {
        switch self {
        case .elementary: return "쉬운 설명과 짧은 집중 루틴"
        case .middle:     return "개념 연결과 학교 시험 대비"
        case .high:       return "실전형 분석과 깊이 있는 복습"
        }
    }
}

enum Subject: String, Codable, CaseIterable, Identifiable {
    case korean, english, math, science, social
    case history
    case japanese, chinese, cs, data_science
    case data_structure, computer_system, networking
    case music, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .korean:          return "국어"
        case .english:         return "영어"
        case .math:            return "수학"
        case .science:         return "과학"
        case .social:          return "사회"
        case .history:         return "역사"
        case .japanese:        return "일본어"
        case .chinese:         return "중국어"
        case .cs:              return "정보과학"
        case .data_science:    return "데이터과학"
        case .data_structure:  return "자료구조"
        case .computer_system: return "컴퓨터시스템일반"
        case .networking:      return "정보통신"
        case .music:           return "음악"
        case .other:           return "기타"
        }
    }
    var icon: String {
        switch self {
        case .korean:          return "📖"
        case .english:         return "🇺🇸"
        case .math:            return "➗"
        case .science:         return "🔬"
        case .social:          return "🌍"
        case .history:         return "🏺"
        case .japanese:        return "🇯🇵"
        case .chinese:         return "🇨🇳"
        case .cs:              return "💻"
        case .data_science:    return "📊"
        case .data_structure:  return "🌲"
        case .computer_system: return "🖥️"
        case .networking:      return "🌐"
        case .music:           return "🎵"
        case .other:           return "📌"
        }
    }
    var needsTextbookInput: Bool {
        switch self {
        case .math, .science, .social, .history, .japanese, .chinese, .music: return true
        default: return false
        }
    }
    var needsCSInput: Bool {
        switch self {
        case .cs, .data_science, .data_structure, .computer_system, .networking: return true
        default: return false
        }
    }
    var inputHint: String {
        switch self {
        case .korean:          return "작품명과 궁금한 개념을 적어주세요."
        case .english:         return "모의고사 또는 교과서 중 하나를 고르세요."
        case .math, .science, .social, .history, .japanese, .chinese, .music:
            return "교과서 정보와 단원을 적어주면 좋아요."
        case .cs, .data_science, .data_structure, .computer_system, .networking:
            return "교재와 단원을 적어주면 검색 정확도가 높아집니다."
        case .other:           return "범위와 원하는 결과물을 자유롭게 설명해주세요."
        }
    }
}

// MARK: - Subject-specific inputs

struct KoreanInput: Codable {
    var textName: String = ""
    var concepts: [String] = []
}

struct EnglishMockExamInput: Codable {
    var grade: Int = 1
    var year: Int = 2024
    var month: Int = 3
    var questionNumbers: [Int] = []
}

struct EnglishTextbookInput: Codable {
    var publisher: String = ""
    var author: String = ""
    var grade: Int = 1
    var semester: Int = 1
    var chapter: String = ""
    var section: String = ""
}

struct EnglishInput: Codable {
    var inputType: String = "mock_exam"   // "mock_exam" | "textbook"
    var mockExam: EnglishMockExamInput? = EnglishMockExamInput()
    var textbook: EnglishTextbookInput?
}

struct TextbookInput: Codable {
    var publisher: String = ""
    var author: String = ""
    var grade: Int = 1
    var semester: Int? = 1
    var chapter: String = ""
}

struct CSInput: Codable {
    var publisher: String = ""
    var author: String = ""
    var grade: Int = 1
    var semester: Int? = 1
    var chapter: String = ""
    var relatedFiles: [String] = []
}

// MARK: - Request body

struct StudySessionCreate: Codable {
    var purpose: StudyPurpose
    var schoolLevel: SchoolLevel
    var subject: Subject
    var koreanInput: KoreanInput?
    var englishInput: EnglishInput?
    var textbookInput: TextbookInput?
    var csInput: CSInput?
    var otherDescription: String?
    var pastExamContent: String?
    var daysRemaining: Int?
    var studyHoursPerDay: [String: Double]?
}

// MARK: - API responses

struct StudyContent: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let topic: String
    let conceptExplanation: String
    let conceptSummary: String
    let contentOutline: String
    let studyStartGuide: String
    let selfCheckQuiz: String
    let recommendedProblems: String
    let studyDirection: String?
}

struct StudyPlanItem: Codable, Identifiable {
    var id: String { date + dayOfWeek }
    let date: String
    let dayOfWeek: String
    let topics: [String]
    let studyHours: Double
    let tasks: [String]
}

struct StudyPlan: Codable {
    let sessionId: String
    let purpose: StudyPurpose
    let totalDays: Int
    let planItems: [StudyPlanItem]
    let calendarView: String
}

struct StudySession: Codable, Identifiable {
    let id: String
    let purpose: StudyPurpose
    let schoolLevel: SchoolLevel
    let subject: Subject
    let topicDescription: String
    let content: StudyContent?
    var plan: StudyPlan?
    var notificationsEnabled: Bool
}

struct MindMapResponse: Codable {
    let sessionId: String
    let mindmap: String
}

struct NotificationScheduleRequest: Codable {
    var message: String
    var time: String
    var days: [String]
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedOrNil: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
