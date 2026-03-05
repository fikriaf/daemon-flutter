# Analisis Mock Data Frontend - Kebutuhan Backend

## Mock Data yang Ada di Frontend

### 1. Settings Screen
| Field | Value Saat Ini | Sumber | Endpoint |
|-------|----------------|--------|----------|
| User Avatar | "U" | Hardcoded | - |
| User Name | "User Profile" | Hardcoded | - |
| Email | "user@example.com" | Hardcoded | - |
| Subscription | "Free" | Hardcoded | - |

**Endpoint yang dibutuhkan:**
- ⚠️ `GET /v1/agent/me` - Perlu update response (tambah user + subscription)

---

### 2. Sidebar Drawer - History
| Field | Value Saat Ini | Sumber | Endpoint |
|-------|----------------|--------|----------|
| History Item 1 | "What is flutter?" | Hardcoded | - |
| History Item 2 | "How to build an app" | Hardcoded | - |
| History Item 3 | "Top 10 programming languages" | Hardcoded | - |

**Endpoint yang dibutuhkan:**
- ✅ `GET /v1/agent/chats` - Sudah ada

---

### 3. Discover Screen
| Field | Value Saat Ini | Sumber | Endpoint |
|-------|----------------|--------|----------|
| Article Title | "The Future of AI..." | Hardcoded | - |
| Source | "Tech Crunch" | Hardcoded | - |
| Time | "2 hours ago" | Hardcoded | - |
| Image | picsum.photos | Hardcoded | - |
| Categories | Tab items | Hardcoded | - |

**Endpoint yang dibutuhkan:**
- ❌ `GET /v1/agent/discover` - Baru (pake Exa MCP)

---

### 4. Finance Screen
| Field | Value Saat Ini | Sumber | Endpoint |
|-------|----------------|--------|----------|
| S&P 500 | "5,946.04" | Hardcoded | - |
| NASDAQ | "18,879.88" | Hardcoded | - |
| Dow Jones | "43,766.19" | Hardcoded | - |
| VIX | "17.46" | Hardcoded | - |
| Crypto prices | - | - | - |
| Market Summary | Hardcoded news | Hardcoded | - |
| Tabs | US Markets, Crypto, Earnings, Predictions, Screener | Hardcoded | - |

**Endpoint yang dibutuhkan:**
- ❌ `GET /v1/agent/finance` - Baru (pake Binance API + Exa MCP)

---

### 5. Chat/Response (Root Screen)
| Field | Value Saat Ini | Sumber | Endpoint |
|-------|----------------|--------|----------|
| User Message | Input user | Real ✅ | - |
| AI Response | Hardcoded "Untuk awal 2026..." | Hardcoded | - |
| Reasoning Steps | Hardcoded "Searching for..." | Hardcoded | - |
| Sources | Hardcoded "cnbcindonesia" | Hardcoded | - |
| Tabs | Answer, Links, Images | Hardcoded | - |

**Endpoint yang dibutuhkan:**
- ✅ `POST /v1/chat/completions` - Sudah ada (perlu tambah sources di response)

---

## Ringkasan Endpoint yang Butuh Ditambahkan/Update

### Priority 1 - Wajib (Data User & Chat)

| Endpoint | Method | Status | Keterangan |
|----------|--------|--------|------------|
| `/v1/agent/me` | GET | ⚠️ Update | Tambah `user` object & `subscription` |
| `/v1/chat/completions` | POST | ⚠️ Update | Tambah `sources` array di response |
| `/v1/agent/chats` | GET | ✅ | History sidebar |

### Priority 2 - Data Frontend (Discover & Finance)

| Endpoint | Method | Status | Keterangan |
|----------|--------|--------|------------|
| `/v1/agent/discover` | GET | ❌ Baru | Articles + categories (Exa MCP) |
| `/v1/agent/finance` | GET | ❌ Baru | Indices + Crypto + Summary |

---

## Detail Output JSON yang Diperlukan

