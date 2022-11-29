{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic sorted multiset implementations on top of AVL tree.             *
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
unit lgTreeMultiSet;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}

interface

uses

  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgAbstractContainer,
  lgAvlTree;

type

  { TGAbstractTreeMultiSet: common multiset abstract ancestor class }
  generic TGAbstractTreeMultiSet<T> = class abstract(specialize TGAbstractMultiSet<T>)
  public
  type
    TAbstractTreeMultiSet = specialize TGAbstractTreeMultiSet<T>;

  protected
  type

    TTree = specialize TGCustomAvlTree<T, TEntry>;
    PNode = TTree.PNode;

    TEnumerator = class(TContainerEnumerator)
    protected
      FEnum: TTree.TEnumerator;
      FCurrKeyCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(tms: TAbstractTreeMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TReverseEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FCurrKeyCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(tms: TAbstractTreeMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TDistinctEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(tms: TAbstractTreeMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TEntryEnumerable = class(specialize TGAutoEnumerable<TEntry>)
    protected
      FOwner: TAbstractTreeMultiSet;
      FEnum: TTree.TEnumerator;
      function  GetCurrent: TEntry; override;
    public
      constructor Create(tms: TAbstractTreeMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TTailEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FCurrKeyCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(const aLowBound: T; tms: TAbstractTreeMultiSet; aInclusive: Boolean);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FTree: TTree;
    procedure EntryRemoved(p: PEntry);
    function  GetCapacity: SizeInt; override;
    function  DoGetEnumerator: TSpecEnumerator; override;
    procedure DoClear; override;
    procedure DoTrimToFit; override;
    procedure DoEnsureCapacity(aValue: SizeInt); override;
    function  FindEntry(const aKey: T): PEntry; override;
    function  FindOrAdd(const aKey: T; out p: PEntry): Boolean; override;
    function  DoSubEntry(const e: TEntry): Boolean; override;
    function  DoSymmSubEntry(const e: TEntry): Boolean; override;
    function  DoExtract(const aKey: T): Boolean; override;
    function  GetEntryCount: SizeInt; override;
    function  DoDoubleEntryCounters: SizeInt; override;
    function  GetDistinct: IEnumerable; override;
    function  GetEntries: IEntryEnumerable; override;
    procedure DoIntersect(aSet: TSpecMultiSet); override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
    function  DoExtractIf(aTest: TTest): TArray; override;
    function  DoExtractIf(aTest: TOnTest): TArray; override;
    function  DoExtractIf(aTest: TNestTest): TArray; override;
    function  FindNearestLT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestLE(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGT(const aPattern: T; out aValue: T): Boolean;
    function  FindNearestGE(const aPattern: T; out aValue: T): Boolean;
  public
    destructor Destroy; override;
    function  Reverse: IEnumerable; override;
    function  FindMin(out aValue: T): Boolean;
    function  FindMax(out aValue: T): Boolean;
  { returns True if exists element whose value greater then or equal to aValue (depending on aInclusive) }
    function FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean = True): Boolean;
  { returns True if exists element whose value less then aBound (or equal to aValue, depending on aInclusive) }
    function FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean = False): Boolean;
  { enumerates values whose are strictly less than(if not aInclusive) aHighBound }
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; virtual; abstract;
  { enumerates values whose are greater than or equal to(if aInclusive) aLowBound }
    function  Tail(const aLowBound: T; aInclusive: Boolean = True): IEnumerable;
  { enumerates values whose are greater than or equal to aLowBound and strictly less than aHighBound(by default)}
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      virtual; abstract;
  { returns sorted multiset whose items are strictly less than(if not aInclusive) aHighBound }
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TAbstractTreeMultiSet;
      virtual; abstract;
  { returns sorted multiset whose items are greater than or equal(if aInclusive) to aLowBound }
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TAbstractTreeMultiSet; virtual; abstract;
  { returns sorted multiset whose items are greater than or equal to aLowBound and strictly less than
    aHighBound(by default) }
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]):
      TAbstractTreeMultiSet; virtual; abstract;
  end;

  { TGBaseTreeMultiSet implements sorted multiset;
      functor TCmpRel (comparison relation) must provide:
        class function Less([const[ref]] L, R: T): Boolean; }
  generic TGBaseTreeMultiSet<T, TCmpRel> = class(specialize TGAbstractTreeMultiSet<T>)
  protected
  type
    TBaseTree = specialize TGAvlTree<T, TEntry, TCmpRel>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FCurrKeyCount: SizeInt;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; tms: TAbstractTreeMultiSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
                  overload;
    end;

    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor CreateCopy(aMultiSet: TGBaseTreeMultiSet);
    function Clone: TGBaseTreeMultiSet;  override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGBaseTreeMultiSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGBaseTreeMultiSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGBaseTreeMultiSet;
      override;
  end;

  { TGTreeMultiSet implements set, it assumes that type T implements TCmpRel }
  generic TGTreeMultiSet<T> = class(specialize TGBaseTreeMultiSet<T, T>);

  { TGComparableTreeMultiSet implements sorted multiset;
      it assumes that type T has defined comparison operator < }
  generic TGComparableTreeMultiSet<T> = class(specialize TGAbstractTreeMultiSet<T>)
  protected
  type
    TComparableTree = specialize TGComparableAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FCurrKeyCount: SizeInt;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; tms: TAbstractTreeMultiSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
                  overload;
    end;

    class function DoCompare(const L, R: T): Boolean; static;
  public
    class function Comparator: TLess; static; inline;
    constructor Create;
    constructor Create(aCapacity: SizeInt);
    constructor Create(const a: array of T);
    constructor Create(e: IEnumerable);
    constructor CreateCopy(aMultiSet: TGComparableTreeMultiSet);
    function Clone: TGComparableTreeMultiSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGComparableTreeMultiSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGComparableTreeMultiSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGComparableTreeMultiSet;
      override;
  end;

  generic TGObjectTreeMultiSet<T: class; TCmpRel> = class(specialize TGBaseTreeMultiSet<T, TCmpRel>)
  private
    FOwnsObjects: Boolean;
  protected
    function  DoSubEntry(const e: TEntry): Boolean; override;
    function  DoSymmSubEntry(const e: TEntry): Boolean; override;
    function  DoRemove(const aKey: T): Boolean; override;
    procedure DoClear; override;
    procedure EntryRemoved(p: PEntry);
    procedure DoIntersect(aSet: TSpecMultiSet); override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
  public
    constructor Create(aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aMultiSet: TGObjectTreeMultiSet);
    function  Clone: TGObjectTreeMultiSet; override;
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGObjTreeMultiSet<T: class> = class(specialize TGObjectTreeMultiSet<T, T>);

  { TGRegularTreeMultiSet implements sorted multiset with regular comparator }
  generic TGRegularTreeMultiSet<T> = class(specialize TGAbstractTreeMultiSet<T>)
  protected
  type
    TRegularTree = specialize TGRegularAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FLess: TLess;
      FCurrKeyCount: SizeInt;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; tms: TAbstractTreeMultiSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
                  overload;
    end;

  public
    constructor Create;
    constructor Create(aLess: TLess);
    constructor Create(aCapacity: SizeInt; aLess: TLess);
    constructor Create(const a: array of T; aLess: TLess);
    constructor Create(e: IEnumerable; aLess: TLess);
    constructor CreateCopy(aMultiSet: TGRegularTreeMultiSet);
    function Comparator: TLess; inline;
    function Clone: TGRegularTreeMultiSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGRegularTreeMultiSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGRegularTreeMultiSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGRegularTreeMultiSet;
      override;
  end;

  { TGDelegatedTreeMultiSet implements (sorted) multiset with regular comparator }
  generic TGDelegatedTreeMultiSet<T> = class(specialize TGAbstractTreeMultiSet<T>)
  protected
  type
    TDelegatedTree = specialize TGDelegatedAvlTree<T, TEntry>;

    THeadEnumerable = class(TContainerEnumerable)
    protected
      FEnum: TTree.TEnumerator;
      FHighBound: T;
      FLess: TOnLess;
      FCurrKeyCount: SizeInt;
      FInclusive,
      FDone: Boolean;
      function  GetCurrent: T; override;
    public
      constructor Create(const aHighBound: T; tms: TAbstractTreeMultiSet; aInclusive: Boolean); overload;
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TRangeEnumerable = class(THeadEnumerable)
      constructor Create(const aLowBound, aHighBound: T; tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
                  overload;
    end;

  public
    constructor Create;
    constructor Create(aLess: TOnLess);
    constructor Create(aCapacity: SizeInt; aLess: TOnLess);
    constructor Create(const a: array of T; aLess: TOnLess);
    constructor Create(e: IEnumerable; aLess: TOnLess);
    constructor CreateCopy(aMultiSet: TGDelegatedTreeMultiSet);
    function Comparator: TOnLess; inline;
    function Clone: TGDelegatedTreeMultiSet; override;
    function Head(const aHighBound: T; aInclusive: Boolean = False): IEnumerable; override;
    function Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): IEnumerable;
      override;
    function HeadSet(const aHighBound: T; aInclusive: Boolean = False): TGDelegatedTreeMultiSet; override;
    function TailSet(const aLowBound: T; aInclusive: Boolean = True): TGDelegatedTreeMultiSet; override;
    function SubSet(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds = [rbLow]): TGDelegatedTreeMultiSet;
      override;
  end;

implementation
{$B-}{$COPERATORS ON}

{ TGAbstractTreeMultiSet.TEnumerator }

function TGAbstractTreeMultiSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeMultiSet.TEnumerator.Create(tms: TAbstractTreeMultiSet);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
end;

destructor TGAbstractTreeMultiSet.TEnumerator.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeMultiSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      Result := FEnum.MoveNext;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
end;

procedure TGAbstractTreeMultiSet.TEnumerator.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGAbstractTreeMultiSet.TReverseEnumerable }

