extern crate tokio;

use axum::Json;
use axum::{extract::Path, extract::State, response::IntoResponse, routing::get, Router};
use csv;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Instant;

// parsing the fields for future use and for fair comparison with
// other languages, but getting a (neat!) warning that some fields
// are never accessed
#[allow(dead_code)]
struct StopTime {
    trip_id: String,
    stop_id: String,
    arrival: String,
    departure: String,
}

struct Trip {
    trip_id: String,
    route_id: String,
    service_id: String,
}

#[derive(Debug, Serialize)]
struct TripResponse<'data> {
    trip_id: &'data str,
    service_id: &'data str,
    route_id: &'data str,
    schedules: Vec<ScheduleResponse<'data>>,
}

#[derive(Debug, Serialize)]
struct ScheduleResponse<'data> {
    stop_id: &'data str,
    arrival_time: &'data str,
    departure_time: &'data str,
}

struct Data {
    trips: Vec<Trip>,
    trips_ix_by_route: HashMap<String, Vec<usize>>,
    stop_times: Vec<StopTime>,
    stop_times_ix_by_trip: HashMap<String, Vec<usize>>,
}

#[tokio::main]
async fn main() {
    let (stop_times, stop_times_ix_by_trip) = get_stop_times();
    let (trips, trips_ix_by_route) = get_trips();
    let data = Data {
        trips: trips,
        trips_ix_by_route: trips_ix_by_route,
        stop_times: stop_times,
        stop_times_ix_by_trip: stop_times_ix_by_trip,
    };

    let app =
        Router::with_state(Arc::new(data)).route("/schedules/:route_id", get(schedule_handler));

    // run it with hyper on localhost:3000
    axum::Server::bind(&"0.0.0.0:4000".parse().unwrap())
        .serve(app.into_make_service())
        .await
        .unwrap();
}

async fn schedule_handler(
    Path(route_id): Path<String>,
    State(data): State<Arc<Data>>,
) -> axum::response::Response {
    let resp: Vec<TripResponse> = data
        .trips_ix_by_route
        .get(&route_id)
        .unwrap_or(&Vec::new())
        .iter()
        .map(|trip_ix| {
            let trip = &data.trips[*trip_ix];
            let schedules: Vec<ScheduleResponse> = data
                .stop_times_ix_by_trip
                .get(&trip.trip_id)
                .unwrap_or(&Vec::new())
                .iter()
                .map(|stop_time_ix| {
                    let stop_time = &data.stop_times[*stop_time_ix];
                    ScheduleResponse {
                        stop_id: &stop_time.stop_id,
                        arrival_time: &stop_time.arrival,
                        departure_time: &stop_time.departure,
                    }
                })
                .collect();
            TripResponse {
                trip_id: &trip.trip_id,
                service_id: &trip.service_id,
                route_id: &trip.route_id,
                schedules: schedules,
            }
        })
        .collect();
    Json(resp).into_response()
}

fn get_stop_times() -> (Vec<StopTime>, HashMap<String, Vec<usize>>) {
    let now = Instant::now();
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(false)
        .from_path("../MBTA_GTFS/stop_times.txt")
        .expect("read stop_times.txt");

    let mut rdr_iter = rdr.records();

    match rdr_iter.next() {
        Some(Ok(row)) => {
            if row.get(0) != Some("trip_id")
                || row.get(1) != Some("arrival_time")
                || row.get(2) != Some("departure_time")
                || row.get(3) != Some("stop_id")
            {
                println!("{:?}", row);
                panic!("stop_times.txt unexpected format")
            }
        }
        _ => {
            panic!("error retrieving first row of stop_times.txt")
        }
    }

    let mut stop_time_by_trip: HashMap<String, Vec<usize>> = HashMap::new();
    let mut ix: usize = 0;

    let mut stop_times: Vec<StopTime> = Vec::with_capacity(2_000_000);
    for result in rdr_iter {
        let record = result.expect("CSV record");
        let trip_id: String = record.get(0).expect("row trip").into();

        let trips = stop_time_by_trip
            .entry(trip_id.clone())
            .or_insert(Vec::new());
        trips.push(ix);

        stop_times.push(StopTime {
            trip_id: trip_id,
            stop_id: record.get(3).expect("row stop").into(),
            arrival: record.get(1).expect("row arrival").into(),
            departure: record.get(2).expect("row departure").into(),
        });
        ix = ix + 1;
    }

    let elapsed = now.elapsed();
    println!(
        "parsed {:?} stop_times in {:?} ms",
        stop_times.len(),
        elapsed.as_millis()
    );

    return (stop_times, stop_time_by_trip);
}

fn get_trips() -> (Vec<Trip>, HashMap<String, Vec<usize>>) {
    let now = Instant::now();
    let mut rdr = csv::ReaderBuilder::new()
        .has_headers(false)
        .from_path("../MBTA_GTFS/trips.txt")
        .expect("read trips.txt");

    let mut rdr_iter = rdr.records();

    match rdr_iter.next() {
        Some(Ok(row)) => {
            if row.get(0) != Some("route_id")
                || row.get(1) != Some("service_id")
                || row.get(2) != Some("trip_id")
            {
                println!("{:?}", row);
                panic!("trips.txt unexpected format")
            }
        }
        _ => {
            panic!("error retrieving first row of trips.txt")
        }
    }

    let mut trips: Vec<Trip> = Vec::with_capacity(2_000_000);
    let mut trip_by_route: HashMap<String, Vec<usize>> = HashMap::new();

    let mut ix: usize = 0;
    for result in rdr_iter {
        let record = result.expect("CSV record");
        let route_id: String = record.get(0).expect("row route").into();
        let e = trip_by_route.entry(route_id.clone()).or_insert(Vec::new());
        e.push(ix);
        trips.push(Trip {
            route_id: route_id,
            service_id: record.get(1).expect("row service").into(),
            trip_id: record.get(2).expect("row trip_id").into(),
        });
        ix += 1;
    }

    let elapsed = now.elapsed();
    println!(
        "parsed {:?} trips in {:?} ms",
        trips.len(),
        elapsed.as_millis()
    );

    return (trips, trip_by_route);
}
