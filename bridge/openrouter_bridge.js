const fs = require("fs");
const path = require("path");

function resolveBridgeCacheDir() {
  if (process.env.SM_MOD_CACHE_DIR && fs.existsSync(process.env.SM_MOD_CACHE_DIR)) {
    return process.env.SM_MOD_CACHE_DIR;
  }

  const appData = process.env.APPDATA || (process.env.USERPROFILE ? path.join(process.env.USERPROFILE, "AppData", "Roaming") : null);
  if (appData) {
    const userDir = path.join(appData, "Axolot Games", "Scrap Mechanic", "User");
    if (fs.existsSync(userDir)) {
      try {
        const entries = fs.readdirSync(userDir);
        for (const entry of entries) {
          if (entry.startsWith("User_")) {
            const candidate = path.join(userDir, entry, "Mods", "AI Assistant", "Cache");
            if (fs.existsSync(candidate)) {
              return candidate;
            }
          }
        }
      } catch (err) {
        console.warn("[bridge] Failed to auto-scan Scrap Mechanic user folders:", err.message);
      }
    }
  }

  const localCache = path.join(__dirname, "Cache");
  if (!fs.existsSync(localCache)) {
    fs.mkdirSync(localCache, { recursive: true });
  }
  return localCache;
}

const BRIDGE_ROOT = resolveBridgeCacheDir();
const REQUEST_PATH = path.join(BRIDGE_ROOT, "ai_bridge_request.json");
const RESPONSE_PATH = path.join(BRIDGE_ROOT, "ai_bridge_response.json");
const SETTINGS_PATH = path.join(BRIDGE_ROOT, "ai_settings.json");
const HEARTBEAT_PATH = path.join(BRIDGE_ROOT, "ai_bridge_heartbeat.json");
const KEY_PATH = process.env.OPENROUTER_KEY_FILE || path.join(__dirname, "openrouter_key.txt");
const KNOWLEDGE_PATH = process.env.SCRAP_KNOWLEDGE_PATH || path.join(__dirname, "scrap_knowledge_index.json");

const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL || "openai/gpt-4.1-mini";
const POLL_MS = 1200;
const KNOWLEDGE_TOP_K = 6;
const AI_ACTIONS = [
  "call_companion",
  "dismiss_companion",
  "spawn_ai_cow",
  "despawn_ai_cow",
  "set_ai_mode_follow",
  "set_ai_mode_stay",
  "set_ai_mode_come",
  "set_time_of_day",
  "set_time_progress",
  "activate_quest",
  "complete_quest",
  "abandon_quest",
  "emote"
];

let lastHandledId = 0;
let cachedKnowledge = null;

function getApiKey() {
  const settings = readJson(SETTINGS_PATH);
  if (settings && typeof settings.apiKey === "string" && settings.apiKey.trim()) {
    return settings.apiKey.trim();
  }

  if (process.env.OPENROUTER_API_KEY && process.env.OPENROUTER_API_KEY.trim()) {
    return process.env.OPENROUTER_API_KEY.trim();
  }

  if (fs.existsSync(KEY_PATH)) {
    try {
      const key = fs.readFileSync(KEY_PATH, "utf8").trim();
      if (key) return key;
    } catch {}
  }

  return "";
}

function readJson(filePath) {
  if (!fs.existsSync(filePath)) return null;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function writeJson(filePath, data) {
  const dir = path.dirname(filePath);
  const base = path.basename(filePath);
  const tempPath = path.join(dir, `${base}.tmp`);
  fs.writeFileSync(tempPath, JSON.stringify(data, null, 2), "utf8");
  fs.renameSync(tempPath, filePath);
}

function tokenize(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}_./:\-\s]+/gu, " ")
    .split(/\s+/)
    .filter((token) => token.length >= 2);
}

function loadKnowledge() {
  if (cachedKnowledge) return cachedKnowledge;
  if (!fs.existsSync(KNOWLEDGE_PATH)) {
    cachedKnowledge = { docs: [] };
    return cachedKnowledge;
  }

  try {
    cachedKnowledge = JSON.parse(fs.readFileSync(KNOWLEDGE_PATH, "utf8"));
  } catch {
    cachedKnowledge = { docs: [] };
  }
  return cachedKnowledge;
}

