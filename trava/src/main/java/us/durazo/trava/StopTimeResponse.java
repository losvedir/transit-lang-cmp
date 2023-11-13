package us.durazo.trava;

public record StopTimeResponse(
    String stopId,
    String arrival,
    String departure) {
}
