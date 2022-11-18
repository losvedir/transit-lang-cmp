program trascal;

{$mode objfpc}{$H+}

uses
  cthreads,
  Classes,
  SysUtils,
  DateUtils,
  lgUtils,
  lgHashMap,
  lgVector,
  jsonparser,
  fpjson,
  fpjsonrtti,
  csvutils,
  fphttpapp,
  httpdefs,
  httpprotocol,
  httproute;

{$M+}

type
  TIntList          = specialize TGVector<Integer>;
  TStringIntListMap = specialize TGObjHashMapLP<String, TIntList>;

  TStopTime = class
  private
    FTripID   : string;
    FStopID   : string;
    FArrival  : string;
    FDeparture: string;
  public
    constructor Create(ATripID, AStopID, AArrival, ADeparture: string);
    property TripID   : string read FTripID write FTripID;
    property StopID   : string read FStopID write FStopID;
    property Arrival  : string read FArrival write FArrival;
    property Departure: string read FDeparture write FDeparture;
  end;
  TStopTimeDynArr = array of TStopTime;

  TTrip = class
  private
    FTripID   : string;
    FRouteID  : string;
    FServiceID: string;
  public
    constructor Create(ATripID, ARouteID, AServiceID: string);
    property TripID   : string read FTripID write FTripID;
    property RouteID  : string read FRouteID write FRouteID;
    property ServiceID: string read FServiceID write FServiceID;
  end;
  TTripDynArr = array of TTrip;

  TTripResponse = class(TPersistent)
  private
    FTripID   : string;
    FServiceID: string;
    FRouteID  : string;
    FSchedules: TCollection;
  published
    // for reading from JSON, must have exact same casing as the JSON keys
    property trip_id: string read FTripID write FTripID;
    property service_id: string read FServiceID write FServiceID;
    property route_id: string read FRouteID write FRouteID;
    property schedules: TCollection read FSchedules write FSchedules;
  public
    constructor Create(const ATripID,AServiceID,ARouteID: String);
    destructor Destroy; override;
    // convenient Pascal style aliases
    property TripID: string read FTripID write FTripID;
    property ServiceID: string read FServiceID write FServiceID;
    property RouteID: string read FRouteID write FRouteID;
  end;
  TTripResponseDynArr = array of TTripResponse;

  TScheduleResponse = class(TCollectionItem)
  private
    FStopID   : string;
    FArrival  : string;
    FDeparture: string;
  published
    // for reading from JSON, must have exact same casing as the JSON keys
    property stop_id: string read FStopID write FStopID;
    property arrival_time: string read FArrival write FArrival;
    property departure_time: string read FDeparture write FDeparture;
  public
    constructor Create(const AStopID,AArrival,ADeparture: String);
    // convenient Pascal style aliases
    property StopID: string read FStopID write FStopID;
    property Arrival: string read FArrival write FArrival;
    property Departure: string read FDeparture write FDeparture;
  end;

  TScheduleResponses = class(TCollection)
  private
    function GetItem(const AIndex: Integer): TScheduleResponse;
    procedure SetItem(const AIndex: Integer; AItem: TScheduleResponse);
  public
    constructor Create;
    property Items[Index: Integer]: TScheduleResponse read GetItem write SetItem;
  end;

{ TStopTime }

constructor TStopTime.Create(ATripID, AStopID, AArrival, ADeparture: string);
begin
  FTripID    := ATripID;
  FStopID    := AStopID;
  FArrival   := AArrival;
  FDeparture := ADeparture;
end;

{ TTrip }

constructor TTrip.Create(ATripID, ARouteID, AServiceID: string);
begin
  FTripID    := ATripID;
  FRouteID   := ARouteID;
  FServiceID := AServiceID;
end;

{ TTripResponse }

constructor TTripResponse.Create(const ATripID,AServiceID,ARouteID: String);
begin
  FTripID    := ATripID;
  FServiceID := AServiceID;
  FRouteID   := ARouteID;
  FSchedules := TScheduleResponses.Create;
end;

destructor TTripResponse.Destroy;
begin
  FSchedules.Free;
  inherited Destroy;
end;

{ TScheduleResponse }

