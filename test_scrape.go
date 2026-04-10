package main

import (
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type Rss struct {
	Channel Channel `xml:"channel"`
}

type Channel struct {
	Items []Item `xml:"item"`
}

type Item struct {
	Title string `xml:"title"`
}

func main() {
	fmt.Println("Testing Go Scraper RSS...")
	url := "https://www.forexlive.com/feed/news"
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0")
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	var rss Rss
	xml.Unmarshal(body, &rss)

	var titles []string
	for i, item := range rss.Channel.Items {
		if i >= 5 {
			break
		}
		titles = append(titles, item.Title)
	}
	fmt.Println("Result:", strings.Join(titles, " | "))
}