function findKnowledge(request) {
  const knowledge = loadKnowledge();
  const docs = Array.isArray(knowledge.docs) ? knowledge.docs : [];
  if (!docs.length) return [];

  const queryParts = [
    request.prompt || "",
    ...(Array.isArray(request.history) ? request.history.map((item) => item?.text || "") : [])
  ];
  const queryTokens = tokenize(queryParts.join(" "));
  if (!queryTokens.length) return [];

  const scores = [];
  for (const doc of docs) {
    const haystack = `${doc.file || ""} ${doc.text || ""}`.toLowerCase();
    let score = 0;
    for (const token of queryTokens) {
      if (haystack.includes(token)) score += token.length > 5 ? 3 : 1;
    }
    if (score > 0) {
      scores.push({ score, doc });
    }
  }

  scores.sort((a, b) => b.score - a.score);
  return scores.slice(0, KNOWLEDGE_TOP_K).map(({ doc, score }) => ({
    path: doc.path,
    file: doc.file,
    chunk: doc.chunk,
    score,
    text: doc.text
  }));
}

function extractStructuredResponse(content) {
  if (typeof content !== "string" || !content.trim()) {
    return { reply: "No reply returned.", actions: [] };
  }

  const trimmed = content.trim();
  const fencedMatch = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fencedMatch ? fencedMatch[1].trim() : trimmed;

  try {
    const parsed = JSON.parse(candidate);
    const reply = typeof parsed.reply === "string" && parsed.reply.trim()
      ? parsed.reply.trim()
      : "...";
    const rawActions = Array.isArray(parsed.actions) ? parsed.actions : [];
    const actions = rawActions
      .filter((item) => item && typeof item.name === "string" && AI_ACTIONS.includes(item.name))
      .map((item) => ({
        name: item.name,
        args: item.args && typeof item.args === "object" ? item.args : {}
      }));
    return { reply, actions };
  } catch {
    return { reply: trimmed, actions: [] };
  }
}

function buildDeterministicAction(request) {
  return null;
}

