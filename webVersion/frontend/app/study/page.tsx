'use client'

import { AnimatePresence, motion } from 'framer-motion'
import { useRouter } from 'next/navigation'
import type { ReactNode } from 'react'
import { useEffect, useState } from 'react'

import { api } from '@/lib/api'
import { CS_SUBJECTS, PURPOSE_META, SCHOOL_LEVEL_META, SUBJECT_META, TEXTBOOK_SUBJECTS } from '@/lib/types'
import type { StudyPurpose, StudySchoolLevel, StudySessionCreate, Subject } from '@/lib/types'

type Step = 'purpose' | 'subject' | 'input' | 'loading'
type BackendStatus = 'checking' | 'ready' | 'down'

const ALL_PURPOSES = Object.keys(PURPOSE_META) as StudyPurpose[]
const ALL_SCHOOL_LEVELS = Object.keys(SCHOOL_LEVEL_META) as StudySchoolLevel[]
const ALL_SUBJECTS = Object.keys(SUBJECT_META) as Subject[]
const DAYS = ['월', '화', '수', '목', '금', '토', '일'] as const

const variants = {
  enter: { opacity: 0, x: 36 },
  center: { opacity: 1, x: 0 },
  exit: { opacity: 0, x: -36 },
}

const SCHEDULE_PRESETS = [
  { key: 'balanced', label: '균형형', hours: { 월: 2, 화: 2, 수: 2, 목: 2, 금: 2, 토: 3, 일: 2 } },
  { key: 'weekdays', label: '주중 집중', hours: { 월: 3, 화: 3, 수: 3, 목: 3, 금: 2, 토: 1, 일: 1 } },
  { key: 'weekend', label: '주말 집중', hours: { 월: 1, 화: 1, 수: 1, 목: 1, 금: 1, 토: 4, 일: 4 } },
] as const

