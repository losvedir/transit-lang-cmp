{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic deque(double ended queue) implementation.                       *
*                                                                           *
*   Copyright(c) 2018-2022 A.Koverdyaev(avk)                                *
*                                                                           *
*   This code is free software; you can redistribute it and/or modify it    *
*   under the terms of the Apache License, Version 2.0;                     *
*   You may obtain a copy of the License at                                 *
*     http://www.apache.org/licenses/LICENSE-2.0.                           *
*                                                                           *
*  Unless required by applicable law or agreed to in writing, software      *
*  distributed under the License is distributed on an "AS IS" BASIS,        *
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
*  See the License for the specific language governing permissions and      *
*  limitations under the License.                                           *
*                                                                           *
*****************************************************************************}
unit lgDeque;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgArrayHelpers,
  lgAbstractContainer,
  lgStrConst;

type

  generic TGDeque<T> = class(specialize TGCustomRingArrayBuffer<T>, specialize IGDeque<T>)
  protected
  const
    SIZE_CUTOFF = 64;

    procedure DoPushFirst(const aValue: T);
    function  AddArray2Head(const a: array of T): SizeInt;
    function  AddContainer2Head(aContainer: TSpecContainer): SizeInt;
    function  AddEnum2Head(e: IEnumerable): SizeInt;
    function  InternalIndex(aIndex: SizeInt): SizeInt; inline;
    function  TailIndex: SizeInt; inline;
    function  PeekTail: T; inline;
    function  ExtractTail: T;
    function  GetItem(aIndex: SizeInt): T; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); virtual;
    function  GetMutable(aIndex: SizeInt): PItem; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure ShiftHeadRight(aToIndex: SizeInt);
    procedure ShiftHeadLeft(aFromIndex: SizeInt);
    procedure ShiftTailRight(aFromIndex: SizeInt);
    procedure ShiftTailLeft(aToIndex: SizeInt);
    procedure InsertItem(aIndex: SizeInt; aValue: T);
    function  ExtractItem(aIndex: SizeInt): T;
    function  DeleteItem(aIndex: SizeInt): T; virtual;
  public
    procedure PushFirst(const aValue: T); inline;
    function  PushAllFirst(const a: array of T): SizeInt;
    function  PushAllFirst(e: IEnumerable): SizeInt;
    procedure PushLast(const aValue: T);
    function  PushAllLast(const a: array of T): SizeInt;
    function  PushAllLast(e: IEnumerable): SizeInt;
  { EXTRACTS element from the head of deque; will raise ELGAccessEmpty if inctance is empty;
    will raise ELGUpdateLock if instance in iteration }
    function  PopFirst: T;
    function  TryPopFirst(out aValue: T): Boolean;
  { EXTRACTS element from the tail of deque; will raise ELGAccessEmpty if inctance is empty;
    will raise ELGUpdateLock if instance in iteration }
    function  PopLast: T;
    function  TryPopLast(out aValue: T): Boolean;
  { examines element in the head of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekFirst: T;
    function  TryPeekFirst(out aValue: T): Boolean;
  { examines element in the tail of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekLast: T;
    function  TryPeekLast(out aValue: T): Boolean;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed);
    will raise ELGUpdateLock if instance in iteration }
    procedure Insert(aIndex: SizeInt; const aValue: T);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration }
    function  Extract(aIndex: SizeInt): T;
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
  { deletes value in position aIndex;
    will raise ELGListError if aIndex out of bounds;
    will raise ELGUpdateLock if instance in iteration }
    procedure Delete(aIndex: SizeInt);
  { will return False if aIndex out of bounds or instance in iteration }
    function  TryDelete(aIndex: SizeInt): Boolean;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Mutable[aIndex: SizeInt]: PItem read GetMutable;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
  end;

  { TGObjectDeque notes:
    TGObjectDeque.PopFirst(or TGObjectDeque.TryPopFirst) and
    TGObjectDeque.PopLast(or TGObjectDeque.TryPopLast) EXTRACTS object from deque:
    one must to free this object yourself;
    for equality comparision of items uses TObjectHelper from LGHelpers  }
  generic TGObjectDeque<T: class> = class(specialize TGDeque<T>)
  private
    FOwnsObjects: Boolean;
  protected
    procedure DoClear; override;
    procedure SetItem(aIndex: SizeInt; const aValue: T); override;
    function  DeleteItem(aIndex: SizeInt): T; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(const A: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGThreadDeque<T> = class
  public
  type
    IDeque = specialize IGDeque<T>;
  private
    FDeque: IDeque;
    FLock: TRtlCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create(aDeque: IDeque);
    destructor Destroy; override;
    procedure Clear;
    procedure PushFirst(const aValue: T); inline;
    procedure PushLast(const aValue: T); inline;
    function  TryPopFirst(out aValue: T): Boolean;
    function  TryPopLast(out aValue: T): Boolean;
    function  TryPeekFirst(out aValue: T): Boolean;
    function  TryPeekLast(out aValue: T): Boolean;
    function  Lock: IDeque;
    procedure Unlock; inline;
  end;

  { TGLiteDeque }

  generic TGLiteDeque<T> = record
  public
  type
    TBuffer            = specialize TGLiteRingDynBuffer<T>;
    TEnumerator        = TBuffer.TEnumerator;
    TReverseEnumerator = TBuffer.TReverseEnumerator;
    TMutableEnumerator = TBuffer.TMutableEnumerator;
    TMutables          = TBuffer.TMutables;
    TReverse           = TBuffer.TReverse;
    TArray             = TBuffer.TArray;
    PItem              = TBuffer.PItem;

  private
  const
    SIZE_CUTOFF = 64;

  type
    TFake = {$IFNDEF FPC_REQUIRES_PROPER_ALIGNMENT}array[0..Pred(SizeOf(T))] of Byte{$ELSE}T{$ENDIF};

  var
    FBuffer: TBuffer;
    function  GetCapacity: SizeInt; inline;
    function  InternalIndex(aIndex: SizeInt): SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetMutable(aIndex: SizeInt): PItem; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T); inline;
    procedure ShiftHeadRight(aToIndex: SizeInt);
    procedure ShiftHeadLeft(aFromIndex: SizeInt);
    procedure ShiftTailRight(aFromIndex: SizeInt);
    procedure ShiftTailLeft(aToIndex: SizeInt);
    procedure InsertItem(aIndex: SizeInt; aValue: T);
    function  DeleteItem(aIndex: SizeInt): T; inline;
  public
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  GetMutableEnumerator: TMutableEnumerator; inline;
    function  Mutables: TMutables; inline; //
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    procedure MakeEmpty; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure PushFirst(const aValue: T); inline;
    procedure PushLast(const aValue: T); inline;
  { EXTRACTS element from the head of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PopFirst: T; inline;
    function  TryPopFirst(out aValue: T): Boolean; inline;
  { EXTRACTS element from the tail of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PopLast: T; inline;
    function  TryPopLast(out aValue: T): Boolean; inline;
  { examines element in the head of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekFirst: T; inline;
    function  TryPeekFirst(out aValue: T): Boolean; inline;
    function  PeekFirstItem: PItem; inline;
    function  TryPeekFirstItem(out aValue: PItem): Boolean; inline;
  { examines element in the tail of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekLast: T; inline;
    function  TryPeekLast(out aValue: T): Boolean; inline;
    function  PeekLastItem: PItem; inline;
    function  TryPeekLastItem(out aValue: PItem): Boolean; inline;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; constref aValue: T);
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
  { deletes and returns value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Delete(aIndex: SizeInt): T;
  { will return False if aIndex out of bounds }
    function  TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
    property  Count: SizeInt read FBuffer.FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
    property  Mutable[aIndex: SizeInt]: PItem read GetMutable;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
  end;

  generic TGLiteThreadDeque<T> = class
  public
  type
    TDeque = specialize TGLiteDeque<T>;
    PDeque = ^TDeque;

  private
    FDeque: TDeque;
    FLock: TRtlCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure PushFirst(const aValue: T); inline;
    procedure PushLast(const aValue: T); inline;
    function  TryPopFirst(out aValue: T): Boolean;
    function  TryPopLast(out aValue: T): Boolean;
    function  TryPeekFirst(out aValue: T): Boolean;
    function  TryPeekLast(out aValue: T): Boolean;
    function  Lock: PDeque;
    procedure Unlock; inline;
  end;

  { TGLiteObjectDeque notes:
    TGLiteObjectDeque.PopFirst(or TGLiteObjectDeque.TryPopFirst) and
    TGLiteObjectDeque.PopLast(or TGLiteObjectDeque.TryPopLast) EXTRACTS object from deque:
    one must to free this object yourself;
    for equality comparision of items uses TObjectHelper from LGHelpers }
  generic TGLiteObjectDeque<T: class> = record
  public
  type
    TDeque             = specialize TGLiteDeque<T>;
    PDeque             = ^TDeque;
    PItem              = TDeque.PItem;
    TEnumerator        = TDeque.TEnumerator;
    TReverseEnumerator = TDeque.TReverseEnumerator;
    TReverse           = TDeque.TReverse;
    TArray             = TDeque.TArray;

  private
    FDeque: TDeque;
    FOwnsObjects: Boolean;
    procedure CheckFreeItems;
    function  GetCapacity: SizeInt; inline;
    function  GetCount: SizeInt; inline;
    function  GetItem(aIndex: SizeInt): T; inline;
    function  GetUncMutable(aIndex: SizeInt): PItem; inline;
    procedure SetItem(aIndex: SizeInt; const aValue: T);
    class operator Initialize(var d: TGLiteObjectDeque);
    class operator Copy(constref aSrc: TGLiteObjectDeque; var aDst: TGLiteObjectDeque);
  public
    function  InnerDeque: PDeque;
    function  GetEnumerator: TEnumerator; inline;
    function  GetReverseEnumerator: TReverseEnumerator; inline;
    function  Reverse: TReverse; inline;
    function  ToArray: TArray; inline;
    procedure Clear; inline;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    procedure TrimToFit; inline;
    procedure PushFirst(const aValue: T); inline;
    procedure PushLast(const aValue: T); inline;
  { EXTRACTS element from the head of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PopFirst: T; inline;
    function  TryPopFirst(out aValue: T): Boolean; inline;
  { EXTRACTS element from the tail of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PopLast: T; inline;
    function  TryPopLast(out aValue: T): Boolean;
  { examines element in the head of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekFirst: T; inline;
    function  TryPeekFirst(out aValue: T): Boolean;
  { examines element in the tail of deque; will raise ELGAccessEmpty if inctance is empty }
    function  PeekLast: T; inline;
    function  TryPeekLast(out aValue: T): Boolean; inline;
  { inserts aValue into position aIndex;
    will raise ELGListError if aIndex out of bounds(aIndex = Count  is allowed) }
    procedure Insert(aIndex: SizeInt; const aValue: T); inline;
  { will return False if aIndex out of bounds }
    function  TryInsert(aIndex: SizeInt; const aValue: T): Boolean; inline;
  { extracts value from position aIndex;
    will raise ELGListError if aIndex out of bounds }
    function  Extract(aIndex: SizeInt): T; inline;
  { will return False if aIndex out of bounds }
    function  TryExtract(aIndex: SizeInt; out aValue: T): Boolean; inline;
  { deletes value in position aIndex;
    will raise ELGListError if aIndex out of bounds }
    procedure Delete(aIndex: SizeInt); inline;
  { will return False if aIndex out of bounds }
    function  TryDelete(aIndex: SizeInt): Boolean; inline;
    property  Count: SizeInt read GetCount;
    property  Capacity: SizeInt read GetCapacity;
    property  Items[aIndex: SizeInt]: T read GetItem write SetItem; default;
  { does not checks aIndex range }
    property  UncMutable[aIndex: SizeInt]: PItem read GetUncMutable;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGLiteThreadObjectDeque<T: class> = class
  public
  type
    TDeque = specialize TGLiteObjectDeque<T>;
    PDeque = ^TDeque;

  private
    FDeque: TDeque;
    FLock: TRtlCriticalSection;
    procedure DoLock; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure PushFirst(const aValue: T); inline;
    procedure PushLast(const aValue: T); inline;
    function  TryPopFirst(out aValue: T): Boolean;
    function  TryPopLast(out aValue: T): Boolean;
    function  TryPeekFirst(out aValue: T): Boolean;
    function  TryPeekLast(out aValue: T): Boolean;
    function  Lock: PDeque;
    procedure Unlock; inline;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGDeque }

procedure TGDeque.DoPushFirst(const aValue: T);
begin
  ItemAdding;
  Dec(FHead);
  if Head < 0 then
    FHead += System.Length(FItems);
  Inc(FCount);
  FItems[Head] := aValue;
end;

function TGDeque.AddArray2Head(const a: array of T): SizeInt;
var
  HeadPos, I, c: SizeInt;
begin
  Result := System.Length(a);
  if Result > 0 then
    begin
      DoEnsureCapacity(ElemCount + Result);
      c := System.Length(FItems);
      HeadPos := Head;
      for I := 0 to System.High(a) do
        begin
          Dec(HeadPos);
          if HeadPos < 0 then
            HeadPos += c;
          FItems[HeadPos] := a[I];
        end;
      FCount += Result;
      FHead := HeadPos;
    end;
end;

function TGDeque.AddContainer2Head(aContainer: TSpecContainer): SizeInt;
var
  HeadPos, c: SizeInt;
  v: T;
begin
  if aContainer <> Self then
    begin
      Result := aContainer.Count;
      if Result > 0 then
        begin
          DoEnsureCapacity(ElemCount + Result);
          c := System.Length(FItems);
          HeadPos := Head;
          for v in aContainer do
            begin
              Dec(HeadPos);
              if HeadPos < 0 then
                HeadPos += c;
              FItems[HeadPos] := v;
            end;
          FCount += Result;
          FHead := HeadPos;
        end;
    end
  else
    Result := AddArray2Head(aContainer.ToArray);
end;

function TGDeque.AddEnum2Head(e: IEnumerable): SizeInt;
begin
  Result := ElemCount;
  with e.GetEnumerator do
    try
      while MoveNext do
        begin
          ItemAdding;
          Dec(FHead);
          if Head < 0 then
            FHead += System.Length(FItems);
          Inc(FCount);
          FItems[Head] := Current;
        end;
    finally
      Free;
    end;
  Result := ElemCount - Result;
end;

function TGDeque.InternalIndex(aIndex: SizeInt): SizeInt;
begin
  Result := aIndex + Head;
  if Result >= System.Length(FItems) then
    Result -= System.Length(FItems);
end;

function TGDeque.TailIndex: SizeInt;
begin
  Result := InternalIndex(Pred(ElemCount));
end;

function TGDeque.PeekTail: T;
begin
  Result := FItems[TailIndex];
end;

function TGDeque.ExtractTail: T;
var
  TailPos: SizeInt;
begin
  TailPos := TailIndex;
  Dec(FCount);
  Result := FItems[TailPos];
  FItems[TailPos] := Default(T);
end;

function TGDeque.GetItem(aIndex: SizeInt): T;
begin
  CheckIndexRange(aIndex);
  Result := FItems[InternalIndex(aIndex)];
end;

procedure TGDeque.SetItem(aIndex: SizeInt; const aValue: T);
begin
  //CheckInIteration;  ???
  CheckIndexRange(aIndex);
  FItems[InternalIndex(aIndex)] := aValue;
end;

function TGDeque.GetMutable(aIndex: SizeInt): PItem;
begin
  CheckIndexRange(aIndex);
  Result := @FItems[InternalIndex(aIndex)];
end;

function TGDeque.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := @FItems[InternalIndex(aIndex)];
end;

procedure TGDeque.ShiftHeadRight(aToIndex: SizeInt);
var
  I, Curr, Prev, c: SizeInt;
begin
  c := System.Length(FItems);
  Curr := InternalIndex(aToIndex);
  for I := aToIndex downto 1 do
    begin
      Prev := Pred(Curr);
      if Prev < 0 then
        Prev += c;
      TFake(FItems[Curr]) := TFake(FItems[Prev]);
      Curr := Prev;
    end;
  TFake(FItems[Curr]) := Default(TFake); //clear old head slot
  Inc(FHead);
  if FHead >= c then
    FHead -= c;
end;

procedure TGDeque.ShiftHeadLeft(aFromIndex: SizeInt);
var
  I, Curr, Next, c: SizeInt;
begin
  c := System.Length(FItems);
  Dec(FHead);
  if FHead < 0 then
    FHead += c;
  Curr := Head;
  for I := 0 to Pred(aFromIndex) do
    begin
      Next := Succ(Curr);
      if Next >= c then
        Next -= c;
      TFake(FItems[Curr]) := TFake(FItems[Next]);
      Curr := Next;
    end;
  TFake(FItems[Curr]) := Default(TFake); //clear last slot
end;

procedure TGDeque.ShiftTailRight(aFromIndex: SizeInt);
var
  I, Curr, Prev, c: SizeInt;
begin
  c := System.Length(FItems);
  Curr := InternalIndex(Pred(ElemCount));  //here FCount already increased
  for I := Pred(ElemCount) downto Succ(aFromIndex) do
    begin
      Prev := Pred(Curr);
      if Prev < 0 then
        Prev += c;
      TFake(FItems[Curr]) := TFake(FItems[Prev]);
      Curr := Prev;
    end;
  TFake(FItems[Curr]) := Default(TFake); //clear old aFromIndex slot
end;

procedure TGDeque.ShiftTailLeft(aToIndex: SizeInt);
var
  I, Curr, Next, c: SizeInt;
begin
  c := System.Length(FItems);
  Curr := InternalIndex(aToIndex);
  for I := aToIndex to Pred(ElemCount) do //here FCount already decreased
    begin
      Next := Succ(Curr);
      if Next >= c then
        Next -= c;
      TFake(FItems[Curr]) := TFake(FItems[Next]);
      Curr := Next;
    end;
  TFake(FItems[Curr]) := Default(TFake); //clear last slot
end;

procedure TGDeque.InsertItem(aIndex: SizeInt; aValue: T);
begin
  if aIndex = 0 then
    DoPushFirst(aValue)
  else
    if aIndex = ElemCount then
      Append(aValue)
    else
      begin
        ItemAdding;
        Inc(FCount); ////
        if ElemCount <= SIZE_CUTOFF then
          ShiftTailRight(aIndex)
        else
          if aIndex >= Pred(ElemCount shr 1) then
            ShiftTailRight(aIndex)
          else
            ShiftHeadLeft(aIndex);
        FItems[InternalIndex(aIndex)] := aValue;
      end;
end;

function TGDeque.ExtractItem(aIndex: SizeInt): T;
var
  I: SizeInt;
begin
  if aIndex = 0 then
    Result := ExtractHead
  else
    if aIndex = Pred(ElemCount) then
      Result := ExtractTail
    else
      begin
        I := InternalIndex(aIndex);
        Result := FItems[I];
        FItems[I] := Default(T);
        Dec(FCount);  ///////
        if ElemCount <= SIZE_CUTOFF then
            ShiftTailLeft(aIndex)
        else
          if aIndex >= Pred(ElemCount shr 1) then
            ShiftTailLeft(aIndex)
          else
            ShiftHeadRight(aIndex);
      end;
end;

function TGDeque.DeleteItem(aIndex: SizeInt): T;
begin
  Result := ExtractItem(aIndex);
end;

procedure TGDeque.PushFirst(const aValue: T);
begin
  CheckInIteration;
  DoPushFirst(aValue);
end;

function TGDeque.PushAllFirst(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AddArray2Head(a);
end;

function TGDeque.PushAllFirst(e: IEnumerable): SizeInt;
var
  o: TObject;
begin
  if not InIteration then
    begin
      o := e._GetRef;
      if o is TSpecContainer then
        Result := AddContainer2Head(TSpecContainer(o))
      else
        Result := AddEnum2Head(e);
    end
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

procedure TGDeque.PushLast(const aValue: T);
begin
  CheckInIteration;
  Append(aValue);
end;

function TGDeque.PushAllLast(const a: array of T): SizeInt;
begin
  CheckInIteration;
  Result := AppendArray(a);
end;

function TGDeque.PushAllLast(e: IEnumerable): SizeInt;
begin
  if not InIteration then
    Result := AppendEnumerable(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGDeque.PopFirst: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := ExtractHead;
end;

function TGDeque.TryPopFirst(out aValue: T): Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      aValue := ExtractHead;
      exit(True);
    end;
  Result := False;
end;

function TGDeque.PopLast: T;
begin
  CheckInIteration;
  CheckEmpty;
  Result := ExtractTail;
end;

function TGDeque.TryPopLast(out aValue: T): Boolean;
begin
  if not InIteration and (ElemCount > 0) then
    begin
      aValue := ExtractTail;
      exit(True);
    end;
  Result := False;
end;

function TGDeque.PeekFirst: T;
begin
  CheckEmpty;
  Result := Items[Head];
end;

function TGDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  if ElemCount > 0 then
    begin
      aValue := FItems[Head];
      exit(True);
    end;
  Result := False;
end;

function TGDeque.PeekLast: T;
begin
  CheckEmpty;
  Result := PeekTail;
end;

function TGDeque.TryPeekLast(out aValue: T): Boolean;
begin
  if ElemCount > 0 then
    begin
      aValue := PeekTail;
      exit(True);
    end;
  Result := False;
end;

procedure TGDeque.Insert(aIndex: SizeInt; const aValue: T);
begin
  CheckInIteration;
  CheckInsertIndexRange(aIndex);
  InsertItem(aIndex, aValue);
end;

function TGDeque.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  Result := not InIteration and IndexInInsertRange(aIndex);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGDeque.Extract(aIndex: SizeInt): T;
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  Result := ExtractItem(aIndex);
end;

function TGDeque.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    aValue := ExtractItem(aIndex);
end;

procedure TGDeque.Delete(aIndex: SizeInt);
begin
  CheckInIteration;
  CheckIndexRange(aIndex);
  DeleteItem(aIndex);
end;

function TGDeque.TryDelete(aIndex: SizeInt): Boolean;
begin
  Result := not InIteration and IndexInRange(aIndex);
  if Result then
    DeleteItem(aIndex);
end;

{ TGObjectDeque }

procedure TGObjectDeque.DoClear;
var
  I, CurrIdx, c: SizeInt;
begin
  if OwnsObjects and (ElemCount > 0) then
    begin
      CurrIdx := FHead;
      c := Capacity;
      for I := 1 to ElemCount do
        begin
          FItems[CurrIdx].Free;
          Inc(CurrIdx);
          if CurrIdx = c then
            CurrIdx := 0;
        end;
    end;
  inherited;
end;

procedure TGObjectDeque.SetItem(aIndex: SizeInt; const aValue: T);
var
  p: PItem;
begin
  //CheckInIteration;
  p := GetMutable(aIndex);
  if p^ <> aValue then
    begin
      if OwnsObjects then
        p^.Free;
      p^ := aValue;
    end;
end;

function TGObjectDeque.DeleteItem(aIndex: SizeInt): T;
begin
  Result := inherited DeleteItem(aIndex);
  if OwnsObjects then
    Result.Free;
end;

constructor TGObjectDeque.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDeque.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDeque.Create(const A: array of T; aOwnsObjects: Boolean = True);
begin
  inherited Create(A);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGObjectDeque.Create(e: IEnumerable; aOwnsObjects: Boolean = True);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

procedure TGThreadDeque.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGThreadDeque.Create(aDeque: IDeque);
begin
  System.InitCriticalSection(FLock);
  FDeque := aDeque;
end;

destructor TGThreadDeque.Destroy;
begin
  DoLock;
  try
    FDeque._GetRef.Free;
    FDeque := nil;
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGThreadDeque.Clear;
begin
  DoLock;
  try
    FDeque.Clear;
  finally
    UnLock;
  end;
end;

procedure TGThreadDeque.PushFirst(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushFirst(aValue);
  finally
    UnLock;
  end;
end;

procedure TGThreadDeque.PushLast(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushLast(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadDeque.TryPopFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadDeque.TryPopLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopLast(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadDeque.TryPeekLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekLast(aValue);
  finally
    UnLock;
  end;
end;

function TGThreadDeque.Lock: IDeque;
begin
  Result := FDeque;
  DoLock;
end;

procedure TGThreadDeque.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteDeque }

function TGLiteDeque.GetCapacity: SizeInt;
begin
  Result := FBuffer.Capacity;
end;

function TGLiteDeque.InternalIndex(aIndex: SizeInt): SizeInt;
begin
  Result := FBuffer.InternalIndex(aIndex);
end;

function TGLiteDeque.GetItem(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(FBuffer.Count) then
    Result := FBuffer.FItems[FBuffer.InternalIndex(aIndex)]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteDeque.GetMutable(aIndex: SizeInt): PItem;
begin
  if SizeUInt(aIndex) < SizeUInt(FBuffer.Count) then
    Result := @FBuffer.FItems[FBuffer.InternalIndex(aIndex)]
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteDeque.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := @FBuffer.FItems[FBuffer.InternalIndex(aIndex)];
end;

procedure TGLiteDeque.SetItem(aIndex: SizeInt; const aValue: T);
begin
  if SizeUInt(aIndex) < SizeUInt(FBuffer.Count) then
    FBuffer.FItems[FBuffer.InternalIndex(aIndex)] := aValue
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

procedure TGLiteDeque.ShiftHeadRight(aToIndex: SizeInt);
var
  I, Curr, Prev, c: SizeInt;
begin
  c := FBuffer.Capacity;
  Curr := InternalIndex(aToIndex);
  for I := aToIndex downto 1 do
    begin
      Prev := Pred(Curr);
      if Prev < 0 then
        Prev += c;
      TFake(FBuffer.FItems[Curr]) := TFake(FBuffer.FItems[Prev]);
      Curr := Prev;
    end;
  TFake(FBuffer.FItems[Curr]) := Default(TFake); //clear old head slot
  Inc(FBuffer.FHead);
  if FBuffer.Head >= c then
    FBuffer.FHead -= c;
end;

procedure TGLiteDeque.ShiftHeadLeft(aFromIndex: SizeInt);
var
  I, Curr, Next, c: SizeInt;
begin
  c := FBuffer.Capacity;
  Dec(FBuffer.FHead);
  if FBuffer.Head < 0 then
    FBuffer.FHead += c;
  Curr := FBuffer.Head;
  for I := 0 to Pred(aFromIndex) do
    begin
      Next := Succ(Curr);
      if Next >= c then
        Next -= c;
      TFake(FBuffer.FItems[Curr]) := TFake(FBuffer.FItems[Next]);
      Curr := Next;
    end;
  TFake(FBuffer.FItems[Curr]) := Default(TFake); //clear last slot
end;

procedure TGLiteDeque.ShiftTailRight(aFromIndex: SizeInt);
var
  I, Curr, Prev, c: SizeInt;
begin
  c := FBuffer.Capacity;
  Curr := InternalIndex(Pred(Count));  //here FBuffer.FCount already increased
  for I := Pred(Count) downto Succ(aFromIndex) do
    begin
      Prev := Pred(Curr);
      if Prev < 0 then
        Prev += c;
      TFake(FBuffer.FItems[Curr]) := TFake(FBuffer.FItems[Prev]);
      Curr := Prev;
    end;
  TFake(FBuffer.FItems[Curr]) := Default(TFake); //clear old aFromIndex slot
end;

procedure TGLiteDeque.ShiftTailLeft(aToIndex: SizeInt);
var
  I, Curr, Next, c: SizeInt;
begin
  c := FBuffer.Capacity;
  Curr := InternalIndex(aToIndex);
  for I := aToIndex to Pred(Count) do //here FBuffer.FCount already decreased
    begin
      Next := Succ(Curr);
      if Next >= c then
        Next -= c;
      TFake(FBuffer.FItems[Curr]) := TFake(FBuffer.FItems[Next]);
      Curr := Next;
    end;
  TFake(FBuffer.FItems[Curr]) := Default(TFake); //clear last slot
end;

procedure TGLiteDeque.InsertItem(aIndex: SizeInt; aValue: T);
begin
  if aIndex = 0 then
    FBuffer.PushFirst(aValue)
  else
    if aIndex = Count then
      FBuffer.PushLast(aValue)
    else
      begin
        FBuffer.ItemAdding;
        Inc(FBuffer.FCount); ////
        if Count <= SIZE_CUTOFF then
          ShiftTailRight(aIndex)
        else
          if aIndex >= Pred(Count shr 1) then
            ShiftTailRight(aIndex)
          else
            ShiftHeadLeft(aIndex);
        FBuffer.FItems[InternalIndex(aIndex)] := aValue;
      end;
end;

function TGLiteDeque.DeleteItem(aIndex: SizeInt): T;
var
  I: SizeInt;
begin
  if aIndex = 0 then
    Result := FBuffer.PopHead
  else
    if aIndex = Pred(Count) then
      Result := FBuffer.PopTail
    else
      begin
        I := InternalIndex(aIndex);
        Result := FBuffer.FItems[I];
        FBuffer.FItems[I] := Default(T);
        Dec(FBuffer.FCount);  ///////
        if Count <= SIZE_CUTOFF then
            ShiftTailLeft(aIndex)
        else
          if aIndex >= Pred(Count shr 1) then
            ShiftTailLeft(aIndex)
          else
            ShiftHeadRight(aIndex);
      end;
end;

function TGLiteDeque.GetEnumerator: TEnumerator;
begin
  Result := FBuffer.GetEnumerator;
end;

function TGLiteDeque.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FBuffer.GetReverseEnumerator;
end;

function TGLiteDeque.GetMutableEnumerator: TMutableEnumerator;
begin
  Result := FBuffer.GetMutableEnumerator;
end;

function TGLiteDeque.Mutables: TMutables;
begin
  Result := FBuffer.Mutables;
end;

function TGLiteDeque.Reverse: TReverse;
begin
  Result := FBuffer.Reverse;
end;

function TGLiteDeque.ToArray: TArray;
begin
  Result := FBuffer.ToArray;
end;

procedure TGLiteDeque.Clear;
begin
  FBuffer.Clear;
end;

procedure TGLiteDeque.MakeEmpty;
begin
  FBuffer.MakeEmpty;
end;

function TGLiteDeque.IsEmpty: Boolean;
begin
  Result := FBuffer.Count = 0;
end;

function TGLiteDeque.NonEmpty: Boolean;
begin
  Result := FBuffer.Count <> 0;
end;

procedure TGLiteDeque.EnsureCapacity(aValue: SizeInt);
begin
  FBuffer.EnsureCapacity(aValue);
end;

procedure TGLiteDeque.TrimToFit;
begin
  FBuffer.TrimToFit;
end;

procedure TGLiteDeque.PushFirst(const aValue: T);
begin
  FBuffer.PushFirst(aValue);
end;

procedure TGLiteDeque.PushLast(const aValue: T);
begin
  FBuffer.PushLast(aValue);
end;

function TGLiteDeque.PopFirst: T;
begin
  Result := FBuffer.PopFirst;
end;

function TGLiteDeque.TryPopFirst(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPopFirst(aValue);
end;

function TGLiteDeque.PopLast: T;
begin
  Result := FBuffer.PopLast;
end;

function TGLiteDeque.TryPopLast(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPopLast(aValue);
end;

function TGLiteDeque.PeekFirst: T;
begin
  Result := FBuffer.PeekFirst;
end;

function TGLiteDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPeekFirst(aValue);
end;

function TGLiteDeque.PeekFirstItem: PItem;
begin
  Result := FBuffer.PeekFirstItem;
end;

function TGLiteDeque.TryPeekFirstItem(out aValue: PItem): Boolean;
begin
  Result := FBuffer.TryPeekFirstItem(aValue);
end;

function TGLiteDeque.PeekLast: T;
begin
  Result := FBuffer.PeekLast;
end;

function TGLiteDeque.TryPeekLast(out aValue: T): Boolean;
begin
  Result := FBuffer.TryPeekLast(aValue);
end;

function TGLiteDeque.PeekLastItem: PItem;
begin
  Result := FBuffer.PeekLastItem;
end;

function TGLiteDeque.TryPeekLastItem(out aValue: PItem): Boolean;
begin
  Result := FBuffer.TryPeekLastItem(aValue);
end;

procedure TGLiteDeque.Insert(aIndex: SizeInt; constref aValue: T);
begin
  if SizeUInt(aIndex) <= SizeUInt(FBuffer.Count) then
    InsertItem(aIndex, aValue)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteDeque.TryInsert(aIndex: SizeInt; constref aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) <= SizeUInt(FBuffer.Count);
  if Result then
    InsertItem(aIndex, aValue);
end;

function TGLiteDeque.Delete(aIndex: SizeInt): T;
begin
  if SizeUInt(aIndex) < SizeUInt(FBuffer.Count) then
    Result := DeleteItem(aIndex)
  else
    raise ELGListError.CreateFmt(SEIndexOutOfBoundsFmt, [aIndex]);
end;

function TGLiteDeque.TryDelete(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := SizeUInt(aIndex) < SizeUInt(FBuffer.Count);
  if Result then
    aValue := DeleteItem(aIndex);
end;

{ TGLiteThreadDeque }

procedure TGLiteThreadDeque.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadDeque.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadDeque.Destroy;
begin
  DoLock;
  try
    Finalize(FDeque);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadDeque.Clear;
begin
  DoLock;
  try
    FDeque.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadDeque.PushFirst(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushFirst(aValue);
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadDeque.PushLast(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadDeque.TryPopFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadDeque.TryPopLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadDeque.TryPeekLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadDeque.Lock: PDeque;
begin
  Result := @FDeque;
  DoLock;
end;

procedure TGLiteThreadDeque.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

{ TGLiteObjectDeque }

procedure TGLiteObjectDeque.CheckFreeItems;
var
  v: T;
begin
  if OwnsObjects then
    for v in FDeque do
      v.Free;
end;

function TGLiteObjectDeque.GetCapacity: SizeInt;
begin
  Result := FDeque.Capacity;
end;

function TGLiteObjectDeque.GetCount: SizeInt;
begin
  Result := FDeque.Count;
end;

function TGLiteObjectDeque.GetItem(aIndex: SizeInt): T;
begin
  Result := FDeque.GetItem(aIndex)
end;

function TGLiteObjectDeque.GetUncMutable(aIndex: SizeInt): PItem;
begin
  Result := FDeque.GetUncMutable(aIndex);
end;

procedure TGLiteObjectDeque.SetItem(aIndex: SizeInt; const aValue: T);
var
  p: PItem;
begin
  p := FDeque.GetMutable(aIndex);
  if p^ <> aValue then
    begin
      if OwnsObjects then
        p^.Free;
      p^ := aValue;
    end;
end;

class operator TGLiteObjectDeque.Initialize(var d: TGLiteObjectDeque);
begin
  d.OwnsObjects := True;
end;

class operator TGLiteObjectDeque.Copy(constref aSrc: TGLiteObjectDeque; var aDst: TGLiteObjectDeque);
begin
  if @aDst = @aSrc then
    exit;
  aDst.CheckFreeItems;
  aDst.FDeque := aSrc.FDeque;
  aDst.FOwnsObjects := aSrc.OwnsObjects;
end;

function TGLiteObjectDeque.InnerDeque: PDeque;
begin
  Result := @FDeque;
end;

function TGLiteObjectDeque.GetEnumerator: TEnumerator;
begin
  Result := FDeque.GetEnumerator;
end;

function TGLiteObjectDeque.GetReverseEnumerator: TReverseEnumerator;
begin
  Result := FDeque.GetReverseEnumerator;
end;

function TGLiteObjectDeque.Reverse: TReverse;
begin
  Result := FDeque.Reverse;
end;

function TGLiteObjectDeque.ToArray: TArray;
begin
  Result := FDeque.ToArray;
end;

procedure TGLiteObjectDeque.Clear;
begin
  CheckFreeItems;
  FDeque.Clear;
end;

function TGLiteObjectDeque.IsEmpty: Boolean;
begin
  Result := FDeque.IsEmpty;
end;

function TGLiteObjectDeque.NonEmpty: Boolean;
begin
  Result := FDeque.NonEmpty;
end;

procedure TGLiteObjectDeque.EnsureCapacity(aValue: SizeInt);
begin
  FDeque.EnsureCapacity(aValue);
end;

procedure TGLiteObjectDeque.TrimToFit;
begin
  FDeque.TrimToFit;
end;

procedure TGLiteObjectDeque.PushFirst(const aValue: T);
begin
  FDeque.PushFirst(aValue);
end;

procedure TGLiteObjectDeque.PushLast(const aValue: T);
begin
  FDeque.PushLast(aValue);
end;

function TGLiteObjectDeque.PopFirst: T;
begin
  Result := FDeque.PopFirst;
end;

function TGLiteObjectDeque.TryPopFirst(out aValue: T): Boolean;
begin
  Result := FDeque.TryPopFirst(aValue);
end;

function TGLiteObjectDeque.PopLast: T;
begin
  Result := FDeque.PopLast;
end;

function TGLiteObjectDeque.TryPopLast(out aValue: T): Boolean;
begin
  Result := FDeque.TryPopLast(aValue);
end;

function TGLiteObjectDeque.PeekFirst: T;
begin
  Result := FDeque.PeekFirst;
end;

function TGLiteObjectDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  Result := FDeque.TryPeekFirst(aValue);
end;

function TGLiteObjectDeque.PeekLast: T;
begin
  Result := FDeque.PeekLast;
end;

function TGLiteObjectDeque.TryPeekLast(out aValue: T): Boolean;
begin
  Result := FDeque.TryPeekLast(aValue);
end;

procedure TGLiteObjectDeque.Insert(aIndex: SizeInt; const aValue: T);
begin
  FDeque.Insert(aIndex, aValue);
end;

function TGLiteObjectDeque.TryInsert(aIndex: SizeInt; const aValue: T): Boolean;
begin
  Result := FDeque.TryInsert(aIndex, aValue);
end;

function TGLiteObjectDeque.Extract(aIndex: SizeInt): T;
begin
  Result := FDeque.Delete(aIndex);
end;

function TGLiteObjectDeque.TryExtract(aIndex: SizeInt; out aValue: T): Boolean;
begin
  Result := FDeque.TryDelete(aIndex, aValue);
end;

procedure TGLiteObjectDeque.Delete(aIndex: SizeInt);
var
  v: T;
begin
  v := FDeque.Delete(aIndex);
  if OwnsObjects then
    v.Free;
end;

function TGLiteObjectDeque.TryDelete(aIndex: SizeInt): Boolean;
var
  v: T;
begin
  Result := FDeque.TryDelete(aIndex, v);
  if Result and OwnsObjects then
    v.Free;
end;

{ TGLiteThreadObjectDeque }

procedure TGLiteThreadObjectDeque.DoLock;
begin
  System.EnterCriticalSection(FLock);
end;

constructor TGLiteThreadObjectDeque.Create;
begin
  System.InitCriticalSection(FLock);
end;

destructor TGLiteThreadObjectDeque.Destroy;
begin
  DoLock;
  try
    Finalize(FDeque);
    inherited;
  finally
    UnLock;
    System.DoneCriticalSection(FLock);
  end;
end;

procedure TGLiteThreadObjectDeque.Clear;
begin
  DoLock;
  try
    FDeque.Clear;
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadObjectDeque.PushFirst(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushFirst(aValue);
  finally
    UnLock;
  end;
end;

procedure TGLiteThreadObjectDeque.PushLast(const aValue: T);
begin
  DoLock;
  try
    FDeque.PushLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectDeque.TryPopFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectDeque.TryPopLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPopLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectDeque.TryPeekFirst(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekFirst(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectDeque.TryPeekLast(out aValue: T): Boolean;
begin
  DoLock;
  try
    Result := FDeque.TryPeekLast(aValue);
  finally
    UnLock;
  end;
end;

function TGLiteThreadObjectDeque.Lock: PDeque;
begin
  Result := @FDeque;
  DoLock;
end;

procedure TGLiteThreadObjectDeque.Unlock;
begin
  System.LeaveCriticalSection(FLock);
end;

end.