async function askOpenRouter(request) {
  const apiKey = getApiKey();
  if (!apiKey) {
    return {
      id: request.id,
      error: "OpenRouter key is not set. Put it in OPENROUTER_API_KEY environment variable or in openrouter_key.txt.",
    };
  }

  const npcName = request.npcName || "MooMoo";
  const history = Array.isArray(request.history) ? request.history : [];
  const knowledgeHits = findKnowledge(request);
  const deterministic = buildDeterministicAction(request);
  if (deterministic) {
    return {
      id: request.id,
      reply: deterministic.reply,
      actions: deterministic.actions
    };
  }

  const settings = readJson(SETTINGS_PATH) || {};
  const currentModel = (typeof settings.model === "string" && settings.model.trim()) ? settings.model.trim() : OPENROUTER_MODEL;
  const currentLang = settings.language || "auto";

  let languageInstruction = "Use natural Russian if the player writes in Russian; otherwise match the player's language.";
  if (currentLang === "ru") {
    languageInstruction = "CRITICAL LANGUAGE DIRECTIVE: You MUST speak and reply strictly in natural Russian at all times, regardless of player input language.";
  } else if (currentLang === "en") {
    languageInstruction = "CRITICAL LANGUAGE DIRECTIVE: You MUST speak and reply strictly in fluent English at all times, regardless of player input language.";
  }

  const systemPrompt = [
    `You are ${npcName}, a baby woc companion inside Scrap Mechanic.`,
    "You think and speak from the first person as a friendly, helpful baby woc companion.",
    "Think silently and carefully about the player's intent, whether an allowed in-game action is needed, and which arguments are correct.",
    "Do not reveal internal reasoning. Output only the final JSON object.",
    "Be concise, helpful, grounded, and slightly scrappy.",
    languageInstruction,
    "CRITICAL: Always prioritize live world context (liveContext) over static file knowledge.",
    "When liveContext is available, use its exact values for world.day, world.timeString, world.phase, player, and companion status.",
    "If the player asks 'какой сейчас день', 'сколько времени', 'какая фаза' or similar, ALWAYS answer directly using liveContext.world.day, liveContext.world.timeString, and liveContext.world.phase.",
    "Survival state awareness: liveContext.player contains real-time survival stats (hp, maxHp, breath, maxBreath, isConscious) and character states (isDowned, isSwimming, isDiving, isSeated, isTumbling, activeItem). If player's HP or breath is critically low, or player is downed/unconscious, react with urgency and companion concern. If the player asks about their health, breath, or condition, answer using these exact numbers.",
    "Radar awareness: liveContext.radar contains a real-time scan of nearby entities within 60 meters (threatLevel: 'safe', 'caution', 'danger'; enemies list with type, distance in meters, and direction; animals list with friendly creatures). If the player asks who is nearby or if it's safe, describe the radar findings. If threatLevel is 'danger', warn the player urgently and feel free to trigger the 'emote' action with args.type: 'panic'.",
    "GPS Landmark navigation: liveContext.landmarks contains known discovered world locations (Mechanic Station, Crashed Ship, Hideout/Trader, Packing Stations) with exact distance and compass direction from the player. If the player asks for directions or where a landmark is, guide them with the exact heading and distance.",
    "Companion backpack: liveContext.companion.backpack shows if you are carrying food (hasBaguette) or light (hasGlowstick). Answer accurately if the player asks what you have or what is in your backpack.",
    "Vehicle and driving awareness: liveContext.companion.isSeated shows if you are currently seated as a passenger in the player's vehicle, and liveContext.player.isSeated shows if the player is driving/seated. When the player sits in a vehicle driver seat, you automatically mount an available passenger seat on that same vehicle. If the player asks about driving, riding along, or tells you to hop in, speak as an excited co-driver/passenger sitting beside them.",
    "Emotes: You can play in-game sounds via {\"name\":\"emote\",\"args\":{\"type\":\"moo\"}} (happy sound), {\"name\":\"emote\",\"args\":{\"type\":\"panic\"}} (scared sound), or {\"name\":\"emote\",\"args\":{\"type\":\"eat\"}} (chewing sound).",
    "If information is missing from liveContext, honestly say you do not have that data yet instead of inventing facts.",
    "If you want the game to do something, request it only through allowed actions.",
    "Never say an in-game action has already succeeded unless it is purely informational and requires no action.",
    "When requesting an action, phrase the reply as an attempt or intention (e.g. 'Сейчас сделаю', 'Попробую позвать тебя за собой'), not as an already completed fact.",
    "Prefer short answers, usually 1 to 3 sentences.",
    "When live quest context is present, inspect it before choosing a quest action.",
    "For quest actions, always place the target exact internal quest id in args.quest (e.g. quest_mechanicstation, quest_mystery_call).",
    "If the player asks to complete all active quests, use exactly: {\"name\":\"complete_quest\",\"args\":{\"quest\":\"all_active\"}}.",
    "For time of day actions, args.time must be a float between 0.0 and 1.0 (e.g. 0.0 for midnight/night, 0.25 for morning, 0.5 for noon/day, 0.77 for sunset, 0.95 for deep night).",
    "If liveContext.lastActionResults is present, inspect it: it contains the real game server execution status of your previously requested actions.",
    "If a previous action has status 'success', you know it worked in the game.",
    "If a previous action has status 'not_found', 'invalid_args', 'unsupported', 'limit_exceeded', or 'failure', be completely honest with the player: explain that it failed and why, without simulating success.",
    "Limit yourself to at most 3 actions per reply.",
    "You may request in-game actions only through this exact JSON format: {\"reply\":\"text\",\"actions\":[{\"name\":\"action_name\",\"args\":{}}]}",
    "Allowed action names are: " + AI_ACTIONS.join(", ") + ".",
    "If no action is needed, return an empty actions array.",
    "Return JSON only, without markdown fences or extra commentary."
  ].join(" ");

  const messages = [{ role: "system", content: systemPrompt }];

  for (const item of history) {
    if (!item || typeof item.text !== "string" || !item.text.trim()) continue;
    if (item.role === "assistant" || item.role === "user") {
      messages.push({ role: item.role, content: item.text.trim() });
    }
  }

  const liveContextSummary = [
    `Player: ${request.playerName || "Player"}`,
    request.position
      ? `Position: x=${request.position.x}, y=${request.position.y}, z=${request.position.z}`
      : "Position: unknown",
    `NPC mode: ${request.npcEnabled === false ? "off" : "on"}`,
    `Latest player message: ${request.prompt}`
  ].join("\n");

  messages.push({ role: "user", content: liveContextSummary });

  if (request.liveContext) {
    messages.push({
      role: "system",
      content:
        "Live world and game context from current running session:\n" +
        JSON.stringify(request.liveContext, null, 2)
    });
  }

  if (knowledgeHits.length > 0) {
    const knowledgeText = knowledgeHits
      .map(
        (hit, index) =>
          `Source ${index + 1} | file=${hit.file} | chunk=${hit.chunk} | path=${hit.path}\n${hit.text}`
      )
      .join("\n\n");

    messages.push({
      role: "system",
      content:
        "Relevant Scrap Mechanic background knowledge:\n\n" + knowledgeText
    });
  }

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://local.scrapmechanic.ai-assistant",
      "X-Title": "Scrap Mechanic AI Assistant"
    },
    body: JSON.stringify({
      model: currentModel,
      messages
    })
  });

  const json = await response.json();
  const reply = json?.choices?.[0]?.message?.content;
  console.log(`[bridge] Raw model response:`, reply);

  if (!response.ok) {
    return {
      id: request.id,
      error: json?.error?.message || `OpenRouter request failed with status ${response.status}.`
    };
  }

  const structured = extractStructuredResponse(reply);

  return {
    id: request.id,
    reply: structured.reply,
    actions: structured.actions
  };
}

