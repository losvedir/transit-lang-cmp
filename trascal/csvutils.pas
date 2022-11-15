unit csvutils;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  T2DStringArray = array of TStringArray;

  TCSVDocument = class
  private
    FCells: T2DStringArray;
    FDelimiter: Char;
    function GetCell(const ACol, ARow: SizeInt): String; inline;
    procedure SetCell(const ACol, ARow: SizeInt; AValue: String); inline;
    function GetColCount(const ARow: SizeInt): SizeInt; inline;
    function GetRowCount: SizeInt; inline;
  public
    procedure LoadFromFile(const AFileName: String);
    property Cells[const ACol, ARow: SizeInt]: String read GetCell write SetCell;
    property Delimiter: Char read FDelimiter write FDelimiter;
    property ColCount[const ARow: SizeInt]: SizeInt read GetColCount;
    property RowCount: SizeInt read GetRowCount;
  end;

implementation

uses
  Classes,DateUtils;

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
    SetLength(FCells, 1);
    while i <= n do begin
      case s[i] of
        ',': begin
          SetLength(FCells[r], c + 1);
          FCells[r, c] := Copy(s, j, i - j);
          Inc(c);
          j := i + 1;
        end;
        #10: begin
          SetLength(FCells[r], c + 1);
          FCells[r, c] := Copy(s, j, i - j);
          Inc(r);
          c := 0;
          SetLength(FCells, r + 1);
          j := i + 1;
        end;
      end;
      Inc(i);
    end;
  end;
  SetLength(FCells, r);

  fs.Free;
end;

function TCSVDocument.GetCell(const ACol, ARow: SizeInt): String; inline;
begin
  Result := FCells[ARow, ACol]
end;

procedure TCSVDocument.SetCell(const ACol, ARow: SizeInt; AValue: String); inline;
begin
  FCells[ARow, ACol] := AValue;
end;

function TCSVDocument.GetColCount(const ARow: SizeInt): SizeInt; inline;
begin
  Result := Length(FCells[ARow]);
end;

function TCSVDocument.GetRowCount: SizeInt; inline;
begin
  Result := Length(FCells);
end;

end.
