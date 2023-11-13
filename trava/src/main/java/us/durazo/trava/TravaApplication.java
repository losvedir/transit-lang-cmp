package us.durazo.trava;

import java.util.ArrayList;
import java.util.List;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import jakarta.annotation.PostConstruct;

@SpringBootApplication
@RestController
public class TravaApplication {
	private State state;

	public static void main(String[] args) {
		SpringApplication.run(TravaApplication.class, args);
	}

	@PostConstruct
	public void initState() {
		state = new State();
	}

	@GetMapping("/schedules/{routeId}")
	public List<TripResponse> getSchedules(@PathVariable String routeId) {
		List<TripResponse> tripResponses = new ArrayList<>();

		var trips = state.tripsForRoute(routeId);

		if (trips != null) {
			for (Trip trip : trips) {
				List<StopTimeResponse> stopTimeResponses = new ArrayList<>();
				var stopTimes = state.stopTimesForTrip(trip.tripId());
				if (stopTimes != null) {
					for (StopTime stopTime : stopTimes) {
						stopTimeResponses.add(new StopTimeResponse(stopTime.stopId(), stopTime.arrival(), stopTime.departure()));
					}
				}
				tripResponses.add(new TripResponse(trip.tripId(), trip.routeId(), trip.serviceId(), stopTimeResponses));
			}
		}

		return tripResponses;
	}
}
