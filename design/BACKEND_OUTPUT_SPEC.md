# Detail Backend Output untuk Hapus Mock Data

## 1. Finance Screen

### Endpoint: `GET /v1/agent/finance`

**Data Sources:**
- Indices: Yahoo Finance API / Mock
- Crypto: Binance API (`https://api.binance.com/api/v3/ticker/24hr`)
- Market News: Exa MCP web search
- Sentiment: Fear & Greed Index API atau Exa MCP

```json
{
  "indices": [
    {
      "symbol": "SPX",
      "name": "S&P 500",
      "value": 5946.04,
      "change": -48.06,
      "pct_change": -0.80,
      "trend": "down"
    },
    {
      "symbol": "IXIC", 
      "name": "NASDAQ",
      "value": 18879.88,
      "change": -216.51,
      "pct_change": -1.13,
      "trend": "down"
    },
    {
      "symbol": "DJI",
      "name": "Dow Jones",
      "value": 43766.19,
      "change": -287.97,
      "pct_change": -0.65,
      "trend": "down"
    },
    {
      "symbol": "VIX",
      "name": "VIX",
      "value": 17.46,
      "change": 0.15,
      "pct_change": 0.87,
      "trend": "up"
    }
  ],
  "crypto": [
    {
      "symbol": "BTC",
      "name": "Bitcoin",
      "price": 95432.50,
      "change_24h": 2.34,
      "trend": "up"
    },
    {
      "symbol": "ETH",
      "name": "Ethereum", 
      "price": 3245.67,
      "change_24h": 1.89,
      "trend": "up"
    },
    {
      "symbol": "SOL",
      "name": "Solana",
      "price": 198.45,
      "change_24h": -1.23,
      "trend": "down"
    }
  ],
  "sentiment": {
    "overall": "bearish",
    "fear_greed_index": 32,
    "label": "Fear"
  },
  "market_summary": [
    {
      "title": "Markets closed lower this week led by tech sector decline",
      "summary": "US stocks mostly closed lower on Friday, with NASDAQ leading the decline as the tech sector experienced a sell-off...",
      "source": "Reuters",
      "published_at": "2026-03-01T14:30:00Z"
    },
    {
      "title": "Focus turns to PCE inflation data next week",
      "summary": "Investors are awaiting the latest PCE inflation data scheduled for release next week...",
      "source": "Bloomberg",
      "published_at": "2026-03-01T12:00:00Z"
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

### Binance API Examples

```
GET https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT
GET https://api.binance.com/api/v3/ticker/24hr?symbol=ETHUSDT
GET https://api.binance.com/api/v3/ticker/24hr?symbol=SOLUSDT
```

Response:
```json
{
  "symbol": "BTCUSDT",
  "lastPrice": "95432.50",
  "priceChange": "2187.32",
  "priceChangePercent": "2.34"
}
```

---

## 2. Discover Screen

### Endpoint: `GET /v1/agent/discover?category=tech`

**Data Sources:** Exa MCP web search

```json
{
  "articles": [
    {
      "id": "article_001",
      "title": "The Future of AI and Machine Learning in 2026",
      "summary": "Artificial intelligence continues to evolve rapidly with new breakthroughs in generative AI and multimodal models...",
      "source": "TechCrunch",
      "domain": "techcrunch.com",
      "url": "https://techcrunch.com/2026/02/ai-future-2026",
      "image_url": "https://picsum.photos/seed/ai1/400/200",
      "published_at": "2026-02-28T10:30:00Z",
      "category": "tech"
    },
    {
      "id": "article_002", 
      "title": "Bitcoin Surpasses $95K as Institutional Adoption Grows",
      "summary": "Bitcoin has reached new all-time highs as more institutions announce crypto adoption...",
      "source": "CoinDesk",
      "domain": "coindesk.com",
      "url": "https://coindesk.com/btc-95k",
      "image_url": "https://picsum.photos/seed/btc/400/200",
      "published_at": "2026-03-01T08:00:00Z",
      "category": "crypto"
    },
    {
      "id": "article_003",
      "title": "SpaceX Launches New Starlink Satellites",
      "summary": "SpaceX successfully launched another batch of Starlink satellites to expand global coverage...",
      "source": "SpaceNews",
      "domain": "spacenews.com",
      "url": "https://spacenews.com/starlink-launch",
      "image_url": "https://picsum.photos/seed/space/400/200",
      "published_at": "2026-03-01T06:00:00Z",
      "category": "science"
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

### Query per Category
- `top`: "latest news 2026"
- `tech`: "technology news 2026"
- `finance`: "stock market news 2026"
- `arts`: "arts culture news 2026"

---

## 3. Settings Screen

### Endpoint: `GET /v1/agent/me` (UPDATE)

```json
{
  "agent_id": "731ad310-26be-4e1c-9b5d-965e84fdff8f",
  "name": "default",
  "user": {
    "user_id": "dab8a83c-a830-42b3-bf9f-bea2ecea1eb8",
    "email": "user@example.com",
    "avatar": null
  },
  "subscription": {
    "plan": "free",
    "monthly_token_limit": 1000000,
    "features": ["basic_chat", "limited_mcp"]
  },
  "system_prompt": "You are a helpful crypto assistant.",
  "default_model_id": "minimax/minimax-m2.5",
  "wallet_address": "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU",
  "monthly_token_limit": 1000000,
  "is_active": true,
  "created_at": "2026-03-01T08:19:28.286291+00:00"
}
```

---

## 4. Sidebar - History

### Endpoint: `GET /v1/agent/chats` (SUDAH ADA)

```json
{
  "data": [
    {
      "id": "chat_001",
      "title": "What is Flutter?",
      "model_id": "minimax/minimax-m2.5",
      "message_count": 5,
      "created_at": "2026-03-01T10:00:00Z",
      "updated_at": "2026-03-01T10:30:00Z"
    },
    {
      "id": "chat_002",
      "title": "SOL balance check",
      "model_id": "minimax/minimax-m2.5", 
      "message_count": 3,
      "created_at": "2026-03-01T09:00:00Z",
      "updated_at": "2026-03-01T09:15:00Z"
    }
  ],
  "total": 2,
  "page": 1,
  "limit": 20
}
```

---

## 5. Chat Response (Real-time)

### Endpoint: `POST /v1/chat/completions` (UPDATE - tambah sources)

```json
{
  "id": "gen-1772358112-AwgcfhqRdk0os83bVy7K",
  "model": "minimax/minimax-m2.5",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "Untuk awal 2026 ini, belum ada saham Indonesia yang resmi IPO dan tercatat di BEI sampai sekitar 20 Februari 2026.",
        "reasoning": "Searching for latest Indonesian stock IPO information...",
        "tool_calls": []
      },
      "finish_reason": "stop"
    }
  ],
  "sources": [
    {
      "title": "BEI Ungkap Alasan Belum Ada Perusahaan Listing",
      "domain": "cnbcindonesia.com",
      "url": "https://cnbcindonesia.com/news/..."
    },
    {
      "title": "Update IPO 2026: Antrean Panjang di BEI",
      "domain": "investasi.kontan.co.id",
      "url": "https://investasi.kontan.co.id/..."
    }
  ],
  "usage": {
    "prompt_tokens": 367,
    "completion_tokens": 74,
    "total_tokens": 441,
    "cost": 0.0001989
  }
}
```

---

## Summary - Endpoint yang Butuh Dibuat/Update

| Screen | Endpoint | Method | Status | Data Source |
|--------|----------|--------|--------|-------------|
| Settings | `/v1/agent/me` | GET | ⚠️ Update | Database |
| History | `/v1/agent/chats` | GET | ✅ | Database |
| Discover | `/v1/agent/discover` | GET | ❌ Baru | Exa MCP |
| Finance | `/v1/agent/finance` | GET | ❌ Baru | Binance API + Exa MCP |
| Chat Response | `/v1/chat/completions` | POST | ⚠️ Update | LLM + MCP tools |

---

## Implementation Notes

### Finance - Data Flow
```
1. GET /v1/agent/finance
2. Call Binance API (BTCUSDT, ETHUSDT, SOLUSDT) -> crypto prices
3. Call Yahoo Finance / mock -> indices
4. Call Exa MCP (query: "stock market news today") -> market_summary
5. Return combined JSON
```

### Discover - Data Flow
```
1. GET /v1/agent/discover?category=tech
2. Map category to Exa query:
   - top -> "latest news 2026"
   - tech -> "technology news 2026"  
   - finance -> "stock market news 2026"
   - arts -> "arts culture news 2026"
3. Call Exa MCP web_search
4. Format response to articles array
```

### Chat - Sources Flow
```
1. POST /v1/chat/completions
2. LLM processes request
3. If MCP tools used (Exa search):
   - Capture tool results as sources
4. Include sources in response
```
