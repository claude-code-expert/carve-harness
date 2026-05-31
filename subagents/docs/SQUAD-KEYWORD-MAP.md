# Squad Agent 키워드 매핑

> description에 명시된 트리거 + 실전 자연어 패턴

---

## squad-review

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 리뷰, review, 코드 리뷰, PR 리뷰, 코드 봐줘 |
| **추가 한글** | 코드리뷰, 리뷰해, 리뷰해줘, 봐줘, 검토해, 검토해줘, 코드 검토, 코드 확인, 코드 체크, 변경사항 확인, diff 봐줘, 코드 품질 |
| **추가 영문** | code review, review this, check this code, look at this, review my changes, review the diff, PR review, pull request review |

**라우터 패턴:**
```
*"리뷰"*|*"review"*|*"코드 봐"*|*"코드 검토"*|*"코드 확인"*|*"코드 체크"*|*"diff 봐"*|*"변경사항 확인"*|*"코드 품질"*|*"검토해"*|*"pull request"*
```

---

## squad-plan

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 기획, planning, 브레인스토밍, 유저스토리, 와이어프레임, wireframe, 화면 설계, 설계, 스펙 |
| **추가 한글** | 기획해, 기획서, 플래닝, 설계해, 설계해줘, 화면 구성, UI 설계, 화면 그려, 유저 스토리, 스펙 작성, 요구사항, 구현 계획, 작업 분해, 태스크 분해, 기능 정의, 어떻게 만들지, 뭐부터 해야, 구조 잡아 |
| **추가 영문** | plan this, design this, wireframe, user story, spec, requirements, how should I build, architecture plan, feature spec, task breakdown, implementation plan, brainstorm |

**라우터 패턴:**
```
*"기획"*|*"planning"*|*"plan "*|*"플래닝"*|*"브레인스토밍"*|*"brainstorm"*|*"유저스토리"*|*"user story"*|*"와이어프레임"*|*"wireframe"*|*"화면 설계"*|*"화면 구성"*|*"화면 그려"*|*"ui 설계"*|*"설계해"*|*"스펙"*|*"spec"*|*"요구사항"*|*"구현 계획"*|*"뭐부터 해"*|*"어떻게 만들"*|*"구조 잡"*|*"태스크 분해"*|*"작업 분해"*
```

---

## squad-refactor

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 리팩토링, refactor, 정리, 클린업, cleanup, 추출, extract, 분리, 중복 제거, DRY |
| **추가 한글** | 리팩터, 리팩토링해, 코드 정리, 코드 정리해, 깔끔하게, 정리해줘, 코드 개선, 함수 분리, 함수 추출, 컴포넌트 분리, 중복 제거해, 중복 코드, 코드 냄새, 코드 스멜, 구조 개선, 깨끗하게, 클린 코드 |
| **추가 영문** | refactoring, clean up, clean this, extract function, extract component, split this, deduplicate, remove duplication, code smell, simplify, restructure, reorganize |

**라우터 패턴:**
```
*"리팩토링"*|*"리팩터"*|*"refactor"*|*"코드 정리"*|*"정리해"*|*"클린업"*|*"cleanup"*|*"clean up"*|*"추출"*|*"extract"*|*"분리해"*|*"중복 제거"*|*"중복 코드"*|*"deduplic"*|*"코드 개선"*|*"함수 분리"*|*"컴포넌트 분리"*|*"코드 스멜"*|*"code smell"*|*"구조 개선"*|*"깔끔하게"*|*"깨끗하게"*|*"simplify"*|*"dry"*
```

---

## squad-qa

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 테스트, test, QA, 검증, 동작 확인, 돌려봐 |
| **추가 한글** | 테스트해, 테스트 돌려, 테스트 실행, 검증해, 검증해줘, 동작 확인해, 동작해, 잘 되나, 빌드 확인, 빌드 돌려, 린트, 타입체크, 타입 검사, 통과하나, 깨지는거 없나, 리그레션 |
| **추가 영문** | run test, run tests, test this, testing, verify, check if it works, does it work, build check, lint check, type check, regression, pass the tests |

**라우터 패턴:**
```
*"테스트"*|*"test"*|*"qa"*|*"검증"*|*"동작 확인"*|*"돌려"*|*"잘 되나"*|*"잘되나"*|*"빌드 확인"*|*"빌드 돌"*|*"린트"*|*"lint"*|*"타입체크"*|*"타입 검사"*|*"type check"*|*"깨지는"*|*"리그레션"*|*"regression"*|*"통과"*|*"verify"*
```

---

## squad-debug

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 디버깅, debug, 에러, 버그, 왜 안 돼, 안됨, 크래시 |
| **추가 한글** | 디버그, 에러나, 에러 나, 오류, 오류나, 왜 안돼, 왜안돼, 안되, 안 되, 안먹히, 안 먹히, 동작 안, 작동 안, 실패, 문제가, 문제 생겼, 이상해, 이상한, 터졌, 죽었, 뻗었, 펑, 스택트레이스, 스택 트레이스, 원인 분석, 원인 파악 |
| **추가 영문** | debugging, error, bug, not working, doesn't work, broken, crash, crashed, stack trace, traceback, exception, failure, fails, failed, what's wrong, fix this error, root cause |

