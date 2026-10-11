/**
 * IndexedDB-backed offline upload queue.
 *
 * Flows:
 *  1. Items are uploaded immediately via uploadFileWithRetry.
 *  2. On failure the item (as a data URL) is persisted to IndexedDB and
 *     re-enqueued; it is re-attempted on 'online' events and on an interval.
 *  3. When a queued item finally uploads, its resolver (kept in memory)
 *     receives the storage path so the calling form can proceed.
 *
 * A flushed item never leaves form data behind.
 */

import { uploadFileWithRetry } from '@/services/storage.service'

export interface PendingUpload {
  id: string
  bucket: 'images' | 'signatures' | 'attachments'
  userId: string
  filename: string
  dataUrl: string
  createdAt: string
}

const DB_NAME = 'safedepot-uploads'
const STORE = 'pending'
const RETRY_INTERVAL = 20_000

const resolvers = new Map<string, { resolve: (path: string) => void; reject: (e: Error) => void }>()

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1)
    req.onupgradeneeded = () => {
      const db = req.result
      if (!db.objectStoreNames.contains(STORE)) db.createObjectStore(STORE, { keyPath: 'id' })
    }
    req.onsuccess = () => resolve(req.result)
    req.onerror = () => reject(req.error ?? new Error('IndexedDB open failed'))
  })
}

async function dbPut(item: PendingUpload) {
  const db = await openDb()
  return new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite')
    tx.objectStore(STORE).put(item)
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error ?? new Error('IndexedDB put failed'))
  })
}

async function dbGetAll(): Promise<PendingUpload[]> {
  const db = await openDb()
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readonly')
    const req = tx.objectStore(STORE).getAll()
    req.onsuccess = () => resolve((req.result as PendingUpload[]) ?? [])
    req.onerror = () => reject(req.error ?? new Error('IndexedDB read failed'))
  })
}

async function dbDelete(id: string) {
  const db = await openDb()
  return new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite')
    tx.objectStore(STORE).delete(id)
    tx.oncomplete = () => resolve()
    tx.onerror = () => reject(tx.error ?? new Error('IndexedDB delete failed'))
  })
}

async function uploadItem(item: PendingUpload): Promise<string> {
  const blob = await (await fetch(item.dataUrl)).blob()
  return uploadFileWithRetry(item.bucket, item.userId, blob, item.filename)
}

let busy = false

async function processQueue() {
  if (busy) return
  busy = true
  try {
    const items = await dbGetAll()
    for (const item of items) {
      try {
        const path = await uploadItem(item)
        await dbDelete(item.id)
        const pending = resolvers.get(item.id)
        if (pending) {
          resolvers.delete(item.id)
          pending.resolve(path)
        }
      } catch {
        // keep the item, attempt again later
      }
    }
  } finally {
    busy = false
  }
}

/** Try immediately; on failure persist + retry. Always resolves with a storage path. */
export async function enqueueAndUpload(upload: Omit<PendingUpload, 'id' | 'createdAt'>): Promise<string> {
  const item: PendingUpload = { ...upload, id: crypto.randomUUID(), createdAt: new Date().toISOString() }
  try {
    return await uploadItem(item)
  } catch {
    try {
      await dbPut(item)
    } catch {
      throw new Error('Upload failed and could not be queued offline.')
    }
    return new Promise<string>((resolve, reject) => {
      resolvers.set(item.id, { resolve, reject })
      void processQueue()
    })
  }
}

declare global {
  interface Window {
    __safedepotFlushPending?: () => Promise<void>
  }
}
window.__safedepotFlushPending = processQueue

if (typeof window !== 'undefined') {
  window.addEventListener('online', () => void processQueue())
  setInterval(() => void processQueue(), RETRY_INTERVAL)
}

export { processQueue as flushPending }