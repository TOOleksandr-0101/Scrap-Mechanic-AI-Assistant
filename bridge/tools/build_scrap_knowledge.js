const fs = require("fs");
const path = require("path");

function getGameSurvivalDir() {
  if (process.env.SM_GAME_DIR && fs.existsSync(process.env.SM_GAME_DIR)) {
    return process.env.SM_GAME_DIR;
  }

  const candidates = [
    String.raw`H:\SteamLibrary\steamapps\common\Scrap Mechanic`,
    String.raw`C:\Program Files (x86)\Steam\steamapps\common\Scrap Mechanic`,
    String.raw`D:\SteamLibrary\steamapps\common\Scrap Mechanic`,
    String.raw`E:\SteamLibrary\steamapps\common\Scrap Mechanic`
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) return candidate;
  }

  return candidates[0];
}

const GAME_DIR = getGameSurvivalDir();
const ROOTS = [
  path.join(GAME_DIR, "Survival", "Scripts", "game"),
  path.join(GAME_DIR, "Survival", "Character", "CharacterSets"),
  path.join(GAME_DIR, "Survival", "CraftingRecipes"),
  path.join(GAME_DIR, "Survival", "BuilderGuides"),
  path.join(GAME_DIR, "Survival", "Dialog"),
  path.join(GAME_DIR, "Survival", "ScriptJsonFiles"),
  path.join(GAME_DIR, "Data", "Objects"),
  path.join(GAME_DIR, "Data", "Harvestables"),
  path.join(GAME_DIR, "Data", "Character")
];

const OUTPUT_PATH = path.resolve(__dirname, "..", "scrap_knowledge_index.json");
const MAX_FILE_BYTES = 512 * 1024;
const CHUNK_SIZE = 2200;

function walk(dir, results = []) {
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(fullPath, results);
      continue;
    }

    if (!/\.(lua|json|txt)$/i.test(entry.name)) continue;
    try {
      const stat = fs.statSync(fullPath);
      if (stat.size <= MAX_FILE_BYTES) {
        results.push(fullPath);
      }
    } catch {}
  }
  return results;
}

function normalize(text) {
  return text
    .replace(/\r/g, "")
    .replace(/[^\p{L}\p{N}_./:\-\s]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function splitIntoChunks(text) {
  const chunks = [];
  let cursor = 0;
  while (cursor < text.length) {
    const part = text.slice(cursor, cursor + CHUNK_SIZE);
    chunks.push(part.trim());
    cursor += CHUNK_SIZE;
  }
  return chunks.filter(Boolean);
}

function build() {
  console.log(`[knowledge] Scanning game files in: ${GAME_DIR}`);
  const files = ROOTS.flatMap((root) => walk(root));
  const docs = [];

  for (const filePath of files) {
    let raw;
    try {
      raw = fs.readFileSync(filePath, "utf8");
    } catch {
      continue;
    }

    const cleaned = normalize(raw);
    if (!cleaned) continue;

    const matchingRoot = ROOTS.find((root) => filePath.startsWith(root));
    const relative = matchingRoot ? path.relative(matchingRoot, filePath) : filePath;

    const chunks = splitIntoChunks(cleaned);
    for (let i = 0; i < chunks.length; i += 1) {
      docs.push({
        id: `${relative}#${i + 1}`,
        path: filePath,
        file: path.basename(filePath),
        chunk: i + 1,
        text: chunks[i]
      });
    }
  }

  fs.mkdirSync(path.dirname(OUTPUT_PATH), { recursive: true });
  fs.writeFileSync(
    OUTPUT_PATH,
    JSON.stringify(
      {
        generatedAt: new Date().toISOString(),
        roots: ROOTS,
        count: docs.length,
        docs
      },
      null,
      2
    ),
    "utf8"
  );

  console.log(`[knowledge] Saved ${docs.length} knowledge chunks to ${OUTPUT_PATH}`);
}

build();
