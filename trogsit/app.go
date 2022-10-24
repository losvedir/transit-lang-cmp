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
	TripID    string
	StopID    string
	Arrival   string
	Departure string
}

type Trip struct {
	TripID    string
	RouteID   string
	ServiceID string
}

type TripResponse struct {
	TripID    string             `json:"trip_id"`
	ServiceID string             `json:"service_id"`
	RouteID   string             `json:"route_id"`
	Schedules []ScheduleResponse `json:"schedules"`
}

type ScheduleResponse struct {
	StopID    string `json:"stop_id"`
	Arrival   string `json:"arrival_time"`
	Departure string `json:"departure_time"`
}

func buildTripResponse(
	route string,
	stopTimes []*StopTime,
	stopTimesIxByTrip map[string][]int,
	trips []*Trip,
	tripsIxByRoute map[string][]int,
) []TripResponse {
	tripIxs := tripsIxByRoute[route]

	resp := make([]TripResponse, 0, len(tripIxs))
	for _, tripIx := range tripIxs {
		trip := trips[tripIx]
		tripResponse := TripResponse{
			TripID:    trip.TripID,
			ServiceID: trip.ServiceID,
			RouteID:   trip.RouteID,
		}

		stopTimeIxs := stopTimesIxByTrip[trip.TripID]
		tripResponse.Schedules = make([]ScheduleResponse, 0, len(stopTimeIxs))
		for _, stopTimeIx := range stopTimeIxs {
			stopTime := stopTimes[stopTimeIx]
			tripResponse.Schedules = append(tripResponse.Schedules, ScheduleResponse{
				StopID:    stopTime.StopID,
				Arrival:   stopTime.Arrival,
				Departure: stopTime.Departure,
			})
		}

		resp = append(resp, tripResponse)
	}

	return resp
}

func main() {
	stopTimes, stopTimesIxByTrip := getStopTimes()
	trips, tripsIxByRoute := getTrips()

	http.HandleFunc("/schedules/", func(w http.ResponseWriter, r *http.Request) {
		route := strings.Split(r.URL.Path, "/")[2]
		resp := buildTripResponse(route, stopTimes, stopTimesIxByTrip, trips, tripsIxByRoute)
		w.Header().Set("Content-Type", "application/json")
		json_resp, err := json.Marshal(resp)
		if err != nil {
			fmt.Println("json error", err)
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte("500 - Something bad happened!"))
		} else {
			w.Write(json_resp)
		}
	})
	log.Fatal(http.ListenAndServe(":4000", nil))
}

func getStopTimes() ([]*StopTime, map[string][]int) {
	filename := "../MBTA_GTFS/stop_times.txt"
	headers := []string{"trip_id", "arrival_time", "departure_time", "stop_id"}

	stopTimes := make([]*StopTime, 0, 1_000_000)
	stsByTrip := make(map[string][]int)
	start := time.Now()

	parseCsvFile(filename, headers, func(records []string, i int) {
		trip := records[0]

		stsByTrip[trip] = append(stsByTrip[trip], i)
		stopTimes = append(stopTimes, &StopTime{TripID: trip, StopID: records[3], Arrival: records[1], Departure: records[2]})
	})

	elapsed := time.Since(start)
	fmt.Println("parsed", len(stopTimes), "stop times in", elapsed)

	return stopTimes, stsByTrip
}

func getTrips() ([]*Trip, map[string][]int) {
	filename := "../MBTA_GTFS/trips.txt"
	headers := []string{"route_id", "service_id", "trip_id"}

	trips := make([]*Trip, 0, 70_000)
	tripsByRoute := make(map[string][]int)
	start := time.Now()

	parseCsvFile(filename, headers, func(records []string, i int) {
		route := records[0]

		tripsByRoute[route] = append(tripsByRoute[route], i)
		trips = append(trips, &Trip{TripID: records[2], RouteID: route, ServiceID: records[1]})
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
