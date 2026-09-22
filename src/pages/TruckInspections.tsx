import { useEffect, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Truck, Plus, Trash2, ClipboardCheck } from 'lucide-react'
import { toast } from 'sonner'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { CardContent } from '@/components/ui/card'
import { Dialog, DialogContent, DialogHeader, DialogTitle } from '@/components/ui/dialog'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { PageHeader, EmptyState, SectionCard, KPICard } from '@/components/shared'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { useDepotFilter } from '@/hooks/useDepotFilter'
import ChecklistRenderer, { type CheckedAnswers } from '@/components/inspections/ChecklistRenderer'
import SignaturePad from '@/components/SignaturePad'
import { listTrucks, createTruck, deleteTruck, listTruckInspections, createTruckInspection, computeCompliance } from '@/services/inspections.service'
import { listChecklistTemplates } from '@/services/checklistTemplates.service'
import { listDepots } from '@/services/depots.service'
import { formatDate, cn } from '@/lib/utils'
import type { InspectionAnswer, Truck as TruckEntity, TruckInspection } from '@/types/entities'

const INSPECTION_TYPES = ['PRE_TRIP', 'ON_ROAD', 'WEEKLY', 'PERIODIC'] as const

export default function TruckInspections() {
  const user = useCurrentUser()
  const { depotId } = useDepotFilter()
  const queryClient = useQueryClient()
  const [selectedTruck, setSelectedTruck] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)
  const [addingTruck, setAddingTruck] = useState(false)

  const effectiveDepotId = user.effectiveDepotId ?? depotId ?? ''
  const { data: trucks = [] } = useQuery({ queryKey: ['trucks', effectiveDepotId], queryFn: () => listTrucks(effectiveDepotId ? { depotId: effectiveDepotId } : {}) })
  const { data: inspections = [] } = useQuery({
    queryKey: ['truck-inspections', effectiveDepotId, selectedTruck ?? 'all'],
    queryFn: () => listTruckInspections(selectedTruck ? { truckId: selectedTruck } : effectiveDepotId ? { depotId: effectiveDepotId } : {}),
  })
  const { data: depots = [] } = useQuery({ queryKey: ['depots'], queryFn: () => listDepots() })
  const depotName = (id: string | null) => depots.find((d) => d.id === id)?.name ?? '—'

  const fleet = trucks
  const plateOf = (id: string) => trucks.find((t) => t.id === id)?.plate_number ?? '—'

  const invalidate = () => {
    queryClient.invalidateQueries({ queryKey: ['trucks'] })
    queryClient.invalidateQueries({ queryKey: ['truck-inspections'] })
  }

  const addTruck = useMutation({
    mutationFn: (input: Partial<TruckEntity>) => createTruck(input),
    onSuccess: () => {
      toast.success('Truck added to fleet')
      setAddingTruck(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not add truck'),
  })

  const delTruck = useMutation({
    mutationFn: deleteTruck,
    onSuccess: () => {
      toast.success('Truck removed')
      setSelectedTruck(null)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not remove truck'),
  })

  const saveInspection = useMutation({
    mutationFn: createTruckInspection,
    onSuccess: () => {
      toast.success('Truck inspection saved')
      setCreating(false)
      invalidate()
    },
    onError: (e) => toast.error(e instanceof Error ? e.message : 'Could not save inspection'),
  })

  return (
    <div className="space-y-8">
      <PageHeader
        title="Truck Inspections"
        subtitle={`${fleet.length} trucks in fleet · ${inspections.length} inspections recorded`}
        actions={<Button onClick={() => setCreating(true)} disabled={trucks.length === 0}><ClipboardCheck className="mr-1 h-4 w-4" /> New truck inspection</Button>}
      />

      <div className="grid grid-cols-1 gap-6 sm:grid-cols-3">
        <KPICard icon={<Truck className="h-4 w-4" />} iconHue="blue" label="Fleet size" value={fleet.length} />
        <KPICard icon={<ClipboardCheck className="h-4 w-4" />} iconHue="green" label="Passes" value={inspections.filter((i) => i.result === 'PASS').length} />
        <KPICard icon={<ClipboardCheck className="h-4 w-4" />} iconHue="red" label="Fails" value={inspections.filter((i) => i.result === 'FAIL').length} />
      </div>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-5">
        <SectionCard title="Fleet" className="lg:col-span-2">
          <CardContent className="p-0">
            <div className="p-3">
              <Button size="sm" variant="outline" className="w-full" onClick={() => setAddingTruck(true)}>
                <Plus className="mr-1 h-4 w-4" /> Add truck
              </Button>
            </div>
            {fleet.length === 0 ? (
              <div className="p-3">
                <EmptyState title="No trucks" description="Add trucks to your fleet to run inspections." />
              </div>
            ) : (
              <div className="space-y-1 p-3 pt-0">
                {fleet.map((t) => (
                  <div key={t.id} className="flex items-center justify-between gap-2">
                    <button
                      onClick={() => setSelectedTruck(t.id)}
                      className={cn('flex-1 rounded-lg border px-3 py-2 text-left text-sm transition-colors', selectedTruck === t.id ? 'border-brand bg-brand/5 font-medium' : 'border-gray-100 hover:bg-muted/50')}
                    >
                      <div>{t.plate_number}</div>
                      <div className="text-xs text-muted-foreground">{t.make ? `${t.make}${t.model ? ` ${t.model}` : ''}` : t.chassis_number ?? '—'}</div>
                    </button>
                    <Button size="sm" variant="ghost" className="h-8 px-2 text-rag-bad" onClick={() => delTruck.mutate(t.id)}>
                      <Trash2 className="h-3.5 w-3.5" />
                    </Button>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </SectionCard>

        <SectionCard title={selectedTruck ? `Inspections — ${plateOf(selectedTruck)}` : 'Inspection history'} className="lg:col-span-3">
          <CardContent className="p-0">
            {inspections.length === 0 ? (
              <div className="p-6">
                <EmptyState title="No inspections" description={trucks.length === 0 ? 'Add a truck first.' : 'Run the first truck inspection from the button above.'} />
              </div>
            ) : (
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Date</TableHead>
                    <TableHead className="hidden sm:table-cell">Truck</TableHead>
                    <TableHead className="hidden md:table-cell">Type</TableHead>
                    <TableHead>Compliance</TableHead>
                    <TableHead>Result</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {inspections.map((i) => (
                    <TableRow key={i.id}>
                      <TableCell>{formatDate(i.inspection_date)}</TableCell>
                      <TableCell className="hidden sm:table-cell">{plateOf(i.truck_id)}</TableCell>
                      <TableCell className="hidden md:table-cell">{i.inspection_type}</TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <div className="h-2 w-16 overflow-hidden rounded-full bg-muted">
                            <div className={cn('h-full rounded-full', (i.compliance_percentage ?? 0) >= 85 ? 'bg-rag-good' : (i.compliance_percentage ?? 0) >= 70 ? 'bg-rag-warn' : 'bg-rag-bad')} style={{ width: `${Math.min(100, i.compliance_percentage ?? 0)}%` }} />
                          </div>
                          <span className="text-xs font-medium">{i.compliance_percentage ?? 0}%</span>
                        </div>
                      </TableCell>
                      <TableCell>
                        {i.result ? (
                          <span className={cn('rounded-full px-2 py-0.5 text-xs font-semibold', i.result === 'PASS' ? 'bg-rag-good/10 text-rag-good' : 'bg-rag-bad/10 text-rag-bad')}>{i.result}</span>
                        ) : (
                          <span className="text-xs text-muted-foreground">—</span>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
            <div className="border-t p-3 text-xs text-muted-foreground">{depotName(effectiveDepotId) || 'All depots'}</div>
          </CardContent>
        </SectionCard>
      </div>

      <TruckForm open={addingTruck} onOpenChange={setAddingTruck} defaultDepotId={effectiveDepotId} activeDepotName={depotName(effectiveDepotId)} onSave={(input) => addTruck.mutate(input)} />

      <TruckInspectionForm
        open={creating}
        onOpenChange={setCreating}
        trucks={trucks}
        templateDefault={selectedTruck}
        userId={user.userId ?? 'anon'}
        userName={user.fullName}
        defaultDepotId={effectiveDepotId}
        plateOf={plateOf}
        onSave={(input) => saveInspection.mutateAsync(input)}
      />
    </div>
  )
}

function TruckForm({
  open,
  onOpenChange,
  defaultDepotId,
  activeDepotName,
  onSave,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  defaultDepotId: string
  activeDepotName: string | null
  onSave: (input: Partial<TruckEntity>) => void
}) {
  const [plate, setPlate] = useState('')
  const [chassis, setChassis] = useState('')

  useEffect(() => {
    if (open) {
      setPlate('')
      setChassis('')
    }
  }, [open])

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader><DialogTitle>Add truck</DialogTitle></DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label className="text-sm font-medium text-muted-foreground">Plate number *</Label>
            <Input value={plate} onChange={(e) => setPlate(e.target.value)} placeholder="KCC 123A" />
          </div>
          <div className="space-y-1.5">
            <Label className="text-sm font-medium text-muted-foreground">Chassis number</Label>
            <Input value={chassis} onChange={(e) => setChassis(e.target.value)} />
          </div>
          <div className="text-xs text-muted-foreground">Depot: <strong>{activeDepotName ?? '—'}</strong></div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
            <Button
              disabled={!plate.trim() || !defaultDepotId}
              onClick={() => onSave({ depot_id: defaultDepotId || undefined, plate_number: plate.trim(), chassis_number: chassis || null })}
            >
              Add truck
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}

function TruckInspectionForm({
  open,
  onOpenChange,
  trucks,
  templateDefault,
  userId,
  userName,
  defaultDepotId,
  plateOf,
  onSave,
}: {
  open: boolean
  onOpenChange: (v: boolean) => void
  trucks: TruckEntity[]
  templateDefault: string | null
  userId: string
  userName: string
  defaultDepotId: string
  plateOf: (id: string) => string
  onSave: (input: Partial<TruckInspection>) => Promise<unknown>
}) {
  const { data: templates = [] } = useQuery({ queryKey: ['templates-TRUCK'], queryFn: () => listChecklistTemplates('TRUCK') })
  const [truckId, setTruckId] = useState('')
  const [inspectionType, setInspectionType] = useState('PRE_TRIP')
  const [odometer, setOdometer] = useState('')
  const [driverName, setDriverName] = useState('')
  const [inspectionDate, setInspectionDate] = useState(new Date().toISOString().slice(0, 10))
  const [templateId, setTemplateId] = useState('')
  const [answers, setAnswers] = useState<CheckedAnswers>({})
  const [signature, setSignature] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const template = templates.find((t) => t.id === templateId)

  useEffect(() => {
    if (!open) return
    setTruckId((templateDefault && trucks.some((t) => t.id === templateDefault) ? templateDefault : trucks[0]?.id) ?? '')
    setInspectionType('PRE_TRIP')
    setInspectionDate(new Date().toISOString().slice(0, 10))
    setTemplateId('')
    setAnswers({})
    setOdometer('')
    setDriverName('')
    setSignature(null)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open])

  const submit = async () => {
    if (!truckId) return toast.error('Choose a truck.')
    if (!template) return toast.error('Choose a truck checklist template.')
    const answersArr = Object.values(answers).map((a) => a as InspectionAnswer)
    const compliance = computeCompliance(answersArr)
    const defectNotes = answersArr
      .filter((a) => a.response === 'FAIL' || a.response === 'NON_COMPLIANT')
      .map((a) => a.corrective_action ?? a.note ?? 'Failed item')
      .join('; ') || null
    setBusy(true)
    try {
      await onSave({
        truck_id: truckId,
        depot_id: defaultDepotId || undefined,
        inspection_date: inspectionDate,
        inspection_type: inspectionType,
        odometer: Number(odometer) || null,
        driver_user_id: userId,
        driver_name: driverName || userName,
        template_id: template.id,
        answers: answersArr,
        compliance_percentage: compliance,
        result: compliance >= 70 ? 'PASS' : 'FAIL',
        defect_notes: defectNotes,
        signature_path: signature,
      })
      onOpenChange(false)
    } catch {
      // toast handled by parent mutation
    } finally {
      setBusy(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[92vh] overflow-y-auto">
        <DialogHeader><DialogTitle>New truck inspection</DialogTitle></DialogHeader>
        <div className="space-y-4">
          <div className="grid gap-3 sm:grid-cols-3">
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Truck *</Label>
              <Select value={truckId} onValueChange={setTruckId}>
                <SelectTrigger><SelectValue placeholder={plateOf(truckId) || 'Select truck'} /></SelectTrigger>
                <SelectContent>{trucks.map((t) => <SelectItem key={t.id} value={t.id}>{t.plate_number}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Type</Label>
              <Select value={inspectionType} onValueChange={setInspectionType}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>{INSPECTION_TYPES.map((t) => <SelectItem key={t} value={t}>{t}</SelectItem>)}</SelectContent>
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Date</Label>
              <Input type="date" value={inspectionDate} onChange={(e) => setInspectionDate(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Odometer (km)</Label>
              <Input type="number" value={odometer} onChange={(e) => setOdometer(e.target.value)} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Driver name</Label>
              <Input value={driverName} onChange={(e) => setDriverName(e.target.value)} placeholder={userName} />
            </div>
            <div className="space-y-1.5">
              <Label className="text-sm font-medium text-muted-foreground">Template *</Label>
              <Select value={templateId} onValueChange={(v) => { setTemplateId(v); setAnswers({}) }}>
                <SelectTrigger><SelectValue placeholder="Choose template" /></SelectTrigger>
                <SelectContent>{templates.map((t) => <SelectItem key={t.id} value={t.id}>{t.title}</SelectItem>)}</SelectContent>
              </Select>
            </div>
          </div>

          {template ? (
            <>
              <ChecklistRenderer sections={template.sections} answers={answers} onChange={setAnswers} />
              <div>
                <Label className="mb-1 block text-sm font-medium text-muted-foreground">Inspector signature</Label>
                <SignaturePad userId={userId} onSignature={setSignature} defaultValue={signature} />
              </div>
              <div className="flex justify-end gap-2">
                <Button variant="ghost" onClick={() => onOpenChange(false)}>Cancel</Button>
                <Button disabled={busy} onClick={() => void submit()}>{busy ? 'Saving…' : 'Save inspection'}</Button>
              </div>
            </>
          ) : (
            <p className="text-sm text-muted-foreground">Choose a truck checklist template to begin.</p>
          )}
        </div>
      </DialogContent>
    </Dialog>
  )
}