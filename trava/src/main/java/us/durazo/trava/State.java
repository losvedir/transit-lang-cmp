package us.durazo.trava;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.nio.file.FileSystems;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class State {
  public ArrayList<Trip> allTrips;
  public Map<String, List<Integer>> tripsIxByRoute;
  public ArrayList<StopTime> allStopTimes;
  public Map<String, List<Integer>> stopTimesIxByTrip;

  public State() {
    allTrips = new ArrayList<>();
    tripsIxByRoute = new HashMap<>();

    allStopTimes = new ArrayList<>();
    stopTimesIxByTrip = new HashMap<>();

    loadTrips();
    loadStopTimes();
  }

  public List<Trip> tripsForRoute(String routeId) {
    List<Trip> trips = new ArrayList<>();

    var ixs = tripsIxByRoute.get(routeId);
    if (ixs != null) {
      for (Integer ix : ixs) {
        trips.add(allTrips.get(ix));
      }
    }

    return trips;
  }

  public List<StopTime> stopTimesForTrip(String tripId) {
    List<StopTime> stopTimes = new ArrayList<>();

    var ixs = stopTimesIxByTrip.get(tripId);
    if (ixs != null) {
      for (Integer ix : ixs) {
        stopTimes.add(allStopTimes.get(ix));
      }
    }

    return stopTimes;
  }

  private void loadTrips() {
    try {
      long start = System.currentTimeMillis();
      Path path = Paths.get("../MBTA_GTFS/trips.txt");
      List<String> lines = Files.readAllLines(path);

      String[] header = lines.get(0).split(",");
      assert "route_id".equals(header[0]);
      assert "service_id".equals(header[1]);
      assert "trip_id".equals(header[2]);

      int i = 0;
      for (String line : lines.subList(1, lines.size())) {
        String[] cells = line.split(",");
        String routeID = cells[0];
        allTrips.add(new Trip(cells[2], routeID, cells[1]));

        tripsIxByRoute.computeIfAbsent(routeID, k -> new ArrayList<>()).add(i);

        i++;
      }

      long stop = System.currentTimeMillis();
      System.out.println("Loading trips took: " + (stop - start) + " ms");
    } catch (IOException e) {
      e.printStackTrace();
    }
  }

  private void loadStopTimes() {
    try {
      long start = System.currentTimeMillis();
      Path path = Paths.get("../MBTA_GTFS/stop_times.txt");
      List<String> lines = Files.readAllLines(path);

      String[] header = lines.get(0).split(",");
      assert "trip_id".equals(header[0]);
      assert "arrival_time".equals(header[1]);
      assert "departure_time".equals(header[2]);
      assert "stop_id".equals(header[3]);

      int i = 0;
      for (String line : lines.subList(1, lines.size())) {
        String[] cells = line.split(",");
        String tripId = cells[0];
        allStopTimes.add(new StopTime(tripId, cells[3], cells[1], cells[2]));

        stopTimesIxByTrip.computeIfAbsent(tripId, k -> new ArrayList<>()).add(i);

        i++;
      }

      long stop = System.currentTimeMillis();
      System.out.println("Loading stop times took: " + (stop - start) + " ms");
    } catch (IOException e) {
      e.printStackTrace();
    }
  }
}
