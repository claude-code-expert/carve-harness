// src/types.ts — carve 파이프라인이 공유하는 데이터 구조 (레이어 A)

/** carve가 지원하는 프로젝트 타입. 반응형 웹은 'web'으로 흡수한다. */
export type ProjectType =
  | 'cli'
  | 'web'
  | 'mobile'
  | 'desktop'
  | 'batch'
  | 'library'
  | 'unknown';

/**
 * analyzer가 읽기 전용 스캔으로 만들어내는 프로젝트 프로필.
 * designer/catalog가 구성요소 추천에 사용한다.
 */
export interface ProjectProfile {
  /** 분석한 프로젝트 루트 절대경로 */
  root: string;
  /** 분류된 프로젝트 타입 */
  type: ProjectType;
  /** 탐지된 언어 (예: ['typescript','javascript']) */
  languages: string[];
  /** 패키지 매니저 (npm/pnpm/yarn/bun/pip/poetry/cargo/go/null) */
  packageManager: string | null;
  /** 테스트 명령 (훅 템플릿 변수). 미탐지 시 null */
  testCmd: string | null;
  /** 린트 명령. 미탐지 시 null */
  lintCmd: string | null;
  /** 포맷 명령. 미탐지 시 null */
  formatCmd: string | null;
  /** CI 시스템 (github-actions/gitlab-ci/null) */
  ci: string | null;
  /** git 리포지토리 여부 */
  hasGit: boolean;
  /** 분류 근거가 된 시그널 (디버깅·doctor용) */
  signals: string[];
  /** monorepo 워크스페이스 도구 태그 (예: ['pnpm-workspace','turbo']). 비-monorepo면 빈 배열. */
  workspaces: string[];
  /** 컨테이너·빌드 시그널. */
  container: { dockerfile: boolean; compose: boolean; makefile: boolean };
}
