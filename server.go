package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

// =========================================================================
// KONSTANTA & KONFIGURASI
// =========================================================================
const (
	GROUNDING_OFF          = 0
	GROUNDING_GO_SCRAPER   = 1
	GROUNDING_AI_DEDICATED = 2

	MEMORY_FILE        = "memory/oracle_memory.json"
	PELAJARAN_FILE     = "PelajaranBerharga.json"
	MAX_MEMORY_DAYS    = 30
	MAX_ENTRIES_SYMBOL = 720   // ~24 entry/hari * 30 hari
	DISASTER_THRESHOLD = -0.50 // Loss >= 50% dari balance = Disaster
	VICTORY_MIN_USD    = 2.0   // Minimal profit USD agar dicatat sebagai pelajaran
)

var (
	ActiveGroundingMode = GROUNDING_OFF
	AIGroundingModel    = "google/gemma-4-31B-it"
	DisableAI           = false // AI re-enabled with HuggingFace support
	hfApiKey            = ""

	liveNewsData string = "Sistem AI Berita Aktif (HuggingFace)."

	// Rotator kunci API Gemini
	geminiApiKeys []string
	currentKeyIdx int
	keyMu         sync.Mutex

	mu       sync.Mutex
	memoryMu sync.Mutex

	// Menyimpan data Tick-by-Tick terakhir dari MQL5 untuk web dashboard
	LatestMT5Status = make(map[string]map[string]float64)

	// Phase 5: Global News Timer
	nextHighImpactNews time.Time
	minToNextNews      int = 9999
)

// =========================================================================
// STRUKTUR DATA NATIVE GEMINI
// =========================================================================
type GeminiRequest struct {
	Contents         []Content         `json:"contents"`
	SystemInstruction *Content         `json:"system_instruction,omitempty"`
	Tools            []Tool            `json:"tools,omitempty"`
	GenerationConfig *GenerationConfig `json:"generationConfig,omitempty"`
}

type Content struct {
	Role  string `json:"role,omitempty"`
	Parts []Part `json:"parts"`
}

type Part struct {
	Text string `json:"text"`
}

type Tool struct {
	GoogleSearchRetrieval *struct{} `json:"google_search_retrieval,omitempty"`
}

type GenerationConfig struct {
	Temperature     float64 `json:"temperature,omitempty"`
	TopP            float64 `json:"topP,omitempty"`
	TopK            int     `json:"topK,omitempty"`
	MaxOutputTokens int     `json:"maxOutputTokens,omitempty"`
}

type GeminiResponse struct {
	Candidates []struct {
		Content struct {
			Parts []Part `json:"parts"`
		} `json:"content"`
		GroundingMetadata interface{} `json:"groundingMetadata,omitempty"`
	} `json:"candidates"`
}

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}
type FFEvent struct {
	Title   string `json:"title"`
	Impact  string `json:"impact"`
	Country string `json:"country"`
	Date    string `json:"date"` // Tambah field date untuk filter hari ini
}

// --- MEMORY ---
type MemoryEntry struct {
	Timestamp string  `json:"ts"`
	Symbol    string  `json:"sym"`
	Input     string  `json:"in"`
	Decision  string  `json:"dec"`
	Action    string  `json:"act"`
	EntryPx   float64 `json:"entry"` // Price In
	ExitPx    float64 `json:"exit"`  // Price Out (Baru)
	SL        float64 `json:"sl"`
	TP        float64 `json:"tp"`
	Ticket    string  `json:"ticket"` // MT5 Ticket id (Baru)
	Type      string  `json:"type"`   // BUY/SELL (Baru)
	Volume    float64 `json:"vol"`    // Lot size (Baru)
	Result    string  `json:"res,omitempty"`
	ProfitUSD float64 `json:"pnl,omitempty"`
	Balance   float64 `json:"bal,omitempty"`
}

type OracleMemory struct {
	History map[string][]MemoryEntry `json:"history"`
}

// --- PELAJARAN BERHARGA ---
type Lesson struct {
	Date      string  `json:"date"`
	Symbol    string  `json:"symbol"`
	Kind      string  `json:"kind"`     // "VICTORY" atau "DISASTER"
	Decision  string  `json:"decision"` // string keputusan Oracle
	Context   string  `json:"context"`  // input market saat itu
	ProfitUSD float64 `json:"pnl"`
	Balance   float64 `json:"balance_at_time"`
	Analysis  string  `json:"analysis"` // teks AI analisis
}

type PelajaranBerharga struct {
	TotalVictories int      `json:"total_victories"`
	TotalDisasters int      `json:"total_disasters"`
	Victories      []Lesson `json:"victories"`
	Disasters      []Lesson `json:"disasters"`
	LastUpdated    string   `json:"last_updated"`
}

// RSS untuk scraper
type RSS struct {
	Channel Channel `xml:"channel"`
}
type Channel struct {
	Items []Item `xml:"item"`
}
type Item struct {
	Title string `xml:"title"`
}

// =========================================================================
// MEMORY: LOAD, SAVE, TRIM, INJECT
// =========================================================================
func loadMemory() OracleMemory {
	memoryMu.Lock()
	defer memoryMu.Unlock()

	os.MkdirAll(filepath.Dir(MEMORY_FILE), 0755)
	mem := OracleMemory{History: make(map[string][]MemoryEntry)}

	data, err := os.ReadFile(MEMORY_FILE)
	if err == nil {
		json.Unmarshal(data, &mem)
	}
	return mem
}

