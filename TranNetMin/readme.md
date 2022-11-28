# ASP.NET Minimal Transit API

I understand that .NET and C# have a reputation for being excessively verbose, and overwrought compared to other languages. To try to dispell that impression, I wanted to implement a "minimal" ASP.NET/C# API that could also compete with the best alternatives. The entire application is implemented in the Program.cs file, and uses my [Sylvan.Data.Csv](https://github.com/MarkPflug/Sylvan) library for loading the CSV files.

Coincidently, the original rust and C# implementations had the exact same number of lines, when measuring trannet with powershell cmd: `dir *.cs -rec | gc | measure-object`. This minimal implementation is less than half the LOC, without doing anything particularly egregious to achieve that. I reworked the route data structures a bit to make binding the response trivial. These changes might violate the spirit of the comparison, but feel more idiomatic to me.

Here is a comparison of the rust (trustit), original C# (trannet) and the minimal (TranNetMin) implementations, running on my machine, which Windows 10 running on an Intel I7-7700K. I included TranNetMin running on .NET 6, and .NET 7 rc2. Your results will certainly vary.

|Implementation|LOC|CSV Load (ms)|Req/s|
| - | - | - | - |
|Trustit|213|987|844|
|Trannet|213|1457|649|
|TranNetMin 6.0|90|498|838|
|TranNetMin 7.0|90|551|902|

At least on my machine, this minimal ASP.NET implementation beats the current tRUSTit implementation at CSV parsing by a significant margin, and is roughly equivalent (faster on .NET 7) in request throughput.