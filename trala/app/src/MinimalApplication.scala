package app

import gtfs_data.*
import com.github.plokhotnyuk.jsoniter_scala.core.*
import com.github.plokhotnyuk.jsoniter_scala.macros.*
import scala.collection.mutable.ArrayBuffer

object MinimalApplication extends cask.MainRoutes:
  GTFSData // reference it, to trigger the data load

  override def port = 4000

  given JsonValueCodec[ArrayBuffer[TripResponse]] = JsonCodecMaker.make

  @cask.get("/schedules/:route")
  def schedules(route: String) =
    val schedules = GTFSData.schedulesForRoute(route)
    cask.Response(
      writeToString(schedules),
      headers = Seq("Content-Type" -> "application/json")
    )

  @cask.get("/")
  def hello() =
    "Hello World!"

  @cask.post("/do-thing")
  def doThing(request: cask.Request) =
    request.text().reverse

  initialize()