func saveMemory(mem OracleMemory) {
	memoryMu.Lock()
	defer memoryMu.Unlock()
	os.MkdirAll(filepath.Dir(MEMORY_FILE), 0755)
	data, _ := json.MarshalIndent(mem, "", "  ")
	os.WriteFile(MEMORY_FILE, data, 0644)
}

func trimMemory(entries []MemoryEntry) []MemoryEntry {
	cutoff := time.Now().AddDate(0, 0, -MAX_MEMORY_DAYS)
	filtered := []MemoryEntry{}
	for _, e := range entries {
		t, err := time.Parse(time.RFC3339, e.Timestamp)
		if err != nil || t.After(cutoff) {
			filtered = append(filtered, e)
		}
	}
	// Batasi maksimal entri per symbol
	if len(filtered) > MAX_ENTRIES_SYMBOL {
		filtered = filtered[len(filtered)-MAX_ENTRIES_SYMBOL:]
	}
	return filtered
}

func appendMemory(symbol string, entry MemoryEntry) {
	mem := loadMemory()
	entries := mem.History[symbol]
	entries = append(entries, entry)
	entries = trimMemory(entries)
	mem.History[symbol] = entries
	saveMemory(mem)
}

func updateLastMemory(symbol, result string, profitUSD, balance float64) {
	mem := loadMemory()
	entries := mem.History[symbol]
	if len(entries) == 0 {
		return
	}
	// Update entry PENDING terakhir
	for i := len(entries) - 1; i >= 0; i-- {
		if entries[i].Result == "" || entries[i].Result == "PENDING" {
			entries[i].Result = result
			entries[i].ProfitUSD = profitUSD
			entries[i].Balance = balance
			break
		}
	}
	mem.History[symbol] = entries
	saveMemory(mem)
}

func buildMemoryContext(symbol string) string {
	mem := loadMemory()
	entries := mem.History[symbol]
	if len(entries) == 0 {
		return "Belum ada riwayat keputusan untuk simbol ini."
	}
	// Ambil 5 keputusan terakhir
	start := 0
	if len(entries) > 5 {
		start = len(entries) - 5
	}
	recent := entries[start:]

	// Hitung statistik singkat
	wins, losses, pending := 0, 0, 0
	totalPnl := 0.0
	for _, e := range entries {
		switch e.Result {
		case "WIN":
			wins++
			totalPnl += e.ProfitUSD
		case "LOSS", "CUT":
			losses++
			totalPnl += e.ProfitUSD
		default:
			pending++
		}
	}

	ctx := fmt.Sprintf("=== MEMORI ORACLE (%s) ===\nStatistik 30 Hari: WIN=%d LOSS=%d PENDING=%d | Total PnL: $%.2f\n\n5 Keputusan Terakhir:\n", symbol, wins, losses, pending, totalPnl)
	for _, e := range recent {
		ctx += fmt.Sprintf("  [%s] %s → Hasil: %s | PnL: $%.2f\n", e.Timestamp[:10], e.Decision, e.Result, e.ProfitUSD)
	}
	return ctx
}

// =========================================================================
// PELAJARAN BERHARGA: LOAD, SAVE, ANALISIS
// =========================================================================
func loadPelajaran() PelajaranBerharga {
	pb := PelajaranBerharga{}
	data, err := os.ReadFile(PELAJARAN_FILE)
	if err == nil {
		json.Unmarshal(data, &pb)
	}
	return pb
}

func savePelajaran(pb PelajaranBerharga) {
	pb.TotalVictories = len(pb.Victories)
	pb.TotalDisasters = len(pb.Disasters)
	pb.LastUpdated = time.Now().Format(time.RFC3339)
	data, _ := json.MarshalIndent(pb, "", "  ")
	os.WriteFile(PELAJARAN_FILE, data, 0644)
}

func generateAnalysis(kind, symbol, decision, context string, pnl, balance float64) string {
	if DisableAI {
		return "Analisis AI dinonaktifkan sementara."
	}
	var prompt string
	if kind == "VICTORY" {
		prompt = fmt.Sprintf(`Anda adalah analis trading profesional. Tulis analisis singkat (3-5 kalimat) tentang MENGAPA strategi ini BERHASIL menghasilkan profit.
Simbol: %s
Keputusan Oracle: %s
Konteks Pasar Saat Itu: %s
Profit: $%.2f
Tulis dalam bahasa Indonesia, padat dan informatif. Fokus pada faktor kunci keberhasilan dan kondisi pasar yang mendukung.`, symbol, decision, context, pnl)
	} else {
		prompt = fmt.Sprintf(`Anda adalah analis trading profesional. Tulis analisis post-mortem mendalam (5-7 kalimat) tentang MENGAPA strategi ini GAGAL parah hingga loss %.0f%% dari balance.
Simbol: %s
Keputusan Oracle: %s
Konteks Pasar Saat Itu: %s
Loss: $%.2f dari Balance $%.2f
Tulis dalam bahasa Indonesia. Identifikasi: (1) akar penyebab kegagalan, (2) sinyal bahaya yang seharusnya terdeteksi, (3) pelajaran agar tidak terulang.`, pnl/balance*100, symbol, decision, context, pnl, balance)
	}

	res, err := callHuggingFaceNative(prompt, "google/gemma-4-31B-it")
	if err != nil {
		res, err = callGeminiNative(prompt, "Anda adalah analis trading profesional.", "gemini-1.5-flash", false)
	}
	if err != nil {
		return "Analisis tidak tersedia."
	}
	return res
}