constructor TScheduleResponse.Create(const AStopID,AArrival,ADeparture: String);
begin
  FStopID    := AStopID;
  FArrival   := AArrival;
  FDeparture := ADeparture;
end;

{ TScheduleResponses }

function TScheduleResponses.GetItem(const AIndex: Integer): TScheduleResponse;
begin
  Result := TScheduleResponse(inherited GetItem(AIndex));
end;

procedure TScheduleResponses.SetItem(const AIndex: Integer; AItem: TScheduleResponse);
begin
  inherited SetItem(AIndex, AItem);
end;

constructor TScheduleResponses.Create;
begin
  inherited Create(TScheduleResponse);
end;

function BuildTripResponse(ARoute: string; AStopTimes: TStopTimeDynArr; AStopTimesIxByTrip: TStringIntListMap;
  ATrips: TTripDynArr; ATripsIxByRoute: TStringIntListMap): TTripResponseDynArr;
var
  LTripIxs,LStopTimeIxs: TIntList;
  LTrip: TTrip;
  LTripIx,LStopTimeIx: Integer;
  LTripResponse: TTripResponse;
  LStopTime: TStopTime;
  LScheduleResponse: TScheduleResponse;
begin
  Result := TTripResponseDynArr.Create;
  if ATripsIxByRoute.TryGetValue(ARoute, LTripIxs) then begin
    SetLength(Result, LTripIxs.Count);
    for LTripIx := 0 to LTripIxs.Count - 1 do begin
      LTrip := ATrips[LTripIx];
      with LTrip do
        LTripResponse := TTripResponse.Create(TripID, ServiceID, RouteID);

      if AStopTimesIxByTrip.TryGetValue(LTrip.TripID, LStopTimeIxs) then
        for LStopTimeIx := 0 to LStopTimeIxs.Count - 1 do begin
          LStopTime := AStopTimes[LStopTimeIx];
          
          LScheduleResponse := LTripResponse.Schedules.Add as TScheduleResponse;
          with LScheduleResponse do begin
            StopID    := LStopTime.StopID;
            Arrival   := LStopTime.Arrival;
            Departure := LStopTime.Departure;
          end;
        end;

      Result[LTripIx] := LTripResponse;
    end;
  end;
end;

procedure GetStopTimes(var AStopTimes: TStopTimeDynArr; var AStopTimesIxByTrip: TStringIntListMap);
var
  LCSV: TCSVDocument;
  LStart,LEnd: TDateTime;
  i: Integer;
  LTrip: String;
  LStopTimesIx: ^TIntList;
begin
  LCSV := TCSVDocument.Create;
  try
    LStart := Now;
 
    LCSV.LoadFromFile('../MBTA_GTFS/stop_times.txt');
 
    if (LCSV[0, 0] <> 'trip_id') or (LCSV[3, 0] <> 'stop_id') or (LCSV[1, 0] <> 'arrival_time') or (LCSV[2, 0] <> 'departure_time') then begin
      WriteLn('stop_times.txt not in expected format:');
      for i := 0 to LCSV.ColCount[0] - 1 do begin
        WriteLn(i, ' ' + LCSV[i, 0]);
      end;
      Halt(1);
    end;
 
    SetLength(AStopTimes, LCSV.RowCount - 1);
    AStopTimesIxByTrip := TStringIntListMap.Create([moOwnsValues]);
    for i := 1 to LCSV.RowCount - 1 do begin
      LTrip := LCSV[0, i];
      if not AStopTimesIxByTrip.FindOrAddMutValue(LTrip, LStopTimesIx) then
        LStopTimesIx^ := TIntList.Create;
      LStopTimesIx^.Add(i - 1);
      AStopTimes[i - 1] := TStopTime.Create(LTrip, LCSV[3, i], LCSV[1, i], LCSV[2, i]);
    end;
 
    LEnd := Now;
 
    WriteLn('parsed ', Length(AStopTimes), ' stop times in ', SecondSpan(LStart, LEnd):1:3,' seconds');
  finally
    LCSV.Free;
  end;
end;

