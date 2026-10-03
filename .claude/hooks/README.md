# Slack 알림 훅

Claude Code 작업 중 **권한 승인이 필요할 때**와 **작업이 끝났을 때** Slack 채널로 카드를 보냅니다.
자리를 비워도 세션이 멈춰 있는지 끝났는지 터미널을 보지 않고 알 수 있습니다.

## 설정 (클론 후 1회)

### 1. Slack Incoming Webhook 발급

1. <https://api.slack.com/apps> → **Create New App** → From scratch
2. 좌측 **Incoming Webhooks** → 토글 **On**
3. **Add New Webhook to Workspace** → 알림을 받을 채널 선택
4. 발급된 `https://hooks.slack.com/services/...` 복사

> 메시지에 실행할 명령어·파일 경로·작업 요약이 포함됩니다. **비공개 채널**을 권장합니다.

### 2. `.claude/settings.local.json` 에 값 채우기

이 파일은 `.gitignore` 에 걸려 있어 커밋되지 않습니다.

```json
{
  "env": {
    "SLACK_WEBHOOK_URL": "https://hooks.slack.com/services/...",
    "SLACK_MENTION": "",
    "SLACK_NOTIFY_MIN_SECONDS": "60"
  }
}
```

| 변수 | 필수 | 설명 |
|------|------|------|
| `SLACK_WEBHOOK_URL` | O | 발급받은 Webhook URL. **비워두면 훅이 아무 동작도 하지 않습니다.** |
| `SLACK_MENTION` | X | 권한 요청 시 멘션할 대상. 예: `<@U01ABCDEFG>` |
| `SLACK_NOTIFY_MIN_SECONDS` | X | 완료 알림 최소 소요 시간(초). 기본 `60` |

### 3. 재로드

훅은 **세션 시작 시점의 설정**을 사용합니다. `/hooks` 를 한 번 열거나 세션을 재시작하세요.

## 이벤트별 알림

| 이벤트 | 조건 | 카드 |
|--------|------|------|
| `Notification` (`permission_prompt`) | 권한 승인 창이 뜰 때 | 🔐 권한 요청 필요 — 작업 / 내용(실제 명령어) / 상황 / 알림 |
| `Notification` (`idle_prompt`) | 60초 이상 입력 대기 | ⏳ 입력 대기 중 |
| `Stop` | 응답 종료 시 | ✅ 작업 완료 — 요약 / 변경 파일 수 / 소요 시간 |
| `SessionEnd` | 세션 종료 시 | 🔚 세션 종료 — 사유 / 변경 |
| `UserPromptSubmit` | 매 턴 시작 | 전송 없음. 소요 시간 계산용 시작 시각만 기록 |

### 알림 노이즈 억제

`Stop` 은 **매 응답마다** 발생합니다. 짧은 질의응답까지 Slack에 쏟아지지 않도록,
**소요 시간이 `SLACK_NOTIFY_MIN_SECONDS` 미만이면서 git 변경도 없는 턴**은 전송하지 않습니다.
모든 턴을 받고 싶으면 `SLACK_NOTIFY_MIN_SECONDS` 를 `0` 으로 설정하세요.

## 동작 확인 (전송 없이 테스트)

`SLACK_DRY_RUN=1` 을 주면 Slack으로 보내지 않고 payload를 stderr로 출력합니다.

```bash
echo '{"hook_event_name":"Stop","last_assistant_message":"테스트","session_id":"test123","cwd":"'"$PWD"'"}' \
  | SLACK_DRY_RUN=1 SLACK_WEBHOOK_URL=x SLACK_NOTIFY_MIN_SECONDS=0 .claude/hooks/slack-notify.sh
```

실제 전송을 확인하려면 `SLACK_DRY_RUN` 을 빼고 `SLACK_WEBHOOK_URL` 에 진짜 URL을 넣으세요.

## 설계 메모

- 훅이 세션을 방해하면 안 되므로 **모든 실패는 `exit 0` 으로 흡수**합니다. URL 미설정·`jq` 부재·네트워크 실패 모두 조용히 통과합니다.
- **stdout에 아무것도 출력하지 않습니다.** `UserPromptSubmit` 의 stdout은 모델 컨텍스트로 주입되기 때문입니다.
- `Notification` 페이로드에는 도구 상세가 없어, "무슨 작업인지"는 `transcript_path`(JSONL)를 역순으로 훑어 직전 `tool_use` 블록에서 읽습니다.
- `PermissionRequest` 대신 `Notification` 을 쓰는 이유: `PermissionRequest` 는 권한 판단이 필요한 **모든** 호출에 발생해 이미 허용된 도구까지 알림이 갑니다.
- `SessionEnd` 만 동기(`timeout: 5`)입니다. 세션이 끝나며 백그라운드 프로세스가 같이 종료될 수 있기 때문입니다.
- macOS 기준으로 작성되었습니다(역순 읽기에 `tac` 이 아닌 `tail -r` 사용). Linux에서는 `tail -r` 을 `tac` 으로 바꾸세요.

---

# 자동 포맷 훅 (`format.sh`)

Claude가 `Edit` / `Write` / `MultiEdit`로 파일을 수정한 직후, 해당 파일 하나에 대해 자동으로 실행됩니다.

| 확장자 | 실행 순서 |
|--------|-----------|
| `ts` `tsx` `js` `jsx` `mjs` `cjs` | `eslint --fix` → `prettier --write` |
| `json` `css` `md` | `prettier --write` |

- 프로젝트 밖 파일, `node_modules`, `.next`는 건너뜁니다. `.prettierignore` 대상(`src/components/ui` 등)도 포맷하지 않습니다.
- 자동수정이 안 되는 ESLint **에러**가 남으면 exit 2로 에러 내용을 Claude에게 전달해 직접 고치게 합니다. (warning은 무시)
- 포맷 규칙: 루트 `.prettierrc.json` (Tailwind 클래스 정렬 포함, `globals.css` 기준)
- 전체 수동 포맷: `pnpm format`

### 끄는 방법

`.claude/settings.json`의 `hooks.PostToolUse` 항목을 삭제하거나, `/hooks` 메뉴에서 비활성화합니다.
