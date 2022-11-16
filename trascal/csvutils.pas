unit csvutils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,gvector;

type
  TStringVector = specialize TVector<String>;
  T2DStringArray = specialize TVector<TStringVector>;

  TCSVDocument = class
  private
    FCells: T2DStringArray;
    FDelimiter: Char;
    function GetCell(const ACol, ARow: SizeInt): String; inline;
    procedure SetCell(const ACol, ARow: SizeInt; AValue: String); inline;
    function GetColCount(const ARow: SizeInt): SizeInt; inline;
    function GetRowCount: SizeInt; inline;
  public
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: String);
    property Cells[const ACol, ARow: SizeInt]: String read GetCell write SetCell;
    property Delimiter: Char read FDelimiter write FDelimiter;
    property ColCount[const ARow: SizeInt]: SizeInt read GetColCount;
    property RowCount: SizeInt read GetRowCount;
  end;

implementation

uses
  Classes,DateUtils;

destructor TCSVDocument.Destroy;
var
  i: SizeInt;
begin
  if Assigned(FCells) then begin
    for i := 0 to FCells.Size - 1 do
      FCells[i].Free;
    FCells.Free;
  end;
  inherited Destroy;
end;

procedure TCSVDocument.LoadFromFile(const AFileName: String);
var
  fs: TFileStream;
  s: String;
  n,i,j,r,c: SizeInt;
begin
  fs := TFileStream.Create(AFileName, fmOpenRead);
  n := fs.Size;
  SetLength(s, n);
  fs.Read(s[1], n);

  i := 1;
  j := i;
  r := 0;
  c := 0;
  
  if n > 0 then begin
    FCells := T2DStringArray.Create;
    FCells.PushBack(TStringVector.Create);
    while i <= n do begin
      case s[i] of
        ',': begin
          FCells[r].PushBack(Copy(s, j, i - j));
          j := i + 1;
          Inc(c);
        end;
        #10: begin
          FCells[r].PushBack(Copy(s, j, i - j));
          j := i + 1;
          Inc(r);
          c := 0;
          FCells.PushBack(TStringVector.Create);
        end;
      end;
      Inc(i);
    end;
  end;
  FCells.PopBack;

  fs.Free;
end;

function TCSVDocument.GetCell(const ACol, ARow: SizeInt): String; inline;
begin
  Result := FCells[ARow][ACol]
end;

procedure TCSVDocument.SetCell(const ACol, ARow: SizeInt; AValue: String); inline;
begin
  FCells[ARow][ACol] := AValue;
end;

function TCSVDocument.GetColCount(const ARow: SizeInt): SizeInt; inline;
begin
  Result := FCells[ARow].Size;
end;

function TCSVDocument.GetRowCount: SizeInt; inline;
begin
  Result := FCells.Size;
end;

end.
