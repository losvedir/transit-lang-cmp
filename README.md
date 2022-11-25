# An informal comparison of several programming languages

This repository implements the same simple backend API in a variety of
languages. It's just a personal project of mine to get a feel for the languages,
and shouldn't be taken _too_ seriously. So far I've built it in C#, Typescript
(Deno), Elixir, Go, Rust, and Scala. Star the repository and/or follow me on
Twitter (@losvedir) if you want updates on the project. I hope to eventually get
to Swift, Kotlin, ordinary Java, Nim, and Zig. And feel free to open an issue if
you want to suggest another language, or a PR if you want to implement one!
Please check out [the requirements](/REQUIREMENTS.md) if so.

All the apps read in the MBTA's GTFS data, which is the standard spec for
transit data - stuff like the routes, stops, and schedules for a system. The
apps look for files in an `MBTA_GTFS` folder, but could be easily updated to
work with any transit system's data. To get the MBTA data, the following
commands can be run in the repo's root directory:

```
> curl -o MBTA_GTFS.zip https://cdn.mbta.com/MBTA_GTFS.zip
> unzip -d MBTA_GTFS MBTA_GTFS.zip
```

The apps are all named some mashup of "Transit" and the programming language
name.

For now, the apps only read in the GTFS trips and stop_times data. They parse
the files, which are `.txt` but CSV, into an in-memory list of structs. I was
interested to see how long this takes, as it's a bunch of IO - there are roughly
75k trips and 2 million stop_times in the MBTA data. In a future iteration, I'd
also like to handle "services", which specify which trips run on which days.

The apps set up a simple webserver that responds to `/schedules/:route`
requests, and returns a JSON response of all the "schedules" (trips with
included stop_times) for that route. This involves a "join" through trips, and
for some routes serializes a bunch of data. (The most, I think, is for the Red
line at about 7MB of a response.) I represented it this way because even though
so far I've only implemented some of the functionality, I think it makes sense
conceptually to want to look up trips by route_id and/or service_id, and to look
up stop_times by trip_id and/or stop_id. So rather than just storing the data as
a hashmap, I figured it was better to store the data as a big list, and have
various handles into it.

## Data

Currently, I'm collecting two things. The first is how long it takes the apps to
load the GTFS `stop_times.txt` file into an in-memory structure (together with a
hashmap "index" to access it more efficiently). The second is the requests per
second that the webservers can field, as measured using the k6 tool.

I'm running this on my personal laptop, from Apple -> About this Mac:

```
MacBook Pro (14-inch, 2021)
Chip: Apple M1 Pro
Memory: 32 GB

MacOS: Ventura 13.0
```

The process (such as it is) for benchmarking:

- Close all apps other than Terminal and Activity Monitor
- Use ActivityMonitor to close unnecessary background processes (Chrome updater,
  etc)
