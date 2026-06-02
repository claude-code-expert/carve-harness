// src/cli.ts — carve CLI 코어 (레이어 A)
// bin/carve.ts는 이 모듈의 얇은 진입점일 뿐이다. 로직은 여기서 테스트한다.
import { readFileSync } from 'node:fs';
import { cmdList, cmdInstall, cmdDoctor, cmdUninstall, cmdInitClaude } from './commands.ts';
import type { HarnessLevel } from './designer.ts';

/** 테스트 주입용 출력 채널 (console과 호환) */
export interface IO {
  log: (msg: string) => void;
  error: (msg: string) => void;
}

/** package.json에서 버전을 읽는다. */
export function loadVersion(): string {
  const pkg = JSON.parse(
    readFileSync(new URL('../package.json', import.meta.url), 'utf8'),
  ) as { version: string };
  return pkg.version;
}

export const USAGE = `carve — 프로젝트에 맞는 하네스를 깎아 설치하는 CLI

사용법:
  carve [install]      대화형으로 구성요소를 선택해 설치 (일괄 설치 없음)
                       옵션: --level <minimal|standard|full> (레벨 강제) · --only a,b (명시 선택) · --lsp-servers
  carve init-claude    CLAUDE.md 베이스라인 + .claude/rules/* 생성 (언어 스택 기준)
  carve uninstall      설치한 하네스 자산을 클린 제거
  carve list           설치 가능/설치된 구성요소 목록
  carve doctor         설치된 하네스를 감사 (보안·권한·문법)

옵션:
  -v, --version        버전 출력
  -h, --help           이 도움말 출력`;

// 알려진 명령.
export const KNOWN_COMMANDS = ['install', 'init-claude', 'uninstall', 'list', 'doctor'] as const;

/** `--only a,b,c` 또는 `--only=a,b,c` → 선택 id 배열. 없으면 undefined. */
export function parseOnly(args: string[]): string[] | undefined {
  const split = (v: string) => v.split(',').map((s) => s.trim()).filter(Boolean);
  const eq = args.find((a) => a.startsWith('--only='));
  if (eq) return split(eq.slice('--only='.length));
  const i = args.indexOf('--only');
  const next = i >= 0 ? args[i + 1] : undefined;
  if (next !== undefined && !next.startsWith('-')) return split(next);
  return undefined;
}

/** `--flag value` 또는 `--flag=value` → value. 없으면 undefined. */
function flagValue(args: string[], name: string): string | undefined {
  const eq = args.find((a) => a.startsWith(`${name}=`));
  if (eq) return eq.slice(name.length + 1);
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
}

/** `--level <minimal|standard|full>` → 레벨. 잘못된 값은 'invalid', 없으면 undefined. */
export function parseLevel(args: string[]): HarnessLevel | 'invalid' | undefined {
  const raw = flagValue(args, '--level');
  if (raw === undefined) return undefined;
  const levels: HarnessLevel[] = ['minimal', 'standard', 'full'];
  return levels.includes(raw as HarnessLevel) ? (raw as HarnessLevel) : 'invalid';
}

/**
 * 진입점이 대화형 설치(wizard)로 갈지 결정한다.
 * 조건: 인자 없음(`carve`) 또는 `carve install` + (--only/--yes 없음) + TTY.
 * (--only/--yes는 비대화형 의도이므로 run()으로 보낸다.)
 */
export function isInteractiveInstall(args: string[], isTTY: boolean): boolean {
  const intent = args.length === 0 || args[0] === 'install';
  const hasOnly = args.includes('--only') || args.some((a) => a.startsWith('--only='));
  return intent && !hasOnly && !args.includes('--yes') && isTTY;
}

/** 대화형 설치 대상 디렉토리: 첫 비플래그 위치 인자, 없으면 cwd. */
export function installDir(args: string[]): string {
  const rest = args[0] === 'install' ? args.slice(1) : args;
  return rest.find((a) => !a.startsWith('-')) ?? process.cwd();
}

/**
 * 인자를 해석해 동작을 수행한다. 종료 코드를 반환한다.
 * @param args  process.argv.slice(2)
 * @param io    테스트 주입용 출력 채널
 */
export function run(args: string[], io: IO = console): number {
  const cmd = args[0];

  if (cmd === undefined || cmd === '--help' || cmd === '-h') {
    io.log(USAGE);
    return 0;
  }
  if (cmd === '--version' || cmd === '-v') {
    io.log(loadVersion());
    return 0;
  }

  // 대상 디렉토리: 플래그가 아닌 첫 위치 인자 또는 현재 작업 디렉토리
  const positionals = args.slice(1).filter((a) => !a.startsWith('-'));
  const dir = positionals[0] ?? process.cwd();
  switch (cmd) {
    case 'list':
      return cmdList(io);
    case 'install': {
      const lvl = parseLevel(args);
      if (lvl === 'invalid') {
        io.error('--level 값은 minimal | standard | full 중 하나여야 합니다.');
        return 1;
      }
      return cmdInstall(dir, io, parseOnly(args), args.includes('--lsp-servers'), lvl);
    }
    case 'init-claude':
      return cmdInitClaude(dir, io);
    case 'doctor':
      return cmdDoctor(dir, io);
    case 'uninstall':
      return cmdUninstall(dir, io);
  }

  io.error(`알 수 없는 명령: ${cmd}\n\n${USAGE}`);
  return 1;
}
