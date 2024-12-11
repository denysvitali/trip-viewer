package main

import (
	"net/http"
	"strings"
)

func main() {
	// This is a dummy web server in Go that serves the `json` files
	// of this directory and uses an open CORS policy.

	mux := http.NewServeMux()
	fs := http.FileServer(http.Dir("."))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, ".json") {
			http.Error(w, "Not Found", http.StatusNotFound)
			return
		}
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
		w.Header().Set("Access-Control-Allow-Origin", "*")
		fs.ServeHTTP(w, r)
	})
	s := http.Server{
		Handler: mux,
		Addr:    "127.0.0.1:8000",
	}
	s.ListenAndServe()
}