function TGAbstractTreeMultiSet.TReverseEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeMultiSet.TReverseEnumerable.Create(tms: TAbstractTreeMultiSet);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetReverseEnumerator;
end;

destructor TGAbstractTreeMultiSet.TReverseEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeMultiSet.TReverseEnumerable.MoveNext: Boolean;
begin
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      Result := FEnum.MoveNext;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
end;

procedure TGAbstractTreeMultiSet.TReverseEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGAbstractTreeMultiSet.TDistinctEnumerable }

function TGAbstractTreeMultiSet.TDistinctEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeMultiSet.TDistinctEnumerable.Create(tms: TAbstractTreeMultiSet);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
end;

destructor TGAbstractTreeMultiSet.TDistinctEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeMultiSet.TDistinctEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractTreeMultiSet.TDistinctEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractTreeMultiSet.TEntryEnumerable }

function TGAbstractTreeMultiSet.TEntryEnumerable.GetCurrent: TEntry;
begin
  Result := FEnum.Current^.Data;
end;

constructor TGAbstractTreeMultiSet.TEntryEnumerable.Create(tms: TAbstractTreeMultiSet);
begin
  inherited Create;
  FOwner := tms;
  FEnum := tms.FTree.GetEnumerator;
end;

destructor TGAbstractTreeMultiSet.TEntryEnumerable.Destroy;
begin
  FEnum.Free;
  FOwner.EndIteration;
  inherited;
