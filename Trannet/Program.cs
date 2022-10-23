using Trannet.Services;

// Load on startup, not on first request (would skew any benchmark).
_ = GTFSService.SchedulesForRoute("");

// Set up web api
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Map URL directly to method with same signature
app.MapGet("/Schedules/{routeId}", GTFSService.SchedulesForRoute);
// Same as this: app.MapGet("/Schedules/{routeId}", (string routeId) => GTFSService.SchedulesForRoute(routeId));

app.Run();
