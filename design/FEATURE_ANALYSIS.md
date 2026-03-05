# Analisis Fitur Backend untuk Frontend Home & Sandbox

## 1. Fitur yang SUDAH ADA (Sudah Terimplementasi)

### Home Feature - Menu-menu Bawaan

| Menu | Endpoint | Status |
|------|----------|--------|
| **Dashboard Overview** | GET `/v1/agent/me` | ✅ Ada |
| **Saldo / Balance** | GET `/v1/agent/balance` | ✅ Ada |
| **Usage / Statistics** | GET `/v1/agent/usage` | ✅ Ada |
| **Riwayat Pembayaran** | GET `/v1/agent/payments` | ✅ Ada |
| **Riwayat Request** | GET `/v1/agent/requests` | ✅ Ada |
| **Daftar Model** | GET `/v1/models` | ✅ Ada |
| **Health Check** | GET `/health` | ✅ Ada |

### Sandbox Feature

| Menu | Endpoint | Status |
|------|----------|--------|
| **Chat Interface** | POST `/v1/chat/completions` | ✅ Ada |
| **Streaming Response** | SSE | ✅ Ada |
| **Tool Calls (MCP)** | Daemon Intel, Exa | ✅ Ada |
| **Reasoning Display** | `reasoning` field | ✅ Ada |

---

## 2. Fitur yang KURANG / BELUM ADA

Berikut adalah fitur-fitur yang perlu ditambahkan ke backend agar frontend Home & Sandbox berjalan lengkap:

### A. Agent Settings (Untuk Konfigurasi Agent)

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **Edit System Prompt** | PATCH `/v1/agent/settings` | Ubah system prompt agent |
| **Edit Default Model** | PATCH `/v1/agent/settings` | Pilih model default |
| **Edit Wallet Address** | PATCH `/v1/agent/settings` | Ubah wallet address |
| **Edit Monthly Limit** | PATCH `/v1/agent/settings` | Ubah batas token bulanan |

### B. API Key Management (Untuk Agent User)

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **List API Keys** | GET `/v1/agent/api-keys` | Lihat semua API key agent |
| **Create API Key** | POST `/v1/agent/api-keys` | Buat API key baru |
| **Delete API Key** | DELETE `/v1/agent/api-keys/:id` | Hapus API key |
| **Regenerate API Key** | POST `/v1/agent/api-keys/:id/regenerate` | Regenerate API key |

*Catatan: Saat ini API key management hanya ada di `/admin/*` (hanya admin yang bisa)*

### C. MCP Server Configuration (Untuk Agent)

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **List Available MCP Servers** | GET `/v1/agent/mcp-servers` | Lihat MCP servers yang bisa diaktifkan |
| **Enable MCP Server** | POST `/v1/agent/mcp-servers` | Aktifkan MCP server untuk agent |
| **Disable MCP Server** | DELETE `/v1/agent/mcp-servers/:id` | Nonaktifkan MCP server |
| **Configure MCP Server** | PATCH `/v1/agent/mcp-servers/:id` | Ubah config MCP server (API keys, dll) |

*Catatan: Saat ini MCP server management hanya ada di `/admin/*` (hanya admin yang bisa)*

### D. Chat History

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **Save Chat Session** | POST `/v1/agent/chats` | Simpan sesi chat |
| **List Chat Sessions** | GET `/v1/agent/chats` | Lihat riwayat chat |
| **Get Chat Detail** | GET `/v1/agent/chats/:id` | Lihat detail chat |
| **Delete Chat** | DELETE `/v1/agent/chats/:id` | Hapus chat |
| **Continue Chat** | POST `/v1/chat/completions` dengan `session_id` | Lanjutkan chat sebelumnya |

### E. Real-time Updates

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **WebSocket / SSE for Balance** | WS `/ws/balance` | Update saldo real-time |
| **WebSocket / SSE for Usage** | WS `/ws/usage` | Update usage real-time |

### F. Payment/Top-up

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **Generate Payment Address** | POST `/v1/agent/payments/address` | Generate wallet address untuk top-up |
| **Get Payment Status** | GET `/v1/agent/payments/:id` | Cek status pembayaran |
| **Manual Top-up (Admin)** | POST `/admin/agents/:id/top-up` | Top-up manual (SUDAH ADA di admin) |

