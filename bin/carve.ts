#!/usr/bin/env -S node --disable-warning=ExperimentalWarning
// bin/carve.ts — 엔트리포인트. 로직은 src/cli.ts에 있다.
// shebang의 --disable-warning: Node의 .ts 타입 스트리핑 ExperimentalWarning을 숨겨
// 사용자가 carve 실행 시마다 경고를 보지 않게 한다 (Node 21.3+ 지원).
import { run } from '../src/cli.ts';

const argv = process.argv.slice(2);

// 대화형 설치: TTY + install + --only/--yes 없음 → wizard로 선택 설치 (일괄 설치 없음)
if (
  argv[0] === 'install' &&
  !argv.includes('--only') &&
  !argv.some((a) => a.startsWith('--only=')) &&
  !argv.includes('--yes') &&
  process.stdin.isTTY
) {
  const { interactiveInstall } = await import('../src/commands.ts');
  const dir = argv.slice(1).find((a) => !a.startsWith('-')) ?? process.cwd();
  process.exit(await interactiveInstall(dir, console));
} else {
  process.exit(run(argv));
}
