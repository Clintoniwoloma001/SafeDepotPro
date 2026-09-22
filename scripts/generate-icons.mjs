/**
 * Generate PWA + favicon assets from the production brand logo.
 * Source: public/logo.png (portrait) → padded to a square on the brand dark
 * background so full mark renders on every platform without cropping.
 *
 * Run: node scripts/generate-icons.mjs
 */
import sharp from 'sharp'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const outDir = resolve(root, 'public')
const SRC = resolve(root, 'public/logo.png')
const BG = '#1a1a1a'

async function main() {
  const meta = await sharp(SRC).metadata()
  const w = meta.width ?? 480
  const h = meta.height ?? 640
  const side = Math.max(w, h)

  // Square canvas filled with the brand background, logo centred on top.
  const squareImage = await sharp(SRC)
    .resize(side, side, { fit: 'contain', background: BG })
    .png()
    .toBuffer()

  // Maskable: same canvas but logo scaled to ~62% (within the safe zone).
  const maskable = await sharp({
    create: { width: side, height: side, channels: 4, background: BG },
  })
    .composite([
      { input: await sharp(SRC).resize(Math.round(side * 0.62), Math.round(side * 0.62), { fit: 'contain', background: BG }).png().toBuffer(), gravity: 'center' },
    ])
    .png()
    .toBuffer()

  await Promise.all([
    sharp(squareImage).resize(512, 512).png().toFile(resolve(outDir, 'icon-512.png')),
    sharp(squareImage).resize(192, 192).png().toFile(resolve(outDir, 'icon-192.png')),
    sharp(maskable).resize(512, 512).png().toFile(resolve(outDir, 'icon-512-maskable.png')),
    sharp(squareImage).resize(180, 180).png().toFile(resolve(outDir, 'apple-touch-icon.png')),
    sharp(SRC).resize(64, 64).png().toFile(resolve(outDir, 'favicon.png')),
  ])

  console.log('Icons generated in /public: icon-192.png, icon-512.png, icon-512-maskable.png, apple-touch-icon.png, favicon.png')
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})