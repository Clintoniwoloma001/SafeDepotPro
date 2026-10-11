import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { useAuth } from '@/contexts/AuthContext'
import { listDepots } from '@/services/depots.service'
import { supabase } from '@/lib/supabaseClient'
import { toast } from 'sonner'

export default function OAuthCallback() {
  const { user, profile, loading, refreshProfile } = useAuth()
  const navigate = useNavigate()
  const [depotId, setDepotId] = useState('')
  const [saving, setSaving] = useState(false)
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots(), enabled: Boolean(user) })

  useEffect(() => {
    void supabase.auth.getSession()
  }, [])

  if (loading || !user) {
    return (
      <div className="flex min-h-screen items-center justify-center text-sm text-muted-foreground">Finishing sign-in…</div>
    )
  }

  // Profile exists and already has a depot → straight to the app.
  if (profile?.depot_id) {
    navigate('/', { replace: true })
    return null
  }

  const save = async () => {
    if (!depotId) {
      toast.error('Select a depot.')
      return
    }
    setSaving(true)
    const { error } = await supabase.from('profiles').update({ depot_id: depotId }).eq('id', user.id)
    if (error) {
      toast.error(error.message)
      setSaving(false)
      return
    }
    await refreshProfile()
    navigate('/', { replace: true })
  }

  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-b from-slate-100 to-slate-200 p-4">
      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Welcome</CardTitle>
          <CardDescription>Your account needs a depot to continue (required at signup).</CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <Select value={depotId} onValueChange={setDepotId}>
            <SelectTrigger className="w-full">
              <SelectValue placeholder="Select your depot" />
            </SelectTrigger>
            <SelectContent>
              {depots.map((d) => (
                <SelectItem key={d.id} value={d.id}>
                  {d.name} ({d.code})
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          <Button className="w-full" onClick={save} disabled={saving}>
            {saving ? 'Saving…' : 'Continue'}
          </Button>
          <Button
            variant="ghost"
            className="w-full"
            onClick={async () => {
              await supabase.auth.signOut()
              navigate('/auth/login')
            }}
          >
            Sign out instead
          </Button>
        </CardContent>
      </Card>
    </div>
  )
}