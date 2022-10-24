package main

import (
	"bufio"
	"encoding/csv"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

type StopTime struct {
	TripID    string `json:"-"`
	StopID    string `json:"stop_id"`
	Arrival   string `json:"arrival_time"`
	Departure string `json:"departure_time"`
}

type Trip struct {
	TripID    string `json:"trip_id"`
	ServiceID string `json:"service_id"`
	RouteID   string `json:"route_id"`
}

type TripResponse struct {
	*Trip
	Stops []*StopTime `json:"schedules"`
}

func buildTripResponse(
	trips []*Trip,
	stopTimesByTrip map[string][]*StopTime,
) []TripResponse {
	resp := make([]TripResponse, 0, len(trips))

	for _, trip := range trips {
		tripResp := TripResponse{
			Trip:  trip,
			Stops: stopTimesByTrip[trip.TripID],
		}

		resp = append(resp, tripResp)
	}

	return resp
}

func main() {
	_, stopTimesByTrip := getStopTimes()
	_, tripsByRoute := getTrips()

	http.HandleFunc("/schedules/", func(w http.ResponseWriter, r *http.Request) {
		route := strings.Split(r.URL.Path, "/")[2]
		resp := buildTripResponse(tripsByRoute[route], stopTimesByTrip)
		w.Header().Set("Content-Type", "application/json")

		if err := json.NewEncoder(w).Encode(resp); err != nil {
			fmt.Println("json error", err)
		}
	})
	log.Fatal(http.ListenAndServe(":4000", nil))
}

func getStopTimes() ([]*StopTime, map[string][]*StopTime) {
	filename := "../MBTA_GTFS/stop_times.txt"
	headers := []string{"trip_id", "arrival_time", "departure_time", "stop_id"}

	stopTimes := make([]*StopTime, 0, 1_000_000)
	stsByTrip := make(map[string][]*StopTime)
	start := time.Now()

	parseCsvFile(filename, headers, func(records []string, i int) {
		trip := records[0]
		stop := &StopTime{
			TripID:    trip,
			StopID:    records[3],
			Arrival:   records[1],
			Departure: records[2],
		}

		stsByTrip[trip] = append(stsByTrip[trip], stop)
		stopTimes = append(stopTimes, stop)
	})

	elapsed := time.Since(start)
	fmt.Println("parsed", len(stopTimes), "stop times in", elapsed)

	return stopTimes, stsByTrip
}

func getTrips() ([]*Trip, map[string][]*Trip) {
	filename := "../MBTA_GTFS/trips.txt"
	headers := []string{"route_id", "service_id", "trip_id"}

	trips := make([]*Trip, 0, 70_000)
	tripsByRoute := make(map[string][]*Trip)
	start := time.Now()

	parseCsvFile(filename, headers, func(records []string, i int) {
		route := records[0]
		trip := &Trip{
			TripID:    records[2],
			RouteID:   route,
			ServiceID: records[1],
		}

		tripsByRoute[route] = append(tripsByRoute[route], trip)
		trips = append(trips, trip)
	})

	elapsed := time.Since(start)
	fmt.Println("parsed", len(trips), "trips in", elapsed)

	return trips, tripsByRoute
}

func parseCsvFile(filename string, headers []string, parseRec func([]string, int)) {
	f, rd := openCsv(filename, headers)
	defer f.Close()

	var err error
	i := 0

	for records, err := rd.Read(); err == nil; records, err = rd.Read() {
		parseRec(records, i)
		i++
	}

	if err != nil && err != io.EOF {
		panic(err)
	}
}

func openCsv(filename string, headers []string) (*os.File, *csv.Reader) {
	f, err := os.Open(filename)
	if err != nil {
		panic(err)
	}

	rd := csv.NewReader(bufio.NewReader(f))
	rd.ReuseRecord = true

	records, err := rd.Read()
	if err != nil {
		panic(err)
	}

	if len(records) > len(headers) {
		records = records[:len(headers)]
	}

	for i := 0; i < len(records); i++ {
		if records[i] != headers[i] {
			fmt.Println(filename, "not in expected format:")
			for i, cell := range records {
				fmt.Println(i, cell)
			}

			panic(1)
		}
	}

	return f, rd
}