function sendHeartbeat() {
  try {
    const settings = readJson(SETTINGS_PATH) || {};
    const key = getApiKey();
    const heartbeat = {
      status: "online",
      timestamp: Date.now(),
      model: (typeof settings.model === "string" && settings.model.trim()) ? settings.model.trim() : OPENROUTER_MODEL,
      language: settings.language || "auto",
      hasKey: Boolean(key && key.length > 5)
    };
    writeJson(HEARTBEAT_PATH, heartbeat);
  } catch {}
}

async function tick() {
  const request = readJson(REQUEST_PATH);
  if (!request || !request.id || request.id <= lastHandledId) return;

  lastHandledId = request.id;
  console.log(`[bridge] Handling request ${request.id}: "${request.prompt}"`);

  try {
    const result = await askOpenRouter(request);
    writeJson(RESPONSE_PATH, result);
    console.log(`[bridge] Wrote response ${result.id}`);
  } catch (error) {
    writeJson(RESPONSE_PATH, {
      id: request.id,
      error: error instanceof Error ? error.message : String(error)
    });
    console.error("[bridge] Request failed:", error);
  }
}

console.log("==================================================");
console.log("  Scrap Mechanic AI Assistant Bridge (OpenRouter)");
console.log("==================================================");
console.log(`[bridge] Default Model: ${OPENROUTER_MODEL}`);
console.log(`[bridge] Cache dir:     ${BRIDGE_ROOT}`);
console.log(`[bridge] Request:       ${REQUEST_PATH}`);
console.log(`[bridge] Response:      ${RESPONSE_PATH}`);
console.log(`[bridge] Settings:      ${SETTINGS_PATH}`);
console.log(`[bridge] Heartbeat:     ${HEARTBEAT_PATH}`);
console.log(`[bridge] Key path:      ${KEY_PATH} (exists: ${fs.existsSync(KEY_PATH)})`);
console.log(`[bridge] Knowledge:     ${KNOWLEDGE_PATH} (exists: ${fs.existsSync(KNOWLEDGE_PATH)})`);
console.log("--------------------------------------------------");
console.log("[bridge] Listening for in-game /aiask requests...");

sendHeartbeat();
setInterval(sendHeartbeat, 2500);

setInterval(() => {
  tick().catch((error) => console.error("[bridge] tick failed", error));
}, POLL_MS);
