# Improvements on C# sample

``` ini

BenchmarkDotNet=v0.13.2, OS=Windows 11 (10.0.22000.1098/21H2)
AMD Ryzen 9 5950X, 1 CPU, 32 logical and 16 physical cores
.NET SDK=7.0.100-rc.1.22431.12
  [Host] : .NET 7.0.0 (7.0.22.42610), X64 RyuJIT AVX2  [AttachedDebugger]
  Net70  : .NET 7.0.0 (7.0.22.42610), X64 RyuJIT AVX2

Jit=RyuJit  Platform=X64  

```

## LoadTrips

| Method                   | Job   | Runtime  |     Mean |    Error |   StdDev |   StdErr |      Min |       Q1 |   Median |       Q3 |      Max |  Op/s | Ratio | RatioSD | Rank | Baseline |      Gen0 |      Gen1 |      Gen2 |  Allocated | Alloc Ratio |
| ------------------------ | ----- | -------- | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | ----: | ----: | ------: | ---: | -------- | --------: | --------: | --------: | ---------: | ----------: |
| _01_Original             | Net60 | .NET 6.0 |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |    NA |     ? |       ? |    ? | Yes      |         - |         - |         - |          - |           ? |
| _02_ListAndDictionaryUse | Net60 | .NET 6.0 |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |    NA |     ? |       ? |    ? | No       |         - |         - |         - |          - |           ? |
| _03_CacheFriendly        | Net60 | .NET 6.0 |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |    NA |     ? |       ? |    ? | No       |         - |         - |         - |          - |           ? |
|                          |       |          |          |          |          |          |          |          |          |          |          |       |       |         |      |          |           |           |           |            |             |
| _01_Original             | Net70 | .NET 7.0 | 70.46 ms | 1.385 ms | 2.030 ms | 0.377 ms | 66.32 ms | 69.17 ms | 70.00 ms | 72.23 ms | 73.94 ms | 14.19 |  1.00 |    0.00 |    3 | Yes      | 4285.7143 | 3142.8571 | 1285.7143 | 63080717 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 58.70 ms | 1.154 ms | 1.897 ms | 0.321 ms | 55.42 ms | 57.49 ms | 58.43 ms | 59.99 ms | 63.14 ms | 17.04 |  0.83 |    0.04 |    2 | No       | 3444.4444 | 3333.3333 | 1111.1111 | 47521523 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 46.32 ms | 0.672 ms | 0.525 ms | 0.151 ms | 45.01 ms | 46.20 ms | 46.45 ms | 46.62 ms | 47.01 ms | 21.59 |  0.66 |    0.02 |    1 | No       | 3272.7273 | 2454.5455 |  909.0909 | 46363628 B |        0.73 |

Benchmarks with issues:
  LoadTripsBenchmarks._01_Original: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  LoadTripsBenchmarks._02_ListAndDictionaryUse: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  LoadTripsBenchmarks._03_CacheFriendly: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)

## LoadStop

| Method                   | Job   | Runtime  |    Mean |    Error |   StdDev |   StdErr |     Min |      Q1 |  Median |      Q3 |     Max |   Op/s | Ratio | RatioSD | Rank | Baseline |       Gen0 |       Gen1 |      Gen2 |    Allocated | Alloc Ratio |
| ------------------------ | ----- | -------- | ------: | -------: | -------: | -------: | ------: | ------: | ------: | ------: | ------: | -----: | ----: | ------: | ---: | -------- | ---------: | ---------: | --------: | -----------: | ----------: |
| _01_Original             | Net60 | .NET 6.0 |      NA |       NA |       NA |       NA |      NA |      NA |      NA |      NA |      NA |     NA |     ? |       ? |    ? | Yes      |          - |          - |         - |            - |           ? |
| _02_ListAndDictionaryUse | Net60 | .NET 6.0 |      NA |       NA |       NA |       NA |      NA |      NA |      NA |      NA |      NA |     NA |     ? |       ? |    ? | No       |          - |          - |         - |            - |           ? |
| _03_CacheFriendly        | Net60 | .NET 6.0 |      NA |       NA |       NA |       NA |      NA |      NA |      NA |      NA |      NA |     NA |     ? |       ? |    ? | No       |          - |          - |         - |            - |           ? |
|                          |       |          |         |          |          |          |         |         |         |         |         |        |       |         |      |          |            |            |           |              |             |
| _01_Original             | Net70 | .NET 7.0 | 1.467 s | 0.0281 s | 0.0276 s | 0.0069 s | 1.428 s | 1.445 s | 1.466 s | 1.476 s | 1.528 s | 0.6818 |  1.00 |    0.00 |    3 | Yes      | 62000.0000 | 61000.0000 | 5000.0000 | 1157427424 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 1.268 s | 0.0141 s | 0.0117 s | 0.0033 s | 1.239 s | 1.260 s | 1.276 s | 1.276 s | 1.280 s | 0.7887 |  0.86 |    0.02 |    2 | No       | 50000.0000 | 49000.0000 | 6000.0000 |  869224088 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 1.181 s | 0.0146 s | 0.0136 s | 0.0035 s | 1.161 s | 1.171 s | 1.182 s | 1.189 s | 1.210 s | 0.8466 |  0.80 |    0.02 |    1 | No       | 51000.0000 | 50000.0000 | 6000.0000 |  899098368 B |        0.78 |

Benchmarks with issues:
  LoadStopTimesBenchmarks._01_Original: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  LoadStopTimesBenchmarks._02_ListAndDictionaryUse: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  LoadStopTimesBenchmarks._03_CacheFriendly: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)

## SchedulesForRoute

| Method        | Job   | Runtime  |     Mean |    Error |   StdDev |   StdErr |      Min |      Max |   Median |       Q1 |       Q3 |  Op/s | Ratio | RatioSD | Rank |      Gen0 |      Gen1 |  Allocated | Alloc Ratio |
| ------------- | ----- | -------- | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | -------: | ----: | ----: | ------: | ---: | --------: | --------: | ---------: | ----------: |
| _01_Original  | Net60 | .NET 6.0 |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |    NA |     ? |       ? |    ? |         - |         - |          - |           ? |
| _11_StructFix | Net60 | .NET 6.0 |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |       NA |    NA |     ? |       ? |    ? |         - |         - |          - |           ? |
|               |       |          |          |          |          |          |          |          |          |          |          |       |       |         |      |           |           |            |             |
| _01_Original  | Net70 | .NET 7.0 | 36.27 ms | 0.261 ms | 0.231 ms | 0.062 ms | 35.83 ms | 36.69 ms | 36.25 ms | 36.15 ms | 36.39 ms | 27.57 |  1.00 |    0.00 |    2 | 5000.0000 | 1571.4286 | 85135720 B |        1.00 |
| _11_StructFix | Net70 | .NET 7.0 | 21.84 ms | 0.193 ms | 0.180 ms | 0.047 ms | 21.62 ms | 22.17 ms | 21.78 ms | 21.71 ms | 21.97 ms | 45.78 |  0.60 |    0.00 |    1 | 2437.5000 |  968.7500 | 40924442 B |        0.48 |

Benchmarks with issues:
  SchedulesForRouteBenchmarks._01_Original: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  SchedulesForRouteBenchmarks._11_StructFix: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
