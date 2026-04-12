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

	MEMORY_FILE          = "memory/oracle_memory.json"
	PELAJARAN_FILE       = "PelajaranBerharga.json"
	MAX_MEMORY_DAYS      = 30
	MAX_ENTRIES_SYMBOL   = 720  // ~24 entry/hari * 30 hari
	DISASTER_THRESHOLD   = -0.50 // Loss >= 50% dari balance = Disaster
	VICTORY_MIN_USD      = 2.0   // Minimal profit USD agar dicatat sebagai pelajaran
)

var (
	ActiveGroundingMode = GROUNDING_GO_SCRAPER
	AIGroundingModel    = "gemma-4-26b-a4b-it"

	liveNewsData string = "Belum ada berita ditarik."

	apiKey     string = "aduhkaboaw91h9i28hoablkdl09190jelnkaknldwa90hoi2"
	apiBaseUrl string = "https://ai.aikeigroup.net/v1/chat/completions"

	mu        sync.Mutex
	memoryMu  sync.Mutex

	// Menyimpan data Tick-by-Tick terakhir dari MQL5 untuk web dashboard
	LatestMT5Status = make(map[string]map[string]float64)
)

// =========================================================================
// STRUKTUR DATA
// =========================================================================
type OpenAIRequest struct {
	Model     string    `json:"model"`
	Messages  []Message `json:"messages"`
	WebSearch bool      `json:"web_search,omitempty"`
}
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}
type OpenAIResponse struct {
	Choices []struct {
		Message           Message                `json:"message"`
		GroundingMetadata map[string]interface{} `json:"groundingMetadata,omitempty"`
	} `json:"choices"`
}
type FFEvent struct {
	Title   string `json:"title"`
	Impact  string `json:"impact"`
	Country string `json:"country"`
	Date    string `json:"date"`   // Tambah field date untuk filter hari ini
}

// --- MEMORY ---
type MemoryEntry struct {
	Timestamp string  `json:"ts"`
	Symbol    string  `json:"sym"`
	Input     string  `json:"in"`
	Decision  string  `json:"dec"`
	Action    string  `json:"act"`
	EntryPx   float64 `json:"entry"`
	SL        float64 `json:"sl"`
	TP        float64 `json:"tp"`
	Result    string  `json:"res,omitempty"`  // "WIN" / "LOSS" / "PENDING" / "CUT"
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

	reqBody := OpenAIRequest{
		Model: "gemini-3.1-flash-lite-preview",
		Messages: []Message{
			{Role: "user", Content: prompt},
		},
	}
	jsonValue, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "Gagal generate analisis."
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "Gagal memanggil AI untuk analisis."
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)

	if len(aiResp.Choices) > 0 {
		return strings.TrimSpace(aiResp.Choices[0].Message.Content)
	}
	return "Analisis tidak tersedia."
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
	go beritaForexRoutine()

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
		// Format: "SYMBOL|RESULT|PROFIT_USD|BALANCE|LAST_DECISION"
		// Contoh: "EURUSD|WIN|15.50|100775.00|SELL_LIMIT|1.17390..."
		raw := string(body)
		parts := strings.SplitN(raw, "|", 5)

		if len(parts) < 4 {
			http.Error(w, "Format salah. Harap: SYMBOL|RESULT|PROFIT_USD|BALANCE", http.StatusBadRequest)
			return
		}

		symbol := strings.TrimSpace(parts[0])
		result := strings.TrimSpace(parts[1])
		profitUSD := 0.0
		balance := 0.0
		fmt.Sscanf(parts[2], "%f", &profitUSD)
		fmt.Sscanf(parts[3], "%f", &balance)
		lastDecision := ""
		if len(parts) >= 5 {
			lastDecision = parts[4]
		}

		fmt.Printf("\n💬 [Feedback] %s: %s | PnL=$%.2f | Bal=$%.2f\n", symbol, result, profitUSD, balance)

		// Update memori dengan hasil
		updateLastMemory(symbol, result, profitUSD, balance)

		// Evaluasi untuk PelajaranBerharga
		go recordLesson(symbol, lastDecision, "", profitUSD, balance)

		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK"))
	})

	// Endpoint API: Web Dashboard Metrics
	http.HandleFunc("/api/stats", handleApiStats)

	// PHASE 3: Scalper Drone Endpoint
	http.HandleFunc("/scalp", handleScalperDrone)

	// Endpoint Frontend
	http.Handle("/dashboard/", http.StripPrefix("/dashboard/", http.FileServer(http.Dir("./dashboard"))))

	fmt.Println("⚡ Antigravity Quant [The Oracle v9 APEX ENGINE] Menyala!")
	fmt.Println("📍 POST /          → Oracle Deep Thinker (M1 Swing)")
	fmt.Println("📍 POST /feedback  → Feedback Loop (Win/Loss Tracker)")
	fmt.Println("📍 POST /scalp     → Scalper Drone (M1/M5 Fast Alpha)")
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
	reqBody := OpenAIRequest{
		Model:    "gemini-3.1-flash-lite-preview",
		Messages: []Message{
			{Role: "system", Content: systemScalper},
			{Role: "user", Content: prompt},
		},
	}

	jsonValue, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		w.Write([]byte("HOLD|0|0|0|Internal error"))
		return
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		w.Write([]byte("HOLD|0|0|0|AI timeout"))
		return
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(respBody, &aiResp)

	decision := "HOLD|0|0|0|No signal"
	if len(aiResp.Choices) > 0 {
		decision = strings.TrimSpace(aiResp.Choices[0].Message.Content)
		if !strings.Contains(decision, "|") {
			decision = "HOLD|0|0|0|AI mengoceh"
		}
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
		if val, exists := status["BAL"]; exists {
			totalBalance += val
		}
		if val, exists := status["FLOAT"]; exists {
			totalFloating += val
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
			mu.Unlock()
		}()
		// Update berita setiap 30 menit (bukan 1 jam) agar lebih responsif
		time.Sleep(30 * time.Minute)
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
	fmt.Println("📡 [AIGrounding] AI Khusus menjelajah internet dengan model:", AIGroundingModel)
	reqBody := OpenAIRequest{
		Model:     AIGroundingModel,
		WebSearch: true,
		Messages: []Message{
			{Role: "user", Content: "Browsing internet sekarang. Berikan ringkasan berita terpenting hari ini untuk market forex, maksimal 3 kalimat padat. Situasi: " + context},
		},
	}
	jsonValue, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "Gagal menyiapkan request AIGrounding."
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "Gagal memanggil AIGrounding Server."
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)
	if len(aiResp.Choices) > 0 {
		return "AI Grounding: " + strings.TrimSpace(aiResp.Choices[0].Message.Content)
	}
	return "AI Grounding gagal."
}

