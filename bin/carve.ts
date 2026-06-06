#!/usr/bin/env -S node --disable-warning=ExperimentalWarning
// bin/carve.ts — 엔트리포인트. 로직은 src/cli.ts에 있다.
// shebang의 --disable-warning: Node의 .ts 타입 스트리핑 ExperimentalWarning을 숨겨
// 사용자가 carve 실행 시마다 경고를 보지 않게 한다 (Node 21.3+ 지원).
import { run, isInteractiveInstall, installDir, parseLevel } from '../src/cli.ts';

const argv = process.argv.slice(2);
const lvl = parseLevel(argv);

// 대화형 설치: TTY에서 인자 없음(`carve`) 또는 `carve install`(+ --only/--yes 없음) → wizard 선택 설치.
// --level은 wizard 추천 베이스라인에 반영해 전달한다. 잘못된 --level은 run()으로 보내 검증·exit 1.
if (lvl !== 'invalid' && isInteractiveInstall(argv, Boolean(process.stdin.isTTY))) {
  const { interactiveInstall } = await import('../src/commands.ts');
  process.exit(await interactiveInstall(installDir(argv), console, lvl));
} else {
  process.exit(run(argv));
}
