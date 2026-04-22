export type StudyPurpose = 'exam_prep' | 'certification' | 'background' | 'general'
export type StudySchoolLevel = 'elementary' | 'middle' | 'high'
export type Subject =
  | 'korean' | 'english' | 'math' | 'science' | 'social'
  | 'history'
  | 'japanese' | 'chinese' | 'cs' | 'data_science'
  | 'data_structure' | 'computer_system' | 'networking'
  | 'music' | 'other'

export interface KoreanInput       { text_name: string; concepts: string[] }
export interface EnglishMockExam   { grade: number; year: number; month: number; question_numbers: number[] }
export interface EnglishTextbook   { publisher: string; author: string; grade: number; semester: number; chapter: string; section: string }
export interface EnglishInput      { input_type: 'mock_exam'|'textbook'; mock_exam?: EnglishMockExam; textbook?: EnglishTextbook }
export interface TextbookInput     { publisher: string; author: string; grade: number; semester?: number; chapter: string }
export interface CSInput           { publisher: string; author: string; grade: number; semester?: number; chapter: string; related_files: string[] }

export interface StudySessionCreate {
  purpose: StudyPurpose
  school_level: StudySchoolLevel
  subject: Subject
  korean_input?:   KoreanInput
  english_input?:  EnglishInput
  textbook_input?: TextbookInput
  cs_input?:       CSInput
  other_description?: string
  past_exam_content?: string
  days_remaining?: number
  study_hours_per_day?: Record<string, number>
}

export interface StudyContent {
  session_id:          string
  topic:               string
  concept_explanation: string
  concept_summary:     string
  content_outline:     string
  study_start_guide:   string
  self_check_quiz:     string
  recommended_problems:string
  study_direction?:    string
}

export interface StudyPlanItem {
  date:         string
  day_of_week:  string
  topics:       string[]
  study_hours:  number
  tasks:        string[]
}

export interface StudyPlan {
  session_id:   string
  purpose:      StudyPurpose
  total_days:   number
  plan_items:   StudyPlanItem[]
  calendar_view:string
}

export interface StudySession {
  id:                   string
  purpose:              StudyPurpose
  school_level:         StudySchoolLevel
  subject:              Subject
  topic_description:    string
  content?:             StudyContent
  plan?:                StudyPlan
  notifications_enabled:boolean
}

export const SCHOOL_LEVEL_META: Record<StudySchoolLevel, { label: string; icon: string; desc: string }> = {
  elementary: { label: '초등', icon: '🧒', desc: '쉽고 친절한 설명, 짧은 집중 루틴' },
  middle:     { label: '중등', icon: '🧑‍🎓', desc: '개념 연결과 학교 시험 대비 중심' },
  high:       { label: '고등', icon: '🎓', desc: '실전형 분석과 깊이 있는 복습 전략' },
}

export interface MindMapResponse { session_id: string; mindmap: string }

export const PURPOSE_META: Record<StudyPurpose, { label: string; icon: string; desc: string; color: string }> = {
  exam_prep:     { label: '시험 공부',    icon: '📝', desc: '내신·수능·모의고사 대비',  color: 'spark' },
  certification: { label: '자격증',      icon: '🏆', desc: '국가/민간 자격증 취득',    color: 'teal' },
  background:    { label: '배경지식',    icon: '📚', desc: '깊은 이해와 지식 확장',    color: 'lemon' },
  general:       { label: '일반 학습',   icon: '✏️', desc: '자유로운 학습 목표',       color: 'ink' },
}

export const SUBJECT_META: Record<Subject, { label: string; icon: string }> = {
  korean:         { label: '국어',          icon: '📖' },
  english:        { label: '영어',          icon: '🇺🇸' },
  math:           { label: '수학',          icon: '➗' },
  science:        { label: '과학',          icon: '🔬' },
  social:         { label: '사회',          icon: '🌍' },
  history:        { label: '역사',          icon: '🏺' },
  japanese:       { label: '일본어',        icon: '🇯🇵' },
  chinese:        { label: '중국어',        icon: '🇨🇳' },
  cs:             { label: '정보과학',      icon: '💻' },
  data_science:   { label: '데이터과학',    icon: '📊' },
  data_structure: { label: '자료구조',      icon: '🌲' },
  computer_system:{ label: '컴퓨터시스템', icon: '🖥️' },
  networking:     { label: '정보통신',      icon: '🌐' },
  music:          { label: '음악',          icon: '🎵' },
  other:          { label: '기타',          icon: '📌' },
}

export const TEXTBOOK_SUBJECTS: Subject[] = [
  'math',
  'science',
  'social',
  'history',
  'japanese',
  'chinese',
  'music',
]

export const CS_SUBJECTS: Subject[] = [
  'cs',
  'data_science',
  'data_structure',
  'computer_system',
  'networking',
]
