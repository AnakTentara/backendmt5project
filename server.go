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
	// State Memori yang dijaga untuk di-polling oleh MT5
	currentSignal string = "NEUTRAL" 
	
	// Konfigurasi Private API (Rotating API Gemini Node)
	apiKey     string = "aduhkaboaw91h9i28hoablkdl09190jelnkaknldwa90hoi2"
	apiBaseUrl string = "https://ai.aikeigroup.net/v1/chat/completions"
	
	mu sync.Mutex
)

// Struktur Format OpenAI (Sesuai dengan Snippet GitHub Anda)
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

func main() {
	// Menjalankan Otak AI Menganalisa Data Secara Asynchronous di Background
	go aiRutinitasOtak()

	// -----------------------------------------------------
	// API SERVER UNTUK MT5: Sangat Cepat & Tanpa Beban
	// -----------------------------------------------------
	http.HandleFunc("/signal", func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		sig := currentSignal
		mu.Unlock()

		// Keluaran hanya teks murni "BUY" / "SELL" / "NEUTRAL"
		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(sig))
	})

	fmt.Println("🚀 Antigravity Go Backend siap berterbangan!")
	fmt.Println("📍 Endpoint Port Aktif: http://127.0.0.1:8880/signal")
	
	// Menyalakan server selamanya di port 8880
	log.Fatal(http.ListenAndServe(":8880", nil))
}

func aiRutinitasOtak() {
	for {
		// PENDATAAAN: Di sinilah Anda nanti menyambungkan fungsi RSS scraper untuk berita Forex.
		// Sementara kita mengirim simulasi teks berita panas ke Gemini.
		simulatedNewsData := "The latest employment data (NFP) in the US showed a massive increase in jobs, suggesting the US Dollar will get much stronger."

		fmt.Println("[Otak AI] Berita Baru Terdeteksi. Menghubungi Gemini Rotating API...")

		newSignal := askGemini(simulatedNewsData)

		// Simpan hasil terjemahan ke memori untuk diumpankan ke MT5
		mu.Lock()
		currentSignal = strings.TrimSpace(newSignal)
		mu.Unlock()

		fmt.Println("[Otak AI] Berita diolah! Signal MT5 saat ini:", currentSignal)

		// Delay Rutinitas. Jangan membredel API tiap detik atau IP Anda diban.
		// Idealnya AI akan dipanggil jika ada pemicu baru. Untuk ini, tunggu 15 Menit.
		time.Sleep(15 * time.Minute)
	}
}

// Fungsi Panggilan Jarak Jauh (HTTP Request ke Server Rotating API Anda)
func askGemini(newsText string) string {
	
	// PROMPT ENGINEERING: Sangat ketat agar robot tidak bingung
	promptString := fmt.Sprintf(`Tugas Anda: Analisa fundamental. 
	Berita Finansial: "%s" 
	Jika berita ini membuat Euro / EURUSD NAIK, jawab "BUY". 
	Jika berita ini membuat EURUSD TURUN (karena USD menguat), jawab "SELL". 
	Jika tidak berimpact, jawab "NEUTRAL". 
	JAWAB HANYA SATU KATA MUTLAK SAJA.`, newsText)

	reqBody := OpenAIRequest{
		Model: "gemini-3.1-flash-lite-preview",
		Messages: []Message{
			{Role: "system", Content: "You are the world's most elite quant algorithms processor. Respond exclusively with one exact keyword as instructed."},
			{Role: "user", Content: promptString},
		},
	}

	jsonValue, _ := json.Marshal(reqBody)

	// Persiapan Tembakan Post ke `ai.aikeigroup.net`
	req, err := http.NewRequest("POST", apiBaseUrl, bytes.NewBuffer(jsonValue))
	if err != nil {
		fmt.Println("X Error membentuk request API:", err)
		return "NEUTRAL"
	}

	// Memasukkan Kunci Akses Layaknya Format OpenAI Standard
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	// Panggilan Eksekusi. Kasih batas waktu gagal 10 Detik
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("X Gagal menghubungi API Server Node Anda:", err)
		return "NEUTRAL"
	}
	defer resp.Body.Close()

	// Memecah (Parsing) Respon Format OpenAI
	body, _ := io.ReadAll(resp.Body)
	var aiResp OpenAIResponse
	json.Unmarshal(body, &aiResp)

	// Jika sukses, lempar 1 kata mutlak itu kembali
	if len(aiResp.Choices) > 0 {
		return aiResp.Choices[0].Message.Content
	}

	return "NEUTRAL"
}