// =========================================================================
// DEEP THINKER ALGORITHM
// =========================================================================
func tanyakanWarrenBuffet(mt5Report, news, memoryContext, symbol string) string {

	// Muat Pelajaran Berharga untuk konteks tambahan
	pb := loadPelajaran()
	pelajaranCtx := ""
	if len(pb.Disasters) > 0 {
		pelajaranCtx += "\n⚠️ PELAJARAN DARI DISASTER MASA LALU:\n"
		for i, d := range pb.Disasters {
			if i >= 2 { break } // Ambil 2 disaster terakhir
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
- MARKET ORDER AGRESIF: Jika Delta M1+M15 kuat dan searah dan momentum didukung berita → langsung BUY atau SELL. Jangan tunggu LIMIT.
- LIMIT ORDER: Hanya saat pasar ranging tanpa momentum, gunakan LIMIT untuk menangkap pantulan S/R.
- WIN_STREAK >= 3 → Anda sedang dalam kondisi excellent, bisa sedikit lebih agresif tapi TETAP DISIPLIN R:R.
- LOSS_STREAK >= 2 → Waspada, pasar mungkin bergerak tak wajar. Pilih HOLD atau LIMIT saja.
- SPREAD > 15 poin → Hindari market order kecuali momentum sangat kuat.
- ATR > 80 pip = volatile → SL wajib lebih lebar dari 1x ATR.
- Jika FLOAT negatif > 5% dari BAL → wajib CUT_LOSS_ALL.
- Harga dekat D1_H (< 5 pip) → zona SELL/resistance. Harga dekat D1_L (< 5 pip) → zona BUY/support.
- PELAJARAN masa lalu adalah hukum: jangan ulangi pola yang sudah terbukti merugi.
- Jika BAL - DAILY_START_BAL < -(5% dari DAILY_START_BAL) → HOLD total, jangan buka posisi baru.

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
		"Simbol: %s\nData Radar MT5: [%s]\nAgenda Ekonomi: [%s]\nGrounding Internet: [%s]\n\n%s\n%s",
		symbol, mt5Report, news, groundingContext, memoryContext, pelajaranCtx,
	)

	reqBody := OpenAIRequest{
		Model:     "gemini-3.1-flash-lite-preview",
		WebSearch: false,
		Messages: []Message{
			{Role: "system", Content: systemPersona},
			{Role: "user", Content: promptString},
		},
	}

	jsonValue, _ := json.Marshal(reqBody)
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "HOLD|0|0|0|Error Internal HTTP Server"
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "HOLD|0|0|0|Gagal menghubungi Rotator Gemini"
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)

	if len(aiResp.Choices) > 0 {
		if aiResp.Choices[0].GroundingMetadata != nil {
			fmt.Println("✅ [Oracle] Google Search Grounding aktif!")
		} else {
			fmt.Println("⚠️  [Oracle] Menjawab tanpa Google Search Grounding.")
		}
		pesan := strings.TrimSpace(aiResp.Choices[0].Message.Content)
		if !strings.Contains(pesan, "|") {
			return "HOLD|0|0|0|AI Mengoceh Tidak Karuan"
		}
		return pesan
	}

	return "HOLD|0|0|0|Rotator Kosong"
}