end;

function TGAbstractTreeMultiSet.TEntryEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractTreeMultiSet.TEntryEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractTreeMultiSet.TTailEnumerable }

function TGAbstractTreeMultiSet.TTailEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGAbstractTreeMultiSet.TTailEnumerable.Create(const aLowBound: T; tms: TAbstractTreeMultiSet;
  aInclusive: Boolean);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumeratorAt(aLowBound, aInclusive);
end;

destructor TGAbstractTreeMultiSet.TTailEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractTreeMultiSet.TTailEnumerable.MoveNext: Boolean;
begin
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      Result := FEnum.MoveNext;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
end;

procedure TGAbstractTreeMultiSet.TTailEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGAbstractTreeMultiSet }

procedure TGAbstractTreeMultiSet.EntryRemoved(p: PEntry);
begin
  FCount -= p^.Count;
end;

function TGAbstractTreeMultiSet.GetCapacity: SizeInt;
begin
  Result := FTree.Capacity;
end;

function TGAbstractTreeMultiSet.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGAbstractTreeMultiSet.DoClear;
begin
  FTree.Clear;
  FCount := 0;
end;

procedure TGAbstractTreeMultiSet.DoTrimToFit;
begin
  FTree.TrimToFit;
end;

procedure TGAbstractTreeMultiSet.DoEnsureCapacity(aValue: SizeInt);
begin
  FTree.EnsureCapacity(aValue);
