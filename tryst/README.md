# Tryst

```shell
> brew install crystal
> crystal --version
Crystal 1.6.2 (2022-11-03)

LLVM: 14.0.6
Default target: aarch64-apple-darwin22.1.0
> crystal build --release -Dpreview_mt src/tryst.cr
> CRYSTAL_WORKERS=8 ./tryst
Loaded 1715408 stop times for 68185 trips in 00:00:01.512136000
Loaded 68185 trips for 190 routes in 00:00:00.104107000
Listening on http://127.0.0.1:4000
```

Gets performance generally comparable to C# or Go. Compared to those implementations, Tryst usually has lower P95 times but noteably higher max times: 300ms-450ms on all tests. I suppose it's GC pauses. Memory usage tops out at ~460MB, CPU usage reaches 650% in the large responses test.