export default function StudyPage() {
  const router = useRouter()
  const [step, setStep] = useState<Step>('purpose')
  const [purpose, setPurpose] = useState<StudyPurpose>('general')
  const [schoolLevel, setSchoolLevel] = useState<StudySchoolLevel | null>(null)
  const [subject, setSubject] = useState<Subject>('math')
  const [error, setError] = useState('')
  const [backendStatus, setBackendStatus] = useState<BackendStatus>('checking')
  const [backendMessage, setBackendMessage] = useState('백엔드 연결 상태를 확인하는 중입니다.')

  const [koreanName, setKoreanName] = useState('')
  const [koreanConcepts, setKoreanConcepts] = useState('')
  const [publisher, setPublisher] = useState('')
  const [author, setAuthor] = useState('')
  const [grade, setGrade] = useState(1)
  const [semester, setSemester] = useState(1)
  const [chapter, setChapter] = useState('')
  const [section, setSection] = useState('')
  const [otherDesc, setOtherDesc] = useState('')
  const [hasPastExam, setHasPastExam] = useState(false)
  const [pastExam, setPastExam] = useState('')
  const [daysLeft, setDaysLeft] = useState(14)
  const [hours, setHours] = useState<Record<string, number>>({
    월: 2,
    화: 2,
    수: 2,
    목: 2,
    금: 2,
    토: 3,
    일: 1,
  })
  const [mockYear, setMockYear] = useState(2024)
  const [mockMonth, setMockMonth] = useState(6)
  const [mockNums, setMockNums] = useState('')
  const [engType, setEngType] = useState<'mock_exam' | 'textbook'>('mock_exam')

  const isExam = purpose === 'exam_prep' || purpose === 'certification'
  const stepOrder: Step[] = ['purpose', 'subject', 'input', 'loading']
  const stepIdx = stepOrder.indexOf(step)
  const totalWeeklyHours = Object.values(hours).reduce((sum, value) => sum + value, 0)
  const validationErrors = getValidationErrors({
    purpose,
    schoolLevel,
    subject,
    koreanName,
    koreanConcepts,
    publisher,
    author,
    chapter,
    section,
    otherDesc,
    hasPastExam,
    pastExam,
    daysLeft,
    hours,
    engType,
    mockNums,
  })
  const isReadyToSubmit = validationErrors.length === 0
  const studyBrief = buildStudyBrief({
    purpose,
    schoolLevel,
    subject,
    koreanName,
    koreanConcepts,
    publisher,
    author,
    grade,
    semester,
    chapter,
    section,
    otherDesc,
    engType,
    mockYear,
    mockMonth,
    mockNums,
    daysLeft,
    totalWeeklyHours,
  })

  async function checkBackend() {
    setBackendStatus('checking')
    setBackendMessage('백엔드 연결 상태를 확인하는 중입니다.')
    try {
      await api.healthCheck()
      setBackendStatus('ready')
      setBackendMessage('백엔드가 정상적으로 실행 중입니다.')
      return true
    } catch {
      setBackendStatus('down')
      setBackendMessage('백엔드 서버에 연결하지 못했습니다. FastAPI 서버를 먼저 켜주세요.')
      return false
    }
  }

  useEffect(() => {
    void checkBackend()
  }, [])

  function buildPayload(): StudySessionCreate {
    const base: StudySessionCreate = { purpose, school_level: schoolLevel ?? 'middle', subject }

    if (subject === 'korean') {
      base.korean_input = {
        text_name: koreanName.trim(),
        concepts: koreanConcepts
          .split(',')
          .map((item) => item.trim())
          .filter(Boolean),
      }
    } else if (subject === 'english') {
      if (engType === 'mock_exam') {
        base.english_input = {
          input_type: 'mock_exam',
          mock_exam: {
            grade,
            year: mockYear,
            month: mockMonth,
            question_numbers: mockNums
              .split(',')
              .map((item) => Number.parseInt(item.trim(), 10))
              .filter((item) => Number.isFinite(item)),
          },
        }
      } else {
        base.english_input = {
          input_type: 'textbook',
          textbook: {
            publisher: publisher.trim(),
            author: author.trim(),
            grade,
            semester,
            chapter: chapter.trim(),
            section: section.trim(),
          },
        }
      }
    } else if (TEXTBOOK_SUBJECTS.includes(subject)) {
      base.textbook_input = {
        publisher: publisher.trim(),
        author: author.trim(),
        grade,
        semester,
        chapter: chapter.trim(),
      }
    } else if (CS_SUBJECTS.includes(subject)) {
      base.cs_input = {
        publisher: publisher.trim(),
        author: author.trim(),
        grade,
        semester,
        chapter: chapter.trim(),
        related_files: [],
      }
    } else {
      base.other_description = otherDesc.trim()
    }

    if (hasPastExam && pastExam.trim()) {
      base.past_exam_content = pastExam.trim()
    }

    if (isExam) {
      base.days_remaining = daysLeft
      base.study_hours_per_day = hours
    }

    return base
  }

  async function handleSubmit() {
    const backendReady = backendStatus === 'ready' ? true : await checkBackend()
    if (!backendReady) {
      setError('백엔드 서버가 꺼져 있습니다. `webVersion`에서 FastAPI를 먼저 실행한 뒤 다시 시도해주세요.')
      return
    }

    if (!isReadyToSubmit) {
      setError(validationErrors[0] ?? '입력값을 다시 확인해주세요.')
      return
    }

    setStep('loading')
    setError('')

    try {
      const session = await api.createSession(buildPayload())
      router.push(`/study/${session.id}`)
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : '오류가 발생했습니다.')
      setStep('input')
    }
  }

  function applySchedulePreset(hoursByDay: Record<string, number>) {
    setHours(hoursByDay)
  }

  const stepLabels: Record<Step, string> = {
    purpose: '학습 목적 선택',
    subject: '과목 선택',
    input: '입력 브리프 작성',
    loading: 'Gemini가 자료를 만드는 중',
  }

  return (
    <main className="min-h-screen bg-cream bg-dot-grid font-body">
      <div className="border-b-2 border-ink bg-cream/90 px-6 py-4 backdrop-blur-sm">
        <div className="mx-auto flex max-w-6xl items-center justify-between gap-6">
          <a href="/" className="font-display text-lg font-bold">
            Study<span className="text-spark">Agents</span>
          </a>
              <div className="hidden items-center gap-3 md:flex">
                <span className="border-2 border-ink bg-white px-3 py-1 font-display text-xs font-semibold">
                  {PURPOSE_META[purpose].label}
                </span>
                <span className="border-2 border-ink bg-lemon px-3 py-1 font-display text-xs font-semibold">
                  {schoolLevel ? `${SCHOOL_LEVEL_META[schoolLevel].icon} ${SCHOOL_LEVEL_META[schoolLevel].label}` : '학교급 선택'}
                </span>
                <span className="border-2 border-ink bg-teal text-cream px-3 py-1 font-display text-xs font-semibold">
                  {SUBJECT_META[subject].label}
                </span>
          </div>
        </div>
      </div>

      <section className="mx-auto max-w-6xl px-6 pb-12 pt-10">
        <div className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          <div className="space-y-5">
            <span className="section-kicker">
              <span className="inline-block h-2 w-2 rounded-full bg-ink animate-pulse-dot" />
              맞춤형 학습 브리프 생성기
            </span>
            <div>
              <p className="font-display text-sm uppercase tracking-[0.2em] text-muted">Study flow</p>
              <h1 className="mt-2 font-display text-[clamp(2.4rem,5vw,4.6rem)] font-bold leading-[1.02]">
                입력이 좋아질수록
                <br />
                결과물도 더 정교해집니다.
              </h1>
              <p className="mt-5 max-w-2xl text-[16px] leading-7 text-muted">
                과목, 범위, 남은 시간만 정확히 적어도 AI가 웹 검색과 분석을 거쳐 설명 자료, 문제 추천,
                계획표, 마인드맵까지 한 번에 구성합니다.
              </p>
            </div>
          </div>

          <div className="glass-panel border-2 border-ink p-6 shadow-brutal">
            <div className="flex items-center justify-between">
              <div>
                <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">Current brief</p>
                <h2 className="mt-2 font-display text-xl font-bold">이번 세션 미리보기</h2>
              </div>
              <span className="border-2 border-ink bg-lemon px-3 py-1 font-display text-xs font-bold">
                Step {Math.min(stepIdx + 1, 3)} / 3
              </span>
            </div>
            <div className="mt-5 space-y-4">
              {studyBrief.map((item) => (
                <div key={item.label} className="border-2 border-ink bg-white p-4 shadow-brutal-sm">
                  <p className="font-display text-[11px] uppercase tracking-[0.16em] text-muted">{item.label}</p>
                  <p className="mt-2 text-sm leading-6">{item.value}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      <div className="mx-auto max-w-6xl px-6 pb-16">
        <div className="mb-8 flex flex-wrap items-center gap-4">
          <h2 className="font-display text-2xl font-bold">{stepLabels[step]}</h2>
          <div className="flex items-center gap-2">
            {stepOrder.slice(0, 3).map((currentStep, index) => (
              <div key={currentStep} className="flex items-center gap-2">
                <div
                  className={`flex h-9 w-9 items-center justify-center border-2 border-ink font-display text-xs font-bold ${
                    index <= stepIdx ? 'bg-spark text-cream' : 'bg-white'
                  }`}
                >
                  {index + 1}
                </div>
                {index < 2 && (
                  <div className={`h-0.5 w-12 ${index < stepIdx ? 'bg-spark' : 'bg-ink/15'}`} />
                )}
              </div>
            ))}
          </div>
        </div>

        <div
          className={`mb-6 flex flex-wrap items-center justify-between gap-3 border-2 p-4 ${
            backendStatus === 'ready'
              ? 'border-teal bg-teal/10'
              : backendStatus === 'down'
                ? 'border-red-500 bg-red-50'
                : 'border-ink bg-white'
          }`}
        >
          <div>
            <p className="font-display text-sm font-bold">
              {backendStatus === 'ready'
                ? '백엔드 연결 완료'
                : backendStatus === 'down'
                  ? '백엔드 연결 필요'
                  : '백엔드 확인 중'}
            </p>
            <p className="mt-1 text-sm text-muted">{backendMessage}</p>
          </div>
          <button
            className="border-2 border-ink bg-white px-4 py-2 font-display text-sm font-semibold shadow-brutal-sm transition-all hover:-translate-y-0.5 hover:shadow-brutal"
            onClick={() => void checkBackend()}
          >
            다시 확인
          </button>
        </div>

        <AnimatePresence mode="wait">
          <motion.div
            key={step}
            variants={variants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ duration: 0.25 }}
          >
            {step === 'purpose' && (
              <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="brutal-card p-6 sm:col-span-2">
                    <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">학교급 선택</p>
                    <div className="mt-4 grid gap-3 sm:grid-cols-3">
                      {ALL_SCHOOL_LEVELS.map((currentSchoolLevel) => {
                        const meta = SCHOOL_LEVEL_META[currentSchoolLevel]
                        const selected = currentSchoolLevel === schoolLevel
                        return (
                          <button
                            key={currentSchoolLevel}
                            onClick={() => setSchoolLevel(currentSchoolLevel)}
                            className={`border-2 border-ink p-4 text-left transition-all duration-100 ${
                              selected ? 'bg-lemon shadow-brutal' : 'bg-white hover:-translate-y-0.5 hover:shadow-brutal-lg'
                            }`}
                          >
                            <p className="text-2xl">{meta.icon}</p>
                            <p className="mt-2 font-display text-base font-bold">{meta.label}</p>
                            <p className="mt-2 text-sm leading-6 text-muted">{meta.desc}</p>
                          </button>
                        )
                      })}
                    </div>
                  </div>

                  {ALL_PURPOSES.map((currentPurpose) => {
                    const meta = PURPOSE_META[currentPurpose]
                    const selected = currentPurpose === purpose
                    return (
                      <button
                        key={currentPurpose}
                        onClick={() => setPurpose(currentPurpose)}
                        className={`brutal-card p-6 text-left transition-all duration-100 ${
                          selected ? 'bg-spark text-cream shadow-brutal' : 'hover:-translate-y-0.5 hover:shadow-brutal-lg'
                        }`}
                      >
                        <div className="mb-4 text-4xl">{meta.icon}</div>
                        <div className="font-display text-lg font-bold">{meta.label}</div>
                        <p className={`mt-2 text-sm leading-6 ${selected ? 'text-cream/85' : 'text-muted'}`}>{meta.desc}</p>
                      </button>
                    )
                  })}
                  <button
                    className={`brutal-btn sm:col-span-2 py-4 text-base ${!schoolLevel ? 'cursor-not-allowed opacity-60' : ''}`}
                    onClick={() => schoolLevel && setStep('subject')}
                    disabled={!schoolLevel}
                  >
                    과목 선택으로 이동 →
                  </button>
                </div>

                <aside className="space-y-4">
                  <PanelCard title="추천 사용 시나리오" accent="spark">
                    <ul className="space-y-2 text-sm leading-6 text-muted">
                      <li>시험 대비: 기출 경향과 복습 루프까지 함께 구성</li>
                      <li>자격증: 기간 기반 플랜과 핵심 출제 포인트 강화</li>
                      <li>배경지식: 개념 구조와 맥락 위주의 학습 자료 생성</li>
                    </ul>
                  </PanelCard>
                  <PanelCard title="이번 세션 핵심" accent="teal">
                    <p className="text-sm leading-6 text-muted">
                      {schoolLevel ? `${SCHOOL_LEVEL_META[schoolLevel].label} 수준에 맞춰` : '학교급과 목적에 맞춰'} 결과물의 톤과 계획 전략이 함께 바뀝니다.
                    </p>
                  </PanelCard>
                </aside>
              </div>
            )}

            {step === 'subject' && (
              <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
                <div>
                  <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                    {ALL_SUBJECTS.map((currentSubject) => {
                      const meta = SUBJECT_META[currentSubject]
                      const selected = currentSubject === subject
                      return (
                        <button
                          key={currentSubject}
                          onClick={() => setSubject(currentSubject)}
                          className={`brutal-card flex flex-col items-center gap-2 py-5 text-sm font-display font-semibold transition-all duration-100 ${
                            selected ? 'bg-ink text-cream' : 'hover:-translate-y-0.5 hover:shadow-brutal-lg'
                          }`}
                        >
                          <span className="text-3xl">{meta.icon}</span>
                          <span className="text-center">{meta.label}</span>
                        </button>
                      )
                    })}
                  </div>

                  <div className="mt-6 flex gap-3">
                    <button
                      className="flex-1 border-2 border-ink bg-white py-4 font-display font-semibold shadow-brutal-sm transition-all hover:-translate-y-0.5 hover:shadow-brutal"
                      onClick={() => setStep('purpose')}
                    >
                      ← 이전
                    </button>
                    <button className="brutal-btn flex-1 py-4" onClick={() => setStep('input')}>
                      브리프 작성 →
                    </button>
                  </div>
                </div>

                <aside className="space-y-4">
                  <PanelCard title="선택된 조합" accent="spark">
                    <p className="text-sm text-muted">학교급</p>
                    <p className="font-display text-lg font-bold">
                      {schoolLevel ? `${SCHOOL_LEVEL_META[schoolLevel].icon} ${SCHOOL_LEVEL_META[schoolLevel].label}` : '선택 대기'}
                    </p>
                    <p className="mt-4 text-sm text-muted">목적</p>
                    <p className="font-display text-lg font-bold">{PURPOSE_META[purpose].label}</p>
                    <p className="mt-4 text-sm text-muted">과목</p>
                    <p className="font-display text-lg font-bold">
                      {SUBJECT_META[subject].icon} {SUBJECT_META[subject].label}
                    </p>
                  </PanelCard>
                  <PanelCard title="AI 출력물" accent="teal">
                    <ul className="space-y-2 text-sm leading-6 text-muted">
                      <li>주제에 맞춘 개념 설명과 요약</li>
                      <li>단원 구조를 한 번에 보는 내용 정리</li>
                      <li>추천 문제와 연습 방향 제안</li>
                      {isExam && <li>시험 일정 기반 학습 플랜 자동 설계</li>}
                    </ul>
                  </PanelCard>
                </aside>
              </div>
            )}

            {step === 'input' && (
              <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
                <div className="space-y-6">
                  <div className="brutal-card p-6 space-y-4">
                    <div className="flex flex-wrap items-center justify-between gap-3">
                        <h3 className="font-display text-lg font-bold">
                          {SUBJECT_META[subject].icon} {SUBJECT_META[subject].label} 정보
                        </h3>
                      <div className="flex flex-wrap gap-2">
                        <InfoPill>{PURPOSE_META[purpose].label}</InfoPill>
                        {schoolLevel && <InfoPill>{SCHOOL_LEVEL_META[schoolLevel].label}</InfoPill>}
                      </div>
                    </div>

                    {subject === 'korean' && (
                      <>
                        <Field
                          label="작가 및 작품 이름"
                          placeholder="예) 이상 - 날개 / 수필 한 편 / 고전 시가 작품명"
                          value={koreanName}
                          onChange={setKoreanName}
                        />
                        <TextAreaField
                          label="다루고 싶은 개념"
                          placeholder="예) 반어법, 서술자 시점, 의식의 흐름"
                          value={koreanConcepts}
                          onChange={setKoreanConcepts}
                          hint="쉼표로 구분하면 AI가 개념 설명과 작품 해설에 반영합니다."
                        />
                      </>
                    )}

                    {subject === 'english' && (
                      <>
                        <div className="flex gap-2">
                          {(['mock_exam', 'textbook'] as const).map((type) => (
                            <button
                              key={type}
                              onClick={() => setEngType(type)}
                              className={`border-2 border-ink px-4 py-2 font-display text-sm font-semibold ${
                                engType === type ? 'bg-ink text-cream' : 'bg-white'
                              }`}
                            >
                              {type === 'mock_exam' ? '모의고사' : '교과서'}
                            </button>
                          ))}
                        </div>

                        {engType === 'mock_exam' ? (
                          <>
                            <NumRow
                              grade={grade}
                              onGrade={setGrade}
                              year={mockYear}
                              onYear={setMockYear}
                              month={mockMonth}
                              onMonth={setMockMonth}
                            />
                            <TextAreaField
                              label="지문 번호"
                              placeholder="예) 18, 20, 23"
                              value={mockNums}
                              onChange={setMockNums}
                              hint="여러 번호를 쉼표로 입력하면 필요한 지문만 집중 분석합니다."
                            />
                          </>
                        ) : (
                          <>
                            <Row2>
                              <Field label="출판사" placeholder="예) 능률 / YBM" value={publisher} onChange={setPublisher} />
                              <Field label="저자" placeholder="예) 김성곤" value={author} onChange={setAuthor} />
                            </Row2>
                            <Row2>
                              <NumField label="학년" value={grade} onChange={setGrade} min={1} max={6} />
                              <NumField label="학기" value={semester} onChange={setSemester} min={1} max={2} />
                            </Row2>
                            <Field label="단원" placeholder="예) Unit 3. Reading Skills" value={chapter} onChange={setChapter} />
                            <Field label="세부 범위" placeholder="예) 본문 / 대화문 / 어휘 정리" value={section} onChange={setSection} />
                          </>
                        )}
                      </>
                    )}

                    {TEXTBOOK_SUBJECTS.includes(subject) && (
                      <>
                        <Row2>
                          <Field label="출판사" placeholder="예) 미래엔" value={publisher} onChange={setPublisher} />
                          <Field label="저자" placeholder="예) 홍길동" value={author} onChange={setAuthor} />
                        </Row2>
                        <Row2>
                          <NumField label="학년" value={grade} onChange={setGrade} min={1} max={6} />
                          <NumField label="학기" value={semester} onChange={setSemester} min={1} max={2} />
                        </Row2>
                        <Field label="단원" placeholder="예) 3단원. 생태계와 환경" value={chapter} onChange={setChapter} />
                      </>
                    )}

                    {CS_SUBJECTS.includes(subject) && (
                      <>
                        <Row2>
                          <Field label="출판사" placeholder="예) 와이비엠" value={publisher} onChange={setPublisher} />
                          <Field label="저자" placeholder="예) 이영준" value={author} onChange={setAuthor} />
                        </Row2>
                        <Row2>
                          <NumField label="학년" value={grade} onChange={setGrade} min={1} max={6} />
                          <NumField label="학기" value={semester} onChange={setSemester} min={1} max={2} />
                        </Row2>
                        <Field label="단원" placeholder="예) 3. 알고리즘과 프로그래밍" value={chapter} onChange={setChapter} />
                      </>
                    )}

                    {subject === 'other' && (
                      <TextAreaField
                        label="학습 내용"
                        placeholder="예) 독서 토론 준비, 논술 자료 정리, 프레젠테이션 주제 조사"
                        value={otherDesc}
                        onChange={setOtherDesc}
                        hint="범위, 목적, 원하는 산출물을 함께 적으면 결과가 좋아집니다."
                      />
                    )}
                  </div>

                  {isExam && (
                    <div className="brutal-card p-6 space-y-4">
                      <div className="flex items-center justify-between gap-3">
                        <h3 className="font-display text-lg font-bold">시험 대비 보강 정보</h3>
                        <span className="border-2 border-ink bg-lemon px-3 py-1 font-display text-xs font-bold">
                          {daysLeft}일 남음
                        </span>
                      </div>

                      <label className="flex cursor-pointer items-center gap-3">
                        <input
                          type="checkbox"
                          className="h-5 w-5 accent-spark"
                          checked={hasPastExam}
                          onChange={(event) => setHasPastExam(event.target.checked)}
                        />
                        <span className="font-display font-semibold">기출 문제를 함께 분석할게요</span>
                      </label>

                      {hasPastExam && (
                        <TextAreaField
                          label="기출 또는 오답 메모"
                          placeholder="문항, 자주 틀리는 포인트, 출제 패턴을 붙여넣어 주세요."
                          value={pastExam}
                          onChange={setPastExam}
                        />
                      )}

                      <div className="space-y-4 rounded-sm border-2 border-ink bg-spark-dim p-4">
                        <div className="flex items-center gap-4">
                          <label className="font-display text-sm font-semibold text-muted">남은 기간</label>
                          <input
                            type="range"
                            min={1}
                            max={365}
                            value={daysLeft}
                            onChange={(event) => setDaysLeft(Number(event.target.value))}
                            className="flex-1 accent-spark"
                          />
                          <span className="w-16 text-right font-display font-bold text-spark">{daysLeft}일</span>
                        </div>

                        <div className="space-y-3">
                          <div className="flex flex-wrap gap-2">
                            {SCHEDULE_PRESETS.map((preset) => (
                              <button
                                key={preset.key}
                                className="border-2 border-ink bg-white px-3 py-2 font-display text-xs font-semibold hover:bg-ink hover:text-cream"
                                onClick={() => applySchedulePreset(preset.hours)}
                              >
                                {preset.label}
                              </button>
                            ))}
                          </div>
                          <div className="space-y-2">
                            <p className="font-display text-sm font-semibold text-muted">
                              요일별 공부 시간 · 주간 총 {totalWeeklyHours.toFixed(1)}시간
                            </p>
                            {DAYS.map((day) => (
                              <div key={day} className="flex items-center gap-3">
                                <span className="w-6 font-display text-sm font-bold">{day}</span>
                                <input
                                  type="range"
                                  min={0}
                                  max={8}
                                  step={0.5}
                                  value={hours[day] ?? 0}
                                  onChange={(event) =>
                                    setHours((current) => ({ ...current, [day]: Number(event.target.value) }))
                                  }
                                  className="flex-1 accent-teal"
                                />
                                <span className="w-14 text-right font-display text-sm font-bold text-teal">
                                  {(hours[day] ?? 0).toFixed(1)}h
                                </span>
                              </div>
                            ))}
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {error && <p className="border-2 border-red-500 bg-red-50 p-3 text-sm text-red-700 whitespace-pre-line">{error}</p>}

                  <div className="flex gap-3">
                    <button
                      className="flex-1 border-2 border-ink bg-white py-4 font-display font-semibold shadow-brutal-sm transition-all hover:-translate-y-0.5 hover:shadow-brutal"
                      onClick={() => setStep('subject')}
                    >
                      ← 이전
                    </button>
                    <button
                      className={`brutal-btn flex-1 py-4 ${!isReadyToSubmit ? 'cursor-not-allowed opacity-60' : ''}`}
                      onClick={handleSubmit}
                      disabled={!isReadyToSubmit}
                    >
                      AI 학습 자료 생성 ✦
                    </button>
                  </div>
                </div>

                <aside className="space-y-4">
                  <PanelCard title="브리프 체크리스트" accent={isReadyToSubmit ? 'teal' : 'spark'}>
                    {isReadyToSubmit ? (
                      <div className="space-y-2 text-sm leading-6">
                        <p className="font-display font-semibold text-teal">제출 준비 완료</p>
                        <p className="text-muted">현재 입력이면 AI가 자료 생성에 필요한 정보를 충분히 받습니다.</p>
                      </div>
                    ) : (
                      <ul className="space-y-2 text-sm leading-6 text-muted">
                        {validationErrors.map((issue) => (
                          <li key={issue}>• {issue}</li>
                        ))}
                      </ul>
                    )}
                  </PanelCard>

                  <PanelCard title="AI가 만들어줄 결과물" accent="teal">
                    <ul className="space-y-2 text-sm leading-6 text-muted">
                      <li>핵심 개념 설명과 이해 포인트</li>
                      <li>복습하기 쉬운 요약 정리</li>
                      <li>추천 문제와 자료 탐색 방향</li>
                      {isExam ? <li>남은 기간 기반의 실전 학습 계획표</li> : <li>주제 구조를 보는 마인드맵</li>}
                    </ul>
                  </PanelCard>

                  <PanelCard title="추천 입력 방식" accent="spark">
                    <p className="text-sm leading-6 text-muted">
                      교과서명, 단원명, 기출 범위처럼 실제 공부 맥락을 적을수록 검색 결과가 더 정확해집니다.
                    </p>
                  </PanelCard>
                </aside>
              </div>
            )}

            {step === 'loading' && (
              <div className="flex flex-col items-center gap-8 py-16">
                <div className="brutal-card w-full max-w-xl p-8 text-center">
                  <div className="mb-6 flex justify-center gap-2">
                    {[0, 1, 2].map((index) => (
                      <motion.div
                        key={index}
                        className="h-4 w-4 border-2 border-ink bg-spark"
                        animate={{ y: [0, -12, 0] }}
                        transition={{ duration: 0.6, repeat: Infinity, delay: index * 0.15 }}
                      />
                    ))}
                  </div>
                  <p className="font-display text-lg font-bold">Gemini가 학교급에 맞춰 검색과 정리를 동시에 진행하고 있습니다.</p>
                  <p className="mt-3 text-sm leading-6 text-muted">
                    검색 근거를 바탕으로 개념 설명, 요약, 추천 문제, 마인드맵용 구조를 순서대로 생성합니다.
                  </p>
                </div>

                <div className="grid w-full max-w-xl gap-3 md:grid-cols-3">
                  {[
                    { title: '웹 검색', desc: '최신 자료와 설명 맥락 수집' },
                    { title: 'AI 분석', desc: '입력 조건에 맞는 핵심 정보 선별' },
                    { title: '자료 정리', desc: '학습에 바로 쓰는 형태로 변환' },
                  ].map((item) => (
                    <div key={item.title} className="border-2 border-ink bg-white p-4 text-center shadow-brutal-sm">
                      <p className="font-display text-sm font-bold">{item.title}</p>
                      <p className="mt-2 text-xs leading-5 text-muted">{item.desc}</p>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </motion.div>
        </AnimatePresence>
      </div>
    </main>
  )
}

function getValidationErrors(input: {
  purpose: StudyPurpose
  schoolLevel: StudySchoolLevel | null
  subject: Subject
  koreanName: string
  koreanConcepts: string
  publisher: string
  author: string
  chapter: string
  section: string
  otherDesc: string
  hasPastExam: boolean
  pastExam: string
  daysLeft: number
  hours: Record<string, number>
  engType: 'mock_exam' | 'textbook'
  mockNums: string
}) {
  const issues: string[] = []

  if (!input.schoolLevel) {
    issues.push('초등/중등/고등 중 현재 학교급을 선택해주세요.')
  }

  if (input.subject === 'korean') {
    if (!input.koreanName.trim()) issues.push('국어 작품 또는 지문 이름을 입력해주세요.')
    if (!input.koreanConcepts.trim()) issues.push('국어에서 다루고 싶은 개념을 한 가지 이상 적어주세요.')
  }

  if (input.subject === 'english') {
    if (input.engType === 'mock_exam' && !input.mockNums.trim()) {
      issues.push('영어 모의고사 지문 번호를 입력해주세요.')
    }
    if (input.engType === 'textbook') {
      if (!input.publisher.trim() || !input.author.trim()) issues.push('영어 교과서의 출판사와 저자를 입력해주세요.')
      if (!input.chapter.trim()) issues.push('영어 교과서 단원을 입력해주세요.')
      if (!input.section.trim()) issues.push('영어 교과서 세부 범위를 입력해주세요.')
    }
  }

  if (TEXTBOOK_SUBJECTS.includes(input.subject)) {
    if (!input.publisher.trim() || !input.author.trim()) issues.push('교과서 과목은 출판사와 저자가 필요합니다.')
    if (!input.chapter.trim()) issues.push('단원을 입력해주세요.')
  }

  if (CS_SUBJECTS.includes(input.subject)) {
    if (!input.publisher.trim() || !input.author.trim()) issues.push('정보과학 과목은 출판사와 저자가 필요합니다.')
    if (!input.chapter.trim()) issues.push('학습할 단원을 입력해주세요.')
  }

  if (input.subject === 'other' && !input.otherDesc.trim()) {
    issues.push('학습 내용을 자유롭게 설명해주세요.')
  }

  if ((input.purpose === 'exam_prep' || input.purpose === 'certification') && input.daysLeft < 1) {
    issues.push('남은 기간은 1일 이상이어야 합니다.')
  }

  if ((input.purpose === 'exam_prep' || input.purpose === 'certification') && !Object.values(input.hours).some((value) => value > 0)) {
    issues.push('최소 하루 이상의 공부 시간을 설정해주세요.')
  }

  if (input.hasPastExam && !input.pastExam.trim()) {
    issues.push('기출 분석을 선택했다면 내용도 함께 입력해주세요.')
  }

  return issues
}

function buildStudyBrief(input: {
  purpose: StudyPurpose
  schoolLevel: StudySchoolLevel | null
  subject: Subject
  koreanName: string
  koreanConcepts: string
  publisher: string
  author: string
  grade: number
  semester: number
  chapter: string
  section: string
  otherDesc: string
  engType: 'mock_exam' | 'textbook'
  mockYear: number
  mockMonth: number
  mockNums: string
  daysLeft: number
  totalWeeklyHours: number
}) {
  const subjectMeta = SUBJECT_META[input.subject]
  const purposeMeta = PURPOSE_META[input.purpose]
  const schoolLevelMeta = input.schoolLevel ? SCHOOL_LEVEL_META[input.schoolLevel] : null

  let topic = '과목과 범위를 선택하면 여기에서 요약됩니다.'
  if (input.subject === 'korean' && input.koreanName.trim()) {
    topic = `${input.koreanName.trim()} · ${input.koreanConcepts.trim() || '핵심 개념 정리'}`
  } else if (input.subject === 'english') {
    topic =
      input.engType === 'mock_exam'
        ? `${input.mockYear}년 ${input.mockMonth}월 모의고사 · ${input.mockNums.trim() || '지문 번호 대기'}`
        : `${input.publisher.trim() || '출판사'} ${input.author.trim() || '저자'} · ${input.chapter.trim() || '단원'} ${input.section.trim() || ''}`.trim()
  } else if (input.subject === 'other') {
    topic = input.otherDesc.trim() || topic
  } else if (input.chapter.trim()) {
    topic = `${input.publisher.trim() || '교과서'} ${input.author.trim() || ''} · ${input.grade}학년 ${input.semester}학기 ${input.chapter.trim()}`.trim()
  }

  return [
    { label: '학교급', value: schoolLevelMeta ? `${schoolLevelMeta.icon} ${schoolLevelMeta.label}` : '학교급 선택 필요' },
    { label: '목적', value: `${purposeMeta.icon} ${purposeMeta.label}` },
    { label: '과목', value: `${subjectMeta.icon} ${subjectMeta.label}` },
    { label: '브리프', value: topic },
    {
      label: '리듬',
      value:
        input.purpose === 'exam_prep' || input.purpose === 'certification'
          ? `${input.daysLeft}일 안에 주 ${input.totalWeeklyHours.toFixed(1)}시간 학습`
          : '설명 자료와 구조 정리에 집중',
    },
  ]
}

function PanelCard({
  accent,
  title,
  children,
}: {
  accent: 'spark' | 'teal'
  title: string
  children: ReactNode
}) {
  return (
    <div className={`border-2 border-ink p-5 shadow-brutal-sm ${accent === 'spark' ? 'bg-spark-dim' : 'bg-teal-dim'}`}>
      <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">{title}</p>
      <div className="mt-3">{children}</div>
    </div>
  )
}

function Field({
  label,
  placeholder,
  value,
  onChange,
}: {
  label: string
  placeholder: string
  value: string
  onChange: (value: string) => void
}) {
  return (
    <div className="space-y-1">
      <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">{label}</label>
      <input className="brutal-input" placeholder={placeholder} value={value} onChange={(event) => onChange(event.target.value)} />
    </div>
  )
}

function TextAreaField({
  label,
  placeholder,
  value,
  onChange,
  hint,
}: {
  label: string
  placeholder: string
  value: string
  onChange: (value: string) => void
  hint?: string
}) {
  return (
    <div className="space-y-1">
      <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">{label}</label>
      <textarea
        rows={4}
        className="brutal-input resize-none"
        placeholder={placeholder}
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
      {hint && <p className="text-xs leading-5 text-muted">{hint}</p>}
    </div>
  )
}

function NumField({
  label,
  value,
  onChange,
  min,
  max,
}: {
  label: string
  value: number
  onChange: (value: number) => void
  min: number
  max: number
}) {
  return (
    <div className="space-y-1">
      <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">{label}</label>
      <div className="flex items-center border-2 border-ink bg-white">
        <button
          className="px-4 py-3 font-bold transition-colors hover:bg-ink hover:text-cream"
          onClick={() => onChange(Math.max(min, value - 1))}
        >
          -
        </button>
        <span className="flex-1 text-center font-display font-bold">{value}</span>
        <button
          className="px-4 py-3 font-bold transition-colors hover:bg-ink hover:text-cream"
          onClick={() => onChange(Math.min(max, value + 1))}
        >
          +
        </button>
      </div>
    </div>
  )
}

function Row2({ children }: { children: ReactNode }) {
  return <div className="grid gap-3 sm:grid-cols-2">{children}</div>
}

function NumRow({
  grade,
  onGrade,
  year,
  onYear,
  month,
  onMonth,
}: {
  grade: number
  onGrade: (value: number) => void
  year: number
  onYear: (value: number) => void
  month: number
  onMonth: (value: number) => void
}) {
  return (
    <div className="grid grid-cols-3 gap-3">
      <NumField label="학년" value={grade} onChange={onGrade} min={1} max={6} />
      <NumField label="년도" value={year} onChange={onYear} min={2010} max={2035} />
      <NumField label="월" value={month} onChange={onMonth} min={1} max={12} />
    </div>
  )
}

function InfoPill({ children }: { children: ReactNode }) {
  return <span className="border-2 border-ink bg-white px-3 py-1 font-display text-xs font-semibold">{children}</span>
}
