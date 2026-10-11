import { jsPDF } from 'jspdf'
import type { ToolboxTalk, ToolboxAttendee } from '@/types/entities'
import type { OrgSettings } from '@/types/entities'
import { formatDate } from '@/lib/utils'

const CRIMSON: [number, number, number] = [204, 0, 0]
const DARK: [number, number, number] = [26, 26, 26]
const GRAY: [number, number, number] = [120, 120, 120]

function pageHeader(doc: jsPDF, settings: OrgSettings, title: string, subtitle?: string) {
  const w = doc.internal.pageSize.getWidth()
  doc.setFillColor(...CRIMSON)
  doc.rect(0, 0, w, 22, 'F')
  doc.setTextColor(255, 255, 255)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(13)
  doc.text(settings.org_name || 'SafeDepot Pro', 14, 13)
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9)
  doc.text('HSE Management', 14, 18)
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(16)
  doc.text(title, 14, 40)
  if (subtitle) {
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(10)
    doc.setTextColor(...GRAY)
    doc.text(subtitle, 14, 47)
  }
}

function pageFooter(doc: jsPDF) {
  const pages = doc.getNumberOfPages()
  for (let i = 1; i <= pages; i++) {
    doc.setPage(i)
    const w = doc.internal.pageSize.getWidth()
    const h = doc.internal.pageSize.getHeight()
    doc.setDrawColor(...CRIMSON)
    doc.setLineWidth(0.4)
    doc.line(14, h - 14, w - 14, h - 14)
    doc.setTextColor(...GRAY)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(8)
    doc.text(`SafeDepot Pro — generated ${formatDate(new Date().toISOString())}`, 14, h - 9)
    doc.text(`${i} / ${pages}`, w - 14, h - 9, { align: 'right' })
  }
}

function sectionHeading(doc: jsPDF, text: string, y: number): number {
  doc.setFont('helvetica', 'bold')
  doc.setFontSize(11)
  doc.setTextColor(...CRIMSON)
  doc.text(text, 14, y)
  doc.setDrawColor(...CRIMSON)
  doc.setLineWidth(0.2)
  doc.line(14, y + 2, doc.internal.pageSize.getWidth() - 14, y + 2)
  return y + 6
}

function body(doc: jsPDF, text: string, y: number): number {
  doc.setFont('helvetica', 'normal')
  doc.setFontSize(9.5)
  doc.setTextColor(...DARK)
  const lines = doc.splitTextToSize(text ?? '', doc.internal.pageSize.getWidth() - 28)
  doc.text(lines, 14, y)
  return y + lines.length * 4.2
}

function ensureSpace(doc: jsPDF, y: number, need = 18): number {
  const h = doc.internal.pageSize.getHeight()
  if (y > h - 40 - need) {
    doc.addPage()
    return 26
  }
  return y
}

export function buildToolboxTalkPdf(talk: Pick<ToolboxTalk, 'talk_date' | 'facilitator' | 'topic' | 'discussion_points' | 'takeaways' | 'action_items'>, attendees: ToolboxAttendee[], settings: OrgSettings): jsPDF {
  const doc = new jsPDF()
  pageHeader(doc, settings, 'Toolbox Talk', `${talk.topic} — ${formatDate(talk.talk_date)}`)
  let y = 58

  y = ensureSpace(doc, y)
  y = sectionHeading(doc, 'Details', y)
  y = body(doc, `Date: ${formatDate(talk.talk_date)}\nFacilitator: ${talk.facilitator}\nTopic: ${talk.topic}`, y + 2)

  y = ensureSpace(doc, y, 30)
  y = sectionHeading(doc, 'Discussion Points', y)
  y = body(doc, talk.discussion_points || '—', y + 2)

  y = ensureSpace(doc, y, 22)
  y = sectionHeading(doc, 'Takeaways', y)
  y = body(doc, talk.takeaways || '—', y + 2)

  y = ensureSpace(doc, y, 22)
  y = sectionHeading(doc, 'Action Items', y)
  y = body(doc, talk.action_items || '—', y + 2)

  y = ensureSpace(doc, y, 40)
  y = sectionHeading(doc, `Attendees (${attendees.length})`, y)
  const col = doc.internal.pageSize.getWidth() - 28
  attendees.forEach((a, i) => {
    const xx = 14 + (i % 2) * (col / 2 + 6)
    const yy = y + 4 + Math.floor(i / 2) * 14
    if (yy > doc.internal.pageSize.getHeight() - 30) {
      doc.addPage()
      y = 26
      return
    }
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(9)
    doc.text(a.full_name, xx, yy)
  })

  // Photos are never embedded — reference supporting evidence separately.
  y = doc.internal.pageSize.getHeight() - 8
  doc.setFont('helvetica', 'italic')
  doc.setFontSize(8.5)
  doc.setTextColor(...GRAY)
  doc.text('Note: supporting photographic evidence is attached separately.', 14, y - 30)

  pageFooter(doc)
  return doc
}

export function buildGenericPdf(settings: OrgSettings, title: string, subtitle: string | null, rows: { label: string; value: string }[], footerNote?: string): jsPDF {
  const doc = new jsPDF()
  pageHeader(doc, settings, title, subtitle ?? undefined)
  let y = 58
  for (const row of rows) {
    y = ensureSpace(doc, y, 12)
    doc.setFont('helvetica', 'bold')
    doc.setFontSize(9)
    doc.setTextColor(...GRAY)
    doc.text(row.label, 14, y)
    doc.setFont('helvetica', 'normal')
    doc.setFontSize(9.5)
    doc.setTextColor(...DARK)
    doc.text(doc.splitTextToSize(row.value || '—', doc.internal.pageSize.getWidth() - 28).slice(0, 6), 14, y + 5)
    y += 14
  }
  if (footerNote) {
    y = ensureSpace(doc, y, 20)
    doc.setFont('helvetica', 'italic')
    doc.setFontSize(8.5)
    doc.setTextColor(...GRAY)
    doc.text(footerNote, 14, y)
  }
  pageFooter(doc)
  return doc
}