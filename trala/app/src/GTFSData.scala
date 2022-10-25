package gtfs_data

import scala.io.Source
import scala.collection.mutable.ArrayBuffer
import scala.collection.mutable.Map
import scala.util.Using

case class Trip(tripID: String, routeID: String, serviceID: String)
case class StopTime(
    tripID: String,
    stopID: String,
    arrival: String,
    departure: String
)

case class TripResponse(
    trip_id: String,
    route_id: String,
    service_id: String,
    schedules: ArrayBuffer[ScheduleResponse]
)

case class ScheduleResponse(
    stop_id: String,
    arrival_time: String,
    departure_time: String
)

object GTFSData:
  val (trips, tripsIxByRoute) = getTrips
  val (stopTimes, stopTimesIxByTrip) = getStopTimes

  def schedulesForRoute(route: String): ArrayBuffer[TripResponse] =
    var tripResponses = ArrayBuffer[TripResponse]()
    for
      tripIxs <- tripsIxByRoute.get(route)
      tripIx <- tripIxs
    do
      val trip = trips(tripIx)
      var schedules = ArrayBuffer[ScheduleResponse]()
      for
        stopTimeIxs <- stopTimesIxByTrip.get(trip.tripID)
        stopTimeIx <- stopTimeIxs
      do
        val stopTime = stopTimes(stopTimeIx)
        schedules += ScheduleResponse(
          stopTime.stopID,
          stopTime.arrival,
          stopTime.departure
        )
      tripResponses += TripResponse(
        trip.tripID,
        trip.routeID,
        trip.serviceID,
        schedules
      )
    tripResponses

  def getTrips: (ArrayBuffer[Trip], Map[String, ArrayBuffer[Int]]) =
    Using.resource(Source.fromFile("../MBTA_GTFS/trips.txt")) { source =>
      val lines = source.getLines()
      val header = lines.next().split(",", 4)
      assert(header.length > 3)
      assert(header(0) == "route_id")
      assert(header(1) == "service_id")
      assert(header(2) == "trip_id")

      val trips = ArrayBuffer.empty[Trip]
      val tripsIxByRoute = Map.empty[String, ArrayBuffer[Int]]

      for (line, i) <- lines.zipWithIndex do
        val cells = line.split(",", 4)
        val route = cells(0)
        trips += Trip(cells(2), route, cells(1))
        tripsIxByRoute.getOrElseUpdate(route, ArrayBuffer.empty) += i

      (trips, tripsIxByRoute)
    }

  def getStopTimes: (ArrayBuffer[StopTime], Map[String, ArrayBuffer[Int]]) =
    val timingStart = System.nanoTime()
    val result =
      Using.resource(Source.fromFile("../MBTA_GTFS/stop_times.txt")) { source =>
        val lines = source.getLines()
        val header = lines.next().split(",", 5)
        assert(header.length > 4)
        assert(header(0) == "trip_id")
        assert(header(1) == "arrival_time")
        assert(header(2) == "departure_time")
        assert(header(3) == "stop_id")

        val stopTimes = ArrayBuffer.empty[StopTime]
        val stopTimesIxByTrip = Map.empty[String, ArrayBuffer[Int]]

        for (line, i) <- lines.zipWithIndex do
          val cells = line.split(",", 5)
          val trip = cells(0)
          stopTimes += StopTime(trip, cells(3), cells(1), cells(2))
          stopTimesIxByTrip.getOrElseUpdate(trip, ArrayBuffer.empty) += i

        (stopTimes, stopTimesIxByTrip)
      }
    val timingEnd = System.nanoTime()
    println(
      f"Loaded stop_times.txt in ${(timingEnd - timingStart) / 1000000} ms"
    )
    result
