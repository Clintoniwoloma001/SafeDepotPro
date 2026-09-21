import { Link } from 'react-router-dom'
import { Button } from '@/components/ui/button'

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-gradient-to-b from-slate-100 to-slate-200 p-6 text-center">
      <div className="text-6xl font-extrabold text-brand">404</div>
      <h1 className="text-xl font-semibold">Page not found</h1>
      <p className="text-sm text-muted-foreground">The page you’re looking for doesn’t exist or you don’t have access.</p>
      <Link to="/">
        <Button>Back to dashboard</Button>
      </Link>
    </div>
  )
}