func recordLesson(symbol, decision, context string, pnl, balance float64) {
	pb := loadPelajaran()

	lesson := Lesson{
		Date:      time.Now().Format("2006-01-02"),
		Symbol:    symbol,
		Decision:  decision,
		Context:   context,
		ProfitUSD: pnl,
		Balance:   balance,
	}

	if balance > 0 && pnl/balance <= DISASTER_THRESHOLD {
		// DISASTER: loss >= 50% balance
		fmt.Printf("🚨 [PelajaranBerharga] DISASTER TERDETEKSI! Loss $%.2f (%.1f%%). Menganalisis...\n", pnl, pnl/balance*100)
		lesson.Kind = "DISASTER"
		lesson.Analysis = generateAnalysis("DISASTER", symbol, decision, context, pnl, balance)
		pb.Disasters = append(pb.Disasters, lesson)

		// Sort disasters terbaru di atas
		sort.Slice(pb.Disasters, func(i, j int) bool {
			return pb.Disasters[i].Date > pb.Disasters[j].Date
		})
		fmt.Printf("📖 Analisis Disaster disimpan ke %s\n", PELAJARAN_FILE)
	} else if pnl >= VICTORY_MIN_USD {
		// VICTORY: profit cukup signifikan
		fmt.Printf("🏆 [PelajaranBerharga] VICTORY dicatat! Profit $%.2f\n", pnl)
		lesson.Kind = "VICTORY"
		lesson.Analysis = generateAnalysis("VICTORY", symbol, decision, context, pnl, balance)
		pb.Victories = append(pb.Victories, lesson)

		// Batasi victories ke 500 entri (tetap simpan semua, tapi trim yang lama kalau terlalu penuh)
		if len(pb.Victories) > 500 {
			pb.Victories = pb.Victories[len(pb.Victories)-500:]
		}
	}

	savePelajaran(pb)
}

// =========================================================================
// MAIN: SERVER
// =========================================================================
func main() {
	if !DisableAI {
		initKeys()
		go beritaForexRoutine()
	}

	// Endpoint utama: Konsultasi Oracle
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Harus POST", http.StatusMethodNotAllowed)
			return
		}

		body, _ := io.ReadAll(r.Body)
		mt5Report := string(body)

		// Ekstrak simbol dari payload (format: "SYMBOL:EURUSD PORTFOLIO[...]")
		symbol := "UNKNOWN"
		if idx := strings.Index(mt5Report, "SYMBOL:"); idx != -1 {
			rest := mt5Report[idx+7:]
			if end := strings.IndexAny(rest, " \n\t|"); end != -1 {
				symbol = rest[:end]
			} else {
				symbol = strings.TrimSpace(rest)
			}
		}

		// Update Data Real-Time untuk Web Dashboard
		go updateLatestStatus(symbol, mt5Report)

		// WEEKEND GATE: Pasar Forex Tutup Sabtu & Minggu
		now := time.Now().UTC()
		weekday := now.Weekday()
		if weekday == time.Saturday || weekday == time.Sunday {
			fmt.Printf("[Oracle] 🌙 Weekend Gate: %s hari %s - Pasar Tutup. HOLD.\n", symbol, weekday)
			w.Header().Set("Content-Type", "text/plain")
			w.Write([]byte("HOLD|0|0|0|Weekend: Pasar Forex Tutup. Robot Istirahat."))
			return
		}

		// BUG FIX: mu.Lock hilang sebelum mu.Unlock — race condition mematikan!
		mu.Lock()
		currentNews := liveNewsData
		mu.Unlock()

		memCtx := buildMemoryContext(symbol)

		fmt.Printf("\n[Oracle] 📩 %s | Laporan: %s\n", symbol, mt5Report[:min(80, len(mt5Report))])

		aiDecision := tanyakanWarrenBuffet(mt5Report, currentNews, memCtx, symbol)
		fmt.Printf("[Oracle] 🧠 Keputusan: %s\n", aiDecision)

		// Simpan keputusan ke memori
		parts := strings.Split(aiDecision, "|")
		entry := MemoryEntry{
			Timestamp: time.Now().Format(time.RFC3339),
			Symbol:    symbol,
			Input:     mt5Report,
			Decision:  aiDecision,
			Result:    "PENDING",
		}
		if len(parts) >= 5 {
			entry.Action = strings.TrimSpace(parts[0])
		}
		appendMemory(symbol, entry)

		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(aiDecision))
	})

	// Endpoint feedback: MT5 melaporkan hasil trade
	http.HandleFunc("/feedback", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Harus POST", http.StatusMethodNotAllowed)
			return
		}

		body, _ := io.ReadAll(r.Body)
		// Format baru: "SYMBOL|RESULT|PROFIT_USD|BALANCE|TICKET|TYPE|VOL|PX_IN|PX_OUT"
		raw := string(body)
		parts := strings.Split(raw, "|")

		if len(parts) < 4 {
			http.Error(w, "Format salah.", http.StatusBadRequest)
			return
		}

		symbol := strings.TrimSpace(parts[0])
		result := strings.TrimSpace(parts[1])
		var profitUSD, balance, vol, pxIn, pxOut float64
		fmt.Sscanf(parts[2], "%f", &profitUSD)
		fmt.Sscanf(parts[3], "%f", &balance)

		ticket := "-"
		tradeType := "-"
		if len(parts) >= 9 {
			ticket = parts[4]
			tradeType = parts[5]
			fmt.Sscanf(parts[6], "%f", &vol)
			fmt.Sscanf(parts[7], "%f", &pxIn)
			fmt.Sscanf(parts[8], "%f", &pxOut)
		}

		fmt.Printf("\n💬 [Feedback] %s: %s | Ticket:%s | PnL=$%.2f\n", symbol, result, ticket, profitUSD)

		// Update memori dengan hasil mendetail
		lastDecision := ""
		memoryMu.Lock()
		mem := loadMemory()
		if entries, exists := mem.History[symbol]; exists && len(entries) > 0 {
			// Update entri PENDING terakhir dengan data riil dari MT5
			idx := len(entries) - 1
			lastDecision = mem.History[symbol][idx].Decision // Ambil keputusan asli AI
			mem.History[symbol][idx].Result = result
			mem.History[symbol][idx].ProfitUSD = profitUSD
			mem.History[symbol][idx].Balance = balance
			mem.History[symbol][idx].Ticket = ticket
			mem.History[symbol][idx].Type = tradeType
			mem.History[symbol][idx].Volume = vol
			mem.History[symbol][idx].EntryPx = pxIn
			mem.History[symbol][idx].ExitPx = pxOut
		}
		saveMemory(mem)
		memoryMu.Unlock()

		// Evaluasi untuk PelajaranBerharga
		if lastDecision != "" {
			go recordLesson(symbol, lastDecision, "", profitUSD, balance)
		}

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Endpoint API: Web Dashboard Metrics
	http.HandleFunc("/api/stats", handleApiStats)

	// Heartbeat Endpoint: Agar Dashboard dapat update Live Equity meski AI tidur (biasanya luar sesi MT5)
	http.HandleFunc("/heartbeat", func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		payload := string(body)

		symbol := "UNKNOWN"
		if idx := strings.Index(payload, "SYMBOL:"); idx != -1 {
			rest := payload[idx+7:]
			if end := strings.IndexAny(rest, " |\n"); end != -1 {
				symbol = rest[:end]
			} else {
				symbol = strings.TrimSpace(rest)
			}
		}
		go updateLatestStatus(symbol, payload)
		w.WriteHeader(http.StatusOK)
	})

	// PHASE 3: Scalper Drone Endpoint
	http.HandleFunc("/scalp", handleScalperDrone)

	// Endpoint Frontend
	http.Handle("/dashboard/", http.StripPrefix("/dashboard/", http.FileServer(http.Dir("./dashboard"))))

	fmt.Println("⚡ Antigravity Quant [The Oracle v9 APEX ENGINE] Menyala!")
	fmt.Println("📍 POST /          → Oracle Deep Thinker (M1 Swing)")
	fmt.Println("📍 POST /feedback  → Feedback Loop (Win/Loss Tracker)")
	fmt.Println("📍 POST /scalp     → Scalper Drone (M1/M5 Fast Alpha)")
	fmt.Println("📍 POST /heartbeat → Sinkronisasi Equity 24/5")
	fmt.Println("📍 GET  /dashboard → Web Dashboard UI")
	log.Fatal(http.ListenAndServe(":8880", nil))
}

