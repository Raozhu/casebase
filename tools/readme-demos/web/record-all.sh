#!/bin/zsh
# Records every README demo in both languages. The round-table scene needs the isolated
# 12 Knights demo instance; this script restarts it with fresh data for each language.
set -uo pipefail
HERE=${0:A:h}
ROOT=${HERE:h:h:h}
KNIGHTS=$ROOT/build/readme-demos/knights
cd $HERE

SCENES=(${=SCENES:-drop text shot ask meeting mcp})
LANGS=(${=LANGS:-zh en})
for lang in $LANGS; do
  for scene in $SCENES; do
    node record.mjs $scene $lang | tail -1
  done
done

for lang in $LANGS; do
  [[ ${SKIP_ROUNDTABLE:-} == 1 ]] && break
  CB=$ROOT/build/readme-demos/demo-cb-$lang/storage
  RECORD=$(sqlite3 $CB/casebase.sqlite "select id from records where title like 'Q4%' limit 1")
  lsof -ti tcp:3799 | xargs kill 2>/dev/null; sleep 1
  rm -rf $KNIGHTS/data $KNIGHTS/projects; mkdir -p $KNIGHTS/projects $CB/inbox/12knights
  python3 - "$KNIGHTS/agents.json" "$CB" <<'PY'
import json, sys
path, cb = sys.argv[1], sys.argv[2]
c = json.load(open(path))
c["knowledge"]["casebase"] = {"root": cb, "inbox": cb + "/inbox/12knights", "mcp": "/nonexistent"}
c["knowledge"]["threshold"] = 9  # no "found related records" card in the demo
json.dump(c, open(path, "w"), ensure_ascii=False, indent=2)
PY
  echo '{}' > $KNIGHTS/mock-say.json
  # Projects outside the home folder's own tree, so the page shows a neutral "~/12 Knights demo/…" path.
  DEMO_PROJECTS="/Users/Shared/12 Knights demo"; rm -rf "$DEMO_PROJECTS"; mkdir -p "$DEMO_PROJECTS"
  (cd $KNIGHTS && PROJECTS_ROOT="$DEMO_PROJECTS" PORT=3799 MOCK=1 MOCK_STEPS=0 MOCK_SAY=$KNIGHTS/mock-say.json node server.js > server.log 2>&1 &)
  for i in {1..20}; do curl -s -m 1 127.0.0.1:3799/api/health >/dev/null && break; sleep 0.5; done
  node setup-knights.mjs $lang http://127.0.0.1:3799 $KNIGHTS/mock-say.json
  SAY=$([[ $lang == zh ]] && echo "这个定价方案有什么风险？" || echo "Any risks with this pricing?")
  node record-live.mjs $lang --record $RECORD --say "$SAY" | tail -1
done
lsof -ti tcp:3799 | xargs kill 2>/dev/null
rm -rf "/Users/Shared/12 Knights demo"
echo done
