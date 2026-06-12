// src/auditor.ts — 생성물 자기 검증 (레이어 A). secret 노출·과도 권한·훅 주입 + 셸 문법 스캔.
// 설치 전 carve가 자기 산출물을 검사한다(PoC: secret·권한 0건 확인).
import { spawnSync } from 'node:child_process';
import type { Artifact } from './generator.ts';

export type Severity = 'ERROR' | 'WARN';

export interface AuditFinding {
  path: string;
  line: number;
  rule: string;
  severity: Severity;
  message: string;
}

// 시크릿 패턴 (하드코딩된 키/토큰)
const SECRET_RULES: { rule: string; re: RegExp }[] = [
  { rule: 'aws-key', re: /AKIA[0-9A-Z]{16}/ },
  { rule: 'private-key', re: /-----BEGIN [A-Z ]*PRIVATE KEY-----/ },
  { rule: 'github-token', re: /\bghp_[A-Za-z0-9]{36}\b|\bgithub_pat_[A-Za-z0-9_]{22,}/ },
  { rule: 'openai-key', re: /\bsk-[A-Za-z0-9]{20,}\b/ },
  { rule: 'slack-token', re: /\bxox[baprs]-[A-Za-z0-9-]{10,}/ },
];

/** 산출물 목록을 스캔해 보안 findings를 반환한다. */
export function audit(artifacts: Artifact[]): AuditFinding[] {
  const findings: AuditFinding[] = [];
  for (const a of artifacts) {
    const isHook = a.path.includes('/hooks/');
    a.content.split(/\r?\n/).forEach((line, i) => {
      const at = (rule: string, severity: Severity, message: string) =>
        findings.push({ path: a.path, line: i + 1, rule, severity, message });

      for (const { rule, re } of SECRET_RULES) {
        if (re.test(line)) at(rule, 'ERROR', `secret 노출 의심(${rule})`);
      }
      // 원격 코드 실행 (curl|bash) — 훅 주입/RCE.
      // 셸 스크립트의 비주석 줄만 검사한다 — 문서(.md)가 패턴을 "언급"만 해도 설치가 막히는 FP 방지.
      if (a.path.endsWith('.sh') && !line.trimStart().startsWith('#')
        && /(curl|wget)\b[^|]*\|\s*(bash|sh)\b/.test(line)) {
        at('remote-exec', 'ERROR', '원격 코드 실행(curl|bash) — 신뢰 불가');
      }
      // 과도 권한 (0777·멀티 플래그 변형 포함: chmod 0777 /, chmod -fR 777 …)
      if (/chmod\s+(-[a-zA-Z]+\s+)*0?777\b/.test(line)) at('chmod-777', 'ERROR', '과도 권한(chmod 777)');
      if (/\bsudo\b/.test(line)) at('sudo', 'WARN', 'sudo 사용 — 권한 상승');
      // 하드코딩 비밀번호 의심 — backreference로 여닫는 인용부호 일치 강제(불일치 인용 FP 방지)
      if (/password\s*[:=]\s*(['"])[^'"]{3,}\1/i.test(line)) {
        at('hardcoded-password', 'WARN', '하드코딩 비밀번호 의심');
      }
      // 훅 주입: 훅 스크립트가 settings.json/다른 훅을 기록·수정
      if (isHook && /(settings\.json|\.claude\/hooks\/)/.test(line) && /(>>?|tee|writeFile)/.test(line)) {
        at('hook-injection', 'ERROR', '훅이 settings/훅을 수정(주입)');
      }
    });
  }
  return findings;
}

/**
 * 생성된 셸 훅을 실제 문법 검사한다. shellcheck 있으면 사용, 없으면 `bash -n` 폴백.
 * (v1.3 #3·#4 — 정적 룰을 넘어 결정적 셸 검증)
 */
export function auditShellSyntax(artifacts: Artifact[]): AuditFinding[] {
  const findings: AuditFinding[] = [];
  const hasShellcheck = spawnSync('sh', ['-c', 'command -v shellcheck']).status === 0;
  for (const a of artifacts) {
    if (!a.path.endsWith('.sh')) continue;
    const bn = spawnSync('bash', ['-n'], { input: a.content, encoding: 'utf8' });
    if (bn.status !== 0) {
      const msg = (bn.stderr || '').trim().split('\n')[0] || 'syntax error';
      findings.push({ path: a.path, line: 0, rule: 'shell-syntax', severity: 'ERROR', message: `bash -n 실패: ${msg}` });
      continue;
    }
    if (hasShellcheck) {
      const sc = spawnSync('shellcheck', ['-S', 'error', '-'], { input: a.content, encoding: 'utf8' });
      if (sc.status !== 0) {
        findings.push({ path: a.path, line: 0, rule: 'shellcheck', severity: 'ERROR', message: 'shellcheck error' });
      }
    }
  }
  return findings;
}

/** ERROR 심각도만 추린다. */
export function errorsOf(findings: AuditFinding[]): AuditFinding[] {
  return findings.filter((f) => f.severity === 'ERROR');
}
