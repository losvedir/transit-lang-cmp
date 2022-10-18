using System.Diagnostics;

class Trannet
{
  public static void Main(string[] args)
  {
    Debug.Assert(args.Length == 1);
    var route = args[0];

    var (trips, tripsIxByRoute) = GTFS.LoadTrips();
    Console.WriteLine("loaded trips, count: " + trips.Count);

    var (stopTimes, stopTimesIxByTrip) = GTFS.LoadStopTimes();
    Console.WriteLine("loaded stopTimes, count: " + stopTimes.Count);

    Console.WriteLine($"Counting schedules for route {route}");
    var watch = Stopwatch.StartNew();
    int schedules = 0;

    if (tripsIxByRoute.ContainsKey(route))
    {
      var tripsIxs = tripsIxByRoute[route];
      foreach (int tripIx in tripsIxs)
      {
        Trip trip = trips[tripIx];
        schedules += stopTimesIxByTrip[trip.TripID].Count();
      }
    }
    watch.Stop();
    Console.WriteLine($"Found {schedules} schedules in {watch.ElapsedTicks / 1000} µs");
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
