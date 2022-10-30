using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml;

using BenchmarkDotNet.Attributes;
using BenchmarkDotNet.Columns;
using BenchmarkDotNet.Configs;
using BenchmarkDotNet.Diagnosers;
using BenchmarkDotNet.Environments;
using BenchmarkDotNet.Exporters;
using BenchmarkDotNet.Jobs;
using BenchmarkDotNet.Loggers;

using CommandLine;

namespace Trannet.Benchmark.Benchmarks;

static class JobExtensions
{

}

class BenchmarkConfig : ManualConfig
{
    public void AddRuntimes()
    {
        //AddDefaults(AddJob(Job.Default
        //    .WithPlatform(Platform.X64)
        //    .WithJit(Jit.RyuJit)
        //    .WithRuntime(CoreRuntime.Core60)
        //    .WithId("Net60")));

        AddDefaults(AddJob(Job.Default
            .WithPlatform(Platform.X64)
            .WithJit(Jit.RyuJit)
            .WithRuntime(CoreRuntime.Core70)
            .WithId("Net70")));


        //Column.Runtime, Column.Platform, Column.Baseline, Column.Rank, Column.Ratio, Column.Min, Column.Max, Column.Mean, Column.Median, Column.StdErr, Column.StdDev, Column.OperationPerSecond, Column.Rank, Column.Allocated, Column.AllocRatio, Column.AllocatedNativeMemory, Column.Gen0, Column.Gen1, Column.Gen2

    }
    public ManualConfig AddDefaults(ManualConfig config) => config
        .AddDiagnoser(MemoryDiagnoser.Default)
        .AddExporter(MarkdownExporter.GitHub, HtmlExporter.Default, AsciiDocExporter.Default, RPlotExporter.Default)
        .AddLogger(ConsoleLogger.Default)
        .AddColumn(JobCharacteristicColumn.AllColumns)
        .AddColumn(StatisticColumn.AllStatistics)
        .AddColumn(RankColumn.Arabic);

    public BenchmarkConfig()
    {
        AddRuntimes();
    }
}

[RankColumn, BaselineColumn]
[Config(typeof(BenchmarkConfig))]
public class LoadTripsBenchmarks
{
    [Benchmark(Baseline = true)]
    public void _01_Original() => TrannetVersions._01_Original.GTFS.LoadTrips();
    [Benchmark()] 
    public void _02_ListAndDictionaryUse() => TrannetVersions._02_ListAndDictionaryUse.GTFS.LoadTrips();
    [Benchmark()] 
    public void _03_CacheFriendly() => TrannetVersions._03_CacheFriendly.GTFS.LoadTrips();  
    [Benchmark()] 
    public void _04_CsvReader() => TrannetVersions._04_CsvReader.GTFS.LoadTrips();

}

[RankColumn, BaselineColumn]
[Config(typeof(BenchmarkConfig))]
public class LoadStopTimesBenchmarks
{
    [Benchmark(Baseline = true)]
    public void _01_Original() => TrannetVersions._01_Original.GTFS.LoadStopTimes();
    
    [Benchmark()]
    public void _02_ListAndDictionaryUse() => TrannetVersions._02_ListAndDictionaryUse.GTFS.LoadStopTimes();
    
    [Benchmark()]
    public void _03_CacheFriendly() => TrannetVersions._03_CacheFriendly.GTFS.LoadStopTimes(); 
    [Benchmark()]
    public void _04_CsvReader() => TrannetVersions._04_CsvReader.GTFS.LoadStopTimes();
    
}

[Config(typeof(BenchmarkConfig))]
public class SchedulesForRouteBenchmarks
{
    string[] routes = {
        "Mattapan",
        "Orange",
        "Green-B",
        "Green-C",
        "Green-D",
        "Green-E",
        "Blue",
        "741",
        "742",
        "743",
        "751",
        "749",
        "746",
        "CR-Fairmount",
        "CR-Fitchburg",
        "CR-Worcester",
        "CR-Franklin",
        "CR-Greenbush",
        "CR-Haverhill",
        "CR-Kingston",
        "CR-Lowell",
        "CR-Middleborough",
        "CR-Needham",
        "CR-Newburyport",
        "CR-Providence",
        "CR-Foxboro",
        "Boat-F4",
        "Boat-F1",
        "Boat-EastBoston",
        "747",
        "708",
        "1",
        "4",
        "7",
        "8",
        "9",
        "10",
        "11",
        "14",
        "15",
        "16",
        "17",
        "18",
        "19",
        "21",
        "22",
        "23",
        "24",
        "26",
        "28",
        "29",
        "30",
        "31",
        "32",
        "33",
        "34",
        "34E",
        "35",
        "36",
        "37",
        "38",
        "39",
        "40",
        "41",
        "42",
        "43",
        "44",
        "45",
        "47",
        "50",
        "51",
        "52",
        "55",
        "57",
        "59",
        "60",
        "61",
        "62",
        "627",
        "64",
        "65",
        "66",
        "67",
        "68",
        "69",
        "70",
        "71",
        "72",
        "73",
        "74",
        "75",
        "76",
        "77",
        "78",
        "79",
        "80",
        "83",
        "84",
        "85",
};


    [GlobalSetup]
    public void GlobalSetup()
    {
        // We don't want initial load to be part of test
        _ = TrannetVersions._01_Original.GTFSService.SchedulesForRoute("0");
        _ = TrannetVersions._02_ListAndDictionaryUse.GTFSService.SchedulesForRoute("0");
        _ = TrannetVersions._03_CacheFriendly.GTFSService.SchedulesForRoute("0");

        // Multiple datasets with some churn, lets clean up before test
        GC.Collect(GC.MaxGeneration, GCCollectionMode.Forced, blocking: true, compacting: true);

        // Shuffle string array
        var rnd = new Random();
        routes = routes.OrderBy(x => rnd.Next()).ToArray();
    }

    [Benchmark(Baseline = true)]
    public void _01_Original()
    {
        for (int i = 0; i < routes.Length; i++)
            _ = TrannetVersions._01_Original.GTFSService.SchedulesForRoute(routes[i]);
    }

    [Benchmark()]
    public void _11_StructFix()
    {
        for (int i = 0; i < routes.Length; i++)
            _ = TrannetVersions._11_StructFix.GTFSService.SchedulesForRoute(routes[i]);
    }

}
