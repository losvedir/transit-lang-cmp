package transikt

import kotlinx.serialization.Serializable
import org.apache.commons.csv.*
import java.nio.file.*
import kotlin.io.path.*

object GtfsParser {

    private val csvFormat = CSVFormat.RFC4180.builder().setHeader().setSkipHeaderRecord(true).build()

    fun parse(dataDir: Path): GtfsData {
        val trips = dataDir.resolve("trips.txt").readGtfsTrips()
        val stopTimes = dataDir.resolve("stop_times.txt").readStopTimes()
        return GtfsData(trips, stopTimes)
    }

    private fun Path.readGtfsTrips() = readCsvSequence().map { it.toTrip() }

    private fun Path.readStopTimes() = readCsvSequence().map { it.toStopTime() }

    private fun Path.readCsvSequence() = csvFormat.parse(reader())

    private fun CSVRecord.toTrip() = Trip(
        tripId = get("trip_id"),
        routeId = get("route_id"),
        serviceId = get("service_id"),
    )

    private fun CSVRecord.toStopTime() = Stop(
        tripId = get("trip_id"),
        stopId = get("stop_id"),
        arrivalTime = get("arrival_time"),
        departureTime = get("departure_time"),
    )
}

class GtfsData(
    allTrips: List<Trip>,
    allStops: List<Stop>,
) {
    private val tripsByRouteId = allTrips.associateBy { it.routeId }
    private val stopsByTripId = allStops.groupBy { it.tripId }

    fun getTripByRouteId(routeId: String): TripResponse? {
        val trip = tripsByRouteId[routeId] ?: return null
        val stops = stopsByTripId[trip.tripId] ?: emptyList()
        return trip.toTripResponse(stops)
    }
}

data class Trip(
    val tripId: String,
    val routeId: String,
    val serviceId: String,
)

data class Stop(
    val tripId: String,
    val stopId: String,
    val arrivalTime: String,
    val departureTime: String,
)

private fun Trip.toTripResponse(stops: List<Stop>) = TripResponse(
    trip_id = tripId,
    route_id = routeId,
    service_id = serviceId,
    schedules = stops.map { it.toStop() }
)

private fun Stop.toStop() = StopResponse(
    stop_id = stopId,
    arrival_time = arrivalTime,
    departure_time = departureTime,
)

@Serializable
data class TripResponse(
    val trip_id: String,
    val route_id: String,
    val service_id: String,
    val schedules: List<StopResponse>,
)

@Serializable
data class StopResponse(
    val stop_id: String,
    val arrival_time: String,
    val departure_time: String,
)
