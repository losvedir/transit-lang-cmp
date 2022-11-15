program trascal;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  DateUtils,
  generics.collections,
  jsonparser,
  fpjson,
  fpjsonrtti,
  csvdocument,
  fphttpapp,
  httpdefs,
  httproute;

{$M+}

type

  TIntList = specialize TList<Integer>;
  TStringIntListMap = specialize TDictionary<String, TIntList>;

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
  public
    constructor Create(const ATripID,AServiceID,ARouteID: String);
  published
    // for reading from JSON, must have exact same casing as the JSON keys
    property trip_id: string read FTripID write FTripID;
    property service_id: string read FServiceID write FServiceID;
    property route_id: string read FRouteID write FRouteID;
    property schedules: TCollection read FSchedules write FSchedules;
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
  public
    constructor Create(const AStopID,AArrival,ADeparture: String);
  published
    // for reading from JSON, must have exact same casing as the JSON keys
    property stop_id: string read FStopID write FStopID;
    property arrival_time: string read FArrival write FArrival;
    property departure_time: string read FDeparture write FDeparture;
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
  LStopTimesIx: TIntList;
begin
  LCSV := TCSVDocument.Create;
  try
    LCSV.Delimiter := ',';
    LCSV.LoadFromFile('../MBTA_GTFS/stop_times.txt');

    LStart := Now;

    if (LCSV.Cells[0, 0] <> 'trip_id') or (LCSV.Cells[3, 0] <> 'stop_id') or (LCSV.Cells[1, 0] <> 'arrival_time') or (LCSV.Cells[2, 0] <> 'departure_time') then begin
      WriteLn('stop_times.txt not in expected format:');
      for i := 0 to LCSV.ColCount[0] - 1 do begin
        WriteLn(i, ' ' + LCSV.Cells[i, 0]);
      end;
      Halt(1);
    end;

    SetLength(AStopTimes, LCSV.RowCount - 1);
    AStopTimesIxByTrip := TStringIntListMap.Create;
    for i := 1 to LCSV.RowCount - 1 do begin
      LTrip := LCSV.Cells[0, i];

      if not AStopTimesIxByTrip.TryGetValue(LTrip, LStopTimesIx) then begin
        LStopTimesIx := TIntList.Create;
        AStopTimesIxByTrip.Add(LTrip, LStopTimesIx);
      end;
      LStopTimesIx.Add(i);
      AStopTimes[i - 1] := TStopTime.Create(LTrip, LCSV.Cells[3, i], LCSV.Cells[1, i], LCSV.Cells[2, i]);
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
  LTripsIx: TIntList;
begin
  LCSV := TCSVDocument.Create;
  try
    LCSV.Delimiter := ',';
    LCSV.LoadFromFile('../MBTA_GTFS/trips.txt');

    LStart := Now;

    if (LCSV.Cells[2, 0] <> 'trip_id') or (LCSV.Cells[0, 0] <> 'route_id') or (LCSV.Cells[1, 0] <> 'service_id') then begin
      WriteLn('trips.txt not in expected format:');
      for i := 0 to LCSV.ColCount[0] - 1 do begin
        WriteLn(i, ' ' + LCSV.Cells[i, 0]);
      end;
      Halt(1);
    end;  

    SetLength(ATrips, LCSV.RowCount - 1);
    ATripsIxByRoute := TStringIntListMap.Create;
    for i := 1 to LCSV.RowCount - 1 do begin
      LRoute := LCSV.Cells[0, i];

      if not ATripsIxByRoute.TryGetValue(LRoute, LTripsIx) then begin
        LTripsIx := TIntList.Create;
        ATripsIxByRoute.Add(LRoute, LTripsIx);
      end;
      LTripsIx.Add(i);
      ATrips[i - 1] := TTrip.Create(LCSV.Cells[2, i], LRoute, LCSV.Cells[1, i]);
    end;

    LEnd := Now;

    WriteLn('parsed ', Length(ATrips), ' trips in ', SecondSpan(LStart, LEnd):1:3,' seconds');
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
  LRoute: String;
  LResp: TTripResponseDynArr;
  LJSONStreamer: TJSONStreamer;
begin
  LRoute := ARequest.URI.Split(['/'])[2];
  LResp := BuildTripResponse(LRoute, GStopTimes, GStopTimesIxByTrip, GTrips, GTripsIxByRoute);
  LJSONStreamer := TJSONStreamer.Create(nil);
  try
    AResponse.ContentType := 'application/json';
    AResponse.ContentStream := TStringStream.Create(LJSONStreamer.StreamVariant(LResp).AsJSON);
  finally
    LJSONStreamer.Free;
  end;
end;

begin
  GetStopTimes(GStopTimes, GStopTimesIxByTrip);
  GetTrips(GTrips, GTripsIxByRoute);

  Application.Port := 4000;
  HTTPRouter.RegisterRoute('/schedules/',@SchedulesHandler);
  Application.Run;
end.
