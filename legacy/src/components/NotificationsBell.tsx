import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useQuery } from '@tanstack/react-query'
import { Bell, BellOff } from 'lucide-react'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { supabase } from '@/lib/supabaseClient'
import { relativeTime } from '@/lib/utils'
import type { NotificationRecord } from '@/types/entities'

async function fetchNotifications(userId: string, limit = 12): Promise<NotificationRecord[]> {
  const { data, error } = await supabase
    .from('notifications')
    .select('*')
    .eq('user_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data ?? []
}

async function markAllRead(userId: string) {
  await supabase.from('notifications').update({ is_read: true }).eq('user_id', userId).eq('is_read', false)
}

export default function NotificationsBell() {
  const user = useCurrentUser()
  const navigate = useNavigate()
  const [open, setOpen] = useState(false)
  const { data = [], refetch } = useQuery({
    queryKey: ['notifications', user.userId],
    queryFn: () => (user.userId ? fetchNotifications(user.userId) : Promise.resolve([])),
    enabled: Boolean(user.userId),
  })

  const unread = data.filter((n) => !n.is_read).length

  return (
    <DropdownMenu open={open} onOpenChange={(o) => setOpen(o)}>
      <DropdownMenuTrigger asChild>
        <Button variant="ghost" size="icon" className="relative">
          {unread > 0 && (
            <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-brand px-1 text-[10px] font-semibold text-white">
              {unread}
            </span>
          )}
          <Bell className="h-5 w-5" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-80">
        <DropdownMenuItem
          className="flex items-center justify-between"
          disabled
        >
          <span className="font-medium">Notifications</span>
        </DropdownMenuItem>
        <DropdownMenuSeparator />
        {data.length === 0 && (
          <div className="flex flex-col items-center gap-2 px-4 py-8 text-sm text-muted-foreground">
            <BellOff className="h-6 w-6" />
            You&apos;re all caught up.
          </div>
        )}
        <div className="max-h-80 overflow-y-auto">
          {data.map((n) => (
            <DropdownMenuItem
              key={n.id}
              className="cursor-pointer items-start gap-2 whitespace-normal"
              onSelect={() => {
                if (n.link) navigate(n.link)
                setOpen(false)
              }}
            >
              <div>
                <div className={cnTitle(n.is_read)}>{n.title}</div>
                {n.body && <div className="text-xs text-muted-foreground">{n.body}</div>}
                <div className="mt-0.5 text-[11px] text-muted-foreground">{relativeTime(n.created_at)}</div>
              </div>
            </DropdownMenuItem>
          ))}
        </div>
        <DropdownMenuSeparator />
        <DropdownMenuItem
          onSelect={() => {
            if (user.userId) markAllRead(user.userId).then(() => refetch())
          }}
        >
          Mark all as read
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

function cnTitle(isRead: boolean) {
  return isRead ? 'text-sm font-normal' : 'text-sm font-medium'
}