- Wait to see >99% "Idle"
- Start the app server (instructions in each app's README)
- Run all the tests

### Loading stop_times.txt

This is the time it takes for the app to load the stop_times.txt file, which is
roughly 100MB and 2M records and parse it into a big vector/list/array of a
structured `StopTime` structs, together with an "index" on trips, which is a map
from the trip ID to a list of indices into the big stop time list.

| Language | Time (ms) |
| -------- | --------- |
| C#       | 732       |
| Deno     | 3,033     |
| Elixir   | 3,270     |
| Go       | 848       |
| Rust     | 467       |
| Scala    | 858       |
| SQLite   | ~ 4,000   |

### Webserver performance

This is tested using the [k6](https://github.com/grafana/k6) tool, which I
installed via homebrew. There is a `loadTest.js` script in the root of the repo,
and I ran the test as follows:

```
k6 run -u 50 --duration 30s loadTest.js
```

That sets up 50 "virtual users" concurrently accessing the server, and the test
itself has them sequentially issuing requests, of the schedules for roughly a
hundred routes, some pretty hefty, some pretty small, in random order.

I'm not trying for a perfectly uniform test environment, but I close most of my
usual apps and just run it on my laptop by itself. You shouldn't _really_ test
on the same machine, but the requests are decently beefy overall that I figured
the load from the test harness wouldn't disrupt the response data too badly.
Here I report the requests/sec that k6 spits out, and also an eyeball at the
highest RAM and CPU usage I see in ActivityMonitor just out of curiosity.

#### JSON heavy

These use the `loadTest.js` file which includes about a hundred of the MBTA
routes, many of which have JSON schedule data in the megabytes. Consequently,
the performance here is largely a reflection of how fast JSON can be serialized.
All these were with 50 concurrent virtual users.

| Language | Requests/sec | Max CPU (%) | Max RAM (MB) |
| -------- | ------------ | ----------- | ------------ |
| C#       | 1,543        | 638         | 1,600        |
| Deno     | 286          | 285         | 480          |
| Elixir   | 396          | 751         | 1,200        |
| Go       | 2,663        | 606         | 1,100        |
| Rust     | 2,289        | 640         | 564          |
| Scala    | 471          | 710         | 3,600        |

#### Smaller responses

These use the `loadTestSmallResponses.js` runner, and only use about a dozen
routes whose schedule data is in the ~50KB to ~200KB range, so the requests are
a lot higher, and less dominated by JSON encoding. Since the responses are
smaller and more requests can be handled, I also tried it with different number
of concurrent "virtual users".

Requests per second, by language and concurrent virtual user count (higher is
better).

| Language | 1 VU  | 10 VU  | 50 VU  | 100 VU |
| -------- | ----- | ------ | ------ | ------ |
| C#       | 2,280 | 11,796 | 13,261 | 13,095 |
| Deno     | 2,396 | 3,525  | 3,602  | 3,624  |
| Elixir   | 624   | 3,153  | 3,814  | 4,045  |
| Go       | 2,269 | 10,367 | 10,855 | 10,945 |
| Rust     | 2,924 | 17,474 | 18,934 | 18,764 |
| Scala    | 780   | 4,564  | 4,712  | 4,734  |

Response times in milliseconds: median / p95 / max, by language and concurrent
virtual user count (lower is better):

| Language | 1 VU         | 10 VU       | 50 VU         | 100 VU        |
| -------- | ------------ | ----------- | ------------- | ------------- |
| C#       | .3 / 1 / 13  | .6 / 2 / 28 | 3 / 10 / 118  | 6 / 20 / 143  |
| Deno     | .3 / 1 / 199 | 3 / 4 / 204 | 14 / 18 / 217 | 27 / 35 / 236 |
| Elixir   | 1 / 4 / 7    | 3 / 8 / 19  | 12 / 24 / 65  | 22 / 47 / 140 |
| Go       | .3 / 1 / 13  | .6 / 3 / 43 | 3 / 16 / 79   | 6 / 29 / 129  |
| Rust     | .2 / .7 / 2  | .4 / 1 / 11 | 2 / 5 / 31    | 5 / 10 / 45   |
| Scala    | 1 / 3 / 6    | 2 / 5 / 125 | 4 / 58 / 395  | 11 / 86 / 583 |

### Searching the data

This metric I collected from a previous commit, and involved simply counting the
number of StopTimes for the Red line. I removed this code in favor of the
webserver approach, but am keeping the stats here for posterity.

| Language | Time (ms) |
| -------- | --------- |
| C#       | 1.0       |
| Deno     | 1.4       |
| Elixir   | 3.2       |
| Go       | 0.4       |
| Rust     | 0.7       |
| Scala    | 2.5       |
| SQLite   | 13        |

## Thoughts

Here are some scattered thoughts while I went about writing this.

### C#

Where to begin! First, I went into this very confused at just a jargon level of
what all the different pieces of the Microsoft ecosystem are. C# is the language
and it runs on the ".NET CLR". The build/run tool is `dotnet` so that's kind of
the main term, but I also saw "CLR" thrown around. I ended up working with ".NET
6.0", which is what all the guides and docs called it, and which was cross
platform. I didn't see ".NET Core" anywhere like I was expecting, which I
believe is what _used_ to be the explicitly cross-platform piece? Amusingly, I
spent a fair bit of time trying to look up the standard ".NET web framework"
before eventually finally realizing that that's what ASP.NET is. So that was
useful to connect for me, since I've seen "ASP" a lot but had had no idea how it
fit into the picture.

I wasn't entirely sure I'd even be able to complete this project. I wasn't sure
how truly cross platform .NET was, in reality, though development went off
without a hitch! I'm going to say, yes, at least for my simple use case of using
the standard library plus ASP.NET, it's truly cross platform. I didn't try
bringing in any 3rd party libraries, and I imagine there could be some
incompatibilities there. In the future I'd like to explore F#, which is a
language more inline with my sensibilities, but I wanted to try more "vanilla
.NET" first. The developer experience in VSCode was great, the language server
worked well, and the code formatter worked (though I despise the convention of
opening curly braces on the next line).

As for the language, C# is... all right, I guess. It kind of reminds me of Dart;
it works fine, the tooling is good, it's verbose and very object oriented, but
it doesn't really spark joy. The "billion dollar mistake" is important to me,
and while C# has non-nullability sugar in its typesystem (i.e. with `?` after a
number of types), the type system wasn't as rigorous as I was maybe hoping. At
one point I had a bug because I did a `stopWatch.Elapsed / 1000` by accident
instead of `stopWatch.ElapsedTicks / 1000`. The former is a `TimeSpan` struct
instead of a `long` like `ElapsedTicks`, so intuitively it feels like I
shouldn't be able to divide it, though it did a best effort and did _something_
to it, though I'm not quite sure what.

ASP.NET has a lot of conventions and magic. I don't personally love all that
magic but if you're experienced with it, I could see how it would make designing
web apps pretty quick.

But, wow, I was incredibly surprised and impressed with the performance! It was
comparable to my unoptimized Rust (i.e.: treating Rust like a high level
language with lots of clones)!

All in all, I was pleasantly surprised and pretty impressed with dotnet and C#.

### Deno

Deno is pretty neat. I really want it to succeed. I really like TypeScript, and
Deno almost gives me what I want: pretending TypeScript is a full-fledged
language, with a standard library, that I can build non-frontend apps with.
Let's just sweep all that JS-heritage and V8 stuff under the rug...

I wish the standard library weren't at URLs like all the other packages. It
would be great if the `deno` tool you downloaded also included the standard
library, and you could just reference it without any network stuff. The
documentation is also pretty cryptic (and I think autogenerated?).

The package management stuff I haven't quite wrapped my head around. Obviously,
you shouldn't be downloading stuff willy-nilly, but I think with some
combination of the conventional deps.ts, import_map, specifying a lock file, the
vendor command, --no-remote, etc, I feel like I have all the pieces to kind of
build up a reasonable approach, but I don't quite understand it all just yet.

Personally, the `--allow-read`, `--allow-net`, etc stuff feels a little gimmicky
to me. I don't think other languages really have that, and I'm not sure what the
threat model is here. I control the backend code, and if I'm worried about my
code doing unexpected things like that I have larger issues. I just run with
`-A` all the time.

The performance was great when looking at a single virtual user, but sort of
topped out there. I don't know if it just can't handle async and multiple cores
very well, or if I was doing something wrong.

### Elixir

Elixir is my primary language, so I threw this one in to compare its performance
to see what I could be missing. I like Elixir the language and all its nice OTP
goodies, but it's known to be a little slow, so I was wondering how much
performance I'm leaving on the table.

Normally, my first thought for some state in Elixir would be an Agent or custom
GenServer, but that would funnel all requests to the one data source, which
would respond sequentially, and I thought under load that could be a bottleneck.
So I opted to put the data in ETS, with read concurrency enabled.

ETS stores data as a set (in this case) of Erlang tuples, and wanting to follow
the conventions of the other apps, I decided to add an extra "primary key"
integer to each tuple, for the purpose of the "indexes". The other languages
allow you to simply index into the underlying list, but that's not really
possible with the way ETS stores data.

This approach works fine for GTFS static data which is loaded on app start-up,
but I'm not entirely sure yet how I will handle when I need to _update_ data, if
I extend the apps to poll the real-time vehicle positions and predictions data.
In that scenario, I've had issues before with how to handle locking and atomic
updates to ETS data. Most likely it would be something like create a whole new
ETS table in the background and then swap it out for this one after it's ready.

Initially I used Phoenix here, since in my experience it's the go-to way to
quickly spin up a web app in Elixir-land, but Jose Valim (!!!) issued a PR to
switch to a simple Plug, to make the code more comparable to the other
languages, for someone perusing what a simple implementation in each might look
like. The actual benchmarks were roughly comparable, with only a very slight
edge to Plug in one of the benchmarks, which impressed me with how lightweight
Phoenix is for all you get!

The final performance results were unfortunately low, an order of magnitude
worse than Rust, but faster than Deno. On the other hand the ratio of median
response time to max response time was lowest with Elixir than any other
language, which can have its own benefits.

### Go

I was super happy to get the work done so far using just the standard library.
And the performance was solid! In the JSON-heavy benchmark it actually is the
fastest of all the languages, though in the lighter-response benchmark it's more
where I expected: fast, but not quite at rust levels.

That said, contrary to my expectations, I found the documentation not great.
While the language reference and tour was pretty good and useful (I kept
referring to the tour), the library documentation on
[pkg.go.dev](https://pkg.go.dev/) was fairly... bad.

It took me longer than I'd like to admit to figure out how to get a dang
`io.Reader`, which is what the CSV parsing package takes. I had hoped
[searching their docs](https://pkg.go.dev/search?q=io.reader) for `io.Reader`
would yield a package or function that at a glance would (1) read from the
filesystem and (2) implement the `io.Reader` interface, but the top result was
simply the definition of the interface, and the rest of the results were random
GitHub repos. And clicking through to the `io.Reader` definition didn't provide
links to anything that implements it. Eventually I gave up and went the other
direction, trying to figure out how to open and read files. I finally found
`os.Open()` (though it was my third try after poking around in `io` and
`io.fs`). I saw it returns a `File`, which then sent me on a bit of a goose
change on how to turn _it_ into an `io.Reader` before realizing that although
it's not mentioned in the docs, the type _does_ implement `Read` and so it _is_
already an `io.Reader`! It was all sort of magical to me, and kind of odd. Now I
realize that in theory I could have searched pkg.go.dev for "Read" to find types
that implement it, and hence satisfy `io.Reader` and would get me to `File` and
`os.Open()` but of course that doesn't work because the search function seems to
be hot garbage.

All that said, actually programming in Go was pretty nice. VSCode support was
solid and the build/run cycle was fast! The final result ended up being pretty
quick, too. It doesn't have the type richness I appreciate, but I didn't mind it
overall.

I started out looking for a "web framework" since that was my expectation of how
this works, but it seemed like there was a reasonable consensus that using
simply the standard library was a good place to start. That was nice, and helped
me avoid the analysis paralysis and reviewing benchmarks and HN and reddit, etc,
to decide _which_ framework to use.

### Rust

This one shocked me in a good way! I was expecting a lot more low level
fiddlyness, and was prepared to simply allocate and clone and do all the tricks
I've read about to not worry about eking out the most performance possible.
After all, I'm comparing against higher level interpreted or GC languages, and
am interested in Rust more for its type system than needing to program at a
system level.

I've had some experience playing with Rust in the past, so it wasn't brand new
to me, but it has been some time so I was expecting to be a lot more, uh...
rusty. All that said, with my initial approach, I just did a lot of String
cloning and got performance comparable to the best of the other languages
(dotnet or Go, depending on the benchmark). But then after a bit of help from
reddit, I removed some unnecessary String allocations, using `&str` and dreaded
(to me) lifetime markers, so that the response structs just referenced the
strings allocated in the actual data, and the performance jumped dramatically,
to be far and away the most performant language.

Also, I don't know how much of this is because Rust is special or because
BurntSushi is a national treasure and his CSV library is impeccably constructed
and documented.

I also was impressed and amused that I got compiler warnings that my Struct had
unnecessary fields (I haven't used the Trips' service_ids or the StopTimes'
arrival and departure times yet), which wasn't raised for any of the other
languages.

For the web server piece, I spent some time trying to decide which framework to
use. When I last looked at Rust, `rocket` was all the rage, but it seems to have
fallen off the radar almost completely these days! That was mildly concerning.
It seems like `actix` has taken over as nearly the "default", except there's a
new-ish one called `axum` that's quite popular. Being a part of the official
tokio project, and guessing that tokio has staying power, I went with `axum`.

It was a little tricky to get working... I felt like I was playing type tetris a
bit to get my app to compile, and was trying to mindlessly copy documentation
without fully understanding it. I've never quite understood the `#[...]` syntax,
and so annotating my `main` function with `#[tokio::main]` is still black magic
to me. I also got tripped up for a while before realizing that I needed to put
`futures` as a dependency in my `Cargo.toml`. That wasn't in the axum docs but I
found it in their examples, though it was quite a wild guess that _that_ was the
thing that allowed the example to compile when mine wasn't. I drew on some
latent knowledge I had buried deep down in there that `futures` was what the
`async` ecosystem was built on, and it was a crate rather than part of the
language, but I had thought it was just a temporary thing for experimentation by
the rust folks back in the day.

I also ran into some issues trying to get my shared state to work. My handler
was failing to typecheck and the compiler error was not helpful. The axum docs
actually mention this is a problem and that there's an `axum-macros` crate that
can help, though. Some of this was my lack of understanding exactly how `Arc`
works and how to safely have shared state across async requests. In the end, I
appreciate that the flexibility is there; right now I just have an `Arc` so that
all my handlers can read the data I prepare up front, but I could see how I
could wrap it in an `RwLock`, for example, to also allow safe updates in the
future. In general, I'm not sure how I feel about Axum's magical
handler/extractor setup, as I still don't really know how it works.

### Scala

Of all the languages I played with here, Scala is the only one I disliked.

Part of the reason was timing: it seems an ecosystem in flux at the moment. It
didn't work with my JDK 19 out of the box, so I had to downgrade to JDK 17 for
it. I sort of blindly followed the scala-lang.org site and went through the
getting started guide, for Scala 3, and then building the first half of my app
in Scala 3, before realizing that Play (the only Scala webframework I'd heard
of) and Scalatra (the other web framework mentioned in the Getting Started
"ecosystem" section of the guide) don't work on Scala 3 yet. I briefly tried
updating my code to Scala 2 but I wasn't super sure what the differences were,
and I didn't really want to learn Scala 2 if everything is moving to Scala 3
(eventually) anyway. Beyond that I got mixed messages in whether to use `sbt`
and `mill` as a build tool.

Beyond that, there seems to be a schism in the community between people who love
super sophisticated types (think Haskell style Applicative Functors or whatever)
and people who want a nicer Java (these days those people might be moving to
Kotlin).

In trying to find a Scala 3 compatible web framework, I saw a lot of people
saying `http4s` is the new standard, so I tried that one first. But after
generating the skeleton for the app, and trying to add my own routes I gave up.
The "router" part is unwieldy and complicated, though I think I was able to
cargo-cult a route of my own. Here's the given example on how to match against
`/hello/:name`:

```scala
def helloWorldRoutes[F[_]: Sync](H: HelloWorld[F]): HttpRoutes[F] =
  val dsl = new Http4sDsl[F]{}
  import dsl._
  HttpRoutes.of[F] {
    case GET -> Root / "hello" / name =>
      for {
        greeting <- H.hello(HelloWorld.Name(name))
        resp <- Ok(greeting)
      } yield resp
  }
```

But then when it comes to implementing the code that actually returns data
there, I got totally flummoxed. Here's the corresponding "HelloWorld" code for
the above route:

```scala
import cats.Applicative
import cats.implicits._
import io.circe.{Encoder, Json}
import org.http4s.EntityEncoder
import org.http4s.circe._

trait HelloWorld[F[_]]:
  def hello(n: HelloWorld.Name): F[HelloWorld.Greeting]

object HelloWorld:
  def apply[F[_]](using ev: HelloWorld[F]): HelloWorld[F] = ev

  final case class Name(name: String) extends AnyVal
  /**
    * More generally you will want to decouple your edge representations from
    * your internal data structures, however this shows how you can
    * create encoders for your data.
    **/
  final case class Greeting(greeting: String) extends AnyVal
  object Greeting:
    given Encoder[Greeting] = new Encoder[Greeting]:
      final def apply(a: Greeting): Json = Json.obj(
        ("message", Json.fromString(a.greeting)),
      )

    given [F[_]]: EntityEncoder[F, Greeting] =
      jsonEncoderOf[F, Greeting]

  def impl[F[_]: Applicative]: HelloWorld[F] = new HelloWorld[F]:
    def hello(n: HelloWorld.Name): F[HelloWorld.Greeting] =
        Greeting("Hello, " + n.name).pure[F]
```

That's a _lot_ of both syntax and semantics to grok. `trait` is an interface,
`object` is a singleton class, `case class` is kind of a data record. I don't
know what `given` or `using` are. I recognize `pure` as related to `Applicative`
but that's a whole complicated library/type concern distinct from
Scala-the-language. I don't really know why the `def impl` does a
`new HelloWorld` with a nested `def hello`.

In the end, I moved on to trying the framework Cask, which

> aims to bring simplicity, flexibility and ease-of-use to Scala webservers,
> avoiding cryptic DSLs or complicated asynchrony

And in the end, I got something that worked! So thanks author of Cask. Cask also
used `mill` rather than `sbt`. The latter seems more "official", or at least is
the tool recommended on scala-lang.org, but oh BOY is it slow! `mill` was nicer
for me to work with.

The performance was not super great, and it used the most memory by far. I don't
know if this is because Cask is not performance-focused, but then I couldn't get
anything else to work... I liked Scala 3 well enough before dealing with the
ecosystem, but I think in the future I'm going to avoid Scala until it finishes
its 2 to 3 transition, and only if the non-typenerds win.

### SQLite

Not really an apples-to-apples comparison but I was curious about the order of
magnitude performance characteristics of SQLite here.

For importing `stop_times` I counted (yes, so take that time with a grain of
salt) while running:

```
sqlite> .mode csv
sqlite> .import MBTA_GTFS/stop_times.txt stop_times
```

And for scanning the data for the number of Red line schedules, I did:

```
sqlite> create index stop_times_by_trip on stop_times(trip_id);
sqlite> create index trips_by_route on trips(route_id);
sqlite> .timer on
sqlite> select count(*) from stop_times where trip_id in (select trip_id from trips where route_id = "Red");
```

Can't beat the convenience! It's an order of magnitude slower than the apps
which keep everything in memory, but of course the tradeoff then is it uses much
less memory! And while a given read is slow(-ish), I understand that a lot of it
is waiting on the filesystem, and that concurrent reads should allow plenty of
throughput.

### Swift

Notes from in-progress work on Swift.

- Had to download many-GB Xcode, which had a host of issues (had to login)
- did `swift init` and then `swift run` and it crashed. Found a discussion
  online where `sudo xcode-select --reset` was recommended and that got the
  HelloWorld to run.
- No code formatter?
- Couldn't figure out how to read the relative MBTA_GTFS folder from my project
  in xcode, but running `swift run` from the directory worked. (Though I had to
  `swift package init` which xcode didn't need.)
