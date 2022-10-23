# Improvements on C# sample

There are ways to speed this up even more, for example in copying results in SchedulesForRoute. It would also be easy to throw in a Parallel.For or Parallel.ForEach.

``` ini

BenchmarkDotNet=v0.13.2, OS=Windows 11 (10.0.22000.1098/21H2)
AMD Ryzen 9 5950X, 1 CPU, 32 logical and 16 physical cores
.NET SDK=7.0.100-rc.1.22431.12
  [Host] : .NET 7.0.0 (7.0.22.42610), X64 RyuJIT AVX2  [AttachedDebugger]
  Net70  : .NET 7.0.0 (7.0.22.42610), X64 RyuJIT AVX2

Jit=RyuJit  Platform=X64  

```

## LoadTrips

| Method                   | Job   | Runtime  |     Mean |    Error |   StdDev |   StdErr |   Median |      Min |       Q1 |       Q3 |      Max |  Op/s | Ratio | RatioSD | Rank | Baseline |      Gen0 |      Gen1 |      Gen2 |  Allocated | Alloc Ratio |
| ------------------------ | ----- | -------- | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | ----: | ----: | ------: | ---: | -------- | --------: | --------: | --------: | ---------: | ----------: |
| _01_Original             | Net70 | .NET 7.0 | 76.14 ms | 1.491 ms | 1.939 ms | 0.396 ms | 76.13 ms | 72.95 ms | 75.03 ms | 77.77 ms | 79.44 ms | 13.13 |  1.00 |    0.00 |    4 | Yes      | 4285.7143 | 3142.8571 | 1285.7143 | 63080632 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 60.94 ms | 1.144 ms | 1.641 ms | 0.310 ms | 60.71 ms | 58.24 ms | 59.92 ms | 61.85 ms | 64.46 ms | 16.41 |  0.80 |    0.03 |    3 | No       | 3444.4444 | 3333.3333 | 1111.1111 | 47521912 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 48.57 ms | 0.961 ms | 1.551 ms | 0.266 ms | 48.27 ms | 45.85 ms | 47.44 ms | 49.48 ms | 51.84 ms | 20.59 |  0.64 |    0.02 |    2 | No       | 3272.7273 | 2454.5455 |  909.0909 | 46362793 B |        0.73 |
| _04_CsvReader            | Net70 | .NET 7.0 | 18.16 ms | 0.363 ms | 1.042 ms | 0.107 ms | 17.87 ms | 16.13 ms | 17.45 ms | 18.89 ms | 20.88 ms | 55.06 |  0.24 |    0.02 |    1 | No       | 1593.7500 | 1562.5000 |  968.7500 | 17435261 B |        0.28 |

## LoadStop

| Method                   | Job   | Runtime  |       Mean |    Error |   StdDev |  StdErr |        Min |         Q1 |     Median |         Q3 |        Max |   Op/s | Ratio | RatioSD | Rank | Baseline |       Gen0 |       Gen1 |      Gen2 |    Allocated | Alloc Ratio |
| ------------------------ | ----- | -------- | ---------: | -------: | -------: | ------: | ---------: | ---------: | ---------: | ---------: | ---------: | -----: | ----: | ------: | ---: | -------- | ---------: | ---------: | --------: | -----------: | ----------: |
| _01_Original             | Net70 | .NET 7.0 | 1,413.4 ms | 20.09 ms | 18.79 ms | 4.85 ms | 1,385.6 ms | 1,396.9 ms | 1,416.0 ms | 1,426.8 ms | 1,443.5 ms | 0.7075 |  1.00 |    0.00 |    4 | Yes      | 62000.0000 | 61000.0000 | 5000.0000 | 1157427512 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 1,225.3 ms | 22.11 ms | 19.60 ms | 5.24 ms | 1,180.9 ms | 1,219.1 ms | 1,223.7 ms | 1,237.7 ms | 1,254.5 ms | 0.8161 |  0.87 |    0.01 |    3 | No       | 50000.0000 | 49000.0000 | 6000.0000 |  869224040 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 1,121.1 ms | 20.49 ms | 19.17 ms | 4.95 ms | 1,083.6 ms | 1,108.5 ms | 1,119.6 ms | 1,131.8 ms | 1,158.7 ms | 0.8920 |  0.79 |    0.02 |    2 | No       | 51000.0000 | 50000.0000 | 6000.0000 |  899098456 B |        0.78 |
| _04_CsvReader            | Net70 | .NET 7.0 |   684.3 ms | 12.99 ms | 12.15 ms | 3.14 ms |   657.5 ms |   678.1 ms |   685.1 ms |   689.7 ms |   706.9 ms | 1.4612 |  0.48 |    0.01 |    1 | No       | 24000.0000 | 23000.0000 | 6000.0000 |  450663344 B |        0.39 |

## SchedulesForRoute

| Method        | Job   | Runtime  |     Mean |    Error |   StdDev |   StdErr |      Min |       Q1 |   Median |       Q3 |      Max |  Op/s | Ratio | RatioSD | Rank |      Gen0 |      Gen1 |  Allocated | Alloc Ratio |
| ------------- | ----- | -------- | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | ----: | ----: | ------: | ---: | --------: | --------: | ---------: | ----------: |
| _01_Original  | Net70 | .NET 7.0 | 34.95 ms | 0.504 ms | 0.471 ms | 0.122 ms | 34.40 ms | 34.60 ms | 34.74 ms | 35.34 ms | 35.96 ms | 28.61 |  1.00 |    0.00 |    2 | 5000.0000 | 2200.0000 | 85135718 B |        1.00 |
| _11_StructFix | Net70 | .NET 7.0 | 22.62 ms | 0.448 ms | 0.461 ms | 0.112 ms | 21.77 ms | 22.34 ms | 22.77 ms | 22.96 ms | 23.44 ms | 44.21 |  0.65 |    0.02 |    1 | 2437.5000 | 1000.0000 | 40923748 B |        0.48 |
