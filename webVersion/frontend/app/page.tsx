'use client'

import { motion } from 'framer-motion'
import Link from 'next/link'

const features = [
  {
    title: '브리프 중심 입력',
    desc: '초등, 중등, 고등 수준과 과목, 범위, 시험 시점을 함께 입력하면 AI가 훨씬 더 정밀하게 자료를 생성합니다.',
    accent: 'spark',
  },
  {
    title: '웹 검색 기반 설명',
    desc: '최신 맥락을 반영해 개념 설명, 요약, 추천 문제와 자료를 한 흐름으로 엮어줍니다.',
    accent: 'teal',
  },
  {
    title: '공부 시작 가이드',
    desc: '읽고 끝나는 자료가 아니라 오늘 바로 시작할 루틴과 셀프 체크까지 제공합니다.',
    accent: 'ink',
  },
]

const outputs = [
  { label: '개념 설명', lines: ['학교급 맞춤 난이도 설명', '헷갈리기 쉬운 포인트 정리'] },
  { label: '문제 추천', lines: ['연습 순서 제안', '기출/문제집 연결'] },
  { label: '공부 시작', lines: ['첫 20분 루틴 제안', '셀프 체크 질문 제공'] },
]

export default function Home() {
  return (
    <main className="min-h-screen bg-cream bg-dot-grid font-body">
      <nav className="sticky top-0 z-50 border-b-2 border-ink bg-cream/90 backdrop-blur-sm">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <span className="font-display text-xl font-bold">
            Study<span className="text-spark">Agents</span>
          </span>
          <Link href="/study" className="brutal-btn px-5 py-2 text-sm">
            브리프 만들기 →
          </Link>
        </div>
      </nav>

      <section className="mx-auto max-w-6xl px-6 pb-20 pt-14">
        <div className="grid gap-10 lg:grid-cols-[1.05fr_0.95fr] lg:items-center">
          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
            className="space-y-7"
          >
            <span className="section-kicker">
              <span className="inline-block h-2 w-2 rounded-full bg-ink animate-pulse-dot" />
              AI 학습 워크스페이스
            </span>

            <div>
              <h1 className="font-display text-[clamp(3rem,7vw,6rem)] font-bold leading-[0.98] tracking-tight">
                검색하고,
                <br />
                정리하고,
                <br />
                바로 공부하게.
              </h1>
              <p className="mt-6 max-w-xl text-[17px] leading-8 text-muted">
                StudyAgents는 단순 요약 도구가 아니라, 입력 브리프를 바탕으로 개념 설명, 추천 문제,
                학습 계획표, 마인드맵, 오늘의 공부 시작 가이드까지 이어서 설계하는 학습 운영 도구입니다.
              </p>
            </div>

            <div className="flex flex-wrap gap-3">
              <Link href="/study" className="brutal-btn px-8 py-4 text-lg">
                학습 세션 시작 →
              </Link>
              <a
                href="#outputs"
                className="border-2 border-ink bg-white px-8 py-4 font-display text-lg font-semibold shadow-brutal transition-all hover:-translate-x-0.5 hover:-translate-y-0.5 hover:shadow-brutal-lg"
              >
                결과물 보기 ↓
              </a>
            </div>

            <div className="grid gap-3 sm:grid-cols-3">
              {[
                ['초·중·고 맞춤', '학교급에 맞춘 설명과 학습 루틴'],
                ['웹 검색', '설명 맥락과 자료 방향 강화'],
                ['한 세션 연결', '플랜, 시작 가이드, 알림까지 확장'],
              ].map(([title, desc]) => (
                <div key={title} className="border-2 border-ink bg-white p-4 shadow-brutal-sm">
                  <p className="font-display text-lg font-bold">{title}</p>
                  <p className="mt-2 text-sm leading-6 text-muted">{desc}</p>
                </div>
              ))}
            </div>
          </motion.div>

          <motion.div
            initial={{ opacity: 0, scale: 0.96 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ delay: 0.1, duration: 0.45 }}
            className="space-y-4"
          >
            <div className="glass-panel border-2 border-ink p-5 shadow-brutal">
              <div className="flex items-center justify-between">
                <div>
                  <p className="font-display text-xs uppercase tracking-[0.18em] text-muted">Session preview</p>
                  <h2 className="mt-2 font-display text-xl font-bold">고등 영어 모의고사 대비 브리프</h2>
                </div>
                <span className="border-2 border-ink bg-spark px-3 py-1 font-display text-xs font-bold text-cream">
                  시험 공부
                </span>
              </div>
              <div className="mt-5 grid gap-3">
                <PreviewCard title="입력" body="고등 · 2024년 6월 모의고사 18, 20, 23번 · 21일 남음" />
                <PreviewCard title="AI 출력" body="지문별 핵심 구문, 주제 추론 포인트, 오답 패턴 정리" />
                <PreviewCard title="실행" body="오늘의 첫 20분 루틴, 주중 독해, 주말 복습 중심 플랜" />
              </div>
            </div>

            <div id="outputs" className="grid gap-4 sm:grid-cols-3">
              {outputs.map((item, index) => (
                <motion.div
                  key={item.label}
                  initial={{ opacity: 0, y: 18 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.2 + index * 0.08 }}
                  className="border-2 border-ink bg-white p-4 shadow-brutal-sm"
                >
                  <p className="font-display text-sm font-bold">{item.label}</p>
                  <div className="mt-3 space-y-2 text-sm text-muted">
                    {item.lines.map((line) => (
                      <p key={line}>• {line}</p>
                    ))}
                  </div>
                </motion.div>
              ))}
            </div>
          </motion.div>
        </div>
      </section>

      <section className="border-y-2 border-ink bg-ink px-6 py-20 text-cream">
        <div className="mx-auto max-w-6xl">
          <div className="mb-10 flex flex-wrap items-end justify-between gap-4">
            <div>
              <p className="font-display text-xs uppercase tracking-[0.2em] text-cream/60">Value design</p>
              <h2 className="mt-2 font-display text-3xl font-bold">좋은 입력이 좋은 학습 루프를 만듭니다.</h2>
            </div>
            <p className="max-w-xl text-sm leading-7 text-cream/75">
              공식 문서와 실제 서비스 설계 관점에서, 입력 폼은 검증과 피드백이 명확해야 하고
              결과 화면은 다음 행동이 바로 보여야 합니다. StudyAgents는 이 흐름을 한 세션 안에 묶습니다.
            </p>
          </div>

          <div className="grid gap-6 md:grid-cols-3">
            {features.map((feature) => (
              <div key={feature.title} className="border-2 border-cream/30 p-6">
                <div
                  className={`mb-4 inline-flex border-2 px-3 py-1 font-display text-xs font-bold ${
                    feature.accent === 'spark'
                      ? 'border-spark bg-spark text-cream'
                      : feature.accent === 'teal'
                        ? 'border-teal bg-teal text-cream'
                        : 'border-lemon bg-lemon text-ink'
                  }`}
                >
                  {feature.title}
                </div>
                <p className="text-sm leading-7 text-cream/75">{feature.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-6xl px-6 py-20">
        <div className="mb-10">
          <p className="font-display text-xs uppercase tracking-[0.2em] text-muted">Workflow</p>
          <h2 className="mt-2 font-display text-3xl font-bold">세션은 이렇게 흘러갑니다.</h2>
        </div>

        <div className="grid gap-5 md:grid-cols-4">
          {[
            ['01', '브리프 작성', '학교급, 과목, 범위, 기출, 일정 조건을 구조화해서 입력합니다.'],
            ['02', '웹 검색 및 분석', 'AI가 최신 맥락과 설명 포인트를 찾고 학습 자료를 엮습니다.'],
            ['03', '결과물 검토', '개념 설명, 요약, 공부 시작 가이드, 학습 방향을 한 화면에서 검토합니다.'],
            ['04', '학습 운영', '계획표, 마인드맵, 알림으로 실제 공부 루틴까지 이어갑니다.'],
          ].map(([step, title, desc]) => (
            <div key={step} className="border-2 border-ink bg-white p-5 shadow-brutal-sm">
              <p className="font-display text-4xl font-bold text-spark">{step}</p>
              <p className="mt-4 font-display text-lg font-bold">{title}</p>
              <p className="mt-3 text-sm leading-7 text-muted">{desc}</p>
            </div>
          ))}
        </div>
      </section>

      <section className="border-t-2 border-ink px-6 py-20">
        <div className="mx-auto flex max-w-6xl flex-col items-start justify-between gap-8 md:flex-row md:items-center">
          <div>
            <p className="font-display text-xs uppercase tracking-[0.2em] text-muted">Ready to start</p>
            <h2 className="mt-2 font-display text-[clamp(2rem,5vw,3.4rem)] font-bold leading-tight">
              공부 자료를 만드는 데
              <br />
              입력 3단계면 충분합니다.
            </h2>
          </div>
          <Link href="/study" className="brutal-btn px-10 py-5 text-xl">
            지금 세션 만들기 →
          </Link>
        </div>
      </section>

      <footer className="border-t-2 border-ink px-6 py-8 text-center font-display text-sm text-muted">
        © 2026 StudyAgents · AI 기반 학습 워크스페이스
      </footer>
    </main>
  )
}

function PreviewCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="border-2 border-ink bg-white p-4 shadow-brutal-sm">
      <p className="font-display text-[11px] uppercase tracking-[0.18em] text-muted">{title}</p>
      <p className="mt-2 text-sm leading-6">{body}</p>
    </div>
  )
}
