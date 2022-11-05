package transikt

import io.ktor.serialization.kotlinx.json.*
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.plugins.*
import io.ktor.server.plugins.contentnegotiation.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import kotlin.io.path.*

fun main() {
    val data = GtfsParser.parse(dataDir = Path("../MBTA_GTFS"))

    embeddedServer(Netty, port = 8080) {
        install(ContentNegotiation) {
            json()
        }
        routing {
            get("/schedules/{route}") {
                val routeId = call.parameters["route"] ?: throw BadRequestException("missing route ID")
                val trip = data.getTripByRouteId(routeId) ?: throw NotFoundException("no trip found for route $routeId")
                call.respond(trip)
            }
        }
    }.start(wait = true)
}