### G. Authentication & User Management

| Fitur | Endpoint Baru | Keterangan |
|-------|---------------|------------|
| **User Register** | POST `/v1/auth/register` | Register user baru |
| **User Login** | POST `/v1/auth/login` | Login user |
| **Create Agent for User** | POST `/v1/agent` | Buat agent baru untuk user |
| **List User's Agents** | GET `/v1/agent/list` | Lihat semua agent user |

---

## 3. RINGKASAN PRIORITAS PENGEMBANGAN

### Prioritas 1 - Wajib untuk Home & SandboxDasar

```
1. [CRITICAL] Agent Settings - Edit system prompt, default model, wallet address
2. [CRITICAL] Agent API Key Management - Buat/hapus API key
3. [CRITICAL] Agent MCP Server Management - Aktifkan/nonaktifkan MCP servers
```

### Prioritas 2 - Penting untuk User Experience

```
4. [HIGH] Chat History - Simpan & lihat riwayat chat
5. [HIGH] User Registration/Login - Auth untuk frontend
6. [HIGH] Create Agent for User - Buat agent saat register
```

### Prioritas 3 - Nice to Have

```
7. [MEDIUM] Real-time Updates - WebSocket untuk balance/usage
8. [MEDIUM] Payment Address Generation
9. [LOW] Continue Chat Session
```

---

## 4. ENDPOINT LENGKAP YANG BUTUH DIBUAT

```typescript
// ===== AGENT SETTINGS =====
PATCH /v1/agent/settings
Body: {
  system_prompt?: string,
  default_model_id?: string,
  wallet_address?: string,
  monthly_token_limit?: number
}

// ===== AGENT API KEYS =====
GET    /v1/agent/api-keys           // List semua API key agent
POST   /v1/agent/api-keys           // Buat API key baru
DELETE /v1/agent/api-keys/:id       // Hapus API key

// ===== AGENT MCP SERVERS =====
GET    /v1/agent/mcp-servers       // List MCP servers tersedia + status
POST   /v1/agent/mcp-servers       // Aktifkan MCP server
DELETE /v1/agent/mcp-servers/:id   // Nonaktifkan MCP server
PATCH  /v1/agent/mcp-servers/:id   // Configure MCP server (env vars)

// ===== CHAT HISTORY =====
GET    /v1/agent/chats              // List chat sessions
GET    /v1/agent/chats/:id          // Get chat detail
DELETE /v1/agent/chats/:id          // Delete chat

// ===== AUTH =====
POST   /v1/auth/register            // Register user
POST   /v1/auth/login               // Login
POST   /v1/agent                    // Create agent (untuk user baru)

// ===== PAYMENT =====
POST   /v1/agent/payments/address   // Generate payment address
GET    /v1/agent/payments/:id      // Get payment status
```

---

## 5. DATABASE TABLES YANG PERLU DITAMBAH

### chats (untuk chat history)
```sql
CREATE TABLE chats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agent_id UUID REFERENCES agents(id),
  title TEXT,
  model_id TEXT,
  messages JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### users (jika tidak menggunakan Supabase Auth)
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  is_active BOOLEAN DEFAULT true
);
```

---

## 6. KESIMPULAN

**Yang SUDAH ADA di Backend saat ini:**
- ✅ Chat completions + streaming + reasoning
- ✅ MCP tools (Daemon Intel, Exa)
- ✅ Usage tracking + billing
- ✅ Admin management (full)
- ✅ Basic agent info endpoints

**Yang KURANG untuk Frontend Home & Sandbox:**
- ❌ Agent settings (edit system prompt, model, wallet)
- ❌ Agent API key management
- ❌ Agent MCP server configuration
- ❌ Chat history
- ❌ User authentication
- ❌ Real-time updates

**Rekomendasi:** Prioritaskan development endpoints prioritas 1 dan 2 terlebih dahulu agar frontend Home & Sandbox bisa berfungsi dengan baik.
