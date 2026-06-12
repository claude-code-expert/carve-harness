// src/cli.ts — carve CLI 코어 (레이어 A)
// bin/carve.ts는 이 모듈의 얇은 진입점일 뿐이다. 로직은 여기서 테스트한다.
import { readFileSync } from 'node:fs';
import {
  cmdList, cmdInstall, cmdDoctor, cmdUninstall, cmdInitClaude,
  cmdUpdate, cmdDiff, cmdMigrate, cmdReport,
} from './commands.ts';
import type { HarnessLevel } from './designer.ts';
import { RESPONSE_LANGS, type ResponseLang } from './claudebase.ts';

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
                       옵션: --lang <en-ko|en|ko> (응답 언어 정책, 기본 en-ko)
  carve uninstall      설치한 하네스 자산을 클린 제거
  carve list           설치 가능/설치된 구성요소 목록
  carve doctor         설치된 하네스를 감사 (보안·권한·문법)
  carve diff           설치 자산을 매니페스트/현재 carve 자산과 3-way 비교 (읽기 전용)
  carve update         carve 갱신분만 제자리 갱신·사용자 수정 보존 (--force · --yes)
  carve migrate        v1 매니페스트를 v2로 무손실 이관 (파일별 해시 back-fill)
  carve report         설치 훅의 로컬 효과 텔레메트리 집계 (opt-in)

옵션:
  -v, --version        버전 출력
  -h, --help           이 도움말 출력`;

// 알려진 명령.
export const KNOWN_COMMANDS = ['install', 'init-claude', 'uninstall', 'list', 'doctor', 'diff', 'update', 'migrate', 'report'] as const;

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

/** `--lang <en-ko|en|ko>` → 응답 언어 정책 (init-claude). 잘못된 값은 'invalid', 없으면 undefined(기본 en-ko). */
export function parseLang(args: string[]): ResponseLang | 'invalid' | undefined {
  const raw = flagValue(args, '--lang');
  if (raw === undefined) return undefined;
  return (RESPONSE_LANGS as readonly string[]).includes(raw) ? (raw as ResponseLang) : 'invalid';
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
  // 에러 경계: 손상 settings.json/manifest 등 커맨드가 throw하면 스택 대신 사유 + exit 1.
  try {
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
      case 'init-claude': {
        const lang = parseLang(args);
        if (lang === 'invalid') {
          io.error('--lang 값은 en-ko | en | ko 중 하나여야 합니다.');
          return 1;
        }
        return cmdInitClaude(dir, io, lang);
      }
      case 'doctor':
        return cmdDoctor(dir, io);
      case 'uninstall':
        return cmdUninstall(dir, io);
      case 'diff':
        return cmdDiff(dir, io);
      case 'migrate':
        return cmdMigrate(dir, io);
      case 'report':
        return cmdReport(dir, io);
      case 'update':
        return cmdUpdate(dir, io, { yes: args.includes('--yes'), force: args.includes('--force') });
    }
  } catch (e) {
    io.error(`오류: ${(e as Error).message}`);
    return 1;
  }

  io.error(`알 수 없는 명령: ${cmd}\n\n${USAGE}`);
  return 1;
}
