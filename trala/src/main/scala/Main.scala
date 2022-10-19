import scala.io.Source
import scala.collection.mutable.ArrayBuffer

case class Trip(tripID: String, routeID: String, serviceID: String)
case class StopTime(
    tripID: String,
    stopID: String,
    arrival: String,
    departure: String
)

@main def hello: Unit =
  val (trips, tripsIxByRoute) = getTrips
  val (stopTimes, stopTimesIxByTrip) = getStopTimes

  var schedules: Int = 0

  val startSearch = System.nanoTime()
  for tripIx <- tripsIxByRoute("Red") do
    val trip = trips(tripIx)
    schedules = schedules + stopTimesIxByTrip(trip.tripID).length
  val endSearch = System.nanoTime()

  println(
    f"found ${schedules} schedules for Red line in ${(endSearch - startSearch) / 1000} µs"
  )

def getTrips: (ArrayBuffer[Trip], Map[String, ArrayBuffer[Int]]) =
  val lines = Source.fromFile("../MBTA_GTFS/trips.txt").getLines()
  val header = lines.next().split(",")
  assert(header.length > 3)
  assert(header(0) == "route_id")
  assert(header(1) == "service_id")
  assert(header(2) == "trip_id")

  var trips: ArrayBuffer[Trip] = ArrayBuffer()
  var tripsIxByRoute: Map[String, ArrayBuffer[Int]] = Map()

  for (line, i) <- lines.zipWithIndex do
    val cells = line.split(",")
    val route = cells(0)
    trips.addOne(Trip(cells(2), route, cells(1)))
    tripsIxByRoute = if tripsIxByRoute.contains(route) then
      tripsIxByRoute(route).addOne(i)
      tripsIxByRoute
    else tripsIxByRoute + (route -> ArrayBuffer[Int](i))

  (trips, tripsIxByRoute)

def getStopTimes: (ArrayBuffer[StopTime], Map[String, ArrayBuffer[Int]]) =
  val timingStart = System.nanoTime()
  val lines = Source.fromFile("../MBTA_GTFS/stop_times.txt").getLines()
  val header = lines.next().split(",")
  assert(header.length > 4)
  assert(header(0) == "trip_id")
  assert(header(1) == "arrival_time")
  assert(header(2) == "departure_time")
  assert(header(3) == "stop_id")

  var stopTimes = ArrayBuffer[StopTime]()
  var stopTimesIxByTrip = Map[String, ArrayBuffer[Int]]()
  for (line, i) <- lines.zipWithIndex do
    val cells = line.split(",")
    val trip = cells(0)
    stopTimes.addOne(StopTime(trip, cells(3), cells(1), cells(2)))
    stopTimesIxByTrip = if stopTimesIxByTrip.contains(trip) then
      stopTimesIxByTrip(trip).addOne(i)
      stopTimesIxByTrip
    else stopTimesIxByTrip + (trip -> ArrayBuffer[Int](i))

  val timingEnd = System.nanoTime()
  println(f"Loaded stop_times.txt in ${(timingEnd - timingStart) / 1000000} ms")
  (stopTimes, stopTimesIxByTrip)
