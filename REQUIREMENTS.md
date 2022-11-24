# Transit App Requirements

Here are some initial thoughts about what the transit apps should do and the
data model they should be using.

The app loads [GTFS static](https://developers.google.com/transit/gtfs) data.
This data is infrequently changed. The MBTA publishes a new version of the data
at most 2-3 times in a day.

GTFS static is comprised of many files, but for our purposes we're working with
two: trips, and stop_times.

A Trip represents a "journey" on a day, over several stops (_which_ day is
determined by the Service it's on). A given trip is naturally indexed by its ID,
but note these are strings and can get quite long (e.g.:
`53126110-KenLechSuspendDKenmoreRiversideLechUnionSuspendDNoGLX`)! There are
tens of thousands of trips.

Trips are often accessed via two possible secondary indexes: `route_id` ("what
are the trips on this route?") and `service_id` ("what are the trips running on
a given day?") or some combination of the two.

A StopTime represents a particular trip arriving/departing at a particular stop.
A given StopTime is naturally indexed by a three element tuple of its `trip_id`,
`stop_id`, and `stop_sequence` (since some trips can loop around and stop at the
same place twice). There are usually a couple million stop times.

StopTimes are often looked up with two possible secondary indexes as well:
`trip_id` ("what are all the stops this trip will be making?") and `stop_id`
("at a given stop, when will the different trips be getting here?")

The app as it exists really only uses one of each case: what are the StopTimes
for a set of trips, on a given route? However, that's just from being limited on
my time and some day I'd like to implement the other access patterns (e.g.: on a
given day at a given stop, what are the upcoming arrival times?)

## The data representation I've chosen

All of the apps I implemented follow the same general pattern, which tries to
efficiently handle the current app's use case as well as the other use cases
mentioned above.

I store both the `trips` and `stop_times` as arrays, together with hashmaps
whose keys are array indexes.

The reason I chose this is so that the app could easily support looking up the
underlying data in different ways. While I've only implemented "trips by route",
it would be trivial to extend it to "trips by service". Similarly, I've only
done "stop times by trip", but it is easy to extend to "stop times by stop".

The underlying trips and stop times could be hashmaps, rather than arrays, but
note that the keys are `trip_id` (which can be very long!) and
`{trip_id, stop_id, stop_sequence}` (which would be even longer!), and so the
secondary indexes, which would have to point to various trips or stop_times,
would grow in memory quite a bit compared to the current approach of simple
integers.

## Serialization

Lastly, I wanted to separate the storage representation (which matches more
closely the GTFS files) from the JSON representation. There should be a
conversion step, and the data shouldn't be parsed directly into how a given JSON
response might look. (Different views of the data might have different keys or
relationships.)
