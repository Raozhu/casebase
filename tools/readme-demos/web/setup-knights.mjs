// Prepares the isolated 12 Knights demo instance: a seated base table, and scripted
// (MOCK_SAY) lines keyed by the names the instance gave its members.
//   node setup-knights.mjs <lang> <rt url> <mock-say.json path>
import { writeFile } from "node:fs/promises";

const [lang = "zh", rt = "http://127.0.0.1:3799", sayFile] = process.argv.slice(2);
const L = (en, zh) => (lang === "zh" ? zh : en);
const api = (path, body) => fetch(`${rt}${path}`, {
  method: body ? "POST" : "GET",
  headers: { "content-type": "application/json" },
  body: body ? JSON.stringify(body) : undefined,
}).then((r) => r.json());

const base = await api("/api/conv", { name: L("Launch prep", "发布准备"), members: [{ id: "claude" }] });
const added = (await api(`/api/conv/${base.id}/members`, { ids: ["r-finance", "r-marketing"] })).added;
const finance = added.find((m) => m.title === "财务" || /financ/i.test(m.title)).name;
const marketing = added.find((m) => m.title === "市场营销" || /market/i.test(m.title)).name;

const lead = L(
  `I read the meeting notes: $12 a month, $99 a year, and annual gets the export add-on. @${finance} @${marketing} take a look from your side.`,
  `我看了会议记录：定价是月付 12 美元、年付 99 美元，年付送导出功能。@${finance} @${marketing} 从各自角度看看有没有风险。`
);
const lines = {
  Claude: [lead],
  Gpt: [lead],
  [finance]: [L(
    "At $12 the research shows 38% trial-to-paid, 13 points above $15. $99 a year is about 30% off, so cash comes in earlier and margin still holds.",
    "按调研数据，12 美元的试用转付费率是 38%，比 15 美元高 13 个点。年付 99 美元约等于打 7 折，现金流回得更早，毛利率没问题。"
  )],
  [marketing]: [L(
    "The risk is the export add-on: if monthly users want it too, annual loses its pull. Put \"export included with annual\" at the top of the launch page.",
    "风险在导出功能：如果月付用户也很需要它，年付就没那么有吸引力。建议发布页第一屏就写「年付送导出」。"
  )],
  _delay: { [finance]: 500, [marketing]: 900 },
};
await writeFile(sayFile, JSON.stringify(lines, null, 2));
console.log(JSON.stringify({ base: base.id, finance, marketing }));