procedure GetTrips(var ATrips: TTripDynArr; var ATripsIxByRoute: TStringIntListMap);
var
  LCSV: TCSVDocument;
  LStart,LEnd: TDateTime;
  i: Integer;
  LRoute: String;
  LTripsIx: ^TIntList;
begin
  LCSV := TCSVDocument.Create;
  try
    LStart := Now;

    LCSV.LoadFromFile('../MBTA_GTFS/trips.txt');

    if (LCSV.Cells[2, 0] <> 'trip_id') or (LCSV.Cells[0, 0] <> 'route_id') or (LCSV.Cells[1, 0] <> 'service_id') then begin
      WriteLn('trips.txt not in expected format:');
      for i := 0 to LCSV.ColCount[0] - 1 do begin
        WriteLn(i, ' ' + LCSV.Cells[i, 0]);
      end;
      Halt(1);
    end;  

    SetLength(ATrips, LCSV.RowCount - 1);
    ATripsIxByRoute := TStringIntListMap.Create([moOwnsValues]);
    for i := 1 to LCSV.RowCount - 1 do begin
      LRoute := LCSV.Cells[0, i];
      if not ATripsIxByRoute.FindOrAddMutValue(LRoute, LTripsIx) then
        LTripsIx^ := TIntList.Create;
      LTripsIx^.Add(i - 1);
      ATrips[i - 1] := TTrip.Create(LCSV.Cells[2, i], LRoute, LCSV.Cells[1, i]);
    end;

    LEnd := Now;

    WriteLn('parsed ', Length(ATrips), ' trips in ', MilliSecondSpan(LStart, LEnd):1:3,'ms');
  finally
    LCSV.Free;
  end;
end;

var
  GStopTimes: TStopTimeDynArr;
  GStopTimesIxByTrip: TStringIntListMap;
  GTrips: TTripDynArr;
  GTripsIxByRoute: TStringIntListMap;

procedure SchedulesHandler(ARequest: TRequest; AResponse: TResponse);
var
  i: Integer;
  LRoute: String;
  LTripResponses: TTripResponseDynArr;
  LTripResponse: TTripResponse;
  LJSON: TJSONData;
  LJSONStreamer: TJSONStreamer;
  LStringStream: TStringStream;
begin
  LRoute := ARequest.RouteParams['route'];
  LTripResponses := BuildTripResponse(LRoute, GStopTimes, GStopTimesIxByTrip, GTrips, GTripsIxByRoute);
  LJSONStreamer := TJSONStreamer.Create(nil);
  try    
    LStringStream := TStringStream.Create();

    LStringStream.WriteString('[');
    if Length(LTripResponses) > 0 then begin
      LJSON := LJSONStreamer.ObjectToJSON(LTripResponses[0]); 
      LStringStream.WriteString(LJSON.FormatJSON(AsCompressedJSON,0));
      LJSON.Free;
      for i := 1 to Length(LTripResponses) - 1 do begin
        LJSON := LJSONStreamer.ObjectToJSON(LTripResponses[i]); 
        LStringStream.WriteString(',' + LJSON.FormatJSON(AsCompressedJSON,0));
        LJSON.Free;
      end;
    end;
    LStringStream.WriteString(']');

    AResponse.ContentType := 'application/json';
    AResponse.Content := LStringStream.DataString;
  finally
    LStringStream.Free;
    for LTripResponse in LTripResponses do
      LTripResponse.Free;
    LJSONStreamer.Free;
  end;
end;

procedure StopHandler(ARequest: TRequest; AResponse: TResponse);
var
  GStopTime: TStopTime;
  GTrip: TTrip;
begin
  for GStopTime in GStopTimes do 
    GStopTime.Free;
  GStopTimesIxByTrip.Free;
  for GTrip in GTrips do
    GTrip.Free;
  GTripsIxByRoute.Free;

  Application.Terminate;
end;

begin
  GetStopTimes(GStopTimes, GStopTimesIxByTrip);
  GetTrips(GTrips, GTripsIxByRoute);

  Application.Port := 4000;
  Application.Threaded := true;
  HTTPRouter.RegisterRoute('/schedules/:route', @SchedulesHandler);
  HTTPRouter.RegisterRoute('/stop', @StopHandler);
  Application.Run;
end.
