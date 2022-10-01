use csv;
use std::collections::HashSet;
use std::env;
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

#[allow(dead_code)]
struct Trip {
    trip_id: String,
    route_id: String,
    service_id: String,
}

fn main() {
    let route = env::args().nth(1).expect("route as argument");
    println!("Finding schedules for {:?}", route);
    let stop_times = get_stop_times();
    let trips = get_trips();

    let search_start = Instant::now();
    let mut route_trips: HashSet<String> = HashSet::new();
    for trip in trips {
        if trip.route_id == route {
            route_trips.insert(trip.trip_id);
        }
    }

    let mut schedule_count = 0;
    for st in stop_times {
        if route_trips.contains(&st.trip_id) {
            schedule_count = schedule_count + 1;
        }
    }
    let search_elapsed = search_start.elapsed();
    println!(
        "Found {:?} schedules for {:?} in {:?}ms",
        schedule_count,
        route,
        search_elapsed.as_millis()
    );
}

fn get_stop_times() -> Vec<StopTime> {
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

    let stop_times: Vec<StopTime> = rdr_iter
        .map(|result| {
            let record = result.expect("CSV record");
            StopTime {
                trip_id: record.get(0).expect("row trip").into(),
                stop_id: record.get(3).expect("row stop").into(),
                arrival: record.get(1).expect("row arrival").into(),
                departure: record.get(2).expect("row departure").into(),
            }
        })
        .collect();

    let elapsed = now.elapsed();
    println!(
        "parsed {:?} stop_times in {:?} ms",
        stop_times.len(),
        elapsed.as_millis()
    );

    return stop_times;
}

fn get_trips() -> Vec<Trip> {
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

    let trips: Vec<Trip> = rdr_iter
        .map(|result| {
            let record = result.expect("CSV record");
            Trip {
                route_id: record.get(0).expect("row route").into(),
                service_id: record.get(1).expect("row service").into(),
                trip_id: record.get(2).expect("row trip_id").into(),
            }
        })
        .collect();

    let elapsed = now.elapsed();
    println!(
        "parsed {:?} trips in {:?} ms",
        trips.len(),
        elapsed.as_millis()
    );

    return trips;
}
