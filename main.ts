// Lantern Keep — Wisp Rush: program penyerahan entry roblox-game-01.
//
// Cara kerja program ini: proyek Rojo di direktori ini sudah dibangun
// menjadi game.rbxl (rojo build default.project.json --output game.rbxl).
// Program ini menyalin place, sumber Luau, screenshot, dan PLAY.json
// ke direktori output, lalu menulis dossier.json — ringkasan yang dibaca
// juri — memakai pustaka make.fun yang sudah di-vendor.
//
// Dijalankan di luar container grader dengan:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
// Di dalam container grader, MAKEFUN_OUTPUT_DIR tidak disetel dan
// output ditulis ke /output.

import { copyFileSync, cpSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

// Direktori repo ini, apa pun working directory pemanggilnya.
const repoRoot = fileURLToPath(new URL('.', import.meta.url));
const outputDir = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

// --- ENTRYPOINT GATE: siapkan direktori output sebelum menyalin apa pun. ---
mkdirSync(outputDir, { recursive: true });

// Place biner hasil Rojo, tautan play, sumber, dan screenshot.
// Berhenti dengan pesan yang jelas bila place belum dibangun —
// dossier dari place yang hilang akan menyesatkan scorer.
if (!existsSync(join(repoRoot, 'game.rbxl'))) {
  throw new Error('game.rbxl tidak ditemukan: jalankan dulu `rojo build default.project.json --output game.rbxl`.');
}
copyFileSync(join(repoRoot, 'game.rbxl'), join(outputDir, 'game.rbxl'));
copyFileSync(join(repoRoot, 'PLAY.json'), join(outputDir, 'PLAY.json'));
cpSync(join(repoRoot, 'src'), join(outputDir, 'src'), { recursive: true });
mkdirSync(join(outputDir, 'screenshots'), { recursive: true });
if (existsSync(join(repoRoot, 'screenshots'))) {
  cpSync(join(repoRoot, 'screenshots'), join(outputDir, 'screenshots'), { recursive: true });
}

// Batas yang dipakai scorer (reference/gate.json): text_max_bytes yang
// membentuk byte dossier; batas lain menolak entry yang scorer tolak
// (lebih dari 4 screenshot atau satu di atas 256 KiB; place di atas
// 500000 instance; sumber script di atas 8 MiB atau path script di atas
// 1048576 karakter, semuanya digabung).
writeFileSync(
  join(outputDir, 'dossier.json'),
  buildDossier(outputDir, {
    text_max_bytes: 65536,
    screenshots: { max: 4, max_bytes: 262144 },
    max_instances: 500000,
    scripts_max_source_bytes: 8388608,
    scripts_max_path_chars: 1048576,
  }),
);
