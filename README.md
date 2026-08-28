# Claude Code 雙帳號互動式熱切換（Windows）

在 Windows 上一次設定兩個 Claude Pro／Max 帳號。完成後仍然使用普通的 `claude` 指令；當互動式 Claude Code 達到使用上限時，由 [`claude-auto-switch`](https://github.com/stephengardner/claude-auto-switch)（`ccx`）切換到另一個有額度的帳號，並沿用原本的 conversation/session。

> 這不是 Anthropic 官方的多帳號功能。工具會在本機保存及替換 OAuth credential。使用前請閱讀[安全注意事項](#安全注意事項)。

## 最快部署

### 1. 安裝前置工具

新電腦需要：

- Windows 10／11
- [PowerShell 7](https://aka.ms/powershell-release?tag=stable)
- [Node.js 22 LTS](https://nodejs.org/)
- Git（使用 clone 安裝時）
- 兩個有效且屬於同一位使用者的 Claude 訂閱帳號

確認版本：

```powershell
pwsh --version
node --version
npm --version
```

### 2. 下載

使用 Git：

```powershell
git clone https://github.com/a5100996/claude-dual-account-hot-switch.git
cd .\claude-dual-account-hot-switch
```

或只下載安裝腳本：

```powershell
New-Item -ItemType Directory -Path .\claude-dual-account-hot-switch -Force | Out-Null
Set-Location .\claude-dual-account-hot-switch
Invoke-WebRequest `
  -Uri "https://raw.githubusercontent.com/a5100996/claude-dual-account-hot-switch/main/setup-claude-dual-account.ps1" `
  -OutFile ".\setup-claude-dual-account.ps1"
```

如果 repository 維持 private，未登入 GitHub 的 `Invoke-WebRequest` 無法下載，請使用已登入的 `gh repo clone`：

```powershell
gh repo clone a5100996/claude-dual-account-hot-switch
cd .\claude-dual-account-hot-switch
```

### 3. 執行設定

先關閉所有 Claude Code CLI／IDE session，然後在 PowerShell 7 執行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass

& ".\setup-claude-dual-account.ps1" `
  -PrimaryEmail "第一個帳號@example.com" `
  -SecondaryEmail "第二個帳號@example.com"
```

腳本會：

1. 檢查 PowerShell、Node.js 及目前是否有 Claude process。
2. 備份 PowerShell profile 與既有 Claude 重要設定。
3. 同時安裝固定版本的 Claude Code 與 `ccx`。
4. 依序開啟兩次 Claude OAuth 瀏覽器登入。
5. 透過 `ccx doctor` 確認兩個 profile 確實屬於不同帳號。
6. 將 PowerShell 的 `claude` 指令接到 `ccx`。
7. 安裝 Claude 狀態列，顯示目前帳號與剩餘額度。
8. 顯示兩個帳號的即時 usage。

第二次登入前，腳本會暫停。請先在 `claude.ai` 登出第一個帳號，或切換到另一個瀏覽器 profile，再按 Enter。

## 日常使用

設定完成後重新開啟 PowerShell：

```powershell
cd "C:\path\to\your-project"
claude
```

不需要改用 `claude -p`，也不需要自製 failover wrapper。

常用管理指令：

```powershell
ccx list                 # 帳號、登入及目前啟用狀態
ccx usage                # 5 小時／每週額度與重置時間
ccx history              # 登入與自動切換紀錄
ccx rotate               # 手動切到下一個健康帳號
ccx use primary --now    # 立即切第一帳號並恢復同一段對話
ccx use secondary --now  # 立即切第二帳號並恢復同一段對話
ccx doctor               # 完整健康檢查
```

### 自動切換如何保留對話

`ccx` 讓帳號 profile 共用原本的 `~/.claude/projects` session/history，並為執行中的 Claude session 替換 credential。Windows 上 Claude Code 通常會重新讀取變更後的憑證。

若熱更新沒有立即生效，執行：

```powershell
ccx use secondary --now
```

`--now` 會重啟 Claude 子程序並以 `--continue` 恢復相同 session，而不是建立新對話。

## 自訂版本

預設使用經過本專案檢查的版本：

- Claude Code `2.1.197`
- `claude-auto-switch` `1.47.0`

指定其他版本：

```powershell
& ".\setup-claude-dual-account.ps1" `
  -PrimaryEmail "first@example.com" `
  -SecondaryEmail "second@example.com" `
  -ClaudeCodeVersion "2.1.197" `
  -CcxVersion "1.47.0"
```

若也要設定 Cursor／VS Code，可加上：

```powershell
-InstallEditorIntegration
```

預設不修改編輯器設定。

## 安全注意事項

- `ccx` 是第三方工具，能讀寫 Claude OAuth credential，也會代理整個 Claude 終端輸入與輸出。
- Credential 只應存在本機使用者目錄，不要放進 Git、雲端硬碟、郵件或聊天訊息。
- 不要設定 `CAS_DEBUG=1`；它會把完整互動 transcript 寫入本機日誌。
- 不建議同時開大量 Claude session；帳號 token renewal 仍可能遇到競態情況。
- `ccx` 會向 Anthropic 官方的 OAuth profile、usage 與 token endpoint 發送認證請求。
- 多個訂閱帳號輪替可能涉及 Anthropic 使用條款的灰色地帶，請自行確認使用方式符合條款。
- 安裝腳本會在「文件」目錄建立 `ClaudeSetupBackup-日期時間`，其中可能包含 OAuth credential，請妥善保管。

更多細節請看 [SECURITY.md](SECURITY.md)。

## 停用或復原

停用 `ccx`，保留帳號 profile：

```powershell
ccx off --no-editor
npm uninstall --global claude-auto-switch
```

重新開啟 PowerShell 後，`claude` 會恢復為原生 Claude Code。

不要直接刪除 `%USERPROFILE%\.claude-auto-switch`，除非已確認不再需要裡面的帳號 credential。若需要完整復原 PowerShell 與 Claude 設定，使用安裝腳本輸出的 `ClaudeSetupBackup-*` 路徑。

## 已有 ccx 設定

為避免覆蓋帳號，bootstrap 腳本偵測到 `%USERPROFILE%\.claude-auto-switch\accounts.json` 時會停止。這時請使用：

```powershell
ccx doctor
ccx login --all
ccx on --no-editor
```

## 驗證清單

```powershell
ccx doctor
ccx list
ccx usage
Get-Command claude
```

`Get-Command claude` 應顯示 PowerShell `Function`，代表普通 `claude` 已經由 `ccx` 接管。
