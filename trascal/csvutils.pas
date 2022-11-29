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
  if Assigned(FCells) then
    FCells.Free;
  inherited Destroy;
end;
 
procedure TCSVDocument.LoadFromFile(const aFileName: string);
var
  ms: specialize TGAutoRef<TMemoryStream>;
  p, pCell, pEnd: pChar;
  Size: SizeInt;
  Row: TStrList;
  pItem: TStrList.PItem;
begin
  ms.Instance.LoadFromFile(aFileName);
  if FCells = nil then
    FCells := TStrList2D.Create;
  FCells.Clear;
  p := ms.Instance.Memory;
  pEnd := p + ms.Instance.Size;
  pCell := p;
  Size := -1;
  Row := nil;
 
  while p < pEnd do begin
    case p^ of
      ',':
        begin
          if Row = nil then begin
            Row := TStrList.Create(Max(Size, DEFAULT_CONTAINER_CAPACITY));
            FCells.Add(Row);
          end;
          pItem := Row.UncMutable[Row.Add('')];
          if p - pCell > 0 then begin
            SetLength(pItem^, p - pCell);
            Move(pCell^, PChar(pItem^)^, p - pCell);
          end;
          pCell := p + 1;
        end;
      #10, #13:
        if Row <> nil then begin
          pItem := Row.UncMutable[Row.Add('')];
          if p - pCell > 0 then begin
            SetLength(pItem^, p - pCell);
            Move(pCell^, PChar(pItem^)^, p - pCell);
          end;
          if Size = -1 then
            Size := Row.Count;
          Row := nil;
          pCell := p + 1;
          Inc(pCell, Ord(pCell^ in [#10, #13]));
        end;
    end;
    Inc(p);
  end;
  if Row = nil then exit;
  pItem := Row.UncMutable[Row.Add('')];
  SetLength(pItem^, p - pCell);
  Move(pCell^, PChar(pItem^)^, p - pCell);
end;
 
end. 