// =========================================================================
// DASHBOARD WEB ANALITYCS & EXTRACTOR
// =========================================================================

// Mengekstrak nilai spesifik dari regex/tag manual
func extractValue(payload, key string) float64 {
	idx := strings.Index(payload, key+":")
	if idx == -1 {
		return 0
	}
	sub := payload[idx+len(key)+1:]
	end := strings.IndexAny(sub, "| \n\t]")
	if end != -1 {
		sub = sub[:end]
	}
	var val float64
	fmt.Sscanf(sub, "%f", &val)
	return val
}

// =========================================================================
// PHASE 3: SCALPER DRONE HANDLER
// =========================================================================
func handleScalperDrone(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "POST only", http.StatusMethodNotAllowed)
		return
	}
	// Weekend gate
	now := time.Now().UTC()
	if now.Weekday() == time.Saturday || now.Weekday() == time.Sunday {
		w.WriteHeader(200)
		w.Write([]byte("HOLD|0|0|0|Weekend gate"))
		return
	}

	body, _ := io.ReadAll(r.Body)
	payload := string(body)

	// Extract symbol
	symbol := "UNKNOWN"
	if idx := strings.Index(payload, "SYMBOL:"); idx != -1 {
		rest := payload[idx+7:]
		if end := strings.IndexAny(rest, " |\n"); end != -1 {
			symbol = rest[:end]
		} else {
			symbol = strings.TrimSpace(rest)
		}
	}

	if DisableAI {
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte("HOLD|0|0|0|Mode Pasif: AI Dimatikan"))
		return
	}

	systemScalper := `Anda adalah Scalper AI ultra-cepat. Tugasmu: HANYA eksekusi peluang scalp 8-15 pip pada M1/M5.
Input: Simbol, Delta M1, Delta M5, Spread, ASK, BID.

ATURAN KETAT:
- Jika M1 dan M5 searah (keduanya positif = bullish, keduanya negatif = bearish) DAN Spread < 15: eksekusi SCALP_BUY atau SCALP_SELL.
- Jika M1 dan M5 berlawanan arah, atau Spread >= 20: HOLD saja.
- SL = 10 pip dari harga. TP = 12 pip dari harga (R:R minimal 1.2).
- ATR tidak diperlukan untuk scalping M1.

OUTPUT WAJIB (1 baris, 5 elemen pip '|'):
SCALP_BUY|0|SL_ABSOLUT|TP_ABSOLUT|Alasan singkat
atau: SCALP_SELL|0|SL_ABSOLUT|TP_ABSOLUT|Alasan singkat
atau: HOLD|0|0|0|Alasan singkat`

	prompt := fmt.Sprintf("Data Scalper: [%s]", payload)
	// Try HF then Gemini for Scalper
	decision, err := callHuggingFaceNative(prompt, "google/gemma-4-26b-a4b-it")
	if err != nil {
		decision, err = callGeminiNative(prompt, systemScalper, "gemini-1.5-flash", false)
	}
	if err != nil {
		decision = "HOLD|0|0|0|Semua provider AI gagal"
	}

	fmt.Printf("[Scalper] 🐝 %s → %s\n", symbol, decision)
	w.Header().Set("Content-Type", "text/plain")
	w.Write([]byte(decision))
}

