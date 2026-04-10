package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"
)

var (
	// Berita Harian dari Internet (Bisa Terhubung Langsung dari ForexFactory API Lokal)
	liveNewsData string = "Belum ada berita ditarik."

	// Konfigurasi Kunci API (Karena Anda memiliki server rotator, arahkan ke localhost Rotator Anda)
	apiKey     string = "aduhkaboaw91h9i28hoablkdl09190jelnkaknldwa90hoi2"
	apiBaseUrl string = "ai.aikeigroup.net/v1/chat/completions" // Arahkan ke Rotator Node.js

	mu sync.Mutex
)

// Struktur HTTP API & ForexFactory
type OpenAIRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
}
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}
type OpenAIResponse struct {
	Choices []struct {
		Message Message `json:"message"`
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

	// 2. Endpoint Deep Thinking untuk MQL5 (Dipanggil Setiap 1 Menit)
	http.HandleFunc("/consult", func(w http.ResponseWriter, r *http.Request) {
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

		fmt.Println("\n[Radar 1-Menit] Menyensor Pergeseran Harga:", mt5Report)

		// Proses Deep Thinking (Memanggil Gemini Rotator)
		aiDecision := tanyakanWarrenBuffet(mt5Report, currentNews)

		// Respon Teks Telanjang (Contoh: "SELL|1.100|1.090|H1 Bearish dan M1 Koreksi")
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(aiDecision))
	})

	fmt.Println("🚀 Antigravity Quant (Deep Thinking Engine) Menyala!")
	fmt.Println("📍 Endpoint: POST http://127.0.0.1:8880/consult")
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
// DEEP THINKER ALGORITHM (MULTI-TIMEFRAME SYNTHESIS)
// =========================================================================
func tanyakanWarrenBuffet(mt5Report string, news string) string {

	systemPersona := `Anda adalah algoritma Quant Trading elit "Deep Thinking" (Logika Presisi Tingkat Warren Buffett).
Anda menerima 2 Data: 
1. Laporan Pergeseran Grafik 3-Dimensi (Delta M1, M15, H1 dalam besaran Pips) dari MT5.
2. Berita Finansial Dunia Makro.

TUGAS DEEP THINKING:
- Hubungkan polaritas mikro (M1/M15) terhadap trend mayorita (H1). 
- Deteksi apakah pergerakan M1 yang berlawanan dengan H1 adalah 'Pullover/Koreksi' emas untuk masuk pasar? Atau justru tanda awal kehancuran tren?
- Padukan ini secara kuat dengan Berita Dunia.

ATURAN OUTPUT BESI (DILARANG MENGOBROL):
Keluarkan SATU BARIS SAJA dengan format pemisah pipa:
ACTION|STOPLOSS|TAKEPROFIT|ALASAN_SINGKAT_ANALITIK_ANDA
(ACTION hanya boleh: BUY, SELL, atau HOLD).
(SL dan TP harus berupa angka harga rasional berdasar current_price).`

	promptString := fmt.Sprintf("Data Radar 1-Menit MT5 Saat Ini: [%s]\nBerita Makro: [%s]", mt5Report, news)

	reqBody := OpenAIRequest{
		Model: "gemini-3.1-flash-lite-preview",
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
		pesan := strings.TrimSpace(aiResp.Choices[0].Message.Content)
		if !strings.Contains(pesan, "|") {
			return "HOLD|0|0|AI Mengoceh Tidak Karuan"
		}
		return pesan
	}

	return "HOLD|0|0|Rotator Kosong"
}
