package us.durazo.trava;

import java.util.List;

public record TripResponse(
    String tripId,
    String routeId,
    String serviceId,
    List<StopTimeResponse> schedules) {
}
