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

func buildTripResponse(trips []*Trip, stopTimesByTrip map[string][]*StopTime) []TripResponse {
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
	start := time.Now()

	stopTimes := make([]*StopTime, 0)
	stsByTrip := make(map[string][]*StopTime)

	err := parseCsvFile(filename, headers, func(records []string, i int) {
		stop := &StopTime{
			TripID:    records[0],
			StopID:    records[3],
			Arrival:   records[1],
			Departure: records[2],
		}

		stsByTrip[stop.TripID] = append(stsByTrip[stop.TripID], stop)
		stopTimes = append(stopTimes, stop)
	})
	if err != nil {
		panic(err)
	}

	elapsed := time.Since(start)
	fmt.Println("parsed", len(stopTimes), "stop times in", elapsed)

	return stopTimes, stsByTrip
}

func getTrips() ([]*Trip, map[string][]*Trip) {
	filename := "../MBTA_GTFS/trips.txt"
	headers := []string{"route_id", "service_id", "trip_id"}
	start := time.Now()

	trips := make([]*Trip, 0)
	tripsByRoute := make(map[string][]*Trip)

	err := parseCsvFile(filename, headers, func(records []string, i int) {
		trip := &Trip{
			TripID:    records[2],
			RouteID:   records[0],
			ServiceID: records[1],
		}

		tripsByRoute[trip.RouteID] = append(tripsByRoute[trip.RouteID], trip)
		trips = append(trips, trip)
	})
	if err != nil {
		panic(err)
	}

	elapsed := time.Since(start)
	fmt.Println("parsed", len(trips), "trips in", elapsed)

	return trips, tripsByRoute
}

func parseCsvFile(filename string, headers []string, parseRec func([]string, int)) error {
	f, rd, err := openCsv(filename, headers)
	if err != nil {
		return err
	}
	defer f.Close()

	i, records := 0, []string(nil)
	for records, err = rd.Read(); err == nil; records, err = rd.Read() {
		parseRec(records, i)
		i++
	}

	if err == io.EOF {
		err = nil
	}

	return err
}

func openCsv(filename string, headers []string) (*os.File, *csv.Reader, error) {
	f, err := os.Open(filename)
	if err != nil {
		return nil, nil, err
	}

	rd := csv.NewReader(bufio.NewReader(f))
	rd.ReuseRecord = true

	records, err := rd.Read()
	if err != nil {
		return nil, nil, err
	}

	if len(records) < len(headers) {
		return nil, nil, fmt.Errorf("more headers provided than in file %#v", records)
	}

	for i := 0; i < len(headers); i++ {
		if records[i] != headers[i] {
			return nil, nil, fmt.Errorf("%v not in expected format, file headers: %#v", filename, records)
		}
	}

	return f, rd, nil
}
