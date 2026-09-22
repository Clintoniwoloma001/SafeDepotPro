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
    <span className="flex h-12 w-12 items-center justify-center overflow-hidden rounded-xl bg-brand shadow-lg">
      <img src="/logo.png" alt="SafeDepot Pro" className="h-10 w-auto object-contain" />
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