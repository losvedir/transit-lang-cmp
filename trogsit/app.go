package main

import (
	"encoding/csv"
	"fmt"
	"os"
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

func main() {
	route := os.Args[1]

	stopTimes := getStopTimes()
	trips := getTrips()

	t1 := time.Now()
	routeTrips := map[string]bool{}
	for _, t := range trips {
		if t.RouteID == route {
			routeTrips[t.TripID] = true
		}
	}

	stopCount := 0
	for _, st := range stopTimes {
		_, relevantTrip := routeTrips[st.TripID]
		if relevantTrip {
			stopCount += 1
		}
	}
	t2 := time.Now()

	fmt.Println("Identified", stopCount, "stops in", t2.Sub(t1), "ms")
}

func getStopTimes() []StopTime {
	f, err := os.Open("../MBTA_GTFS/stop_times.txt")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	start := time.Now()
	r := csv.NewReader(f)
	records, err := r.ReadAll()
	if err != nil {
		panic(err)
	}

	if records[0][0] != "trip_id" || records[0][3] != "stop_id" || records[0][1] != "arrival_time" || records[0][2] != "departure_time" {
		fmt.Println("stop_times.txt not in expected format:")
		for i, cell := range records[0] {
			fmt.Println(i, cell)
		}
		panic(1)
	}

	stopTimes := make([]StopTime, 0, 1_000_000)
	for _, rec := range records[1:] {
		stopTimes = append(stopTimes, StopTime{TripID: rec[0], StopID: rec[3], Arrival: rec[1], Departure: rec[2]})
	}
	end := time.Now()
	elapsed := end.Sub(start)

	fmt.Println("parsed", len(stopTimes), "stop times in", elapsed, "ms")

	return stopTimes
}

func getTrips() []Trip {
	f, err := os.Open("../MBTA_GTFS/trips.txt")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	start := time.Now()
	r := csv.NewReader(f)
	records, err := r.ReadAll()
	if err != nil {
		panic(err)
	}

	if records[0][2] != "trip_id" || records[0][0] != "route_id" || records[0][1] != "service_id" {
		fmt.Println("trips.txt not in expected format:")
		for i, cell := range records[0] {
			fmt.Println(i, cell)
		}
		panic(1)
	}

	trips := make([]Trip, 0, 70_000)
	for _, rec := range records[1:] {
		trips = append(trips, Trip{TripID: rec[2], RouteID: rec[0], ServiceID: rec[1]})
	}
	end := time.Now()
	elapsed := end.Sub(start)

	fmt.Println("parsed", len(trips), "trips in", elapsed, "ms")

	return trips
}
