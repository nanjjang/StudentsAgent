'use client'

import { motion } from 'framer-motion'
import { useParams } from 'next/navigation'
import { useEffect, useState } from 'react'
import type { ReactNode } from 'react'

import { api } from '@/lib/api'
import { PURPOSE_META, SCHOOL_LEVEL_META, SUBJECT_META } from '@/lib/types'
import type { StudyPlan, StudySession } from '@/lib/types'

type Tab = 'content' | 'plan' | 'mindmap' | 'notifications'
type ContentTab = 'concept' | 'summary' | 'outline' | 'start' | 'selfcheck' | 'problems' | 'direction'

const DAYS = ['월', '화', '수', '목', '금', '토', '일'] as const

export default function SessionPage() {
  const { id } = useParams<{ id: string }>()
  const [session, setSession] = useState<StudySession | null>(null)
  const [tab, setTab] = useState<Tab>('content')
  const [contentTab, setContentTab] = useState<ContentTab>('concept')
  const [plan, setPlan] = useState<StudyPlan | null>(null)
  const [mindmap, setMindmap] = useState('')
  const [examText, setExamText] = useState('')
  const [notifMsg, setNotifMsg] = useState('오늘의 학습을 시작해볼까요? 핵심 개념부터 25분만 집중해보세요.')
  const [notifTime, setNotifTime] = useState('19:00')
  const [notifDays, setNotifDays] = useState<string[]>(['월', '화', '수', '목', '금'])
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
  const [loading, setLoading] = useState('')
  const [error, setError] = useState('')
  const [notifSent, setNotifSent] = useState(false)
  const [copiedLabel, setCopiedLabel] = useState('')

  useEffect(() => {
    let cancelled = false

    api
      .getSession(id)
      .then((result) => {
        if (cancelled) return
        setSession(result)
        setPlan(result.plan ?? null)
      })
      .catch((loadError) => {
        if (cancelled) return
        setError(loadError instanceof Error ? loadError.message : '세션을 불러오지 못했습니다.')
      })

    return () => {
      cancelled = true
    }
  }, [id])

  async function loadPlan(force = false) {
    if (plan && !force) {
      setTab('plan')
      return
    }

    setLoading('학습 계획표를 다시 설계하고 있습니다...')
    setError('')
    try {
      const nextPlan = await api.generatePlan(id, daysLeft, hours)
      setPlan(nextPlan)
      setTab('plan')
    } catch (planError) {
      setError(planError instanceof Error ? planError.message : '계획표 생성에 실패했습니다.')
    } finally {
      setLoading('')
    }
  }

  async function loadMindMap(force = false) {
    if (mindmap && !force) {
      setTab('mindmap')
      return
    }

    setLoading('마인드맵을 생성하고 있습니다...')
    setError('')
    try {
      const result = await api.getMindMap(id)
      setMindmap(result.mindmap)
      setTab('mindmap')
    } catch (mapError) {
      setError(mapError instanceof Error ? mapError.message : '마인드맵 생성에 실패했습니다.')
    } finally {
      setLoading('')
    }
  }

  async function analyzeExam() {
    if (!examText.trim()) {
      setError('분석할 기출 문제나 오답 메모를 입력해주세요.')
      return
    }

    setLoading('기출 경향을 분석하고 있습니다...')
    setError('')
    try {
      const result = await api.analyzeExam(id, examText.trim())
      setSession((current) =>
        current?.content
          ? {
              ...current,
              content: { ...current.content, study_direction: result.analysis },
            }
          : current
      )
      setContentTab('direction')
      setTab('content')
    } catch (analysisError) {
      setError(analysisError instanceof Error ? analysisError.message : '기출 분석에 실패했습니다.')
    } finally {
      setLoading('')
    }
  }

  async function saveNotif() {
    if (!notifMsg.trim()) {
      setError('알림 메시지를 입력해주세요.')
      return
    }
    if (notifDays.length === 0) {
      setError('알림을 받을 요일을 하나 이상 선택해주세요.')
      return
    }

    setError('')
    try {
      await api.setNotification(id, notifMsg.trim(), notifTime, notifDays)
      setNotifSent(true)
    } catch (notificationError) {
      setError(notificationError instanceof Error ? notificationError.message : '알림 저장에 실패했습니다.')
    }
  }

  async function copyToClipboard(label: string, value: string) {
    if (!value) return
    try {
      await navigator.clipboard.writeText(value)
      setCopiedLabel(label)
      window.setTimeout(() => setCopiedLabel(''), 1600)
    } catch {
      setError('클립보드 복사에 실패했습니다.')
    }
  }

  if (!session) {
    return <LoadingScreen message={error || '세션을 불러오는 중입니다...'} hasError={Boolean(error)} />
  }

  const content = session.content
  const subject = SUBJECT_META[session.subject]
  const schoolLevel = SCHOOL_LEVEL_META[session.school_level]
  const purpose = PURPOSE_META[session.purpose]
  const totalWeeklyHours = Object.values(hours).reduce((sum, value) => sum + value, 0)
  const contentTabs: { key: ContentTab; label: string; value: string }[] = [
    { key: 'concept', label: '개념 설명', value: content?.concept_explanation ?? '' },
    { key: 'summary', label: '핵심 요약', value: content?.concept_summary ?? '' },
    { key: 'outline', label: '내용 정리', value: content?.content_outline ?? '' },
    { key: 'start', label: '오늘의 공부 시작', value: content?.study_start_guide ?? '' },
    { key: 'selfcheck', label: '셀프 체크', value: content?.self_check_quiz ?? '' },
    { key: 'problems', label: '추천 문제', value: content?.recommended_problems ?? '' },
    ...(content?.study_direction ? [{ key: 'direction' as const, label: '학습 방향', value: content.study_direction }] : []),
  ]
  const activeContent = contentTabs.find((item) => item.key === contentTab)
  const completedModules = [
    Boolean(content?.concept_explanation),
    Boolean(content?.concept_summary),
    Boolean(content?.content_outline),
    Boolean(plan),
    Boolean(mindmap),
    notifSent || session.notifications_enabled,
  ].filter(Boolean).length

  return (
    <main className="min-h-screen bg-cream font-body">
      <div className="sticky top-0 z-40 border-b-2 border-ink bg-cream/95 backdrop-blur-sm">
        <div className="mx-auto flex max-w-7xl items-center justify-between gap-4 px-6 py-4">
          <a href="/" className="font-display font-bold">
            Study<span className="text-spark">Agents</span>
          </a>
          <div className="flex flex-wrap items-center gap-2">
            <span className="border-2 border-ink bg-lemon px-3 py-1 font-display text-sm font-semibold">
              {schoolLevel.icon} {schoolLevel.label}
            </span>
            <span className="border-2 border-ink bg-white px-3 py-1 font-display text-sm font-semibold">
              {subject.icon} {subject.label}
            </span>
            <span
              className={`border-2 border-ink px-3 py-1 font-display text-sm font-semibold ${
                session.purpose === 'exam_prep' ? 'bg-spark text-cream' : 'bg-teal text-cream'
              }`}
            >
              {purpose.label}
            </span>
          </div>
        </div>

        <div className="flex border-t-2 border-ink">
          {(['content', 'plan', 'mindmap', 'notifications'] as const).map((currentTab) => (
            <button
              key={currentTab}
              onClick={() => {
                setTab(currentTab)
                if (currentTab === 'plan') void loadPlan()
                if (currentTab === 'mindmap') void loadMindMap()
              }}
              className={`flex-1 border-r-2 border-ink py-3 font-display text-sm font-semibold transition-colors last:border-r-0 ${
                tab === currentTab ? 'bg-ink text-cream' : 'hover:bg-ink/5'
              }`}
            >
              {{
                content: '학습자료',
                plan: '계획표',
                mindmap: '마인드맵',
                notifications: '알림',
              }[currentTab]}
            </button>
          ))}
        </div>
      </div>

      <section className="border-b-2 border-ink bg-spark-dim px-6 py-8">
        <div className="mx-auto grid max-w-7xl gap-6 lg:grid-cols-[1.2fr_0.8fr]">
          <div>
            <p className="font-display text-xs uppercase tracking-[0.2em] text-muted">Study cockpit</p>
            <h1 className="mt-2 font-display text-[clamp(1.8rem,4vw,3.4rem)] font-bold leading-tight">
              {session.topic_description}
            </h1>
            <p className="mt-4 max-w-3xl text-sm leading-7 text-muted">
              생성된 자료를 탐색하면서 계획표, 마인드맵, 알림까지 같은 세션 안에서 연결해보세요.
              이제 학교급에 맞춘 공부 시작 가이드와 셀프 체크까지 함께 제공합니다.
            </p>
          </div>

          <div className="grid gap-3 sm:grid-cols-3">
            <MetricCard label="완성된 모듈" value={`${completedModules}/6`} tone="spark" />
            <MetricCard label="콘텐츠 섹션" value={`${contentTabs.length}개`} tone="teal" />
            <MetricCard label="주간 학습량" value={`${totalWeeklyHours.toFixed(1)}h`} tone="ink" />
          </div>
        </div>
      </section>

      {loading && <LoadingBanner message={loading} />}
      {error && <div className="border-b-2 border-red-400 bg-red-50 px-6 py-3 text-sm text-red-700">{error}</div>}

      <div className="mx-auto max-w-7xl px-6 py-8">
        {tab === 'content' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="grid gap-6 lg:grid-cols-[1fr_320px]">
            <div className="space-y-4">
              <div className="flex flex-wrap gap-2">
                {contentTabs.map((item) => (
                  <button
                    key={item.key}
                    onClick={() => setContentTab(item.key)}
                    className={`border-2 border-ink px-4 py-2 font-display text-sm font-semibold transition-all ${
                      contentTab === item.key ? 'bg-ink text-cream shadow-brutal-sm' : 'bg-white hover:shadow-brutal-sm'
                    }`}
                  >
                    {item.label}
                  </button>
                ))}
              </div>

              <div className="brutal-card min-h-[420px] p-6">
                <div className="mb-5 flex flex-wrap items-center justify-between gap-3 border-b-2 border-ink/10 pb-4">
                  <div>
                    <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">Focused section</p>
                    <h2 className="mt-1 font-display text-xl font-bold">{activeContent?.label}</h2>
                  </div>
                  <button
                    className="border-2 border-ink bg-white px-4 py-2 font-display text-xs font-semibold shadow-brutal-sm hover:bg-ink hover:text-cream"
                    onClick={() => void copyToClipboard(activeContent?.label ?? '내용', activeContent?.value ?? '')}
                  >
                    {copiedLabel === activeContent?.label ? '복사 완료' : '현재 섹션 복사'}
                  </button>
                </div>

                {activeContent?.value ? (
                  <div className="content-prose whitespace-pre-wrap leading-7 text-[15px]">{activeContent.value}</div>
                ) : (
                  <p className="text-muted">이 섹션은 아직 생성된 내용이 없습니다.</p>
                )}
              </div>
            </div>

            <aside className="space-y-4">
              <SideCard title="다음 액션">
                <div className="space-y-2">
                  <button className="brutal-btn w-full py-3 text-sm" onClick={() => void loadPlan()}>
                    계획표 생성 →
                  </button>
                  <button className="brutal-btn w-full bg-teal border-teal py-3 text-sm" onClick={() => void loadMindMap()}>
                    마인드맵 생성 →
                  </button>
                </div>
              </SideCard>

              <SideCard title="기출 분석">
                <textarea
                  rows={5}
                  className="brutal-input resize-none text-sm"
                  placeholder="기출 문제, 오답 메모, 헷갈렸던 포인트를 붙여넣어 주세요."
                  value={examText}
                  onChange={(event) => setExamText(event.target.value)}
                />
                <button className="brutal-btn mt-3 w-full py-2 text-sm" onClick={() => void analyzeExam()}>
                  분석해서 학습 방향에 반영 →
                </button>
              </SideCard>

              <SideCard title="세션 상태">
                <div className="space-y-2 text-sm leading-6 text-muted">
                  <p>개념 설명: {content?.concept_explanation ? '준비됨' : '대기 중'}</p>
                  <p>개념 요약: {content?.concept_summary ? '준비됨' : '대기 중'}</p>
                  <p>계획표: {plan ? '생성 완료' : '아직 없음'}</p>
                  <p>알림: {notifSent || session.notifications_enabled ? '설정됨' : '미설정'}</p>
                </div>
              </SideCard>
            </aside>
          </motion.div>
        )}

        {tab === 'plan' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="space-y-6">
            <div className="grid gap-4 rounded-sm border-2 border-ink bg-white p-5 shadow-brutal lg:grid-cols-[1fr_1fr_180px]">
              <div className="space-y-2">
                <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">남은 기간</label>
                <div className="flex items-center gap-4">
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
              </div>

              <div className="space-y-2">
                <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">
                  요일별 공부 시간
                </label>
                <div className="flex flex-wrap gap-2">
                  {DAYS.map((day) => (
                    <div key={day} className="flex items-center gap-1">
                      <span className="font-display text-xs font-bold">{day}</span>
                      <input
                        type="number"
                        min={0}
                        max={8}
                        step={0.5}
                        value={hours[day]}
                        onChange={(event) =>
                          setHours((current) => ({
                            ...current,
                            [day]: Number(event.target.value) || 0,
                          }))
                        }
                        className="w-14 border-2 border-ink p-1 text-center text-sm font-display"
                      />
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex items-end">
                <button className="brutal-btn w-full py-3" onClick={() => void loadPlan(true)}>
                  다시 생성 ↺
                </button>
              </div>
            </div>

            {plan ? (
              <div className="space-y-3">
                {plan.plan_items.map((item, index) => (
                  <details key={`${item.date}-${index}`} className="brutal-card group">
                    <summary className="flex cursor-pointer items-center gap-4 p-4 list-none">
                      <span className="border-2 border-ink bg-spark px-2 py-0.5 font-display text-xs font-bold text-cream">
                        {item.day_of_week}
                      </span>
                      <span className="text-sm text-muted">{item.date}</span>
                      <span className="flex-1 font-display text-sm font-semibold">{item.topics.join(' · ')}</span>
                      <span className="font-display font-bold text-teal">{item.study_hours}h</span>
                      <span className="text-muted transition-transform group-open:rotate-180">▾</span>
                    </summary>
                    <div className="space-y-1 border-t-2 border-ink/10 px-4 pb-4 pt-3">
                      {item.tasks.map((task, taskIndex) => (
                        <div key={`${item.date}-${taskIndex}`} className="flex gap-2 text-sm">
                          <span className="font-bold text-spark">▸</span>
                          <span>{task}</span>
                        </div>
                      ))}
                    </div>
                  </details>
                ))}
              </div>
            ) : (
              <div className="brutal-card p-8 text-center text-muted">계획표를 생성하면 일자별 학습 루틴이 여기에 표시됩니다.</div>
            )}
          </motion.div>
        )}

        {tab === 'mindmap' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
            {mindmap ? (
              <div className="brutal-card max-h-[75vh] overflow-auto p-6">
                <MindMapRenderer text={mindmap} />
              </div>
            ) : (
              <div className="brutal-card p-8 text-center text-muted">마인드맵을 생성하면 개념 구조가 계층적으로 표시됩니다.</div>
            )}
          </motion.div>
        )}

        {tab === 'notifications' && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="grid gap-6 lg:grid-cols-[1fr_320px]">
            <div className="brutal-card space-y-5 p-6">
              <div>
                <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">Reminder setup</p>
                <h2 className="mt-2 font-display text-xl font-bold">학습 리듬 알림</h2>
              </div>

              <div className="space-y-1">
                <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">알림 메시지</label>
                <textarea
                  rows={3}
                  className="brutal-input resize-none"
                  value={notifMsg}
                  onChange={(event) => setNotifMsg(event.target.value)}
                />
              </div>

              <div className="space-y-1">
                <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">알림 시간</label>
                <input
                  type="time"
                  className="brutal-input"
                  value={notifTime}
                  onChange={(event) => setNotifTime(event.target.value)}
                />
              </div>

              <div className="space-y-2">
                <label className="font-display text-xs font-semibold uppercase tracking-wider text-muted">알림 요일</label>
                <div className="flex flex-wrap gap-2">
                  {DAYS.map((day) => {
                    const enabled = notifDays.includes(day)
                    return (
                      <button
                        key={day}
                        onClick={() =>
                          setNotifDays((current) => (enabled ? current.filter((item) => item !== day) : [...current, day]))
                        }
                        className={`h-10 w-10 border-2 border-ink font-display text-sm font-bold ${
                          enabled ? 'bg-spark text-cream shadow-brutal-sm' : 'bg-white'
                        }`}
                      >
                        {day}
                      </button>
                    )
                  })}
                </div>
              </div>

              {notifSent ? (
                <div className="border-2 border-teal bg-teal-dim p-3 text-center font-display font-bold text-teal">
                  ✓ 알림이 저장되었습니다.
                </div>
              ) : (
                <button className="brutal-btn w-full py-4" onClick={() => void saveNotif()}>
                  알림 저장 →
                </button>
              )}
            </div>

            <aside className="space-y-4">
              <SideCard title="미리보기">
                <div className="space-y-2 rounded-sm border-2 border-ink bg-white p-4 shadow-brutal-sm">
                  <p className="font-display text-xs uppercase tracking-[0.16em] text-muted">StudyAgents</p>
                  <p className="font-display font-semibold">{notifTime} · {notifDays.join(', ')}</p>
                  <p className="text-sm leading-6 text-muted">{notifMsg || '알림 메시지를 입력하면 미리보기가 표시됩니다.'}</p>
                </div>
              </SideCard>

              <SideCard title="설정 팁">
                <ul className="space-y-2 text-sm leading-6 text-muted">
                  <li>짧고 구체적인 문장일수록 행동 전환이 쉽습니다.</li>
                  <li>복습용이면 평일 저녁, 예습용이면 아침 시간이 잘 맞습니다.</li>
                  <li>시험 직전에는 주말 알림도 함께 켜두는 편이 좋습니다.</li>
                </ul>
              </SideCard>
            </aside>
          </motion.div>
        )}
      </div>
    </main>
  )
}

