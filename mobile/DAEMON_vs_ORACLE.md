# Daemon vs Oracle — Chat Feature Comparison

> Pitching document for Arkham Intelligence.
> All claims are based on current production codebase.

---

## 1. Multi-Model, Bukan Single-Model

**Oracle:** Satu model fixed (GPT-4 Turbo).

**Daemon:** Akses ke seluruh katalog **OpenRouter** — ratusan model (GPT-4o, Claude 3.5, Gemini, Llama, Mistral, dll). User bisa ganti model per-session langsung dari input bar. Model baru otomatis ter-sync dari OpenRouter API. User bisa trade-off antara kecepatan, kualitas, dan cost sesuai kebutuhan analisis.

---

## 2. Graph Visualization Interaktif

**Oracle:** Output teks dan tabel murni.

**Daemon:** Setelah AI memanggil Arkham tool (`get_address_counterparties`, `get_entity_counterparties`, `get_transfers`), graph otomatis muncul di bawah response — dirender dengan **React Flow** di dalam WebView.

**Layout 3-kolom:**
```
[← INFLOW]     [CENTER NODE]     [OUTFLOW →]
  Binance    ←─────────────────→   FTX
  Kraken     ←─   0xAbcd…1234  ─→   Tornado Cash
                                 →   Unknown Wallet
```

**Setiap node menampilkan:**
- Entity logo (langsung dari Arkham)
- Entity type badge — CEX, DeFi, Hacker, Mixer, Bridge, dll (warna berbeda per type)
- Chain badge — ETH, BTC, SOL, ARB, OP, MATIC, AVAX, BSC, BASE, FTM
- Label confidence — `● high` / `● medium` / `● low`
- Tags — `#exchange` `#hot-wallet` dll
- `CONTRACT` badge untuk smart contract

**Setiap edge menampilkan:**
- Volume USD — `$142.5M`
- Jumlah transaksi — `4.8K txs`
- Warna merah untuk outflow, hijau untuk inflow

---

## 3. Konteks Chat Multi-Domain

**Oracle:** Chat general purpose tanpa konteks tambahan.

**Daemon memiliki 4 chat context yang berbeda:**

| Screen | Konteks yang Di-inject ke AI |
|--------|------------------------------|
| **Home** | Chat umum + full Arkham analysis |
| **Discover** | Headline berita crypto terkini |
| **Finance** | Data market live (harga, volume, sentiment) |
| **World Monitor** | Konten dari URL yang di-scrape user |

AI selalu punya konteks yang relevan sebelum user bertanya — bukan hanya menjawab dari pengetahuan pre-training.

---

## 4. Streaming Real-Time dengan Step Visibility

**Oracle:** Response muncul setelah selesai, atau streaming teks saja tanpa indikator proses.

**Daemon:** SSE streaming dengan event terstruktur. User melihat secara real-time:

- `Thinking` — AI sedang reasoning
- `Searching` — memanggil web search
- `Executing Tool` — memanggil Arkham MCP tool
- `Fetching` — mengambil data dari sumber eksternal

Step-by-step ini muncul sebagai indikator live di UI sebelum response final tiba.

---

## 5. MCP Architecture — Pluggable Tool System

**Oracle:** Tool set fixed, tidak bisa di-extend user.

**Daemon:** Menggunakan **Model Context Protocol (MCP)**. Tool dipanggil lewat SSE transport ke MCP server yang terpisah. User bisa enable/disable MCP server masing-masing dari UI (`/sandbox/connectors`). Arkham hanya salah satu dari banyak yang bisa disambungkan — tool baru cukup dideploy sebagai MCP server baru tanpa mengubah core AI.

---

## 6. Web Search Real-Time (Exa)

**Oracle:** Tidak ada web search real-time.

**Daemon:** Terintegrasi dengan **Exa** sebagai search engine. AI bisa mencari informasi terkini dari web sebagai bagian dari reasoning. Source URL ditampilkan di bawah response — lengkap dengan domain, title, dan link.

---

## 7. Session Persistence & History

**Oracle:** Tidak ada memori lintas session.

**Daemon:** Session disimpan di backend (Supabase). User bisa kembali ke conversation sebelumnya dari history drawer. Setiap session punya title, timestamp, dan message count. `session_id` dikirim dari backend via SSE `done` event dan disimpan untuk continuity.

---

## 8. Ekonomi Token Transparan

**Oracle:** Biaya tidak visible ke user.

**Daemon:**
- User punya **balance USDC** yang bisa di-top-up via **Solana**
- Cost estimasi dihitung sebelum request dikirim
- Monthly token limit + usage tracking per bulan
- Log tiap request (model, tokens, cost, duration, tools used)
- Free model tersedia untuk user tanpa saldo

---

## Summary Table

| Dimensi | Oracle | Daemon |
|---------|:------:|:------:|
| Model | Single (GPT-4) | Multi-model, user-pilih |
| Visualisasi | Teks / tabel | Graph interaktif (React Flow) |
| Konteks | General | Domain-specific (news, market, scrape) |
| Transparansi proses | — | Step-by-step live indicator |
| Tool system | Fixed | MCP — pluggable, user-configurable |
| Web search | — | Exa real-time + sources |
| Memory | — | Session persistence + history |
| Ekonomi | Subscription | Pay-per-use USDC, balance transparan |

---

## Key Angle untuk Arkham

Daemon bukan chatbot yang kebetulan punya Arkham data.

Daemon dibangun dengan arsitektur yang menjadikan Arkham tools sebagai **first-class citizen** — termasuk graph visualization yang otomatis muncul ketika data counterparty di-fetch, sesuatu yang Oracle tidak punya. MCP architecture juga berarti integrasi Arkham bisa diperdalam (lebih banyak tools, lebih banyak endpoint) tanpa merombak sistem — cukup extend MCP server.
