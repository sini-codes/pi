# Windows Setup

Pi requires a bash shell on Windows. Checked locations (in order):

1. Custom path from `~/.pi/agent/settings.json`
2. Git Bash (`C:\Program Files\Git\bin\bash.exe`)
3. `bash.exe` on PATH (Cygwin, MSYS2, WSL)

For most users, [Git for Windows](https://git-scm.com/download/win) is sufficient.

PowerShell Core is the default shell tool in this build. Install [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) and make sure `pwsh` is on `PATH`.

```powershell
pi
```

Use `pi --shell bash` to run with Bash instead. Only one shell tool can be active at a time, so do not enable `bash` and `pwsh` together.

## Custom Shell Path

```json
{
  "shellPath": "C:\\cygwin64\\bin\\bash.exe"
}
```