end;

function TGAbstractTreeMultiSet.FindEntry(const aKey: T): PEntry;
var
  Node: PNode;
begin
  Node := FTree.Find(aKey);
  if Node <> nil then
    Result := @Node^.Data
  else
    Result := nil;
end;

function TGAbstractTreeMultiSet.FindOrAdd(const aKey: T; out p: PEntry): Boolean;
var
  Node: PNode;
begin
  Result := FTree.FindOrAdd(aKey, Node);
  p := @Node^.Data;
  if not Result then
    p^.Count := 1;
end;

function TGAbstractTreeMultiSet.DoSubEntry(const e: TEntry): Boolean;
var
  Node: PNode;
begin
  Node := FTree.Find(e.Key);
  if Node <> nil then
   begin
     if Node^.Data.Count > e.Count then
       begin
         FCount -= e.Count;
         Node^.Data.Count -= e.Count;
       end
     eLse
       begin
         FCount -= Node^.Data.Count;
         FTree.RemoveNode(Node);
         exit(True);
       end;
   end;
  Result := False;
end;

function TGAbstractTreeMultiSet.DoSymmSubEntry(const e: TEntry): Boolean;
var
  Node: PNode;
begin
  if FTree.FindOrAdd(e.Key, Node) then
    begin
      if Node^.Data.Count > e.Count then
        begin
          FCount -= e.Count;
          Node^.Data.Count -= e.Count;
        end
      else
        if Node^.Data.Count < e.Count then
          begin
            FCount -= Node^.Data.Count shl 1 - e.Count;
            Node^.Data.Count := e.Count - Node^.Data.Count;
          end
        else  // counts equals
          begin
            FCount -= Node^.Data.Count;
            FTree.Remove(e.Key);
            exit(True);
          end;
    end
  else
    begin
      //Node^.Data.Key := e.Key;
      Node^.Data.Count := e.Count;
      FCount += e.Count;
    end;
  Result := False;
end;