function MetricCard({ label, value, tone }: { label: string; value: string; tone: 'spark' | 'teal' | 'ink' }) {
  return (
    <div className={`border-2 border-ink p-4 shadow-brutal-sm ${tone === 'spark' ? 'bg-white' : tone === 'teal' ? 'bg-teal-dim' : 'bg-lemon'}`}>
      <p className="font-display text-[11px] uppercase tracking-[0.18em] text-muted">{label}</p>
      <p className="mt-2 font-display text-2xl font-bold">{value}</p>
    </div>
  )
}

function SideCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="border-2 border-ink bg-white p-5 shadow-brutal-sm">
      <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">{title}</p>
      <div className="mt-3">{children}</div>
    </div>
  )
}

function MindMapRenderer({ text }: { text: string }) {
  return (
    <div className="space-y-1">
      {text.split('\n').map((line, index) => {
        const isH1 = /^# /.test(line)
        const isH2 = /^## /.test(line)
        const isH3 = /^### /.test(line)
        const isBullet = /^\s*- /.test(line)
        const indent = (line.match(/^ +/)?.[0].length ?? 0) * 4
        const clean = line.replace(/^#{1,6} /, '').replace(/^\s*- /, '')

        if (!clean.trim()) return <div key={index} className="h-3" />
        if (isH1) {
          return (
            <h2 key={index} className="mt-4 border-b-2 border-spark pb-1 font-display text-2xl font-bold text-ink">
              {clean}
            </h2>
          )
        }
        if (isH2) return <h3 key={index} className="mt-3 font-display text-lg font-bold text-spark">{clean}</h3>
        if (isH3) return <h4 key={index} className="mt-2 font-display font-semibold text-teal">{clean}</h4>
        if (isBullet) {
          return (
            <div key={index} className="flex gap-2 text-sm" style={{ paddingLeft: indent + 16 }}>
              <span className="mt-0.5 font-bold text-spark">▸</span>
              <span>{clean}</span>
            </div>
          )
        }
        return <p key={index} className="text-sm text-muted">{clean}</p>
      })}
    </div>
  )
}

function LoadingScreen({ message, hasError }: { message: string; hasError: boolean }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-cream">
      <div className="brutal-card max-w-md p-10 text-center">
        {hasError ? (
          <p className="text-red-500">{message}</p>
        ) : (
          <>
            <div className="mb-4 flex justify-center gap-2">
              {[0, 1, 2].map((index) => (
                <motion.div
                  key={index}
                  className="h-3 w-3 border-2 border-ink bg-spark"
                  animate={{ y: [0, -8, 0] }}
                  transition={{ duration: 0.5, repeat: Infinity, delay: index * 0.12 }}
                />
              ))}
            </div>
            <p className="font-display font-semibold">{message}</p>
          </>
        )}
      </div>
    </div>
  )
}

function LoadingBanner({ message }: { message: string }) {
  return (
    <div className="border-b-2 border-ink bg-lemon px-6 py-3 text-center font-display text-sm font-bold">
      ⏳ {message}
    </div>
  )
}
