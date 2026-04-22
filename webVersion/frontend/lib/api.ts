import type { StudySession, StudySessionCreate, StudyPlan, MindMapResponse } from './types'

const BASE = process.env.NEXT_PUBLIC_API_BASE_URL ?? '/api/v1'

type ValidationDetail = {
  msg?: string
  message?: string
}

async function extractErrorMessage(res: Response): Promise<string> {
  try {
    const payload = (await res.clone().json()) as {
      detail?: string | ValidationDetail[]
      message?: string
    }
    if (typeof payload?.detail === 'string') return payload.detail
    if (Array.isArray(payload?.detail)) {
      const flattened = payload.detail
        .map((item: ValidationDetail) => item.msg ?? item.message)
        .filter(Boolean)
        .join(' / ')
      if (flattened) return flattened
    }
    if (typeof payload?.message === 'string') return payload.message
  } catch {
    // Fallback to plain text below.
  }

  const text = await res.text().catch(() => '')
  return text || res.statusText
}

async function req<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  })
  if (!res.ok) {
    const msg = await extractErrorMessage(res)
    throw new Error(`[${res.status}] ${msg}`)
  }
  return res.json()
}

export const api = {
  healthCheck: async () => {
    const res = await fetch('/_studyagents/health')
    if (!res.ok) {
      throw new Error('백엔드 서버에 연결하지 못했습니다. FastAPI 서버가 켜져 있는지 확인해주세요.')
    }
    return res.json() as Promise<{ status: string; service: string }>
  },

  createSession: (body: StudySessionCreate) =>
    req<StudySession>('/sessions', { method: 'POST', body: JSON.stringify(body) }),

  getSession: (id: string) =>
    req<StudySession>(`/sessions/${id}`),

  generatePlan: (id: string, days: number, hours: Record<string, number>) =>
    req<StudyPlan>(`/sessions/${id}/plan/custom`, {
      method: 'POST',
      body: JSON.stringify({ days_remaining: days, study_hours_per_day: hours }),
    }),

  getMindMap: (id: string) =>
    req<MindMapResponse>(`/sessions/${id}/mindmap`),

  analyzeExam: (id: string, content: string) =>
    req<{ analysis: string }>(`/sessions/${id}/analyze-exam`, {
      method: 'POST',
      body: JSON.stringify({ exam_content: content }),
    }),

  setNotification: (id: string, message: string, time: string, days: string[]) =>
    req(`/sessions/${id}/notifications`, {
      method: 'POST',
      body: JSON.stringify({ message, time, days }),
    }),

  // Streaming content generation — returns ReadableStream
  streamContent: (body: StudySessionCreate) =>
    fetch(`${BASE}/sessions/stream`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    }),
}