func updateLatestStatus(symbol, payload string) {
	mu.Lock()
	defer mu.Unlock()

	if LatestMT5Status[symbol] == nil {
		LatestMT5Status[symbol] = make(map[string]float64)
	}

	LatestMT5Status[symbol]["BAL"] = extractValue(payload, "BAL")
	LatestMT5Status[symbol]["FLOAT"] = extractValue(payload, "FLOAT")
	LatestMT5Status[symbol]["F_MARG"] = extractValue(payload, "F_MARG")
	LatestMT5Status[symbol]["POS"] = extractValue(payload, "POS")
}

func handleApiStats(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	mem := loadMemory()
	pb := loadPelajaran()

	type ChartPoint struct {
		Date string  `json:"date"`
		Val  float64 `json:"val"`
	}

	totalBalance := 0.0
	totalFloating := 0.0
	var overallChart []ChartPoint

	// Hitung PnL harian untuk Chart
	dailyPnL := make(map[string]float64)

	mu.Lock()
	for _, status := range LatestMT5Status {
		// FIX: Jika satu akun punya banyak pair, jangan di-SUM (nanti jadi $400k).
		// Kita ambil nilai tertinggi yang dilaporkan (harus sama semua di satu akun).
		if val, exists := status["BAL"]; exists {
			if val > totalBalance {
				totalBalance = val
			}
		}
		// Floating profit juga bersifat akun-luas, ambil yang terbaru (timpa terus).
		if val, exists := status["FLOAT"]; exists {
			totalFloating = val
		}
	}
	mu.Unlock()

	// Proses data historis
	for _, entries := range mem.History {
		for _, e := range entries {
			if e.Result == "WIN" || e.Result == "LOSS" || e.Result == "CUT" {
				if len(e.Timestamp) >= 10 {
					date := e.Timestamp[:10]
					dailyPnL[date] += e.ProfitUSD
				}
			}
		}
	}

	// Format ke Array dan Sortir by Date
	var dates []string
	for k := range dailyPnL {
		dates = append(dates, k)
	}
	sort.Strings(dates)

	// Bangun balance chart semu berdasarkan balance saat ini mundur,
	// atau profit kumulatif harian maju. Kita pakai Cumulative Profit:
	cumProfit := 0.0
	for _, d := range dates {
		cumProfit += dailyPnL[d]
		overallChart = append(overallChart, ChartPoint{Date: d, Val: cumProfit})
	}

	// Hitung Max Drawdown Berdasarkan Sejarah Pelajaran (karena kita ga simpan full tick)
	maxAbsDrawdown := 0.0
	for _, dis := range pb.Disasters { // Disasters berisi pnl merah yg dibooked
		if dis.ProfitUSD < defaultMin(maxAbsDrawdown, 0.0) {
			maxAbsDrawdown = dis.ProfitUSD
		}
	}
	// Atau jika ada trade loss besar di memory biasa
	for _, entries := range mem.History {
		for _, e := range entries {
			if e.ProfitUSD < defaultMin(maxAbsDrawdown, 0.0) {
				maxAbsDrawdown = e.ProfitUSD
			}
		}
	}

	equity := totalBalance + totalFloating

	// Hitung Win Rate dari semua memory
	totalWins, totalLosses := 0, 0
	for _, entries := range mem.History {
		for _, e := range entries {
			if e.Result == "WIN" {
				totalWins++
			} else if e.Result == "LOSS" || e.Result == "CUT" {
				totalLosses++
			}
		}
	}
	winRate := 0.0
	if totalWins+totalLosses > 0 {
		winRate = float64(totalWins) / float64(totalWins+totalLosses) * 100.0
	}

	// Hitung Total PnL keseluruhan
	totalPnL := 0.0
	for _, d := range dates {
		totalPnL += dailyPnL[d]
	}

	response := map[string]interface{}{
		"equity":           equity,
		"balance":          totalBalance,
		"floating":         totalFloating,
		"max_abs_drawdown": maxAbsDrawdown,
		"chart_data":       overallChart,
		"wins":             pb.TotalVictories,
		"losses":           pb.TotalDisasters,
		"total_wins":       totalWins,
		"total_losses":     totalLosses,
		"win_rate":         winRate,
		"total_pnl":        totalPnL,
		"latest_lessons":   pb.Victories,
		"latest_disasters": pb.Disasters,
		"history":          mem.History, // Tambahkan ini untuk tabel Riwayat
	}

	json.NewEncoder(w).Encode(response)
}

