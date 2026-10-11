import { useEffect, useState } from 'react'
import { toast } from 'sonner'

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

export default function InstallBanner() {
  const [promptEvent, setPromptEvent] = useState<BeforeInstallPromptEvent | null>(null)
  const [installed, setInstalled] = useState(false)

  useEffect(() => {
    const onPrompt = (e: Event) => {
      e.preventDefault()
      setPromptEvent(e as BeforeInstallPromptEvent)
    }
    const onInstalled = () => {
      setInstalled(true)
      setPromptEvent(null)
      toast.success('SafeDepot Pro installed')
    }
    window.addEventListener('beforeinstallprompt', onPrompt)
    window.addEventListener('appinstalled', onInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', onPrompt)
      window.removeEventListener('appinstalled', onInstalled)
    }
  }, [])

  if (!promptEvent || installed) return null

  return (
    <div className="fixed bottom-20 right-6 z-30 flex items-center gap-3 rounded-lg border bg-background p-3 shadow-lg">
      <span className="text-sm">Install SafeDepot Pro?</span>
      <button
        className="rounded-md bg-brand px-3 py-1 text-sm font-medium text-white hover:bg-brand/90"
        onClick={async () => {
          await promptEvent.prompt()
          const choice = await promptEvent.userChoice
          if (choice.outcome === 'accepted') setInstalled(true)
          setPromptEvent(null)
        }}
      >
        Install
      </button>
      <button className="text-sm text-muted-foreground hover:text-foreground" onClick={() => setPromptEvent(null)}>
        Dismiss
      </button>
    </div>
  )
}