function TGAbstractTreeMultiSet.DoExtract(const aKey: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.Find(aKey);
  Result := Node <> nil;
  if Result then
    begin
      Dec(Node^.Data.Count);
      Dec(FCount);
      if Node^.Data.Count = 0 then
        FTree.RemoveNode(Node);
    end;
end;

function TGAbstractTreeMultiSet.GetEntryCount: SizeInt;
begin
  Result := FTree.Count;
end;

function TGAbstractTreeMultiSet.DoDoubleEntryCounters: SizeInt;
var
  Node: PNode;
begin
  Result := ElemCount;
  FCount += Result;
with FTree.GetEnumerator do
  try
    while MoveNext do
      begin
        Node := Current;
        Node^.Data.Count += Node^.Data.Count;
      end;
  finally
    Free;
  end;
end;

function TGAbstractTreeMultiSet.GetDistinct: IEnumerable;
begin
  Result := TDistinctEnumerable.Create(Self);
end;

function TGAbstractTreeMultiSet.GetEntries: IEntryEnumerable;
begin
  Result := TEntryEnumerable.Create(Self);
end;

procedure TGAbstractTreeMultiSet.DoIntersect(aSet: TSpecMultiSet);
var
  {%H-}I: TIntersectHelper;
begin
  I.FSet := Self;
  I.FOtherSet := aSet;
  FTree.RemoveIf(@I.OnIntersect, @EntryRemoved);
  Assert(@I = @I);//to supress hints
end;

function TGAbstractTreeMultiSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractTreeMultiSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractTreeMultiSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractTreeMultiSet.DoExtractIf(aTest: TTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

function TGAbstractTreeMultiSet.DoExtractIf(aTest: TOnTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

function TGAbstractTreeMultiSet.DoExtractIf(aTest: TNestTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTree.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

function TGAbstractTreeMultiSet.FindNearestLT(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindLess(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeMultiSet.FindNearestLE(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindLessOrEqual(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeMultiSet.FindNearestGT(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindGreater(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

function TGAbstractTreeMultiSet.FindNearestGE(const aPattern: T; out aValue: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.FindGreaterOrEqual(aPattern);
  Result := Node <> nil;
  if Result then
    aValue := Node^.Data.Key;
end;

destructor TGAbstractTreeMultiSet.Destroy;
begin
  DoClear;
  FTree.Free;
  inherited;
end;

function TGAbstractTreeMultiSet.Reverse: IEnumerable;
begin
  BeginIteration;
  Result := TReverseEnumerable.Create(Self);
end;

function TGAbstractTreeMultiSet.FindMin(out aValue: T): Boolean;
var
  p: PNode;
begin
  p := FTree.Lowest;
  Result := p <> nil;
  if Result then
    aValue := p^.Data.Key;
end;

function TGAbstractTreeMultiSet.FindMax(out aValue: T): Boolean;
var
  p: PNode;
begin
  p := FTree.Highest;
  Result := p <> nil;
  if Result then
    aValue := p^.Data.Key;
end;

function TGAbstractTreeMultiSet.FindCeil(const aValue: T; out aCeil: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestGE(aValue, aCeil)
  else
    Result := FindNearestGT(aValue, aCeil);
end;

function TGAbstractTreeMultiSet.FindFloor(const aValue: T; out aFloor: T; aInclusive: Boolean): Boolean;
begin
  if aInclusive then
    Result := FindNearestLE(aValue, aFloor)
  else
    Result := FindNearestLT(aValue, aFloor);
end;

function TGAbstractTreeMultiSet.Tail(const aLowBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := TTailEnumerable.Create(aLowBound, Self, aInclusive);
end;

{ TGBaseTreeMultiSet.THeadEnumerable }

function TGBaseTreeMultiSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGBaseTreeMultiSet.THeadEnumerable.Create(const aHighBound: T; tms: TAbstractTreeMultiSet;
  aInclusive: Boolean);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGBaseTreeMultiSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGBaseTreeMultiSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone then
    exit(False);
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      if not FEnum.MoveNext then
        exit(False);
      if FInclusive then
        Result := not TCmpRel.Less(FHighBound, FEnum.Current^.Data.Key)
      else
        Result := TCmpRel.Less(FEnum.Current^.Data.Key, FHighBound);
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
  FDone := not Result;
end;

procedure TGBaseTreeMultiSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGBaseTreeMultiSet.TRangeEnumerable }

constructor TGBaseTreeMultiSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T;
  tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGBaseTreeMultiSet }

class function TGBaseTreeMultiSet.DoCompare(const L, R: T): Boolean;
begin
  Result := TCmpRel.Less(L, R);
end;

class function TGBaseTreeMultiSet.Comparator: TLess;
begin
  Result := @DoCompare;
end;

constructor TGBaseTreeMultiSet.Create;
begin
  FTree := TBaseTree.Create;
end;

constructor TGBaseTreeMultiSet.Create(aCapacity: SizeInt);
begin
  FTree := TBaseTree.Create(aCapacity);
end;

constructor TGBaseTreeMultiSet.Create(const a: array of T);
begin
  FTree := TBaseTree.Create;
  DoAddAll(a);
end;

constructor TGBaseTreeMultiSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TGBaseTreeMultiSet then
    CreateCopy(TGBaseTreeMultiSet(o))
  else
    begin
      if o is TSpecMultiSet then
        Create(TSpecMultiSet(o).EntryCount)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGBaseTreeMultiSet.CreateCopy(aMultiSet: TGBaseTreeMultiSet);
begin
  FTree := TBaseTree(aMultiSet.FTree).Clone;
  FCount := aMultiSet.Count;
end;

function TGBaseTreeMultiSet.Clone: TGBaseTreeMultiSet;
begin
  Result := TGBaseTreeMultiSet.CreateCopy(Self);
end;

function TGBaseTreeMultiSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGBaseTreeMultiSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGBaseTreeMultiSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGBaseTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGBaseTreeMultiSet.Create;
  with THeadEnumerable.Create(aHighBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGBaseTreeMultiSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGBaseTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGBaseTreeMultiSet.Create;
  with TTailEnumerable.Create(aLowBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGBaseTreeMultiSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGBaseTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGBaseTreeMultiSet.Create;
  with TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

{ TGComparableTreeMultiSet.THeadEnumerable }

function TGComparableTreeMultiSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGComparableTreeMultiSet.THeadEnumerable.Create(const aHighBound: T; tms: TAbstractTreeMultiSet;
  aInclusive: Boolean);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGComparableTreeMultiSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGComparableTreeMultiSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone then
    exit(False);
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      if not FEnum.MoveNext then
        exit(False);
      if FInclusive then
        Result := not(FHighBound < FEnum.Current^.Data.Key)
      else
        Result := FEnum.Current^.Data.Key < FHighBound;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
  FDone := not Result;
end;

procedure TGComparableTreeMultiSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGComparableTreeMultiSet.TRangeEnumerable }

constructor TGComparableTreeMultiSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T;
  tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGComparableTreeMultiSet }

class function TGComparableTreeMultiSet.DoCompare(const L, R: T): Boolean;
begin
  Result := L < R;
end;

class function TGComparableTreeMultiSet.Comparator: TLess;
begin
  Result := @DoCompare;
end;

constructor TGComparableTreeMultiSet.Create;
begin
  FTree := TComparableTree.Create;
end;

constructor TGComparableTreeMultiSet.Create(aCapacity: SizeInt);
begin
  FTree := TComparableTree.Create(aCapacity);
end;

constructor TGComparableTreeMultiSet.Create(const a: array of T);
begin
  FTree := TComparableTree.Create;
  DoAddAll(a);
end;

constructor TGComparableTreeMultiSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TGComparableTreeMultiSet then
    CreateCopy(TGComparableTreeMultiSet(o))
  else
    begin
      if o is TSpecMultiSet then
        Create(TSpecMultiSet(o).EntryCount)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGComparableTreeMultiSet.CreateCopy(aMultiSet: TGComparableTreeMultiSet);
begin
  FTree := TComparableTree(aMultiSet.FTree).Clone;
  FCount := aMultiSet.Count;
end;

function TGComparableTreeMultiSet.Clone: TGComparableTreeMultiSet;
begin
  Result := TGComparableTreeMultiSet.CreateCopy(Self);
end;

function TGComparableTreeMultiSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGComparableTreeMultiSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGComparableTreeMultiSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGComparableTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGComparableTreeMultiSet.Create;
  with THeadEnumerable.Create(aHighBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGComparableTreeMultiSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGComparableTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGComparableTreeMultiSet.Create;
  with TTailEnumerable.Create(aLowBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGComparableTreeMultiSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGComparableTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGComparableTreeMultiSet.Create;
  with TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

{ TGObjectTreeMultiSet }

function TGObjectTreeMultiSet.DoSubEntry(const e: TEntry): Boolean;
begin
  Result := inherited DoSubEntry(e);
  if Result and OwnsObjects then
    e.Key.Free;
end;

function TGObjectTreeMultiSet.DoSymmSubEntry(const e: TEntry): Boolean;
begin
  Result := inherited DoSymmSubEntry(e);
  if Result and OwnsObjects then
    e.Key.Free;
end;

function TGObjectTreeMultiSet.DoRemove(const aKey: T): Boolean;
var
  Node: PNode;
begin
  Node := FTree.Find(aKey);
  Result := Node <> nil;
  if Result then
    begin
      Dec(Node^.Data.Count);
      Dec(FCount);
      if Node^.Data.Count = 0 then
        begin
          FTree.RemoveNode(Node);
          if OwnsObjects then
            aKey.Free;
        end;
    end;
end;

procedure TGObjectTreeMultiSet.DoClear;
var
  Node: PNode;
begin
  if OwnsObjects then
    for Node in FTree do
      Node^.Data.Key.Free;
  inherited;
end;

procedure TGObjectTreeMultiSet.EntryRemoved(p: PEntry);
begin
  FCount -= p^.Count;
  if OwnsObjects then
    p^.Key.Free;
end;

procedure TGObjectTreeMultiSet.DoIntersect(aSet: TSpecMultiSet);
var
  {%H-}I: TIntersectHelper;
begin
  I.FSet := Self;
  I.FOtherSet := aSet;
  FTree.RemoveIf(@I.OnIntersect, @EntryRemoved);
  Assert(@I = @I);//to supress hints
end;

function TGObjectTreeMultiSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGObjectTreeMultiSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGObjectTreeMultiSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := ElemCount;
  FTree.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

constructor TGObjectTreeMultiSet.Create(aOwnsObjects: Boolean);
begin
  FTree := TBaseTree.Create;
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeMultiSet.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  FTree := TBaseTree.Create(aCapacity);
  OwnsObjects := aOwnsObjects;
end;

constructor TGObjectTreeMultiSet.Create(const a: array of T; aOwnsObjects: Boolean);
begin
  FTree := TBaseTree.Create;
  OwnsObjects := aOwnsObjects;
  DoAddAll(a);
end;

constructor TGObjectTreeMultiSet.Create(e: IEnumerable; aOwnsObjects: Boolean);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TGObjectTreeMultiSet then
    CreateCopy(TGObjectTreeMultiSet(o))
  else
    begin
      OwnsObjects := aOwnsObjects;
      if o is TSpecMultiSet then
        Create(TSpecMultiSet(o).EntryCount)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGObjectTreeMultiSet.CreateCopy(aMultiSet: TGObjectTreeMultiSet);
begin
  FTree := TBaseTree(aMultiSet.FTree).Clone;
  FCount := aMultiSet.Count;
  OwnsObjects := aMultiSet.OwnsObjects;
end;

function TGObjectTreeMultiSet.Clone: TGObjectTreeMultiSet;
begin
  Result := TGObjectTreeMultiSet.CreateCopy(Self);
end;

{ TGRegularTreeMultiSet.THeadEnumerable }

function TGRegularTreeMultiSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGRegularTreeMultiSet.THeadEnumerable.Create(const aHighBound: T; tms: TAbstractTreeMultiSet;
  aInclusive: Boolean);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
  FLess := TRegularTree(tms.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGRegularTreeMultiSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGRegularTreeMultiSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone then
    exit(False);
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      if not FEnum.MoveNext then
        exit(False);
      if FInclusive then
        Result := not FLess(FHighBound, FEnum.Current^.Data.Key)
      else
        Result := FLess(FEnum.Current^.Data.Key, FHighBound);
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
  FDone := not Result;
end;

procedure TGRegularTreeMultiSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGRegularTreeMultiSet.TRangeEnumerable }

constructor TGRegularTreeMultiSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T;
  tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FLess := TRegularTree(tms.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGRegularTreeMultiSet }

constructor TGRegularTreeMultiSet.Create;
begin
  FTree := TRegularTree.Create(TDefaults.Less);
end;

constructor TGRegularTreeMultiSet.Create(aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
end;

constructor TGRegularTreeMultiSet.Create(aCapacity: SizeInt; aLess: TLess);
begin
  FTree := TRegularTree.Create(aCapacity, aLess);
end;

constructor TGRegularTreeMultiSet.Create(const a: array of T; aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
  DoAddAll(a);
end;

constructor TGRegularTreeMultiSet.Create(e: IEnumerable; aLess: TLess);
begin
  FTree := TRegularTree.Create(aLess);
  DoAddAll(e);
end;

constructor TGRegularTreeMultiSet.CreateCopy(aMultiSet: TGRegularTreeMultiSet);
begin
  FTree := TRegularTree(aMultiSet.FTree).Clone;
  FCount := aMultiSet.Count;
end;

function TGRegularTreeMultiSet.Comparator: TLess;
begin
  Result := TRegularTree(FTree).Comparator;
end;

function TGRegularTreeMultiSet.Clone: TGRegularTreeMultiSet;
begin
  Result := TGRegularTreeMultiSet.CreateCopy(Self);
end;

function TGRegularTreeMultiSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGRegularTreeMultiSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGRegularTreeMultiSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGRegularTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGRegularTreeMultiSet.Create(Comparator);
  with THeadEnumerable.Create(aHighBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGRegularTreeMultiSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGRegularTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGRegularTreeMultiSet.Create(Comparator);
  with TTailEnumerable.Create(aLowBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGRegularTreeMultiSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGRegularTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGRegularTreeMultiSet.Create(Comparator);
  with TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

{ TGDelegatedTreeMultiSet.THeadEnumerable }

function TGDelegatedTreeMultiSet.THeadEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Data.Key;
end;

constructor TGDelegatedTreeMultiSet.THeadEnumerable.Create(const aHighBound: T; tms: TAbstractTreeMultiSet;
  aInclusive: Boolean);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumerator;
  FLess := TDelegatedTree(tms.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := aInclusive;
end;

destructor TGDelegatedTreeMultiSet.THeadEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGDelegatedTreeMultiSet.THeadEnumerable.MoveNext: Boolean;
begin
  if FDone then
    exit(False);
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      if not FEnum.MoveNext then
        exit(False);
      if FInclusive then
        Result := not FLess(FHighBound, FEnum.Current^.Data.Key)
      else
        Result := FLess(FEnum.Current^.Data.Key, FHighBound);
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Data.Count);
    end;
  FDone := not Result;
end;

procedure TGDelegatedTreeMultiSet.THeadEnumerable.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGDelegatedTreeMultiSet.TRangeEnumerable }

constructor TGDelegatedTreeMultiSet.TRangeEnumerable.Create(const aLowBound, aHighBound: T;
  tms: TAbstractTreeMultiSet; aBounds: TRangeBounds);
begin
  inherited Create(tms);
  FEnum := tms.FTree.GetEnumeratorAt(aLowBound, rbLow in aBounds);
  FLess := TDelegatedTree(tms.FTree).Comparator;
  FHighBound := aHighBound;
  FInclusive := rbHigh in aBounds;
end;

{ TGDelegatedTreeMultiSet }

constructor TGDelegatedTreeMultiSet.Create;
begin
  FTree := TDelegatedTree.Create(TDefaults.OnLess);
end;

constructor TGDelegatedTreeMultiSet.Create(aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
end;

constructor TGDelegatedTreeMultiSet.Create(aCapacity: SizeInt; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aCapacity, aLess);
end;

constructor TGDelegatedTreeMultiSet.Create(const a: array of T; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
  DoAddAll(a);
end;

constructor TGDelegatedTreeMultiSet.Create(e: IEnumerable; aLess: TOnLess);
begin
  FTree := TDelegatedTree.Create(aLess);
  DoAddAll(e);
end;

constructor TGDelegatedTreeMultiSet.CreateCopy(aMultiSet: TGDelegatedTreeMultiSet);
begin
  FTree := TDelegatedTree(aMultiSet.FTree).Clone;
  FCount := aMultiSet.Count;
end;

function TGDelegatedTreeMultiSet.Comparator: TOnLess;
begin
  Result := TDelegatedTree(FTree).Comparator;
end;

function TGDelegatedTreeMultiSet.Clone: TGDelegatedTreeMultiSet;
begin
  Result := TGDelegatedTreeMultiSet.CreateCopy(Self);
end;

function TGDelegatedTreeMultiSet.Head(const aHighBound: T; aInclusive: Boolean): IEnumerable;
begin
  BeginIteration;
  Result := THeadEnumerable.Create(aHighBound, Self, aInclusive);
end;

function TGDelegatedTreeMultiSet.Range(const aLowBound, aHighBound: T; aIncludeBounds: TRangeBounds): IEnumerable;
begin
  BeginIteration;
  Result := TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds);
end;

function TGDelegatedTreeMultiSet.HeadSet(const aHighBound: T; aInclusive: Boolean): TGDelegatedTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGDelegatedTreeMultiSet.Create(Comparator);
  with THeadEnumerable.Create(aHighBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGDelegatedTreeMultiSet.TailSet(const aLowBound: T; aInclusive: Boolean): TGDelegatedTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGDelegatedTreeMultiSet.Create(Comparator);
  with TTailEnumerable.Create(aLowBound, Self, aInclusive) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

function TGDelegatedTreeMultiSet.SubSet(const aLowBound, aHighBound: T;
  aIncludeBounds: TRangeBounds): TGDelegatedTreeMultiSet;
var
  e: TEntry;
begin
  Result := TGDelegatedTreeMultiSet.Create(Comparator);
  with TRangeEnumerable.Create(aLowBound, aHighBound, Self, aIncludeBounds) do
    try
      while MoveNext do
        begin
          e := FEnum.Current^.Data;
          Result[e.Key] := e.Count;
        end;
    finally
      Free;
    end;
end;

end.