// helper min untuk Go <1.21
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
func defaultMin(a, b float64) float64 {
	if a < b {
		return a
	}
	return b
}

// =========================================================================
// SENSOR BERITA PUSAT
// =========================================================================
// BUG FIX: defer di dalam infinite loop menyebabkan file descriptor leak!
// Setiap iterasi loop TIDAK boleh pakai defer untuk Close, harus eksplisit di luar.
func beritaForexRoutine() {
	for {
		func() { // wrapper agar defer berfungsi per-iterasi
			resp, err := http.Get("https://nfs.faireconomy.media/ff_calendar_thisweek.json")
			if err != nil {
				fmt.Println("[BeritaForum] Gagal menarik kalender FF:", err)
				return
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			var events []FFEvent
			json.Unmarshal(body, &events)

			todayStr := time.Now().UTC().Format("2006-01-02")
			penting := "📅 Agenda Berita High-Impact Hari Ini:\n"
			jumlah := 0
			for _, ev := range events {
				// FIX: filter hanya event HARI INI (bukan semua minggu ini)
				if ev.Impact == "High" && (ev.Country == "USD" || ev.Country == "EUR" || ev.Country == "GBP") {
					// Kalau field date tersedia, filter per hari. Jika tidak, tampilkan semua high.
					if ev.Date == "" || strings.HasPrefix(ev.Date, todayStr) {
						penting += fmt.Sprintf("  - [%s] %s\n", ev.Country, ev.Title)
						jumlah++
					}
				}
			}

			mu.Lock()
			if jumlah > 0 {
				liveNewsData = penting
				fmt.Printf("[BeritaForex] %d berita high-impact ditemukan hari ini.\n", jumlah)
			} else {
				liveNewsData = "Kondisi Berita Global: Tenang. Tidak ada event high-impact hari ini."
			}

			// Phase 5: Cari event terdekat yang belum lewat
			minDiff := 9999
			var nextTime time.Time
			nowUTC := time.Now().UTC()
			for _, ev := range events {
				if ev.Impact == "High" && (ev.Country == "USD" || ev.Country == "EUR" || ev.Country == "GBP" || ev.Country == "All") {
					evTime, err := time.Parse(time.RFC3339, ev.Date)
					if err == nil && evTime.After(nowUTC) {
						diff := int(evTime.Sub(nowUTC).Minutes())
						if diff < minDiff {
							minDiff = diff
							nextTime = evTime
						}
					}
				}
			}
			minToNextNews = minDiff
			nextHighImpactNews = nextTime
			mu.Unlock()
		}()
		// Update berita setiap 15 menit agar timer lebih akurat
		time.Sleep(15 * time.Minute)
	}
}

// =========================================================================
// DUAL GROUNDING SYSTEMS
// =========================================================================
func performScraperGrounding(context string) string {
	fmt.Println("📡 [GoScraper] Menarik berita RSS ForexLive...")
	url := "https://www.forexlive.com/feed/news"
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0")
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "Gagal scrape internet via Go."
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	var rss RSS
	xml.Unmarshal(body, &rss)

	var titles []string
	for i, item := range rss.Channel.Items {
		if i >= 5 {
			break
		}
		titles = append(titles, item.Title)
	}
	if len(titles) == 0 {
		return "Tidak menemukan berita."
	}
	return "Berita Scraping Mentah: " + strings.Join(titles, " | ")
}

func performAIGrounding(context string) string {
	if DisableAI {
		return "AI Grounding (Google Search) Dinonaktifkan."
	}
	fmt.Println("📡 [AIGrounding] AI Khusus menjelajah internet...")
	prompt := "Ringkasan berita market forex hari ini: " + context
	res, err := callHuggingFaceNative(prompt, "google/gemma-4-31B-it")
	if err != nil {
		res, err = callGeminiNative(prompt, "Asisten riset pasar.", "gemini-1.5-flash", true)
	}
	if err != nil {
		return "AI Grounding gagal: " + err.Error()
	}
	return "AI Grounding: " + res
}

// =========================================================================
// MULTI-PAIR CONTEXT BUILDER
// =========================================================================
func buildGlobalPortfolioContext(excludeSymbol string) string {
	mu.Lock()
	defer mu.Unlock()

	var sb strings.Builder
	sb.WriteString("\n🌐 GLOBAL PORTFOLIO STATUS (Other Pairs):\n")
	found := false
	for sym, data := range LatestMT5Status {
		if sym == excludeSymbol || sym == "UNKNOWN" {
			continue
		}
		pos := int(data["POS"])
		if pos > 0 {
			sb.WriteString(fmt.Sprintf("  - %s: %d open positions | Float: $%.2f\n", sym, pos, data["FLOAT"]))
			found = true
		}
	}
	if !found {
		return "\n🌐 GLOBAL PORTFOLIO: Tidak ada posisi terbuka di pair lain (Diversifikasi Optimal).\n"
	}
	return sb.String()
}

// =========================================================================
// DEEP THINKER ALGORITHM
// =========================================================================
func tanyakanWarrenBuffet(mt5Report, news, memoryContext, symbol string) string {
	if DisableAI {
		return "HOLD|0|0|0|Safety Mode: AI Sedang Maintenance/Disabled"
	}
	mu.Lock()
	minNext := minToNextNews
	mu.Unlock()

	newsSafetyNote := ""
	if minNext <= 15 {
		newsSafetyNote = fmt.Sprintf("\n🚨 CRITICAL NEWS ALERT: Berita High-Impact rilis dalam %d MENIT! Segera Amankan Akun.\n", minNext)
	} else if minNext <= 60 {
		newsSafetyNote = fmt.Sprintf("\n⚠️ NEWS WARNING: Berita High-Impact rilis dalam %d menit.\n", minNext)
	}

	globalCtx := buildGlobalPortfolioContext(symbol)

	// Muat Pelajaran Berharga untuk konteks tambahan
	pb := loadPelajaran()
	pelajaranCtx := ""
	if len(pb.Disasters) > 0 {
		pelajaranCtx += "\n⚠️ PELAJARAN DARI DISASTER MASA LALU:\n"
		for i, d := range pb.Disasters {
			if i >= 2 {
				break
			} // Ambil 2 disaster terakhir
			pelajaranCtx += fmt.Sprintf("  ❌ [%s] %s: %s\n", d.Date, d.Symbol, d.Analysis[:min(150, len(d.Analysis))])
		}
	}
	if len(pb.Victories) > 0 {
		pelajaranCtx += "\n✅ POLA STRATEGI SUKSES SEBELUMNYA:\n"
		recent := pb.Victories
		if len(recent) > 2 {
			recent = recent[len(recent)-2:]
		}
		for _, v := range recent {
			pelajaranCtx += fmt.Sprintf("  ✅ [%s] %s: %s\n", v.Date, v.Symbol, v.Analysis[:min(120, len(v.Analysis))])
		}
	}

	systemPersona := `Anda adalah algoritma Quant Trading tingkat Institusi (Hedge Fund Level) dengan kemampuan belajar dari masa lalu.
Anda menerima Laporan Pasar lengkap dari MetaTrader 5:

1. PORTFOLIO: POS (posisi terbuka), FLOAT (profit/loss mengambang), BAL (saldo akun), F_MARG (margin bebas), WIN_STREAK, LOSS_STREAK
2. STRUCTURE: D1_H (Resistance hari ini), D1_L (Support hari ini), ASK, SPREAD, ATR_PIP
3. SESSION: Sesi pasar dan DAILY_START_BAL (modal awal hari ini) serta CONF_BIAS
4. DELTA: Pergeseran candle M1/M15/H1 dalam pip
5. MEMORI + PELAJARAN historis 30 hari
6. BERITA makro real-time

ATURAN KECERDASAN APEX:
- NEWS HARD-STOP: Jika '🚨 CRITICAL NEWS ALERT' (minNext <= 15) terdeteksi, Anda WAJIB mengeluarkan perintah CUT_LOSS_ALL atau minimal HOLD. Dilarang keras membuka posisi baru (BUY/SELL/LIMIT) sesaat sebelum berita besar. Keselamatan modal di atas segalanya.
- CORRELATION GUARD: Selalu periksa 'GLOBAL PORTFOLIO STATUS'. Jika Anda ingin SELL EURUSD tapi sudah ada posisi SELL GBPUSD yang besar, pertimbangkan risiko korelasi mata uang. Jangan tumpuk risiko pada satu arah mata uang (USD) secara berlebihan.
- MARKET ORDER AGRESIF: Jika Delta M1+M15 kuat dan searah dan momentum didukung berita → langsung BUY atau SELL. Jangan tunggu LIMIT.
- LIMIT ORDER: Hanya saat pasar ranging tanpa momentum, gunakan LIMIT untuk menangkap pantulan S/R.
- WIN_STREAK >= 3 → Kondisi excellent, bisa agresif lot. LOSS_STREAK >= 2 → Waspada, gunakan LIMIT/HOLD.
- SPREAD > 15 poin → Hindari market order kecuali momentum masif.
- ATR > 80 pip = volatile → SL wajib lebih lebar dari 1x ATR.
- Jika FLOAT negatif > 5% dari BAL → wajib CUT_LOSS_ALL demi integritas akun.
- Harga dekat D1_H (< 5 pip) → zona resistance. Harga dekat D1_L (< 5 pip) → zona support.
- Jika BAL - DAILY_START_BAL < -(5% dari DAILY_START_BAL) → HOLD total (Daily Drawdown Limit).

ATURAN OUTPUT BESI (DILARANG MENGOBROL):
Keluarkan SATU BARIS SAJA, 6 elemen pemisah pipa:
ACTION|ENTRY_PRICE|STOPLOSS|TAKEPROFIT|ALASAN_MAX_15_KATA|CONFIDENCE:ANGKA
- ACTION: BUY, SELL, BUY_LIMIT, SELL_LIMIT, AVERAGING_BUY, AVERAGING_SELL, CUT_LOSS_ALL, atau HOLD
- BUY/SELL/HOLD/CUT_LOSS_ALL → ENTRY_PRICE = 0
- BUY_LIMIT/SELL_LIMIT → ENTRY_PRICE = harga limit absolut
- SL dan TP = angka ABSOLUT berdasarkan ATR_PIP
- CONFIDENCE = angka 0-100 (keyakinan Anda atas keputusan ini)
  Contoh: BUY|0|1.1620|1.1700|Momentum bullish M1+M15 kuat|CONFIDENCE:82`

	groundingContext := ""
	if ActiveGroundingMode == GROUNDING_AI_DEDICATED {
		groundingContext = performAIGrounding(mt5Report)
	} else if ActiveGroundingMode == GROUNDING_GO_SCRAPER {
		groundingContext = performScraperGrounding(mt5Report)
	}

	promptString := fmt.Sprintf(
		"Simbol: %s%s%s\nData Radar MT5: [%s]\nAgenda Ekonomi: [%s]\nGrounding Internet: [%s]\n\n%s\n%s",
		symbol, newsSafetyNote, globalCtx, mt5Report, news, groundingContext, memoryContext, pelajaranCtx,
	)

	// Fallback logic: Coba HuggingFace dulu (karena Google bermasalah), lalu Gemini
	hfModels := []string{"google/gemma-4-31B-it", "google/gemma-4-26b-a4b-it"}
	geminiModels := []string{"gemini-3.1-flash-lite-preview", "gemini-1.5-flash"}

	var (
		pesan string
		err   error
	)

	// 1. Coba HuggingFace
	for _, m := range hfModels {
		fmt.Printf("🚀 Mencoba HuggingFace Model: %s\n", m)
		pesan, err = callHuggingFaceNative(promptString, m)
		if err == nil && strings.Contains(pesan, "|") {
			return pesan
		}
		fmt.Printf("⚠️  HuggingFace %s gagal: %v\n", m, err)
	}

	// 2. Coba Gemini (Fallback Terakhir)
	for _, m := range geminiModels {
		fmt.Printf("🚀 Mencoba Gemini Fallback: %s\n", m)
		pesan, err = callGeminiNative(promptString, systemPersona, m, false)
		if err == nil && strings.Contains(pesan, "|") {
			return pesan
		}
		fmt.Printf("⚠️  Gemini %s gagal: %v\n", m, err)
	}

	return "HOLD|0|0|0|Semua Model (HF & Gemini) Gagal"
}

// =========================================================================
// NATIVE GENAI CORE ENGINE
// =========================================================================

func initKeys() {
	data, err := os.ReadFile(".env")
	if err != nil {
		log.Println("⚠️  Gagal membaca .env, menggunakan default environment")
		return
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])

		if strings.HasPrefix(key, "GEMINI_API_KEY_") {
			geminiApiKeys = append(geminiApiKeys, val)
		} else if key == "HF_API_KEY" {
			hfApiKey = val
		}
	}
	fmt.Printf("✅ Terdeteksi %d API Key Gemini & HF Key Aktif.\n", len(geminiApiKeys))
}

