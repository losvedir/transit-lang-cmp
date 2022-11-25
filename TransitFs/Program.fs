open System
open System.Diagnostics
open System.Collections.Generic
open Sylvan.Data.Csv
open System.Text.Json.Serialization

let dataDir = "../MBTA_GTFS"

type Trip = {
    trip_id: string
    route_id: string
    service_id: string
}

type StopTime = {
    [<JsonIgnore>] tripId: string
    stop_id: string
    arrival_id: string
    departure_id: string
}

let loadTrips () =
    let trips = ResizeArray(100_000)
    let tripsIxByRoute = Dictionary<string, ResizeArray<int>>()
    let csvOpts = CsvDataReaderOptions(HasHeaders=true, Delimiter=',')
    use csv = CsvDataReader.Create($"{dataDir}/trips.txt", csvOpts)

    while csv.Read() do
        let routeId = csv.GetString(0)
        trips.Add({ route_id=routeId; service_id=csv.GetString(1); trip_id=csv.GetString(2) })
        match tripsIxByRoute.TryGetValue routeId with
        | true, list -> list.Add(trips.Count - 1)
        | false, _ ->
            let list = ResizeArray()
            list.Add(trips.Count - 1)
            tripsIxByRoute.Add(routeId, list)

    trips, tripsIxByRoute

let loadStopTimes () =
    let stopTimes = ResizeArray(100_000)
    let stopTimesIxByTrip = Dictionary<String, ResizeArray<int>>(100_000)
    let csvOpts = CsvDataReaderOptions(HasHeaders=true, Delimiter=',')
    use csv = CsvDataReader.Create($"{dataDir}/stop_times.txt", csvOpts)

    while csv.Read() do
        let tripID = csv.GetString(0)
        stopTimes.Add({ tripId=tripID; arrival_id=csv.GetString(1); departure_id=csv.GetString(2); stop_id=csv.GetString(3) })
        match stopTimesIxByTrip.TryGetValue(tripID) with
        | true, list -> list.Add(stopTimes.Count - 1)
        | false, _ ->
            let list = ResizeArray()
            list.Add(stopTimes.Count - 1)
            stopTimesIxByTrip.Add(tripID, list)

    stopTimes, stopTimesIxByTrip

let inline timeIt name fn =
    let sw = Stopwatch.StartNew()
    let result = fn()
    sw.Stop()
    printfn "%s: %dms" name sw.ElapsedMilliseconds
    result

let trips, tripsIxByRoute = timeIt "loadTrips" loadTrips
let stopTimes, stopTimesIxByTrip = timeIt "loadStopTimes" loadStopTimes
printfn $"#trips={trips.Count}, #stopTimes={stopTimes.Count}"

open Microsoft.AspNetCore.Builder
open Falco
open Falco.Routing
open Falco.HostBuilder

webHost [||] {

    use_if FalcoExtensions.IsDevelopment DeveloperExceptionPageExtensions.UseDeveloperExceptionPage

    endpoints [
        get "/schedules/{id}" <| fun ctx ->
            let url = Request.getRoute ctx
            let routeId = url.GetString "id" "<empty>"
            match tripsIxByRoute.TryGetValue routeId with
            | true, tripIxs ->
                ctx |> Response.ofJson (seq {
                    for tripIx in tripIxs ->
                        let trip = trips[tripIx]
                        let stopTimeIxs = stopTimesIxByTrip[trip.trip_id]
                        {| trip with
                            schedules = seq { for stopTimeIx in stopTimeIxs -> stopTimes[stopTimeIx] }
                        |}
                })
            | false, _ ->
                ctx |> Response.withStatusCode 404 |> Response.ofPlainText $"No trips found for route: {routeId}"
    ]
}
