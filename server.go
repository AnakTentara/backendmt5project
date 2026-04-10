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
	// Berita Harian dari Internet
	liveNewsData string = "Belum ada berita ditarik." 
	
	// Konfigurasi API
	apiKey     string = "MASUKKAN_KODE_RAHASIA_API_DISINI"
	apiBaseUrl string = "https://ai.aikeigroup.net/v1/chat/completions"
	
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
	// 1. Tarik Berita Forex Asli di Background setiap Jam
	go beritaForexRoutine()

	// 2. Endpoint Konsultasi untuk MT5 (Bukan lagi asal polling tiap detik)
	// MT5 hanya akan memanggil /consult jika indikatornya menyentuh batas bahaya
	http.HandleFunc("/consult", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "Harus POST", http.StatusMethodNotAllowed)
			return
		}

		// Membaca Laporan dari MT5 (Contoh: "RSI=82.5|PRICE=1.095")
		body, _ := io.ReadAll(r.Body)
		mt5Report := string(body)

		mu.Lock()
		currentNews := liveNewsData
		mu.Unlock()

		fmt.Println("[MT5 Merapat] Laporan Lapangan Diterima:", mt5Report)
		
		// Lempar rapat ke Dewan Direksi (Gemini)
		aiDecision := tanyakanWarrenBuffet(mt5Report, currentNews)

		// Keluaran Presisi String (Contoh: "SELL|1.100|1.090")
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(aiDecision))
	})

	fmt.Println("🚀 Antigravity Quant (Warren Buffett Engine) Menyala!")
	fmt.Println("📍 Endpoint Konsultasi: POST http://127.0.0.1:8880/consult")
	log.Fatal(http.ListenAndServe(":8880", nil))
}

// =========================================================================
// FITUR 1: RADAR BERITA DUNIA
// =========================================================================
func beritaForexRoutine() {
	for {
		fmt.Println("[Radar] Mengorek Data Kalender Ekonomi ForexFactory...")
		// Endpoint API gratis kalender minggu ini dari ForexFactory
		resp, err := http.Get("https://nfs.faireconomy.media/ff_calendar_thisweek.json")
		
		if err == nil {
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)
			
			var events []FFEvent
			json.Unmarshal(body, &events)
			
			// Nyaring hanya berita "High Impact" (Merah) untuk Dolar dan Euro
			penting := "Red Impact Hari Ini:\n"
			jumlah := 0
			for _, ev := range events {
				if ev.Impact == "High" && (ev.Country == "USD" || ev.Country == "EUR") {
					penting += fmt.Sprintf("- Negara: %s | Berita: %s\n", ev.Country, ev.Title)
					jumlah++
				}
			}
			
			if jumlah > 0 {
				mu.Lock()
				liveNewsData = penting
				mu.Unlock()
			} else {
				mu.Lock()
				liveNewsData = "Tidak ada berita bahaya (High Impact) terdeteksi hari ini."
				mu.Unlock()
			}
			fmt.Println("[Radar Sukses] Data tersimpan di memori.")
		}
		
		// Cegah server kelelahan, cukup tarik jadwal sehari sekali/jam sekali
		time.Sleep(1 * time.Hour)
	}
}

// =========================================================================
// FITUR 2: SANG DEWAN DIREKSI (GEMINI ANALIST)
// =========================================================================
func tanyakanWarrenBuffet(mt5Report string, news string) string {
	
	systemPersona := `Anda adalah algoritma Quant Trading elit dengan logika setingkat Warren Buffett. Anda BENAR-BENAR bukan manusia. Jangan gunakan sapaan, jangan mengobrol. Anda adalah mesin penghitung matematika.
Anda akan diberikan 2 Data: Data Grafik dari alat Anda (MT5), dan Berita Dunia. 
TUGAS MUTLAK:
Jika data menunjukan Overbought/Oversold dan membelakangi berita, ambil keputusan Buy/Sell/Hold.
Kemudian, tentukan angka Take Profit (TP) dari perhitungan Anda sendiri.
Keluarkan SATU BARIS saja dengan format mutlak:
ACTION|STOPLOSS|TAKEPROFIT|ALASAN_SINGKAT
Contoh keluaran: SELL|0|1.090|RSI Ekstrem Overbought dan Berita USD Bullish.`

	promptString := fmt.Sprintf("Data Grafik Saat Ini: [%s]\nBerita Dunia Saat Ini: [%s]", mt5Report, news)

	reqBody := OpenAIRequest{
		Model: "gemini-3.1-flash-lite-preview",
		Messages: []Message{
			{Role: "system", Content: systemPersona},
			{Role: "user", Content: promptString},
		},
	}

	jsonValue, _ := json.Marshal(reqBody)

	// Persiapan Tembak
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil { return "HOLD|0|0|Error Server Lokal" }

	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil { return "HOLD|0|0|Gagal menghubungi API Gemini" }
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)

	if len(aiResp.Choices) > 0 {
		pesan := strings.TrimSpace(aiResp.Choices[0].Message.Content)
		// Pastikan mesin mematuhi format pemisah pipa "|"
		if !strings.Contains(pesan, "|") {
			return "HOLD|0|0|Mesin Salah Memberi Format Output"
		}
		return pesan
	}

	return "HOLD|0|0|Kosong"
}
