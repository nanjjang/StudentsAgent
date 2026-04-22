import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './app/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        cream:  '#F5F0E8',
        ink:    '#111111',
        spark:  '#FF4D00',
        'spark-dim': '#FFF0EB',
        teal:   '#00A693',
        'teal-dim': '#E0F7F5',
        lemon:  '#FFD60A',
        muted:  '#7A6A55',
      },
      fontFamily: {
        display: ['var(--font-display)', 'sans-serif'],
        body:    ['var(--font-body)',    'sans-serif'],
      },
      boxShadow: {
        brutal:    '4px 4px 0px 0px #111111',
        'brutal-sm': '2px 2px 0px 0px #111111',
        'brutal-lg': '8px 8px 0px 0px #111111',
        'brutal-spark': '4px 4px 0px 0px #FF4D00',
        'brutal-teal':  '4px 4px 0px 0px #00A693',
      },
      backgroundImage: {
        'dot-grid': 'radial-gradient(circle, #11111120 1px, transparent 1px)',
      },
      backgroundSize: {
        'dot-grid': '24px 24px',
      },
      keyframes: {
        'slide-up': {
          from: { opacity: '0', transform: 'translateY(16px)' },
          to:   { opacity: '1', transform: 'translateY(0)' },
        },
        'pulse-dot': {
          '0%, 100%': { transform: 'scale(1)' },
          '50%':      { transform: 'scale(1.4)' },
        },
        typewriter: {
          from: { width: '0' },
          to:   { width: '100%' },
        },
      },
      animation: {
        'slide-up': 'slide-up 0.4s ease both',
        'pulse-dot': 'pulse-dot 1.2s ease infinite',
      },
    },
  },
}

export default config
