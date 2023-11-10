package us.durazo.trava;

public record StopTime(
    String tripId,
    String stopId,
    String arrival,
    String departure) {
}
