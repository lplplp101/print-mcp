# windows-print-mcp

An MCP server that lets Claude (or any MCP client) **print PDF files on your Windows PC**.

> 한국어 설명은 [아래](#한국어)에 있습니다.

Ask things like *"Print the PDF in my Downloads folder, pages 1-3, two copies, black and white"* and it goes straight to your printer.

## Tools

| Tool | What it does |
| --- | --- |
| `list_printers` | Lists installed printers and marks the default one |
| `print_pdf` | Prints a PDF. Options: `printer`, `copies` (1–20), `pages` (e.g. `1-3,5`), `monochrome`, `duplex` (long edge) |

## Requirements

- Windows 10 or 11
- [Node.js](https://nodejs.org) 18 or newer

## Install

### Claude Desktop

Open **Settings → Developer → Edit Config** and add this to `claude_desktop_config.json`
(if `mcpServers` already exists, add only the `"print"` entry inside it):

```json
{
  "mcpServers": {
    "print": {
      "command": "npx",
      "args": ["-y", "windows-print-mcp"]
    }
  }
}
```

Fully quit Claude Desktop (tray icon → Quit) and start it again.

### Claude Code

```bash
claude mcp add print -- npx -y windows-print-mcp
```

### Other clients (Cursor, VS Code, …)

Use command `npx` with args `-y windows-print-mcp` over stdio.

## How it works

Each page is rendered with the built-in Windows PDF engine (`Windows.Data.Pdf`, 300 DPI) and sent to the printer through .NET `System.Drawing.Printing`. No extra PDF viewer needs to be installed.

## Notes

- Only `.pdf` files can be printed. Paths can be absolute (`C:\Users\me\Downloads\a.pdf`) or start with `~`.
- Duplex only works if the printer supports automatic two-sided printing.
- Printing uses real paper and ink — your MCP client will normally ask before calling `print_pdf`.

## License

MIT

---

## 한국어

Claude가 **내 Windows PC에 연결된 프린터로 PDF를 바로 인쇄**할 수 있게 해 주는 MCP 커넥터입니다.
"다운로드 폴더에 있는 PDF 1~3쪽만 흑백으로 2부 뽑아 줘"처럼 말하면 됩니다.

### 도구

- `list_printers` : 설치된 프린터 목록과 기본 프린터
- `print_pdf` : PDF 인쇄 (프린터, 매수, 쪽 범위, 흑백, 양면 선택)

### 설치 (Claude 데스크톱 앱)

1. [Node.js](https://nodejs.org) LTS 버전을 설치합니다.
2. Claude 앱 **설정 → 개발자 → 구성 편집**을 눌러 `claude_desktop_config.json`을 엽니다.
3. 아래 내용을 넣습니다. 이미 `mcpServers`가 있으면 `"print"` 항목만 그 안에 추가하세요.

```json
{
  "mcpServers": {
    "print": {
      "command": "npx",
      "args": ["-y", "windows-print-mcp"]
    }
  }
}
```

4. Claude 앱을 완전히 종료(트레이 아이콘 → 종료)했다가 다시 켭니다.

양면 인쇄는 자동 양면 기능이 있는 프린터에서만 됩니다.
