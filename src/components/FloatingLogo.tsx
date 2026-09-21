import { Link } from 'react-router-dom'
import { useSettings } from '@/contexts/SettingsContext'

/**
 * Fixed bottom-right branded logo. Click → company website from settings.
 * Visible on every authenticated page (mounted in Layout).
 */
export default function FloatingLogo() {
  const { settings } = useSettings()
  const target = settings.company_website

  const inner = (
    <span className="block">
      <img src="/logo.svg" alt="SafeDepot Pro" className="hidden h-10 w-auto" />
      <span className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand text-xl font-bold text-white shadow-lg">
        <svg viewBox="0 0 64 64" className="h-8 w-8" aria-hidden="true">
          <path d="M10 26 L32 8 L54 26 L48 48 L16 48 Z" fill="none" stroke="#fff" strokeWidth="5" strokeLinejoin="round" />
          <rect x="24" y="32" width="16" height="10" rx="2" fill="#f59e0b" />
        </svg>
      </span>
    </span>
  )

  const cls =
    'fixed bottom-6 right-6 z-40 rounded-xl transition-transform duration-200 hover:scale-110 hover:shadow-xl hover:shadow-black/30'

  if (target) {
    return (
      <a href={target} target="_blank" rel="noreferrer noopener" title="Visit company website" className={cls}>
        {inner}
      </a>
    )
  }
  return (
    <Link to="/" title="SafeDepot Pro" className={cls}>
      {inner}
    </Link>
  )
}