**라우터 패턴:**
```
*"디버"*|*"debug"*|*"에러"*|*"error"*|*"버그"*|*"bug"*|*"왜 안"*|*"왜안"*|*"안돼"*|*"안되"*|*"안 돼"*|*"안 되"*|*"오류"*|*"크래시"*|*"crash"*|*"터졌"*|*"죽었"*|*"뻗었"*|*"실패"*|*"fail"*|*"not working"*|*"doesn't work"*|*"broken"*|*"stack trace"*|*"traceback"*|*"exception"*|*"원인 분석"*|*"원인 파악"*|*"이상해"*|*"문제가"*|*"문제 생"*
```

---

## squad-docs

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 문서, README, docs, API 문서, JSDoc, 아키텍처 문서, 가이드 작성, 주석 |
| **추가 한글** | 문서화, 문서 작성, 문서 만들어, 문서 갱신, 문서 업데이트, 독스, 리드미, API 문서화, 주석 달아, 주석 추가, 코멘트 달아, 설명 달아, 타입독, TSDoc, 가이드 만들어, 문서 정리 |
| **추가 영문** | documentation, document this, write docs, update docs, generate docs, readme, api docs, jsdoc, tsdoc, add comments, write guide, architecture doc |

**라우터 패턴:**
```
*"문서"*|*"document"*|*"docs"*|*"readme"*|*"리드미"*|*"jsdoc"*|*"tsdoc"*|*"api 문서"*|*"주석"*|*"comment"*|*"가이드 작성"*|*"가이드 만들"*|*"설명 달아"*|*"문서화"*
```

---

## squad-gitops

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 커밋 메시지, commit message, PR 작성, PR description, 체인지로그, changelog, 릴리즈 노트, conventional commit |
| **추가 한글** | 커밋 메세지, 커밋메시지, 커밋 작성, 커밋 만들어, PR 만들어, PR 써줘, 피알 작성, 풀리퀘스트, 변경 이력, 릴리즈 노트 작성, 배포 노트 |
| **추가 영문** | commit msg, write commit, generate commit, pr description, pull request description, write pr, release note, release notes, changelog entry |

**라우터 패턴:**
```
*"커밋"*|*"commit"*|*"pr 작성"*|*"pr 만들"*|*"pr 써"*|*"피알"*|*"pull request"*|*"풀리퀘"*|*"체인지로그"*|*"changelog"*|*"릴리즈 노트"*|*"release note"*|*"배포 노트"*|*"conventional"*
```

> ⚠️ "PR"은 squad-review의 "PR 리뷰"와 겹칠 수 있음.
> 우선순위: "PR 리뷰/PR review" → squad-review, "PR 작성/PR 만들어" → squad-gitops

---

## squad-audit

| 구분 | 키워드 |
|------|--------|
| **description 명시** | 보안, security, 취약점, vulnerability, audit, OWASP, 시크릿 검사 |
| **추가 한글** | 보안 검사, 보안 점검, 보안 감사, 시크릿, 비밀키, 토큰 노출, 키 노출, 환경변수 검사, 보안 취약점, 의존성 검사, npm audit, 인젝션, XSS, CSRF, 보안 스캔 |
| **추가 영문** | security check, security scan, security audit, vulnerability scan, secret scan, secret leak, exposed key, dependency audit, owasp check, injection, xss, csrf |

**라우터 패턴:**
```
*"보안"*|*"security"*|*"취약점"*|*"vulnerab"*|*"audit"*|*"owasp"*|*"시크릿"*|*"secret"*|*"비밀키"*|*"토큰 노출"*|*"키 노출"*|*"npm audit"*|*"인젝션"*|*"injection"*|*"xss"*|*"csrf"*|*"보안 스캔"*|*"security scan"*
```

---

## 충돌 키워드 우선순위

일부 키워드는 여러 에이전트에 매칭될 수 있다. 라우터에서의 우선순위:

| 키워드 | 충돌 | 우선 에이전트 | 이유 |
|--------|------|-------------|------|
| "PR 리뷰" | review vs gitops | **squad-review** | "리뷰"가 핵심 |
| "PR 작성" | review vs gitops | **squad-gitops** | "작성"이 핵심 |
| "코드 정리" | refactor vs review | **squad-refactor** | "정리"는 리팩토링 |
| "테스트 코드 리뷰" | qa vs review | **squad-review** | "리뷰"가 핵심 |
| "보안 리뷰" | audit vs review | **squad-audit** | "보안"이 핵심 |
| "에러 테스트" | debug vs qa | **squad-debug** | "에러"가 핵심 |
| "빌드 에러" | qa vs debug | **squad-debug** | "에러"가 핵심 |
| "빌드 확인" | qa vs debug | **squad-qa** | "확인"은 검증 |
