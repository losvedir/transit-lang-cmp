package app

import gtfs_data._

object MinimalApplication extends cask.MainRoutes {
  GTFSData // reference it, to trigger the data load

  override def port = 4000

  @cask.get("/schedules/:route")
  def schedules(route: String) =
    val schedules = GTFSData.schedulesForRoute(route)
    upickle.default.write(schedules)

  @cask.get("/")
  def hello() = {
    "Hello World!"
  }

  @cask.post("/do-thing")
  def doThing(request: cask.Request) = {
    request.text().reverse
  }

  initialize()
}
