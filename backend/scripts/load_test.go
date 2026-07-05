package main

import (
	"flag"
	"fmt"
	"io"
	"net/http"
	"sync"
	"sync/atomic"
	"time"
)

type Result struct {
	StatusCode int
	Duration   time.Duration
	CacheHeader string
	Err        error
}

func main() {
	baseURL := flag.String("url", "http://localhost:8080/api/v1", "Base URL for the Flicko API server")
	totalRequests := flag.Int("requests", 500, "Total number of HTTP requests to execute")
	concurrency := flag.Int("concurrency", 25, "Number of concurrent goroutine workers")
	flag.Parse()

	fmt.Println("🚀 FLICKO BACKEND LOAD TEST & PERFORMANCE AUDIT")
	fmt.Println("--------------------------------------------------")
	fmt.Printf("Target Base URL : %s\n", *baseURL)
	fmt.Printf("Total Requests  : %d\n", *totalRequests)
	fmt.Printf("Concurrency     : %d workers\n", *concurrency)
	fmt.Println("--------------------------------------------------")

	// Phase 1: Benchmark GET Caching on discover endpoint
	fmt.Println("\n[Phase 1] Testing Redis Response Cache (/servers/discover)...")
	runCacheBenchmark(*baseURL+"/servers/discover", *totalRequests, *concurrency)

	// Phase 2: Testing Rate Limiter & Throttling
	fmt.Println("\n[Phase 2] Testing Write Rate Limiter & Throttling (/read-receipts)...")
	runRateLimitTest(*baseURL + "/read-receipts")

	fmt.Println("\n✅ LOAD TEST COMPLETE!")
}

func runCacheBenchmark(endpoint string, totalReqs int, concurrency int) {
	client := &http.Client{Timeout: 5 * time.Second}
	jobs := make(chan int, totalReqs)
	results := make(chan Result, totalReqs)

	for i := 0; i < totalReqs; i++ {
		jobs <- i
	}
	close(jobs)

	var wg sync.WaitGroup
	start := time.Now()

	for w := 0; w < concurrency; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for range jobs {
				reqStart := time.Now()
				req, err := http.NewRequest("GET", endpoint, nil)
				if err != nil {
					results <- Result{Err: err}
					continue
				}

				resp, err := client.Do(req)
				dur := time.Since(reqStart)
				if err != nil {
					results <- Result{Err: err, Duration: dur}
					continue
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()

				results <- Result{
					StatusCode:  resp.StatusCode,
					Duration:    dur,
					CacheHeader: resp.Header.Get("X-Cache"),
				}
			}
		}()
	}

	wg.Wait()
	totalDuration := time.Since(start)
	close(results)

	var successCount int64
	var cacheHitCount int64
	var cacheMissCount int64
	var durations []time.Duration

	for res := range results {
		if res.Err == nil && (res.StatusCode >= 200 && res.StatusCode < 300) {
			atomic.AddInt64(&successCount, 1)
			if res.CacheHeader == "HIT" {
				atomic.AddInt64(&cacheHitCount, 1)
			} else {
				atomic.AddInt64(&cacheMissCount, 1)
			}
		}
		if res.Duration > 0 {
			durations = append(durations, res.Duration)
		}
	}

	reqPerSec := float64(totalReqs) / totalDuration.Seconds()
	fmt.Printf("  Total Time Elapsed : %.2fs\n", totalDuration.Seconds())
	fmt.Printf("  Requests Per Sec   : %.2f req/s\n", reqPerSec)
	fmt.Printf("  Successful HTTPs   : %d / %d\n", successCount, totalReqs)
	fmt.Printf("  Cache HITs         : %d (%.1f%%)\n", cacheHitCount, float64(cacheHitCount)/float64(totalReqs)*100)
	fmt.Printf("  Cache MISSes       : %d (%.1f%%)\n", cacheMissCount, float64(cacheMissCount)/float64(totalReqs)*100)

	if len(durations) > 0 {
		var totalDur time.Duration
		minDur := durations[0]
		maxDur := durations[0]
		for _, d := range durations {
			totalDur += d
			if d < minDur {
				minDur = d
			}
			if d > maxDur {
				maxDur = d
			}
		}
		avgDur := totalDur / time.Duration(len(durations))
		fmt.Printf("  Latency (Min/Avg/Max): %v / %v / %v\n", minDur, avgDur, maxDur)
	}
}

func runRateLimitTest(endpoint string) {
	client := &http.Client{Timeout: 3 * time.Second}
	var hit429 int

	// Send 30 rapid requests in tight loop
	for i := 0; i < 30; i++ {
		req, _ := http.NewRequest("POST", endpoint, nil)
		resp, err := client.Do(req)
		if err == nil {
			if resp.StatusCode == 429 {
				hit429++
			}
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
		}
	}

	fmt.Printf("  Burst Requests Sent : 30\n")
	fmt.Printf("  Rate Limit (429)s   : %d requests throttled\n", hit429)
	if hit429 > 0 {
		fmt.Println("  Status              : PASS (Rate Limiter is actively blocking bursts)")
	} else {
		fmt.Println("  Status              : OK (Endpoint allowed request flow)")
	}
}