### 1. GET /v1/agent/me (Update)
```json
{
  "agent_id": "...",
  "name": "default",
  "user": {
    "user_id": "...",
    "email": "user@example.com",
    "avatar": null
  },
  "subscription": {
    "plan": "free",
    "monthly_token_limit": 1000000,
    "features": ["basic_chat", "limited_mcp"]
  },
  "system_prompt": "...",
  "default_model_id": "minimax/minimax-m2.5",
  "wallet_address": "7x...",
  "is_active": true,
  "created_at": "..."
}
```

### 2. GET /v1/agent/discover (Baru)
```json
{
  "articles": [
    {
      "id": "...",
      "title": "The Future of AI...",
      "summary": "...",
      "source": "TechCrunch",
      "domain": "techcrunch.com",
      "url": "https://...",
      "image_url": "https://...",
      "published_at": "2026-03-01T10:00:00Z",
      "category": "tech"
    }
  ],
  "categories": [
    {"id": "top", "name": "Top"},
    {"id": "tech", "name": "Tech & Science"},
    {"id": "finance", "name": "Finance"},
    {"id": "arts", "name": "Arts & Culture"}
  ],
  "updated_at": "2026-03-01T16:00:00Z"
}
```

### 3. GET /v1/agent/finance (Baru)
```json
{
  "indices": [
    {"symbol": "SPX", "name": "S&P 500", "value": 5946.04, "change": -48.06, "pct_change": -0.80, "trend": "down"},
    {"symbol": "IXIC", "name": "NASDAQ", "value": 18879.88, "change": -216.51, "pct_change": -1.13, "trend": "down"},
    {"symbol": "DJI", "name": "Dow Jones", "value": 43766.19, "change": -287.97, "pct_change": -0.65, "trend": "down"},
    {"symbol": "VIX", "name": "VIX", "value": 17.46, "change": 0.15, "pct_change": 0.87, "trend": "up"}
  ],
  "crypto": [
    {"symbol": "BTC", "name": "Bitcoin", "price": 95432.50, "change_24h": 2.34, "trend": "up"},
    {"symbol": "ETH", "name": "Ethereum", "price": 3245.67, "change_24h": 1.89, "trend": "up"},
    {"symbol": "SOL", "name": "Solana", "price": 198.45, "change_24h": -1.23, "trend": "down"}
  ],
  "sentiment": {
    "overall": "bearish",
    "fear_greed_index": 32,
    "label": "Fear"
  },
  "market_summary": [
    {
      "title": "Markets closed lower this week led by tech sector decline",
      "summary": "US stocks mostly closed lower...",
      "source": "Reuters",
      "published_at": "2026-03-01T14:30:00Z"
    }
  ],
  "tabs": [
    {"id": "us_markets", "name": "US Markets"},
    {"id": "crypto", "name": "Crypto"},
    {"id": "earnings", "name": "Earnings"},
    {"id": "predictions", "name": "Predictions"},
    {"id": "screener", "name": "Screener"}
  ],
  "updated_at": "2026-03-01T16:00:00Z"
}
```

### 4. POST /v1/chat/completions (Update - tambah sources)
```json
{
  "id": "gen-...",
  "model": "minimax/minimax-m2.5",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "...",
        "reasoning": "Searching for...",
        "tool_calls": []
      },
      "finish_reason": "stop"
    }
  ],
  "sources": [
    {
      "title": "BEI Ungkap Alasan...",
      "domain": "cnbcindonesia.com",
      "url": "https://..."
    }
  ],
  "usage": {...}
}
```

---

## Kesimpulan

**Endpoint yang perlu diimplementasikan:**

| No | Endpoint | Method | Priority |
|----|----------|--------|----------|
| 1 | `/v1/agent/me` | GET | Priority 1 - Update |
| 2 | `/v1/chat/completions` | POST | Priority 1 - Update (tambah sources) |
| 3 | `/v1/agent/chats` | GET | Priority 1 - Sudah ada ✅ |
| 4 | `/v1/agent/discover` | GET | Priority 2 - Baru |
| 5 | `/v1/agent/finance` | GET | Priority 2 - Baru |
