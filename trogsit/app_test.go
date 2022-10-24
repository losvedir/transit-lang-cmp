package main

import "testing"

func BenchmarkTripResp(b *testing.B) {
	_, stopTimesByTrip := getStopTimes()
	_, tripsIxByRoute := getTrips()
	b.ResetTimer()

	for n := 0; n < b.N; n++ {
		for _, route := range routes {
			buildTripResponse(tripsIxByRoute[route], stopTimesByTrip)
		}
	}
}

func BenchmarkGetStopTimes(b *testing.B) {
	for n := 0; n < b.N; n++ {
		getStopTimes()
	}
}

func BenchmarkGetTrips(b *testing.B) {
	for n := 0; n < b.N; n++ {
		getTrips()
	}
}

var routes = []string{
	"Mattapan",
	"Orange",
	"Green-B",
	"Green-C",
	"Green-D",
	"Green-E",
	"Blue",
	"741",
	"742",
	"743",
	"751",
	"749",
	"746",
	"CR-Fairmount",
	"CR-Fitchburg",
	"CR-Worcester",
	"CR-Franklin",
	"CR-Greenbush",
	"CR-Haverhill",
	"CR-Kingston",
	"CR-Lowell",
	"CR-Middleborough",
	"CR-Needham",
	"CR-Newburyport",
	"CR-Providence",
	"CR-Foxboro",
	"Boat-F4",
	"Boat-F1",
	"Boat-EastBoston",
}
