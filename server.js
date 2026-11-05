#!/usr/bin/env node
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { execFile } from "node:child_process";
import { fileURLToPath } from "node:url";

if (process.platform !== "win32") {
  console.error("windows-print-mcp only runs on Windows.");
  process.exit(1);
}

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PS = path.join(process.env.SystemRoot || "C:\\Windows", "System32", "WindowsPowerShell", "v1.0", "powershell.exe");

function psPrint(file, { printer, copies, pages, monochrome, duplex }) {
  const args = ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", path.join(HERE, "print.ps1"), "-Path", file, "-Copies", String(copies || 1)];
  if (printer) args.push("-Printer", printer);
  if (pages) args.push("-Pages", pages);
  if (monochrome) args.push("-Mono");
  if (duplex) args.push("-Duplex");
  return new Promise((resolve, reject) => {
    execFile(PS, args, { timeout: 180000, windowsHide: true, encoding: "utf8" }, (err, stdout, stderr) => {
      if (err) reject(new Error((stderr || stdout || err.message).trim()));
      else resolve(stdout.trim());
    });
  });
}
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const require = createRequire(import.meta.url);
const ptp = require("pdf-to-printer");

const text = (s) => ({ content: [{ type: "text", text: s }] });
const fail = (s) => ({ content: [{ type: "text", text: s }], isError: true });

function resolvePdf(p) {
  let f = p.trim().replace(/^"|"$/g, "");
  if (f.startsWith("~")) f = path.join(os.homedir(), f.slice(1));
  f = path.resolve(f);
  if (path.extname(f).toLowerCase() !== ".pdf") throw new Error("Only PDF files can be printed: " + f);
  if (!fs.existsSync(f) || !fs.statSync(f).isFile()) throw new Error("File not found: " + f);
  return f;
}

const server = new McpServer({ name: "windows-print-mcp", version: "1.0.0" });

server.registerTool(
  "list_printers",
  {
    title: "List printers",
    description: "List printers installed on this Windows PC and show which one is the default.",
    inputSchema: {},
  },
  async () => {
    try {
      const printers = await ptp.getPrinters();
      const def = await ptp.getDefaultPrinter().catch(() => null);
      if (!printers.length) return text("No printers are installed.");
      const lines = printers.map((p) => `- ${p.name}${def && def.name === p.name ? " (default)" : ""}`);
      return text(lines.join("\n"));
    } catch (e) {
      return fail("Could not list printers: " + e.message);
    }
  }
);

server.registerTool(
  "print_pdf",
  {
    title: "Print PDF",
    description:
      "Send a PDF file on this Windows PC to a printer. Use an absolute Windows path (e.g. C:\\Users\\me\\Downloads\\file.pdf) or ~\\Downloads\\file.pdf. Omit printer to use the default printer.",
    inputSchema: {
      path: z.string().describe("Path to the PDF file on this PC"),
      printer: z.string().optional().describe("Printer name from list_printers; default printer if omitted"),
      copies: z.number().int().min(1).max(20).optional().describe("Number of copies (default 1)"),
      pages: z.string().optional().describe("Page range like '1' or '1-3,5'; all pages if omitted"),
      monochrome: z.boolean().optional().describe("Print in black and white"),
      duplex: z.boolean().optional().describe("Print on both sides (long edge)"),
    },
  },
  async ({ path: p, printer, copies, pages, monochrome, duplex }) => {
    try {
      const file = resolvePdf(p);
      const out = await psPrint(file, { printer, copies, pages, monochrome, duplex });
      const def = printer || (await ptp.getDefaultPrinter().catch(() => null))?.name || "default printer";
      return text(`Print job sent.\nFile: ${file}\nPrinter: ${def}\nCopies: ${copies || 1}\n${out}`);
    } catch (e) {
      return fail("Printing failed: " + e.message);
    }
  }
);

await server.connect(new StdioServerTransport());
