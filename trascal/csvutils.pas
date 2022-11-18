unit csvutils;

{$mode objfpc}{$h+}

interface
 
uses
  SysUtils, lgVector;
 
type
  TCSVDocument = class
  private
  type
    TStrList   = specialize TGVector<string>;
    TStrList2D = specialize TGObjectVector<TStrList>;
  var
    FCells: TStrList2D;
    function  GetCell(aCol, aRow: SizeInt): string; inline;
    function  GetColCount(aRow: SizeInt): SizeInt; inline;
    function  GetRowCount: SizeInt; inline;
  public
    destructor Destroy; override;
    procedure LoadFromFile(const aFileName: string);
    property  Cells[aCol, aRow: SizeInt]: string read GetCell; default;
    property  ColCount[aRow: SizeInt]: SizeInt read GetColCount;
    property  RowCount: SizeInt read GetRowCount;
  end;
 
implementation
 
uses
  Classes, Math, lgUtils;
 
function TCSVDocument.GetCell(aCol, aRow: SizeInt): string;
begin
  Result := FCells[aRow][aCol];
end;
 
function TCSVDocument.GetColCount(aRow: SizeInt): SizeInt;
begin
  Result := FCells[aRow].Count;
end;
 
function TCSVDocument.GetRowCount: SizeInt; inline;
begin
  Result := FCells.Count;
end;
 
destructor TCSVDocument.Destroy;
begin
  FCells.Free;
  inherited;
end;
 
procedure TCSVDocument.LoadFromFile(const aFileName: string);
var
  ss: specialize TGAutoRef<TStringStream>;
  I, CellStart, Size: SizeInt;
  Row: TStrList;
  s: string;
begin
  ss.Instance.LoadFromFile(aFileName);
  s := ss.Instance.DataString;
  ss.Clear;

  FCells := TStrList2D.Create;
  
  CellStart := 0;
  Size := -1;
  Row := nil;
 
  for I := 1 to Length(s) do
    case s[I] of
      ',':
        begin
          if Row = nil then begin
            Row := TStrList.Create(Max(Size, DEFAULT_CONTAINER_CAPACITY));
            FCells.Add(Row);
          end;
          Row.Add(Copy(s, CellStart, I - CellStart));
          CellStart := I + 1;
        end;
      #13, #10:
        begin
          if CellStart = 0 then continue;
          Row.Add(Copy(s, CellStart, I - CellStart));
          if Size = -1 then
            Size := Row.Count;
          CellStart := 0;
          Row := nil;
        end;
    else
      if CellStart = 0 then
        CellStart := I;
    end;
end;
 
end. 