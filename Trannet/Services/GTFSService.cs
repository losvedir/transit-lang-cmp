using System.Diagnostics;

namespace Trannet.Services;

public static class GTFSService
{
  static List<Trip> Trips { get; }
  static Dictionary<string, List<int>> TripsIxByRoute { get; }
  static List<StopTime> StopTimes { get; }
  static Dictionary<string, List<int>> StopTimesIxByTrip { get; }

  static GTFSService()
  {
    (Trips, TripsIxByRoute) = GTFS.LoadTrips();
    (StopTimes, StopTimesIxByTrip) = GTFS.LoadStopTimes();
  }

  public static List<TripResponse> SchedulesForRoute(string route)
  {
    var trips = new List<TripResponse>();
    if (TripsIxByRoute.ContainsKey(route))
    {
      var tripIxs = TripsIxByRoute[route];
      foreach (int tripIx in tripIxs)
      {
        Trip trip = Trips[tripIx];
        var stopTimeIxs = StopTimesIxByTrip[trip.TripID];
        var schedules = new List<StopTimeResponse>();
        foreach (int stopTimeIx in stopTimeIxs)
        {
          StopTime stopTime = StopTimes[stopTimeIx];
          schedules.Add(new StopTimeResponse(stopTime.StopID, stopTime.Arrival, stopTime.Departure));
        }
        trips.Add(new TripResponse(trip.TripID, trip.RouteID, trip.ServiceID, schedules));
      }
    }
    return trips;
  }
}

public struct StopTimeResponse
{
  public string stop_id { get; }
  public string arrival_time { get; }
  public string departure_time { get; }
  public StopTimeResponse(string stopID, string arrival, string departure)
  {
    stop_id = stopID;
    arrival_time = arrival;
    departure_time = departure;
  }
}

public struct TripResponse
{
  public string trip_id { get; }
  public string route_id { get; }
  public string service_id { get; }
  public List<StopTimeResponse> schedules { get; }
  public TripResponse(string tripID, string routeID, string serviceID, List<StopTimeResponse> stop_time_responses)
  {
    trip_id = tripID;
    route_id = routeID;
    service_id = serviceID;
    schedules = stop_time_responses;
  }
}

struct Trip
{
  public Trip(string tripID, string routeID, string serviceID)
  {
    TripID = tripID;
    RouteID = routeID;
    ServiceID = serviceID;
  }
  public string TripID { get; }
  public string RouteID { get; }
  public string ServiceID { get; }
}

struct StopTime
{
  public StopTime(string tripID, string stopID, string arrival, string departure)
  {
    TripID = tripID;
    StopID = stopID;
    Arrival = arrival;
    Departure = departure;
  }

  public string TripID { get; }
  public string StopID { get; }
  public string Arrival { get; }
  public string Departure { get; }
}

class GTFS
{
  public static (List<Trip>, Dictionary<string, List<int>>) LoadTrips()
  {
    string[] lines = System.IO.File.ReadAllLines(@"../MBTA_GTFS/trips.txt");
    string[] header = lines[0].Split(",");
    Debug.Assert(header[0] == "route_id");
    Debug.Assert(header[1] == "service_id");
    Debug.Assert(header[2] == "trip_id");

    var trips = new List<Trip>();
    var tripsIxByRoute = new Dictionary<string, List<int>>();

    var i = 0;
    foreach (string line in lines.Skip(1))
    {
      string[] cells = line.Split(",");
      string routeID = cells[0];
      trips.Add(new Trip(cells[2], routeID, cells[1]));

      if (tripsIxByRoute.ContainsKey(routeID))
      {
        tripsIxByRoute[routeID].Add(i);
      }
      else
      {
        tripsIxByRoute.Add(routeID, new List<int> { i });
      }

      i++;
    }
    return (trips, tripsIxByRoute);
  }

  public static (List<StopTime>, Dictionary<string, List<int>>) LoadStopTimes()
  {
    var watch = new System.Diagnostics.Stopwatch();
    watch.Start();
    string[] lines = System.IO.File.ReadAllLines(@"../MBTA_GTFS/stop_times.txt");
    string[] header = lines[0].Split(",");
    Debug.Assert(header[0] == "trip_id");
    Debug.Assert(header[1] == "arrival_time");
    Debug.Assert(header[2] == "departure_time");
    Debug.Assert(header[3] == "stop_id");

    var stopTimes = new List<StopTime>();
    var stopTimesIxByTrip = new Dictionary<String, List<int>>();

    int i = 0;
    foreach (string line in lines.Skip(1))
    {
      string[] cells = line.Split(",");
      var tripID = cells[0];
      stopTimes.Add(new StopTime(tripID, cells[3], cells[1], cells[2]));

      if (stopTimesIxByTrip.ContainsKey(tripID))
      {
        stopTimesIxByTrip[tripID].Add(i);
      }
      else
      {
        stopTimesIxByTrip.Add(tripID, new List<int> { i });
      }

      i++;
    }
    watch.Stop();
    Console.WriteLine($"loaded stop_times.txt in {watch.ElapsedMilliseconds} ms");
    return (stopTimes, stopTimesIxByTrip);
  }
}
