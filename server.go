package main

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"
)

const (
	GROUNDING_OFF          = 0
	GROUNDING_GO_SCRAPER   = 1
	GROUNDING_AI_DEDICATED = 2
)

var (
	// Konfigurasi Mode Grounding
	ActiveGroundingMode = GROUNDING_GO_SCRAPER // GROUNDING_AI_DEDICATED - kalo ada API Gemini yang bisa grounding
	AIGroundingModel    = "gemma-4-26b-a4b-it" // isi Model Nama nya kalo dedicated

	// Berita Harian dari Internet (Bisa Terhubung Langsung dari ForexFactory API Lokal)
	liveNewsData string = "Belum ada berita ditarik."

	// Konfigurasi Kunci API (Karena Anda memiliki server rotator, arahkan ke localhost Rotator Anda)
	apiKey     string = "aduhkaboaw91h9i28hoablkdl09190jelnkaknldwa90hoi2"
	apiBaseUrl string = "https://ai.aikeigroup.net/v1/chat/completions" // WAJIB gunakan HTTPS://

	mu sync.Mutex
)

// Struktur HTTP API & ForexFactory
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

func main() {
	// 1. Tarik Berita Forex Bebas Hambatan
	go beritaForexRoutine()

	// 2. Endpoint Deep Thinking untuk MQL5 (Menerima dari jalur manapun)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Harus POST", http.StatusMethodNotAllowed)
			return
		}

		// Membaca Laporan Tri-Dimensi: (Contoh: "M1:-10|M15:20|H1:-50|HARGA:1.0950")
		body, _ := io.ReadAll(r.Body)
		mt5Report := string(body)

		mu.Lock()
		currentNews := liveNewsData
		mu.Unlock()

		fmt.Println("\n[Radar 60-Detik] Menerima Laporan Tri-Dimensi MT5:", mt5Report)
		fmt.Println("🔎 [Deep Thinker] Menyambungkan Infrastruktur ke Google Search (Grounding)...")
		fmt.Println("   (Proses browsing mungkin memakan waktu hingga 20 detik...)")

		// Proses Deep Thinking (Memanggil Gemini Rotator)
		aiDecision := tanyakanWarrenBuffet(mt5Report, currentNews)
		fmt.Println("[Deep Thinker] Selesai Berpikir. Keputusan:", aiDecision)

		// Respon Teks Telanjang (Contoh: "SELL|1.100|1.090|H1 Bearish dan M1 Koreksi")
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(aiDecision))
	})

	fmt.Println("🚀 Antigravity Quant (Deep Thinking Engine) Menyala!")
	fmt.Println("📍 Endpoint: POST Terbuka di semua rute (Contoh: http://103.93.129.117:8880/)")
	log.Fatal(http.ListenAndServe(":8880", nil))
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
// Struktur XML untuk RSS
type RSS struct {
	Channel Channel `xml:"channel"`
}
type Channel struct {
	Items []Item `xml:"item"`
}
type Item struct {
	Title string `xml:"title"`
}

