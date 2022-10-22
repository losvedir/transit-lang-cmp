using BenchmarkDotNet.Columns;
using BenchmarkDotNet.Configs;
using BenchmarkDotNet.Environments;
using BenchmarkDotNet.Exporters;
using BenchmarkDotNet.Jobs;
using BenchmarkDotNet.Loggers;
using BenchmarkDotNet.Running;
using Microsoft.Diagnostics.Tracing.Analysis;
using Trannet.Benchmark.Benchmarks;

var summary1 = BenchmarkRunner.Run<LoadTripsBenchmarks>();
var summary2 = BenchmarkRunner.Run<LoadStopTimesBenchmarks>();
var summary3 = BenchmarkRunner.Run<SchedulesForRouteBenchmarks>();


