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
| _01_Original             | Net70 | .NET 7.0 | 72.36 ms | 1.394 ms | 1.763 ms | 0.368 ms | 68.69 ms | 71.32 ms | 72.89 ms | 73.93 ms | 74.63 ms | 13.82 |  1.00 |    0.00 |    3 | Yes      | 4285.7143 | 3142.8571 | 1285.7143 | 63080637 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 58.80 ms | 1.138 ms | 1.633 ms | 0.309 ms | 55.40 ms | 57.41 ms | 59.06 ms | 59.67 ms | 61.51 ms | 17.01 |  0.81 |    0.03 |    2 | No       | 3500.0000 | 3375.0000 | 1125.0000 | 47521557 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 46.91 ms | 0.855 ms | 1.331 ms | 0.235 ms | 44.42 ms | 45.92 ms | 46.64 ms | 47.63 ms | 49.94 ms | 21.32 |  0.65 |    0.03 |    1 | No       | 3272.7273 | 2454.5455 |  909.0909 | 46362841 B |        0.73 |

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
| _01_Original             | Net70 | .NET 7.0 | 1.477 s | 0.0267 s | 0.0237 s | 0.0063 s | 1.425 s | 1.469 s | 1.478 s | 1.489 s | 1.518 s | 0.6769 |  1.00 |    0.00 |    3 | Yes      | 62000.0000 | 61000.0000 | 5000.0000 | 1157427448 B |        1.00 |
| _02_ListAndDictionaryUse | Net70 | .NET 7.0 | 1.250 s | 0.0190 s | 0.0159 s | 0.0044 s | 1.222 s | 1.240 s | 1.252 s | 1.265 s | 1.270 s | 0.8001 |  0.85 |    0.02 |    2 | No       | 50000.0000 | 49000.0000 | 6000.0000 |  869224072 B |        0.75 |
| _03_CacheFriendly        | Net70 | .NET 7.0 | 1.168 s | 0.0107 s | 0.0095 s | 0.0025 s | 1.156 s | 1.161 s | 1.164 s | 1.172 s | 1.186 s | 0.8562 |  0.79 |    0.02 |    1 | No       | 51000.0000 | 50000.0000 | 6000.0000 |  899098344 B |        0.78 |

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
| _01_Original  | Net70 | .NET 7.0 | 36.88 ms | 0.419 ms | 0.392 ms | 0.101 ms | 36.31 ms | 37.59 ms | 36.72 ms | 36.61 ms | 37.27 ms | 27.11 |  1.00 |    0.00 |    2 | 5000.0000 | 1214.2857 | 85135720 B |        1.00 |
| _11_StructFix | Net70 | .NET 7.0 | 23.20 ms | 0.445 ms | 0.437 ms | 0.109 ms | 22.73 ms | 24.12 ms | 23.09 ms | 22.85 ms | 23.38 ms | 43.11 |  0.63 |    0.01 |    1 | 2437.5000 |  875.0000 | 40924442 B |        0.48 |

Benchmarks with issues:
  SchedulesForRouteBenchmarks._01_Original: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
  SchedulesForRouteBenchmarks._11_StructFix: Net60(Jit=RyuJit, Platform=X64, Runtime=.NET 6.0)
