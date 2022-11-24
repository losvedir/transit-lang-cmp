require "http/server"
require "csv"
require "json"

module Tryst
  VERSION = "0.1.0"

  class StopTime
    include JSON::Serializable
    @[JSON::Field(ignore_serialize: true)]
    getter trip_id : String
    getter stop_id : String, arrival_time : String, departure_time : String

    def initialize(@trip_id, @arrival_time, @departure_time, @stop_id)
    end

    def self.load_schedules_from_file(path)
      File.open(path) do |file|
        stop_times = CSV.new(file)
        list = Array(StopTime).new
        hash = Hash(String, Array(Int32)).new do |hash, key|
          hash[key] = Array(Int32).new
        end
        if !stop_times.next || {"trip_id", "arrival_time", "departure_time", "stop_id"} != stop_times.values_at(0,1,2,3)
          p("stop_times.txt not in expected format")
          pp(stop_times.row())
          exit(1)
        end
        while(stop_times.next)
          stop = StopTime.new(*stop_times.values_at(0,1,2,3))
          hash[stop.trip_id] << list.size
          list << stop
        end
        {list, hash}
      end
    end
  end

  class Trip
    getter trip_id : String, route_id : String, service_id : String
    @stop_times_idx : Hash(String, Array(Int32))
    @stop_times : Array(StopTime)

    def initialize(@stop_times, @stop_times_idx, @trip_id, @route_id, @service_id)
    end

    def schedules
      @stop_times_idx[trip_id].map do |idx|
        @stop_times[idx]
      end
    end

    def to_json(j : JSON::Builder)
      j.object do
        j.field "trip_id", trip_id
        j.field "route_id", route_id
        j.field "service_id", service_id
        j.field "schedules", schedules
        #  do
        #   j.array do
        #     schedules.each do |stop_time|
        #       j.start_scalar
        #       stop_time.to_json(io)
        #       j.end_scalar
        #     end
        #   end
        # end
      end
    end

    def self.load_routes_from_file(path : String, stop_times : Array(StopTime), stop_times_idx : Hash(String, Array(Int32)))
      File.open(path) do |file|
        trips = CSV.new(file)
        list = Array(Trip).new
        hash = Hash(String, Array(Int32)).new do |hash, key|
          hash[key] = Array(Int32).new
        end
        if !trips.next || {"route_id", "service_id", "trip_id"} != trips.values_at(0,1,2)
          p("trips.txt not in expected format")
          pp(trips.row())
          exit(1)
        end
        while(trips.next)
          trip = Trip.new(stop_times, stop_times_idx, *trips.values_at(2,0,1))
          hash[trip.route_id] << list.size
          list << trip
        end
        {list, hash}
      end
    end
  end

  start = Time.local
  stop_times, stop_times_idx = StopTime.load_schedules_from_file("../MBTA_GTFS/stop_times.txt")
  puts "Loaded #{stop_times.size} stop times for #{stop_times_idx.size} trips in #{Time.local - start}"

  start = Time.local
  routes, routes_idx = Trip.load_routes_from_file("../MBTA_GTFS/trips.txt", stop_times, stop_times_idx)
  puts "Loaded #{routes.size} trips for #{routes_idx.size} routes in #{Time.local - start}"

  server = HTTP::Server.new do |context|
    request = context.request
    name = request.path.split('/').last
    route = routes_idx[name].map do |idx|
      routes[idx]
    end
    response = context.response
    response.content_type = "application/json"
    route.to_json(response.output)
  end

  address = server.bind_tcp 4000
  puts "Listening on http://#{address}"
  server.listen
end
