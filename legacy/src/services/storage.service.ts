import { supabase } from '@/lib/supabaseClient'
import { STORAGE_BUCKETS } from '@/lib/constants'

function signedOrDefault(bucket: string, path: string | null): string | null {
  if (!path) return null
  if (path.startsWith('http')) return path
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl
}

export const storage = {
  upload(bucket: 'images' | 'signatures' | 'attachments', path: string, file: Blob | ArrayBuffer, contentType?: string) {
    return supabase.storage.from(bucket).upload(path, file, { contentType, upsert: true })
  },
  publicUrl(bucket: keyof typeof STORAGE_BUCKETS, path: string) {
    return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl
  },
  resolveSigned(bucket: keyof typeof STORAGE_BUCKETS, path: string | null) {
    return signedOrDefault(bucket, path)
  },
  async remove(bucket: 'images' | 'signatures' | 'attachments', paths: string[]) {
    if (paths.length === 0) return
    return supabase.storage.from(bucket).remove(paths)
  },
  async download(bucket: 'images' | 'signatures' | 'attachments', path: string) {
    const { data, error } = await supabase.storage.from(bucket).download(path)
    if (error) throw error
    return data
  },
}

export function storagePathFor(bucket: string, userId: string, filename: string): string {
  const safe = filename.replace(/[^a-zA-Z0-9._-]/g, '_')
  return `${bucket}/${userId}/${Date.now()}_${safe}`
}

/**
 * Upload an image file to a storage bucket and return the storage path.
 * Throws after MAX_RETRIES attempts so the caller can drop it in the offline queue.
 */
export async function uploadFileWithRetry(
  bucket: 'images' | 'signatures' | 'attachments',
  userId: string,
  file: Blob,
  filename: string,
): Promise<string> {
  const path = storagePathFor(bucket, userId, filename)
  const MAX_RETRIES = 3
  let lastError: Error | null = null
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const { error } = await storage.upload(bucket, path, file, file.type)
    if (!error) return path
    lastError = error
    if (attempt < MAX_RETRIES) await new Promise((r) => setTimeout(r, 800 * attempt))
  }
  throw lastError ?? new Error('Upload failed')
}

export type ImageSource = { path: string; url: string }