import { csv } from "./deps.ts";
const { parse } = csv;

interface StopTime {
  tripID: string;
  arrival: string;
  departure: string;
  stopID: string;
}

interface Trip {
  tripID: string;
  routeID: string;
  serviceID: string;
}

const get_stop_times = (): [StopTime[], { [tripID: string]: number[] }] => {
  const decoder = new TextDecoder("utf-8");
  const stop_times_raw = Deno.readFileSync("../MBTA_GTFS/stop_times.txt");
  const stop_times = decoder.decode(stop_times_raw);
  const parsed = parse(stop_times, { skipFirstRow: false }) as string[][];

  if (
    parsed[0][0] !== "trip_id" ||
    parsed[0][1] !== "arrival_time" ||
    parsed[0][2] !== "departure_time" ||
    parsed[0][3] !== "stop_id"
  ) {
    console.log("stop_times.txt not in expected format", parsed[0]);
    Deno.exit(1);
  }
  parsed[0];

  const sts: StopTime[] = [];
  const stsByTrip: { [tripID: string]: number[] } = {};

  for (let i = 1; i < parsed.length; i++) {
    const row = parsed[i];
    const tripID = row[0];
    if (stsByTrip[tripID]) {
      stsByTrip[tripID].push(i - 1);
    } else {
      stsByTrip[tripID] = [i - 1];
    }
    sts.push({
      tripID: tripID,
      arrival: row[1],
      departure: row[2],
      stopID: row[3],
    });
  }

  return [sts, stsByTrip];
};

const get_trips = (): [Trip[], { [routeID: string]: number[] }] => {
  const decoder = new TextDecoder("utf-8");
  const trips_raw = Deno.readFileSync("../MBTA_GTFS/trips.txt");
  const trips = decoder.decode(trips_raw);
  const parsed = parse(trips, { skipFirstRow: false }) as string[][];

  if (
    parsed[0][0] !== "route_id" ||
    parsed[0][1] !== "service_id" ||
    parsed[0][2] !== "trip_id"
  ) {
    console.log("trips.txt not in expected format", parsed[0]);
    Deno.exit(1);
  }

  const t: Trip[] = [];
  const tripsByRoute: { [routeID: string]: number[] } = {};

  for (let i = 1; i < parsed.length; i++) {
    const row = parsed[i];
    const route = row[0];
    if (tripsByRoute[route]) {
      tripsByRoute[route].push(i - 1);
    } else {
      tripsByRoute[route] = [i - 1];
    }
    t.push(
      { tripID: row[2], routeID: route, serviceID: row[1] },
    );
  }

  return [t, tripsByRoute];
};

const p = self.performance;

p.mark("startStopTimes");
const [stopTimes, stsByTrip] = get_stop_times();
p.mark("endStopTimes");
p.measure("stopTimes", "startStopTimes", "endStopTimes");

p.mark("startTrips");
const [trips, tripsByRoute] = get_trips();
p.mark("endTrips");
p.measure("trips", "startTrips", "endTrips");

const route = Deno.args[0];
console.log(`Searching stops for route: ${route}`);

p.mark("startSearchStopTimes");

let schedCount = 0;
if (tripsByRoute[route]) {
  tripsByRoute[route].forEach((t_ix) => {
    const trip = trips[t_ix] as Trip;
    if (stsByTrip[trip.tripID]) {
      schedCount += stsByTrip[trip.tripID].length;
    }
  });
}

p.mark("endSearchStopTimes");
p.measure("searchStopTimes", "startSearchStopTimes", "endSearchStopTimes");

console.log(`Found ${schedCount} schedules for ${route}`);

console.log(
  "parse stop times: ",
  p.getEntriesByName("stopTimes")[0].duration,
  "ms",
);

console.log(
  "search stop times: ",
  p.getEntriesByName("searchStopTimes")[0].duration,
  "ms",
);
