import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const manifest = JSON.parse(await readFile(path.join(root, 'docs/asset-manifest.json'), 'utf8'));
for (const entry of manifest) {
  const bytes = await readFile(path.join(root, entry.file));
  const hash = createHash('sha256').update(bytes).digest('hex');
  if (hash !== entry.sha256) throw new Error(`Asset changed: ${entry.file}`);
}
console.log(`Verified ${manifest.length} bundled assets.`);
