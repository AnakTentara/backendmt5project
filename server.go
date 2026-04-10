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

	fmt.Println("🚀 Antigravity Quant [The Oracle] v8 - Memory Edition Menyala!")
	fmt.Println("📍 POST / → Konsultasi Oracle")
	fmt.Println("📍 POST /feedback → Laporan Hasil Trade")
	log.Fatal(http.ListenAndServe(":8880", nil))
}

// helper min untuk Go <1.21
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// =========================================================================
// SENSOR BERITA PUSAT
// =========================================================================
func beritaForexRoutine() {
	for {
		resp, err := http.Get("https://nfs.faireconomy.media/ff_calendar_thisweek.json")
		if err == nil {
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			var events []FFEvent
			json.Unmarshal(body, &events)

			penting := "Red Impact Forex Hari Ini:\n"
			jumlah := 0
			for _, ev := range events {
				if ev.Impact == "High" && (ev.Country == "USD" || ev.Country == "EUR") {
					penting += fmt.Sprintf("- %s: %s\n", ev.Country, ev.Title)
					jumlah++
				}
			}

			mu.Lock()
			if jumlah > 0 {
				liveNewsData = penting
			} else {
				liveNewsData = "Kondisi Berita Global: Tenang."
			}
			mu.Unlock()
		}
		time.Sleep(1 * time.Hour)
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

1. PORTFOLIO: POS (posisi terbuka), FLOAT (profit/loss mengambang), BAL (saldo akun), F_MARG (margin bebas)
2. STRUCTURE: D1_H (Resistance hari ini), D1_L (Support hari ini), ASK (harga saat ini), SPREAD (poin), ATR_PIP (volatilitas H1)
3. SESSION: Sesi pasar aktif (LONDON, NEW_YORK, LONDON+NY_OVERLAP, ASIA)
4. DELTA: Pergeseran candle M1/M15/H1 dalam pip
5. MEMORI: Riwayat & statistik keputusan 30 hari terakhir
6. PELAJARAN: Analisis dari kemenangan dan kegagalan historis
7. BERITA: Konteks makro ekonomi real-time

ATURAN KECERDASAN:
- EKSEKUSI AGRESIF (MARKET ORDER): Jika Delta M1 dan M15 menunjukkan momentum yang sangat kuat dan searah dengan Berita, JANGAN RAGU untuk langsung ACTION: BUY atau SELL (bukan LIMIT). Hajar pasar jika peluang emas ada!
- PENGGUNAAN LIMIT: Gunakan BUY_LIMIT atau SELL_LIMIT hanya jika harga sedang "nanggung" atau bergerak ranging tanpa momentum jelas.
- SPREAD >15 poin = pertimbangkan LIMIT atau HOLD, kecuali momentum (Delta) sedemikian kuatnya hingga spread bisa diabaikan.
- ATR >80 pip = volatile → SL lebih lebar.
- SESSION LONDON+NY_OVERLAP = volume terbesar, sinyal Delta sangat valid.
- Jika FLOAT sangat negatif (kerugian > 5% BAL) → CUT_LOSS_ALL
- SL minimal = 1x ATR_PIP | TP minimal = 1.5x ATR_PIP (R:R >= 1.5)
- Harga dekat D1_H (<5 pip) → rawan pantulan turun. Harga dekat D1_L (<5 pip) → rawan pantulan naik.
- PELAJARI riwayat memori → hindari pola yang berulang gagal.

ATURAN OUTPUT BESI (DILARANG MENGOBROL):
Keluarkan SATU BARIS SAJA, 5 elemen pemisah pipa:
ACTION|ENTRY_PRICE|STOPLOSS|TAKEPROFIT|ALASAN_SINGKAT_MAX_15_KATA
- ACTION: BUY, SELL, BUY_LIMIT, SELL_LIMIT, AVERAGING_BUY, CUT_LOSS_ALL, atau HOLD
- BUY/SELL/HOLD/CUT_LOSS_ALL → ENTRY_PRICE = 0
- BUY_LIMIT/SELL_LIMIT → ENTRY_PRICE = harga limit yang dikalkulasi dari S/R
- SL dan TP: angka harga ABSOLUT berdasarkan ATR_PIP`

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
