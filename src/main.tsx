import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClientProvider } from '@tanstack/react-query'
import { TooltipProvider } from '@/components/ui/tooltip'
import { Toaster } from '@/components/ui/sonner'
import { AuthProvider } from '@/contexts/AuthContext'
import { SettingsProvider } from '@/contexts/SettingsContext'
import { queryClient } from '@/lib/query-client'
import App from './App'
import './index.css'

if (import.meta.env.PROD) {
  console.log(
    '%cSafeDepot Pro',
    'font-weight:bold;font-size:14px;color:#cc0000',
    `\nDeveloped by Clinton Iwoloma — Flatra Tech Ltd\nBuild ${__BUILD_HASH__}`,
  )
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AuthProvider>
          <SettingsProvider>
            <TooltipProvider>
              <App />
              <Toaster />
            </TooltipProvider>
          </SettingsProvider>
        </AuthProvider>
      </BrowserRouter>
    </QueryClientProvider>
  </StrictMode>,
)