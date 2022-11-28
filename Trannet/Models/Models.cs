namespace Trannet.Services;
public record StopTimeResponse(string stop_id, string arrival_time, string departure_time);
public record TripResponse(string trip_id, string route_id, string service_id, List<StopTimeResponse> schedules);
public record Trip(string TripID, string RouteID, string ServiceID);
public record StopTime(string TripID, string StopID, string Arrival, string Departure);