func getGeminiAPIKey() string {
	keyMu.Lock()
	defer keyMu.Unlock()
	if len(geminiApiKeys) == 0 {
		return ""
	}
	key := geminiApiKeys[currentKeyIdx]
	currentKeyIdx = (currentKeyIdx + 1) % len(geminiApiKeys)
	return key
}

func callHuggingFaceNative(prompt, model string) (string, error) {
	if hfApiKey == "" {
		return "", fmt.Errorf("HF_API_KEY tidak dikonfigurasi")
	}

	apiUrl := fmt.Sprintf("https://api-inference.huggingface.co/models/%s", model)
	
	// HuggingFace payload for Text Generation
	payload := map[string]interface{}{
		"inputs": prompt,
		"parameters": map[string]interface{}{
			"max_new_tokens": 512,
			"temperature":    0.7,
			"return_full_text": false,
		},
	}

	jsonValue, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", apiUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+hfApiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 90 * time.Second} // Long timeout for large HF models
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HF API error: %s - %s", resp.Status, string(body))
	}

	// HF returns an array: [{"generated_text": "..."}]
	var hfResp []struct {
		GeneratedText string `json:"generated_text"`
	}
	if err := json.Unmarshal(body, &hfResp); err != nil {
		// Sometimes it returns a single object if error or different task
		return "", fmt.Errorf("unexpected HF response: %s", string(body))
	}

	if len(hfResp) > 0 {
		return strings.TrimSpace(hfResp[0].GeneratedText), nil
	}

	return "", fmt.Errorf("empty response from HuggingFace")
}

