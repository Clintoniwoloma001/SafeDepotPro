import { useState } from 'react'
import { useMutation, useQuery } from '@tanstack/react-query'
import { FileDown, DownloadCloud } from 'lucide-react'
import { toast } from 'sonner'
import ExcelJS from 'exceljs'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { CardContent } from '@/components/ui/card'
import { SectionCard, PageHeader } from '@/components/shared'
import { listDepots } from '@/services/depots.service'
import { listInspections } from '@/services/inspections.service'
import { listIncidents } from '@/services/incidents.service'
import { listHazards } from '@/services/hazards.service'
import { listCapas } from '@/services/capa.service'
import { listManHours } from '@/services/manHours.service'
import { listToolboxTalks } from '@/services/toolboxTalks.service'
import { listPermits } from '@/services/permits.service'
import { listAssets } from '@/services/assets.service'
import { listPersonnel } from '@/services/personnel.service'
import { listTrucks } from '@/services/inspections.service'

export default function PlatformExport() {
  const [depotId, setDepotId] = useState('all')
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')

  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const exportAll = useMutation({
    mutationFn: async () => {
      const opts = depotId && depotId !== 'all' ? { depotId } : {}
      const fromOpt = from ? { from } : {}
      const toOpt = to ? { to } : {}
      const dated = { ...opts, ...fromOpt, ...toOpt }
      const [inspections, incidents, hazards, capas, manHours, toolbox, permits, assets, personnel, trucks] = await Promise.all([
        listInspections(dated),
        listIncidents(opts),
        listHazards(opts),
        listCapas(opts),
        listManHours(dated),
        listToolboxTalks(dated),
        listPermits(opts),
        listAssets(opts),
        listPersonnel(opts),
        listTrucks(opts),
      ])
      return { inspections, incidents, hazards, capas, manHours, toolbox, permits, assets, personnel, trucks }
    },
    onSuccess: (d) => {
      const wb = new ExcelJS.Workbook()
      wb.creator = 'SafeDepot Pro'
      const sheet = (name: string, rows: Record<string, unknown>[]) => {
        const ws = wb.addWorksheet(name)
        if (rows.length === 0) {
          ws.addRow(['No data'])
          return
        }
        const headers = Object.keys(rows[0])
        ws.addRow(headers)
        ws.getRow(1).font = { bold: true }
        rows.forEach((r) => ws.addRow(headers.map((h) => r[h] ?? '')))
        ws.columns.forEach((_, i) => {
          const len = Math.max(...(rows.map((r) => String(r[headers[i]] ?? '').length)), headers[i].length)
          ws.getColumn(i + 1).width = Math.min(40, len + 2)
        })
      }
      sheet('Inspections', d.inspections.map((i) => ({ depot: depotName(i.depot_id), date: i.inspection_date, title: i.title, compliance: i.compliance_percentage, status: i.status, inspector: i.inspector_name })))
      sheet('Incidents', d.incidents.map((i) => ({ depot: depotName(i.depot_id), date: i.occurred_at, type: i.incident_type, severity: i.severity, status: i.status, reported_by: i.reported_by_name })))
      sheet('Hazards', d.hazards.map((h) => ({ depot: depotName(h.depot_id), date: h.created_at, type: h.hazard_type, severity: h.severity, status: h.status, by: h.reported_by_name })))
      sheet('CAPAs', d.capas.map((c) => ({ depot: depotName(c.depot_id), number: c.capa_number, title: c.title, priority: c.priority, due: c.due_date, status: c.status })))
      sheet('Man Hours', d.manHours.map((m) => ({ depot: depotName(m.depot_id), start: m.period_start, end: m.period_end, hours: m.hours_worked, lti: m.lost_time_injuries, recordables: m.recordable_incidents })))
      sheet('Toolbox Talks', d.toolbox.map((t) => ({ depot: depotName(t.depot_id), date: t.talk_date, topic: t.topic, facilitator: t.facilitator })))
      sheet('Permits', d.permits.map((p) => ({ depot: depotName(p.depot_id), number: p.permit_number, job: p.job_title, type: p.permit_type, status: p.status })))
      sheet('Assets', d.assets.map((a) => ({ depot: depotName(a.depot_id), tag: a.asset_tag, name: a.name, status: a.status, condition: a.condition })))
      sheet('Personnel', d.personnel.map((p) => ({ depot: depotName(p.depot_id), name: `${p.first_name} ${p.last_name}`, email: p.email, position: p.position })))
      sheet('Trucks', d.trucks.map((t) => ({ depot: depotName(t.depot_id), plate: t.plate_number, make: t.make, model: t.model })))
      void writeWorkbook(wb)
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Export failed'),
  })

  return (
    <div className="space-y-8 max-w-2xl">
      <PageHeader
        title="Platform Export"
        subtitle="Excel snapshot of records" 
      />

      <SectionCard title="Export workspace">
        <CardContent className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <Labeled label="Depot">
              <Select value={depotId} onValueChange={setDepotId}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All depots</SelectItem>
                  {depots.map((d) => <SelectItem key={d.id} value={d.id}>{d.name}</SelectItem>)}
                </SelectContent>
              </Select>
            </Labeled>
            <Labeled label="From">
              <Input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
            </Labeled>
            <Labeled label="To">
              <Input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
            </Labeled>
          </div>
          <Button className="w-full" disabled={exportAll.isPending} onClick={() => exportAll.mutate()}>
            {exportAll.isPending ? <DownloadCloud className="mr-1 h-4 w-4 animate-pulse" /> : <FileDown className="mr-1 h-4 w-4" />}
            {exportAll.isPending ? 'Gathering data…' : 'Generate Excel export'}
          </Button>
          <p className="text-xs text-muted-foreground">
            Sheets: Inspections, Incidents, Hazards, CAPAs, Man Hours, Toolbox Talks, Permits, Assets, Personnel, Trucks.
            Date filters apply to dated records; static registers return everything for the selected depot.
          </p>
          <p className="text-xs text-rag-good">Primary and secondary data lives in your own Supabase project — this export is a convenience snapshot, not a copy of the source.</p>
        </CardContent>
      </SectionCard>
    </div>
  )

  async function writeWorkbook(wb: ExcelJS.Workbook) {
    const buf = Buffer.from(await wb.xlsx.writeBuffer())
    const url = URL.createObjectURL(new Blob([buf]))
    const a = document.createElement('a')
    a.href = url
    a.download = `safedepotpro_export_${new Date().toISOString().slice(0, 10)}.xlsx`
    a.click()
    URL.revokeObjectURL(url)
    toast.success('Export ready')
  }
}

function Labeled({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="space-y-1.5">
      <Label className="text-sm font-medium text-muted-foreground">{label}</Label>
      {children}
    </div>
  )
}