func performScraperGrounding(context string) string {
	fmt.Println("📡 [GoScraper] Menarik berita secara manual murni dari Go RSS...")
	
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
	fmt.Println("📡 [AIGrounding] AI Khusus sedang menjelajah internet dengan model:", AIGroundingModel)
	reqBody := OpenAIRequest{
		Model:     AIGroundingModel,
		WebSearch: true,
		Messages: []Message{
			{Role: "user", Content: "Browsing internet sekarang. Berikan ringkasan berita terpenting hari ini untuk market forex, maksimal 3 kalimat padat. Situasi pasar mt5 saat ini: " + context},
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
		return "Laporan Khusus AI Grounding: " + strings.TrimSpace(aiResp.Choices[0].Message.Content)
	}

	return "AI Grounding gagal mengembalikan data (Mungkin model salah atau terkena limit)."
}

// =========================================================================
// DEEP THINKER ALGORITHM (MULTI-TIMEFRAME SYNTHESIS)
// =========================================================================
func tanyakanWarrenBuffet(mt5Report string, news string) string {

	systemPersona := `Anda adalah algoritma Quant Trading tingkat Institusi (Hedge Fund Level).
Anda menerima Laporan Pasar lengkap dari MetaTrader 5:

1. PORTFOLIO: POS (posisi terbuka), FLOAT (profit/loss mengambang), BAL (saldo akun), F_MARG (margin bebas)
2. STRUCTURE: D1_H (High tertinggi hari ini = Resistance), D1_L (Low terendah hari ini = Support), ASK (harga saat ini), SPREAD (spread dalam poin), ATR_PIP (volatilitas rata-rata per jam terakhir dalam pip)
3. SESSION: Sesi pasar aktif saat ini (LONDON, NEW_YORK, LONDON+NY_OVERLAP, ASIA)
4. DELTA: Pergeseran candle M1/M15/H1 dalam pip (positif=bullish, negatif=bearish)
5. BERITA: Konteks makro ekonomi real-time dari internet

ATURAN KECERDASAN:
- ATR tinggi (>80 pip) = pasar volatile → SL harus lebih lebar, lebih aman pakai LIMIT order.
- ATR rendah (<30 pip) = pasar lesu → pertimbangkan HOLD kecuali ada sinyal kuat.
- SPREAD tinggi (>15 poin) = hindari MARKET order! Pakai LIMIT saja agar tidak rugi di spread.
- SESSION LONDON+NY_OVERLAP = sesi paling liquid dan terpercaya untuk masuk pasar.
- Jika FLOAT sangat negatif (kerugian > 5% BAL), keluarkan CUT_LOSS_ALL untuk keselamatan akun.
- Jika POS > 0 saat audit, evaluasi apakah posisi harus ditahan, di-average, atau di-cut.
- SL minimal = 1 x ATR_PIP dari harga entry. TP minimal = 1.5 x ATR_PIP (Risk:Reward >= 1.5).
- Jika harga mendekati D1_H (<5 pip) → zona SELL/SELL_LIMIT. Jika mendekati D1_L (<5 pip) → zona BUY/BUY_LIMIT.

ATURAN OUTPUT BESI (DILARANG MENGOBROL, DILARANG MENJELASKAN):
Keluarkan SATU BARIS SAJA dengan format 5 elemen pemisah pipa:
ACTION|ENTRY_PRICE|STOPLOSS|TAKEPROFIT|ALASAN_SINGKAT_MAX_15_KATA
- ACTION: BUY, SELL, BUY_LIMIT, SELL_LIMIT, AVERAGING_BUY, CUT_LOSS_ALL, atau HOLD
- Jika BUY/SELL/HOLD/CUT_LOSS_ALL: ENTRY_PRICE = 0
- Jika BUY_LIMIT/SELL_LIMIT: ENTRY_PRICE = harga target limit yang dihitung dari Support/Resistance
- SL dan TP: angka harga absolut (bukan pip), kalkulasi dari ATR_PIP`

	groundingContext := ""
	if ActiveGroundingMode == GROUNDING_AI_DEDICATED {
		groundingContext = performAIGrounding(mt5Report)
	} else if ActiveGroundingMode == GROUNDING_GO_SCRAPER {
		groundingContext = performScraperGrounding(mt5Report)
	}

	promptString := fmt.Sprintf("Data Radar MT5 Saat Ini: [%s]\nAgenda Ekonomi Hari Ini: [%s]\nHasil Grounding Internet Live: [%s]", mt5Report, news, groundingContext)

	reqBody := OpenAIRequest{
		Model:     "gemini-3.1-flash-lite-preview",
		WebSearch: false, // MATIKAN: Kunci gratis API tidak kuat menahan kuota pencarian berbayar Google.
		Messages: []Message{
			{Role: "system", Content: systemPersona},
			{Role: "user", Content: promptString},
		},
	}

	jsonValue, _ := json.Marshal(reqBody)

	// Pastikan url ini merujuk ke API GEMINI Anda / Rotator Node Anda
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		return "HOLD|0|0|Error Internal HTTP Server"
	}

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	// Karena menggunakan Rotator dan Deep Think, beri waktu pikir luas
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return "HOLD|0|0|Gagal menghubungi Node JS Rotator Gemini"
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)

	if len(aiResp.Choices) > 0 {

		// Deteksi apakah Grounding benar-benar dilakukan mesin
		if aiResp.Choices[0].GroundingMetadata != nil {
			fmt.Println("✅ [Deep Thinker] Google Search Grounding SELESAI! Data berhasil diserap dari Internet.")
			chunks := aiResp.Choices[0].GroundingMetadata["groundingChunks"]
			if chunks != nil {
				// Hitung kasaran berapa banyak sumber web / chunk web yang diambil
				if chunkList, ok := chunks.([]interface{}); ok {
					fmt.Printf("   -> Terdapat %d keping informasi Real-Time yang diukur.\n", len(chunkList))
				}
			}
		} else {
			fmt.Println("⚠️ [Deep Thinker] AI menjawab tanpa membuka Browser Google.")
		}

		pesan := strings.TrimSpace(aiResp.Choices[0].Message.Content)
		if !strings.Contains(pesan, "|") {
			return "HOLD|0|0|AI Mengoceh Tidak Karuan"
		}
		return pesan
	}

	return "HOLD|0|0|Rotator Kosong"
}
