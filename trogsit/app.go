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

	_, stsByTrip := getStopTimes()
	trips, tripsByRoute := getTrips()

	t1 := time.Now()

	scheduleCount := 0

	ts, ok := tripsByRoute[route]
	if ok {
		for _, t_ix := range ts {
			trip := trips[t_ix]
			sts, ok := stsByTrip[trip.TripID]
			if ok {
				scheduleCount += len(sts)
			}
		}
	}

	t2 := time.Now()

	fmt.Println("Identified", scheduleCount, "stops in", t2.Sub(t1))
}

func getStopTimes() ([]StopTime, map[string][]int) {
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
	stsByTrip := make(map[string][]int)
	for i, rec := range records[1:] {
		trip := rec[0]
		sts, ok := stsByTrip[trip]
		if ok {
			stsByTrip[trip] = append(sts, i)
		} else {
			stsByTrip[trip] = []int{i}
		}
		stopTimes = append(stopTimes, StopTime{TripID: trip, StopID: rec[3], Arrival: rec[1], Departure: rec[2]})
	}
	end := time.Now()
	elapsed := end.Sub(start)

	fmt.Println("parsed", len(stopTimes), "stop times in", elapsed)

	return stopTimes, stsByTrip
}

func getTrips() ([]Trip, map[string][]int) {
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
	tripsByRoute := make(map[string][]int)
	for i, rec := range records[1:] {
		route := rec[0]
		ts, ok := tripsByRoute[route]
		if ok {
			tripsByRoute[route] = append(ts, i)
		} else {
			tripsByRoute[route] = []int{i}
		}
		trips = append(trips, Trip{TripID: rec[2], RouteID: route, ServiceID: rec[1]})
	}
	end := time.Now()
	elapsed := end.Sub(start)

	fmt.Println("parsed", len(trips), "trips in", elapsed)

	return trips, tripsByRoute
}