func callGeminiNative(prompt, system, model string, useSearch bool) (string, error) {
	key := getGeminiAPIKey()
	if key == "" {
		return "", fmt.Errorf("no API keys available")
	}

	// Native Google GenAI URL
	apiUrl := fmt.Sprintf("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s", model, key)

	reqObj := GeminiRequest{
		Contents: []Content{
			{
				Parts: []Part{{Text: prompt}},
			},
		},
		SystemInstruction: &Content{
			Parts: []Part{{Text: system}},
		},
		GenerationConfig: &GenerationConfig{
			Temperature: 0.7,
		},
	}

	if useSearch {
		reqObj.Tools = []Tool{
			{GoogleSearchRetrieval: &struct{}{}},
		}
	}

	jsonValue, _ := json.Marshal(reqObj)
	req, err := http.NewRequest("POST", apiUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 45 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API error: %s - %s", resp.Status, string(body))
	}

	var geminiResp GeminiResponse
	if err := json.Unmarshal(body, &geminiResp); err != nil {
		return "", err
	}

	if len(geminiResp.Candidates) > 0 && len(geminiResp.Candidates[0].Content.Parts) > 0 {
		return strings.TrimSpace(geminiResp.Candidates[0].Content.Parts[0].Text), nil
	}

	return "", fmt.Errorf("empty response from Gemini")
}
