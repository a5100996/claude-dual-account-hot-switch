# Security

## Trust boundary

本 repository 的 PowerShell 腳本不會讀取或上傳 OAuth token；它負責安裝並設定第三方套件 `claude-auto-switch`。真正的帳號管理、usage 查詢與 credential rotation 由該套件執行。

`claude-auto-switch` 具有高權限：

- 讀寫每個 Claude profile 的 `.credentials.json`。
- 以 PTY 代理 Claude Code，因此能看見完整終端輸入及輸出。
- 修改 PowerShell profile、Claude status line，以及使用者選擇啟用時的編輯器設定。
- 呼叫 Anthropic OAuth profile、usage 與 token endpoint。

請先自行檢查上游 repository：

- <https://github.com/stephengardner/claude-auto-switch>
- <https://github.com/stephengardner/claude-auto-switch/blob/main/SECURITY.md>

## Local secrets

下列資料不得提交到 Git：

- `.credentials.json`
- `.credentials.prev.json`
- `.claude.json`
- `oauth-token`
- `accounts.json`
- `ClaudeSetupBackup-*`
- Claude transcripts、debug logs 與 session folders

本 repository 的 `.gitignore` 包含對應規則，但 `.gitignore` 不是加密或權限控制。

## Debug logging

不要在一般使用環境設定 `CAS_DEBUG=1`。該選項可能把完整 session transcript 寫入 `~/.claude-auto-switch`。

## Version pinning

安裝腳本預設固定 Claude Code 與 `claude-auto-switch` 版本。更新版本前應重新檢查：

- npm package ownership 與 integrity。
- 新增的 network endpoints。
- npm lifecycle scripts 與 production dependency audit。
- Credential storage、token refresh、shell profile 修改及 session resume 實作。

## Reporting

請勿在公開 issue 貼上 token、`.credentials.json`、完整 `ccx doctor --json` 輸出或含私密內容的 transcript。
