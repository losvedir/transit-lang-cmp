namespace Trannet.Benchmark.TrannetVersions._02_ListAndDictionaryUse;

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