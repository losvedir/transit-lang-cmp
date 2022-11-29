# Pascal Implementation Notes 

There are 2 implementations provided:

* app.pas: The "innocent" version, more or less a direct translation from the Go version, using preshipped libraries as much as possible, with the exception of LGenerics and custom CSV loader as the "built-in" csvdocument unit is not coded with performance in mind, but more for usability
* alt.pas: The "NOS" version, performance focused one, very well optimized for x86_64 (will need extra effort to compile for aarch64-macos, as its static library only has aarch64-linux and aarch64-android as of now), thanks to Arnaud Bouchez, Founder of the Open Source *mORMot* (2) Framework. The same program can be found from https://github.com/synopse/mORMot2/tree/master/ex/lang-cmp and there's also [a relevant blog post](https://blog.synopse.info/?post/2022/11/26/Modern-Pascal-is-Still-in-the-Race)

On my system, which is a ROG GL503VD with the following specs:

* Intel i7-7700HQ
* 16GB DDR4-2400 dual channel RAM
* Sandisk Extreme Portable SSD V2
* Manjaro Linux 64-bit with kernel 6.0.8-1

The following performance characteristics can be observed (also vs Go version):

## app.pas

* stop_times.txt loads in around 3391ms
* trips.txt loads in 129ms
* load test:

```
running (1m00.0s), 00/50 VUs, 0 complete and 50 interrupted iterations
default ✓ [======================================] 50 VUs  30s
WARN[0060] No script iterations finished, consider making the test duration longer 

     data_received..................: 1.9 GB 32 MB/s
     data_sent......................: 367 kB 6.1 kB/s
     http_req_blocked...............: avg=14.72ms  min=82.06µs  med=168.97µs max=1.01s   p(90)=209.28µs p(95)=231.83µs
     http_req_connecting............: avg=14.55ms  min=0s       med=0s       max=1.01s   p(90)=74.43µs  p(95)=118.36µs
     http_req_duration..............: avg=1.39s    min=316.37µs med=469.74ms max=17.58s  p(90)=3.53s    p(95)=5.06s   
       { expected_response:true }...: avg=1.39s    min=316.37µs med=469.74ms max=17.58s  p(90)=3.53s    p(95)=5.06s   
     http_req_failed................: 0.00%  ✓ 0         ✗ 2014
     http_req_receiving.............: avg=190.25ms min=35.82µs  med=71.36ms  max=1.35s   p(90)=574.57ms p(95)=791.75ms
     http_req_sending...............: avg=3.6ms    min=15.48µs  med=3.09ms   max=31.53ms p(90)=7.08ms   p(95)=9.28ms  
     http_req_tls_handshaking.......: avg=0s       min=0s       med=0s       max=0s      p(90)=0s       p(95)=0s      
     http_req_waiting...............: avg=1.19s    min=222.43µs med=383.78ms max=16.74s  p(90)=3.02s    p(95)=4.25s   
     http_reqs......................: 2014   33.565661/s
     vus............................: 50     min=50      max=50
     vus_max........................: 50     min=50      max=50
```

## alt.pas

* stop_times.txt loads in around 968.43ms
* trips.txt loads in 39.54ms
* load test:

```
running (0m33.6s), 00/50 VUs, 347 complete and 0 interrupted iterations
default ✓ [======================================] 50 VUs  30s

     data_received..................: 31 GB  925 MB/s
     data_sent......................: 3.2 MB 96 kB/s
     http_req_blocked...............: avg=6.3µs   min=1.11µs   med=3.02µs   max=12.4ms  p(90)=5.07µs  p(95)=6.28µs 
     http_req_connecting............: avg=1.63µs  min=0s       med=0s       max=5.29ms  p(90)=0s      p(95)=0s     
     http_req_duration..............: avg=48.19ms min=265.23µs med=44.17ms  max=5.17s   p(90)=64.75ms p(95)=72.77ms
       { expected_response:true }...: avg=48.19ms min=265.23µs med=44.17ms  max=5.17s   p(90)=64.75ms p(95)=72.77ms
     http_req_failed................: 0.00%  ✓ 0           ✗ 34353
     http_req_receiving.............: avg=3.38ms  min=15.81µs  med=331.83µs max=516.1ms p(90)=1.58ms  p(95)=2.18ms 
     http_req_sending...............: avg=19.72µs min=4.96µs   med=12.9µs   max=11.36ms p(90)=23.21µs p(95)=28.72µs
     http_req_tls_handshaking.......: avg=0s      min=0s       med=0s       max=0s      p(90)=0s      p(95)=0s     
     http_req_waiting...............: avg=44.79ms min=197.64µs med=43.68ms  max=5.16s   p(90)=63.27ms p(95)=70.02ms
     http_reqs......................: 34353  1023.368544/s
     iteration_duration.............: avg=4.78s   min=3.72s    med=4.72s    max=9.9s    p(90)=5.11s   p(95)=5.27s  
     iterations.....................: 347    10.337056/s
     vus............................: 39     min=39        max=50 
     vus_max........................: 50     min=50        max=50
```

## app.go

* stop_times.txt loads in around 3.410159167s (for some reason, this fluctuates quite a lot, can be as slow as 4s, but also as fast as 2s)
* trips.txt loads in 83.647048ms
* load test:

```
running (0m32.5s), 00/50 VUs, 326 complete and 0 interrupted iterations
default ✓ [======================================] 50 VUs  30s

     data_received..................: 32 GB  982 MB/s
     data_sent......................: 3.0 MB 93 kB/s
     http_req_blocked...............: avg=9.83µs  min=1.06µs   med=2.89µs   max=13.67ms  p(90)=5.49µs  p(95)=7.18µs  
     http_req_connecting............: avg=5.5µs   min=0s       med=0s       max=8.68ms   p(90)=0s      p(95)=0s      
     http_req_duration..............: avg=48.58ms min=127.75µs med=36.97ms  max=473.25ms p(90)=97.21ms p(95)=128.02ms
       { expected_response:true }...: avg=48.58ms min=127.75µs med=36.97ms  max=473.25ms p(90)=97.21ms p(95)=128.02ms
     http_req_failed................: 0.00%  ✓ 0         ✗ 32274
     http_req_receiving.............: avg=5.82ms  min=15.07µs  med=431.57µs max=378.01ms p(90)=19.83ms p(95)=27.57ms 
     http_req_sending...............: avg=59.51µs min=5.16µs   med=11.82µs  max=157.88ms p(90)=23.71µs p(95)=32.29µs 
     http_req_tls_handshaking.......: avg=0s      min=0s       med=0s       max=0s       p(90)=0s      p(95)=0s      
     http_req_waiting...............: avg=42.7ms  min=99.23µs  med=32.95ms  max=471.78ms p(90)=84.91ms p(95)=112.98ms
     http_reqs......................: 32274  993.41332/s
     iteration_duration.............: avg=4.82s   min=2.43s    med=4.91s    max=6.32s    p(90)=5.41s   p(95)=5.69s   
     iterations.....................: 326    10.034478/s
     vus............................: 25     min=25      max=50 
     vus_max........................: 50     min=50      max=50
```

# How to build

A Makefile is provided to ease building. All external dependencies are included in the repo, so all you need to have installed is just:

* GNU Make
* Free Pascal Compiler, I use their main branch, but 3.2.2 should be able to build it as well

by default

`$ make`

will compile both app.pas and alt.pas, but you can specify any if you wish:

`$ make app`

`$ make alt`

as well as cleaning everything to its fresh state:

`$ make clean`
