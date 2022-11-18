{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic bijective map implementation on top of hash table.              *
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
unit lgBiMap;

{$mode objfpc}{$H+}
{$INLINE ON}

interface

uses
  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgAbstractContainer,
  lgStrConst;

type

  generic IGInverseMap<TKey, TValue> = interface(specialize IGMap<TValue, TKey>)
  ['{12C18769-51E6-4FA8-8AC7-904B46B86D9F}']
  end;

  generic IGInverseReadOnlyMap<TKey, TValue> = interface(specialize IGReadOnlyMap<TValue, TKey>)
  ['{E4B4DE39-209C-4AB0-8F31-A8B1C1CFF654}']
  end;

  { TGHashBiMap implements bijective map(i.e. a one-to-one correspondence between keys and values)
     on top of hashtable;

      functor TKeyEqRel(key equality relation) must provide:
        class function HashCode([const[ref]] k: TKey): SizeInt;
        class function Equal([const[ref]] L, R: TKey): Boolean;

      functor TValueEqRel(value equality relation) must provide:
        class function HashCode([const[ref]] v: TValue): SizeInt;
        class function Equal([const[ref]] L, R: TValue): Boolean;  }
  generic TGHashBiMap<TKey, TValue, TKeyEqRel, TValueEqRel> = class(TSimpleIterable,
    specialize IGMap<TKey, TValue>, specialize IGInverseMap<TKey, TValue>,
    specialize IGReadOnlyMap<TKey, TValue>, specialize IGInverseReadOnlyMap<TKey, TValue>)
  {must be  generic TGHashBiMap<TKey, TValue> = class abstract(
              specialize TGContainer<specialize TGMapEntry<TKey, TValue>>), but :( ... see #0033788}
  public
  type
    TSpecBiMap          = specialize TGHashBiMap<TKey, TValue, TKeyEqRel, TValueEqRel>;
    TEntry              = specialize TGMapEntry<TKey, TValue>;
    TInverseEntry       = specialize TGMapEntry<TValue, TKey>;
    IKeyEnumerable      = specialize IGEnumerable<TKey>;
    IValueEnumerable    = specialize IGEnumerable<TValue>;
    IEntryEnumerable    = specialize IGEnumerable<TEntry>;
    IInvEntryEnumerable = specialize IGEnumerable<TInverseEntry>;
    TEntryArray         = specialize TGArray<TEntry>;
    TKeyCollection      = specialize TGAbstractCollection<TKey>;
    TValueCollection    = specialize TGAbstractCollection<TValue>;
    IKeyCollection      = specialize IGCollection<TKey>;
    IValueCollection    = specialize IGCollection<TValue>;
    IInverseMap         = specialize IGInverseMap<TKey, TValue>;
    IInverseRoMap       = specialize IGInverseReadOnlyMap<TKey, TValue>;

  protected
  type

    TNode  = record
      KeyHash,
      ValueHash,
      NextKey,
      NextValue: SizeInt;
      Data: TEntry;
    end;

    TNodeList  = array of TNode;
    TChainList = array of SizeInt;

  const
    {$PUSH}{$J+}
    MAX_CAPACITY: SizeInt = (MAX_CONTAINER_SIZE shr 2) div SizeOf(TNode);
    {$POP}
  type
    TKeyEnumerable = class(specialize TGAutoEnumerable<TKey>)
    protected
      FOwner: TGHashBiMap;
      FList:  TNodeList;
      FCurrIndex,
      FLastIndex: SizeInt;
      function GetCurrent: TKey; override;
    public
      constructor Create(aMap: TGHashBiMap);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TValueEnumerable = class(specialize TGAutoEnumerable<TValue>)
    protected
      FOwner: TGHashBiMap;
      FList:  TNodeList;
      FCurrIndex,
      FLastIndex: SizeInt;
      function GetCurrent: TValue; override;
    public
      constructor Create(aMap: TGHashBiMap);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TEntryEnumerable = class(specialize TGAutoEnumerable<TEntry>)
    protected
      FOwner: TGHashBiMap;
      FList:  TNodeList;
      FCurrIndex,
      FLastIndex: SizeInt;
      function GetCurrent: TEntry; override;
    public
      constructor Create(aMap: TGHashBiMap);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TInvEntryEnumerable = class(specialize TGAutoEnumerable<TInverseEntry>)
    protected
      FOwner: TGHashBiMap;
      FList:  TNodeList;
      FCurrIndex,
      FLastIndex: SizeInt;
      function GetCurrent: TInverseEntry; override;
    public
      constructor Create(aMap: TGHashBiMap);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FNodeList: TNodeList;
    FKeyChains,
    FValueChains: TChainList;
    FCount: SizeInt;
    function  _GetRef: TObject;
    function  GetCount: SizeInt; inline;
    function  GetCapacity: SizeInt; inline;
    procedure InitialAlloc; inline;
    procedure Rehash;
    procedure Resize(aNewCapacity: SizeInt);
    procedure Expand;
    procedure RemoveFromKeyChain(aIndex: SizeInt);
    procedure RemoveFromValueChain(aIndex: SizeInt);
    procedure FixKeyChain(aOldIndex, aNewIndex: SizeInt);
    procedure FixValueChain(aOldIndex, aNewIndex: SizeInt);
    function  DoFindKey(const aKey: TKey; aHash: SizeInt): SizeInt;
    function  DoFindValue(const aValue: TValue; aHash: SizeInt): SizeInt;
    function  FindKey(const aKey: TKey): SizeInt; inline;
    function  FindValue(const aValue: TValue): SizeInt; inline;
    procedure DoAddData(const aKey: TKey; const aValue: TValue; aKeyHash, aValHash: SizeInt);
    procedure DoRemove(aIndex: SizeInt);
    procedure DoClear; virtual;
    procedure DoEnsureCapacity(aValue: SizeInt);
    procedure DoTrimToFit;
    function  DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
    function  DoAddAll(const a: array of TEntry): SizeInt;
    function  DoAddAll(e: IEntryEnumerable): SizeInt;
    function  TryAddOrSetValue(const aKey: TKey; const aValue: TValue): Boolean;
    function  TryAddOrSetKey(const aValue: TValue; const aKey: TKey): Boolean;
    procedure DoAddOrSetValue(const aKey: TKey; const aValue: TValue);
    procedure DoAddOrSetKey(const aValue: TValue; const aKey: TKey);
    function  DoExtractKey(const aKey: TKey; out v: TValue): Boolean;
    function  DoRemoveKey(const aKey: TKey): Boolean; virtual;
    function  DoRemoveKeys(const a: array of TKey): SizeInt;
    function  DoRemoveKeys(e: IKeyEnumerable): SizeInt;
    function  DoExtractValue(const aValue: TValue; out k: TKey): Boolean;
    function  DoRemoveValue(const aValue: TValue): Boolean; virtual;
    function  DoRemoveValues(const a: array of TValue): SizeInt;
    function  DoRemoveValues(e: IValueEnumerable): SizeInt;
    function  DoReplaceValue(const aKey: TKey; const aNewValue: TValue): Boolean; virtual;
    function  DoReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean; virtual;
    procedure DoRetainAll({%H-}c: IKeyCollection); virtual;
    procedure DoRetainAllVal({%H-}c: IValueCollection); virtual;
    function  GetKeys: IKeyEnumerable;
    function  GetValues: IValueEnumerable;
    function  GetEntries: IEntryEnumerable;
  { returns True and add aValue and aKey only if keys do not contain aKey and values do not contain aValue }
    function  AddInverse(const aValue: TValue; const aKey: TKey): Boolean;
    class constructor Init;
  public
    constructor Create;
    constructor Create(const a: array of TEntry);
    constructor Create(e: IEntryEnumerable);
    constructor Create(aCapacity: SizeInt);
    constructor Create(aCapacity: SizeInt; const a: array of TEntry);
    constructor Create(aCapacity: SizeInt; e: IEntryEnumerable);
    constructor CreateCopy(aMap: TGHashBiMap);
    destructor  Destroy; override;
    function  IsEmpty: Boolean;
    function  NonEmpty: Boolean;
    procedure Clear;
    procedure EnsureCapacity(aValue: SizeInt);
    procedure TrimToFit;
    function  Contains(const aKey: TKey): Boolean;
    function  NonContains(const aKey: TKey): Boolean;
    function  ContainsValue(const aValue: TValue): Boolean;
    function  NonContainsValue(const aValue: TValue): Boolean;
  { will raise ELGMapError if not contains aKey }
    function  GetValue(const aKey: TKey): TValue; inline;
  { will raise ELGMapError if not contains aKey }
    function  GetKey(const aValue: TValue): TKey; inline;
    function  TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
    function  TryGetKey(const aValue: TValue; out aKey: TKey): Boolean;
    function  GetValueDef(const aKey: TKey; const aDefault: TValue): TValue; inline;
    function  GetKeyDef(const aValue: TValue; const aDefault: TKey): TKey; inline;
  { returns True and maps aValue to aKey only if not contains aKey and not contains aValue }
    function  Add(const aKey: TKey; const aValue: TValue): Boolean;
  { returns True and maps e.Value to e.Key only if not contains e.Key and not contains e.Value }
    function  Add(const e: TEntry): Boolean;
  { will raise ELGMapError if contains aValue }
    procedure AddOrSetValue(const aKey: TKey; const aValue: TValue);
  { will return False if contains aValue }
    function  TryAddOrSetValue(const e: TEntry): Boolean;
  { will raise ELGMapError if contains aValue }
    procedure AddOrSetKey(const aValue: TValue; const aKey: TKey);
  { will return False if contains aValue }
    function  TryAddOrSetKey(const e: TInverseEntry): Boolean;
  { will add only entries which keys and values are not contained in the map }
    function  AddAll(const a: array of TEntry): SizeInt;
    function  AddAll(e: IEntryEnumerable): SizeInt;
  { returns True if contains aKey and not contains aNewValue }
    function  Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
  { returns True if contains aValue and not contains aNewKey }
    function  ReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean;
    function  Extract(const aKey: TKey; out v: TValue): Boolean;
    function  ExtractValue(const aValue: TValue; out k: TKey): Boolean;
  { returns True if aKey contained in the map and removes an aKey from the map }
    function  Remove(const aKey: TKey): Boolean;
    function  RemoveAll(const a: array of TKey): SizeInt;
    function  RemoveAll(e: IKeyEnumerable): SizeInt;
  { returns True if aValue contained in the map and removes an aValue from the map }
    function  RemoveValue(const aValue: TValue): Boolean;
    function  RemoveValues(const a: array of TValue): SizeInt;
    function  RemoveValues(e: IValueEnumerable): SizeInt;
    procedure RetainAll(c: IKeyCollection);
    procedure RetainAll(c: IValueCollection);
    function  Clone: TSpecBiMap; virtual;
    function  Keys: IKeyEnumerable;
    function  Values: IValueEnumerable;
    function  Entries: IEntryEnumerable;
    function  InvEntries: IInvEntryEnumerable;
  private
    function  IInverseMap.Contains      = ContainsValue;
    function  IInverseMap.NonContains   = NonContainsValue;
    function  IInverseMap.GetValue      = GetKey;
    function  IInverseMap.TryGetValue   = TryGetKey;
    function  IInverseMap.GetValueDef   = GetKeyDef;
    function  IInverseMap.Add           = AddInverse;
    procedure IInverseMap.AddOrSetValue = AddOrSetKey;
    function  IInverseMap.Replace       = ReplaceKey;
    function  IInverseMap.Extract       = ExtractValue;
    function  IInverseMap.Remove        = RemoveValue;
    function  IInverseMap.RetainAll     = RetainAll;
    function  IInverseMap.Keys          = Values;
    function  IInverseMap.Values        = Keys;
    function  IInverseMap.Entries       = InvEntries;

    function  IInverseRoMap.Contains    = ContainsValue;
    function  IInverseRoMap.TryGetValue = TryGetKey;
    function  IInverseRoMap.GetValueDef = GetKeyDef;
    function  IInverseRoMap.Keys        = Values;
    function  IInverseRoMap.Values      = Keys;
    function  IInverseRoMap.Entries     = InvEntries;
    function  IInverseRoMap.NonContains = NonContainsValue;

  public
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
  { will raise ELGMapError if not contains aKey or contains aValue }
    property  Items[const aKey: TKey]: TValue read GetValue write AddOrSetValue; default;
  end;

  { TGHashBiMapK assumes that TKey implements TKeyEqRel }
  generic TGHashBiMapK<TKey, TValue, TValueEqRel> = class(
    specialize TGHashBiMap<TKey, TValue, TKey, TValueEqRel>);

  { TGHashBiMapV assumes that TValue implements TValueEqRel }
  generic TGHashBiMapV<TKey, TValue, TKeyEqRel> = class(
    specialize TGHashBiMap<TKey, TValue, TKeyEqRel, TValue>);

  { TGHashBiMap2 assumes that TKey implements TKeyEqRel and TValue implements TValueEqRel }
  generic TGHashBiMap2<TKey, TValue> = class(specialize TGHashBiMap<TKey, TValue, TKey, TValue>);

  { TGObjectHashBiMap }

  generic TGObjectHashBiMap<TKey, TValue, TKeyEqRel, TValueEqRel> = class(specialize
    TGHashBiMap<TKey, TValue, TKeyEqRel, TValueEqRel>)
  private
    FOwnsKeys: Boolean;
    FOwnsValues: Boolean;
  protected
    procedure SetOwnership(aOwns: TMapObjOwnership); inline;
    procedure DoClear; override;
    function  DoRemoveKey(const aKey: TKey): Boolean; override;
    function  DoRemoveValue(const aValue: TValue): Boolean; override;
    function  DoReplaceValue(const aKey: TKey; const aNewValue: TValue): Boolean; override;
    function  DoReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean; override;
    procedure DoRetainAll({%H-}c: IKeyCollection); override;
    procedure DoRetainAllVal({%H-}c: IValueCollection); override;
  public
    constructor Create(aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor Create(const a: array of TEntry; aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor Create(e: IEntryEnumerable; aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor Create(aCapacity: SizeInt; aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor Create(aCapacity: SizeInt; const a: array of TEntry; aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor Create(aCapacity: SizeInt; e: IEntryEnumerable; aOwns: TMapObjOwnership = OWNS_BOTH);
    constructor CreateCopy(aMap: TGObjectHashBiMap);
    function  Clone: TGObjectHashBiMap; override;
    property  OwnsKeys: Boolean read FOwnsKeys write FOwnsKeys;
    property  OwnsValues: Boolean read FOwnsValues write FOwnsValues;
  end;

  { TGObjHashBiMapK assumes that TKey implements TKeyEqRel }
  generic TGObjHashBiMapK<TKey, TValue, TValueEqRel> = class(specialize
    TGObjectHashBiMap<TKey, TValue, TKey, TValueEqRel>);

  { TGObjHashBiMapV assumes that TValue implements TValueEqRel }
  generic TGObjHashBiMapV<TKey, TValue, TKeyEqRel> = class(specialize
    TGObjectHashBiMap<TKey, TValue, TKeyEqRel, TValue>);

  { TGObjHashBiMap2 assumes that TKey implements TKeyEqRel and TValue implements TValueEqRel }
  generic TGObjHashBiMap2<TKey, TValue> = class(specialize TGObjectHashBiMap<TKey, TValue, TKey, TValue>);

implementation
{$B-}{$COPERATORS ON}

{ TGHashBiMap.TKeyEnumerable }

function TGHashBiMap.TKeyEnumerable.GetCurrent: TKey;
begin
  Result := FList[FCurrIndex].Data.Key;
end;

constructor TGHashBiMap.TKeyEnumerable.Create(aMap: TGHashBiMap);
begin
  inherited Create;
  FOwner := aMap;
  FList := aMap.FNodeList;
  FLastIndex := Pred(aMap.Count);
  FCurrIndex := NULL_INDEX;
end;

destructor TGHashBiMap.TKeyEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

function TGHashBiMap.TKeyEnumerable.MoveNext: Boolean;
begin
  if FCurrIndex < FLastIndex then
    begin
      Inc(FCurrIndex);
      exit(True);
    end;
  Result := False;
end;

procedure TGHashBiMap.TKeyEnumerable.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGHashBiMap.TValueEnumerable }

function TGHashBiMap.TValueEnumerable.GetCurrent: TValue;
begin
  Result := FList[FCurrIndex].Data.Value;
end;

constructor TGHashBiMap.TValueEnumerable.Create(aMap: TGHashBiMap);
begin
  inherited Create;
  FOwner := aMap;
  FList := aMap.FNodeList;
  FLastIndex := Pred(aMap.Count);
  FCurrIndex := NULL_INDEX;
end;

destructor TGHashBiMap.TValueEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

function TGHashBiMap.TValueEnumerable.MoveNext: Boolean;
begin
  if FCurrIndex < FLastIndex then
    begin
      Inc(FCurrIndex);
      exit(True);
    end;
  Result := False;
end;

procedure TGHashBiMap.TValueEnumerable.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGHashBiMap.TEntryEnumerable }

function TGHashBiMap.TEntryEnumerable.GetCurrent: TEntry;
begin
  Result := FList[FCurrIndex].Data;
end;

constructor TGHashBiMap.TEntryEnumerable.Create(aMap: TGHashBiMap);
begin
  inherited Create;
  FOwner := aMap;
  FList := aMap.FNodeList;
  FLastIndex := Pred(aMap.Count);
  FCurrIndex := NULL_INDEX;
end;

destructor TGHashBiMap.TEntryEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

function TGHashBiMap.TEntryEnumerable.MoveNext: Boolean;
begin
  if FCurrIndex < FLastIndex then
    begin
      Inc(FCurrIndex);
      exit(True);
    end;
  Result := False;
end;

procedure TGHashBiMap.TEntryEnumerable.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGHashBiMap.TInvEntryEnumerable }

function TGHashBiMap.TInvEntryEnumerable.GetCurrent: TInverseEntry;
begin
  with FList[FCurrIndex].Data do
    Result := TInverseEntry.Create(Value, Key);
end;

constructor TGHashBiMap.TInvEntryEnumerable.Create(aMap: TGHashBiMap);
begin
  inherited Create;
  FOwner := aMap;
  FList := aMap.FNodeList;
  FLastIndex := Pred(aMap.Count);
  FCurrIndex := NULL_INDEX;
end;

destructor TGHashBiMap.TInvEntryEnumerable.Destroy;
begin
  FOwner.EndIteration;
  inherited;
end;

function TGHashBiMap.TInvEntryEnumerable.MoveNext: Boolean;
begin
  if FCurrIndex < FLastIndex then
    begin
      Inc(FCurrIndex);
      exit(True);
    end;
  Result := False;
end;

procedure TGHashBiMap.TInvEntryEnumerable.Reset;
begin
  FCurrIndex := NULL_INDEX;
end;

{ TGBiMap }

function TGHashBiMap._GetRef: TObject;
begin
  Result := Self;
end;

procedure TGHashBiMap.InitialAlloc;
begin
  System.SetLength(FNodeList, DEFAULT_CONTAINER_CAPACITY);
  System.SetLength(FKeyChains, DEFAULT_CONTAINER_CAPACITY);
  System.FillChar(FKeyChains[0], DEFAULT_CONTAINER_CAPACITY * SizeOf(SizeInt), $ff);
  System.SetLength(FValueChains, DEFAULT_CONTAINER_CAPACITY);
  System.FillChar(FValueChains[0], DEFAULT_CONTAINER_CAPACITY * SizeOf(SizeInt), $ff);
end;

procedure TGHashBiMap.Rehash;
var
  I, kInd, vInd, Mask: SizeInt;
begin
  Mask := System.High(FNodeList);
  System.FillChar(Pointer(FKeyChains)^, Succ(Mask) * SizeOf(SizeInt), $ff);
  System.FillChar(Pointer(FValueChains)^, Succ(Mask) * SizeOf(SizeInt), $ff);
  for I := 0 to Pred(Count) do
    begin
      kInd := FNodeList[I].KeyHash and Mask;
      vInd := FNodeList[I].ValueHash and Mask;
      FNodeList[I].NextKey := FKeyChains[kInd];
      FKeyChains[kInd] := I;
      FNodeList[I].NextValue := FValueChains[vInd];
      FValueChains[vInd] := I;
    end;
end;

procedure TGHashBiMap.Resize(aNewCapacity: SizeInt);
begin
  System.SetLength(FNodeList, aNewCapacity);
  System.SetLength(FKeyChains, aNewCapacity);
  System.SetLength(FValueChains, aNewCapacity);
  Rehash;
end;

procedure TGHashBiMap.Expand;
var
  OldCapacity: SizeInt;
begin
  OldCapacity := Capacity;
  if OldCapacity > 0 then
    begin
      if OldCapacity < MAX_CAPACITY then
        Resize(OldCapacity shl 1)
      else
        CapacityExceedError(OldCapacity shl 1);
    end
  else
    InitialAlloc;
end;

procedure TGHashBiMap.RemoveFromKeyChain(aIndex: SizeInt);
var
  I, Curr, Prev: SizeInt;
begin
  I := FNodeList[aIndex].KeyHash and System.High(FNodeList);
  if FKeyChains[I] <> aIndex then
    begin
      Prev := FKeyChains[I];
      Curr := FNodeList[Prev].NextKey;
      repeat
        if Curr = aIndex then
          begin
            FNodeList[Prev].NextKey := FNodeList[Curr].NextKey;
            exit;
          end;
        Prev := Curr;
        Curr := FNodeList[Curr].NextKey;
      until Curr = NULL_INDEX;
    end
  else
    begin
      FKeyChains[I] := FNodeList[aIndex].NextKey;
      exit;
    end;
  raise ELGMapError.Create(SEInternalDataInconsist);
end;

procedure TGHashBiMap.RemoveFromValueChain(aIndex: SizeInt);
var
  I, Curr, Prev: SizeInt;
begin
  I := FNodeList[aIndex].ValueHash and System.High(FNodeList);
  if FValueChains[I] <> aIndex then
    begin
      Prev := FValueChains[I];
      Curr := FNodeList[Prev].NextValue;
      repeat
        if Curr = aIndex then
          begin
            FNodeList[Prev].NextValue := FNodeList[Curr].NextValue;
            exit;
          end;
        Prev := Curr;
        Curr := FNodeList[Curr].NextValue;
      until Curr = NULL_INDEX;
    end
  else
    begin
      FValueChains[I] := FNodeList[aIndex].NextValue;
      exit;
    end;
  raise ELGMapError.Create(SEInternalDataInconsist);
end;

procedure TGHashBiMap.FixKeyChain(aOldIndex, aNewIndex: SizeInt);
var
  I: SizeInt;
begin
  I := FNodeList[aNewIndex].KeyHash and System.High(FNodeList);
  if FKeyChains[I] <> aOldIndex then
    begin
      I := FKeyChains[I];
      repeat
        if FNodeList[I].NextKey = aOldIndex then
          begin
            FNodeList[I].NextKey := aNewIndex;
            exit;
          end;
        I := FNodeList[I].NextKey;
      until I = NULL_INDEX;
    end
  else
    begin
      FKeyChains[I] := aNewIndex;
      exit;
    end;
  raise ELGMapError.Create(SEInternalDataInconsist);
end;

procedure TGHashBiMap.FixValueChain(aOldIndex, aNewIndex: SizeInt);
var
  I: SizeInt;
begin
  I := FNodeList[aNewIndex].ValueHash and System.High(FNodeList);
  if FValueChains[I] <> aOldIndex then
    begin
      I := FValueChains[I];
      repeat
        if FNodeList[I].NextValue = aOldIndex then
          begin
            FNodeList[I].NextValue := aNewIndex;
            exit;
          end;
        I := FNodeList[I].NextValue;
      until I = NULL_INDEX;
    end
  else
    begin
      FValueChains[I] := aNewIndex;
      exit;
    end;
  raise ELGMapError.Create(SEInternalDataInconsist);
end;

function TGHashBiMap.DoFindKey(const aKey: TKey; aHash: SizeInt): SizeInt;
begin
  Result := FKeyChains[aHash and System.High(FNodeList)];
  while Result <> NULL_INDEX do
    begin
      if (FNodeList[Result].KeyHash = aHash) and TKeyEqRel.Equal(FNodeList[Result].Data.Key, aKey) then
        exit;
      Result := FNodeList[Result].NextKey;
    end;
end;

function TGHashBiMap.DoFindValue(const aValue: TValue; aHash: SizeInt): SizeInt;
begin
  Result := FValueChains[aHash and System.High(FNodeList)];
  while Result <> NULL_INDEX do
    begin
      if (FNodeList[Result].ValueHash = aHash) and TValueEqRel.Equal(FNodeList[Result].Data.Value, aValue) then
        exit;
      Result := FNodeList[Result].NextValue;
    end;
end;

function TGHashBiMap.FindKey(const aKey: TKey): SizeInt;
begin
  if Count > 0 then
    Result:= DoFindKey(aKey, TKeyEqRel.HashCode(aKey))
  else
    Result := NULL_INDEX;
end;

function TGHashBiMap.FindValue(const aValue: TValue): SizeInt;
begin
  if Count > 0 then
    Result := DoFindValue(aValue, TValueEqRel.HashCode(aValue))
  else
    Result := NULL_INDEX;
end;

procedure TGHashBiMap.DoAddData(const aKey: TKey; const aValue: TValue; aKeyHash, aValHash: SizeInt);
var
  kInd, vInd, I: SizeInt;
begin
  I := Count;
  Inc(FCount);
  kInd := aKeyHash and System.High(FNodeList);
  vInd := aValHash and System.High(FNodeList);
  FNodeList[I].Data := TEntry.Create(aKey, aValue);
  FNodeList[I].KeyHash := aKeyHash;
  FNodeList[I].ValueHash := aValHash;
  FNodeList[I].NextKey := FKeyChains[kInd];
  FKeyChains[kInd] := I;
  FNodeList[I].NextValue := FValueChains[vInd];
  FValueChains[vInd] := I;
end;

procedure TGHashBiMap.DoRemove(aIndex: SizeInt);
begin
  RemoveFromKeyChain(aIndex);
  RemoveFromValueChain(aIndex);
  if IsManagedType(TEntry) then
    FNodeList[aIndex].Data := Default(TEntry);
  Dec(FCount);
  if aIndex < Count then
    begin
      if IsManagedType(TEntry) then
        begin
          System.Move(FNodeList[Count], FNodeList[aIndex], SizeOf(TNode));
          System.FillChar(FNodeList[Count], SizeOf(TNode), 0);
        end
      else
        FNodeList[aIndex] := FNodeList[Count];
      FixKeyChain(Count, aIndex);
      FixValueChain(Count, aIndex);
    end;
end;

function TGHashBiMap.GetCount: SizeInt;
begin
  Result := FCount;
end;

function TGHashBiMap.GetCapacity: SizeInt;
begin
  Result := System.Length(FNodeList);
end;

procedure TGHashBiMap.DoClear;
begin
  FNodeList := nil;
  FKeyChains := nil;
  FValueChains := nil;
  FCount := 0;
end;

procedure TGHashBiMap.DoEnsureCapacity(aValue: SizeInt);
begin
  if aValue <= Capacity then
    exit;
  if aValue <= DEFAULT_CONTAINER_CAPACITY then
    aValue := DEFAULT_CONTAINER_CAPACITY
  else
    if aValue <= MAX_CAPACITY then
      aValue := LGUtils.RoundUpTwoPower(aValue)
    else
      CapacityExceedError(aValue);
  Resize(aValue);
end;

procedure TGHashBiMap.DoTrimToFit;
var
  NewCapacity: SizeInt;
begin
  if Count > 0 then
    begin
      NewCapacity := LGUtils.RoundUpTwoPower(Count);
      if NewCapacity < Capacity then
        Resize(NewCapacity);
    end
  else
    Clear;
end;

function TGHashBiMap.DoAdd(const aKey: TKey; const aValue: TValue): Boolean;
var
  kh, vh: SizeInt;
begin
  kh := TKeyEqRel.HashCode(aKey);
  vh := TValueEqRel.HashCode(aValue);
  if Count > 0 then
    begin
      if DoFindKey(aKey, kh) <> NULL_INDEX then
        exit(False);
      if DoFindValue(aValue, vh) <> NULL_INDEX then
        exit(False);
    end;
  if Count = Capacity then
    Expand;
  DoAddData(aKey, aValue, kh, vh);
  Result := True;
end;

function TGHashBiMap.DoAddAll(const a: array of TEntry): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    with a[I] do
      DoAdd(Key, Value);
  Result := Count - Result;
end;

function TGHashBiMap.DoAddAll(e: IEntryEnumerable): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        with Current do
          DoAdd(Key, Value);
    finally
      Free;
    end;
  Result := Count - Result;
end;

function TGHashBiMap.TryAddOrSetValue(const aKey: TKey; const aValue: TValue): Boolean;
begin
  Result := not ContainsValue(aValue);
  if Result then
    if Contains(aKey) then
      DoReplaceValue(aKey, aValue)
    else
      DoAdd(aKey, aValue);
end;

function TGHashBiMap.TryAddOrSetKey(const aValue: TValue; const aKey: TKey): Boolean;
begin
  Result := not Contains(aKey);
  if Result then
    if ContainsValue(aValue) then
      DoReplaceKey(aValue, aKey)
    else
      DoAdd(aKey, aValue);
end;

procedure TGHashBiMap.DoAddOrSetValue(const aKey: TKey; const aValue: TValue);
begin
  if not TryAddOrSetValue(aKey, aValue) then
    raise ELGMapError.Create(SEValueAlreadyExist);
end;

procedure TGHashBiMap.DoAddOrSetKey(const aValue: TValue; const aKey: TKey);
begin
  if not TryAddOrSetKey(aValue, aKey) then
    raise ELGMapError.Create(SEKeyAlreadyExist);
end;

function TGHashBiMap.DoExtractKey(const aKey: TKey; out v: TValue): Boolean;
var
  I: SizeInt;
begin
  I := FindKey(aKey);
  Result := I <> NULL_INDEX;
  if Result then
    begin
      v := FNodeList[I].Data.Value;
      DoRemove(I);
    end;
end;

function TGHashBiMap.DoRemoveKey(const aKey: TKey): Boolean;
var
  Dummy: TValue;
begin
  Result := DoExtractKey(aKey, Dummy);
end;

function TGHashBiMap.DoRemoveKeys(const a: array of TKey): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if DoRemoveKey(a[I]) then
          if IsEmpty then
            break;
      Result := Result - Count;
    end;
end;

function TGHashBiMap.DoRemoveKeys(e: IKeyEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if DoRemoveKey(Current) and (Count = 0) then
              break;
        finally
          Free;
        end;
      Result := Result - Count;
    end
  else
    e.Discard;
end;

function TGHashBiMap.DoExtractValue(const aValue: TValue; out k: TKey): Boolean;
var
  I: SizeInt;
begin
  I := FindValue(aValue);
  Result := I <> NULL_INDEX;
  if Result then
    begin
      k := FNodeList[I].Data.Key;
      DoRemove(I);
    end;
end;

function TGHashBiMap.DoRemoveValue(const aValue: TValue): Boolean;
var
  Dummy: TKey;
begin
  Result := DoExtractValue(aValue, Dummy);
end;

function TGHashBiMap.DoRemoveValues(const a: array of TValue): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if DoRemoveValue(a[I]) then
          if IsEmpty then
            break;
      Result := Result - Count;
    end;
end;

function TGHashBiMap.DoRemoveValues(e: IValueEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if DoRemoveValue(Current) and (Count = 0) then
              break;
        finally
          Free;
        end;
      Result := Result - Count;
    end
  else
    e.Discard;
end;

function TGHashBiMap.DoReplaceValue(const aKey: TKey; const aNewValue: TValue): Boolean;
var
  I, J, h: SizeInt;
begin
  I := FindKey(aKey);
  if I = NULL_INDEX then
    exit(False);
  if FindValue(aNewValue) <> NULL_INDEX then
    exit(False);
  if not TValueEqRel.Equal(aNewValue, FNodeList[I].Data.Value) then
    begin
      h := TValueEqRel.HashCode(aNewValue);
      RemoveFromValueChain(I);
      J := h and Pred(Capacity);
      FNodeList[I].ValueHash := h;
      FNodeList[I].Data.Value := aNewValue;
      FNodeList[I].NextValue := FValueChains[J];
      FValueChains[J] := I;
    end;
  Result := True;
end;

function TGHashBiMap.DoReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean;
var
  I, J, h: SizeInt;
begin
  I := FindValue(aValue);
  if I = NULL_INDEX then
    exit(False);
  if FindKey(aNewKey) <> NULL_INDEX then
    exit(False);
  if not TKeyEqRel.Equal(aNewKey, FNodeList[I].Data.Key) then
    begin
      h := TKeyEqRel.HashCode(aNewKey);
      RemoveFromKeyChain(I);
      J := h and Pred(Capacity);
      FNodeList[I].KeyHash := h;
      FNodeList[I].Data.Key := aNewKey;
      FNodeList[I].NextKey := FKeyChains[J];
      FKeyChains[J] := I;
    end;
  Result := True;
end;

procedure TGHashBiMap.DoRetainAll(c: IKeyCollection);
var
  I: SizeInt = 0;
begin
  while I < Count do
    if c.NonContains(FNodeList[I].Data.Key) then
      DoRemove(I)
    else
      Inc(I);
end;

procedure TGHashBiMap.DoRetainAllVal(c: IValueCollection);
var
  I: SizeInt = 0;
begin
  while I < Count do
    if c.NonContains(FNodeList[I].Data.Value) then
      DoRemove(I)
    else
      Inc(I);
end;

function TGHashBiMap.GetKeys: IKeyEnumerable;
begin
  Result := TKeyEnumerable.Create(Self);
end;

function TGHashBiMap.GetValues: IValueEnumerable;
begin
  Result := TValueEnumerable.Create(Self);
end;

function TGHashBiMap.GetEntries: IEntryEnumerable;
begin
  Result := TEntryEnumerable.Create(Self);
end;

function TGHashBiMap.AddInverse(const aValue: TValue; const aKey: TKey): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(aKey, aValue);
end;

class constructor TGHashBiMap.Init;
begin
  MAX_CAPACITY := LGUtils.RoundUpTwoPower(MAX_CAPACITY);
end;

constructor TGHashBiMap.Create;
begin
  InitialAlloc;
end;

constructor TGHashBiMap.Create(const a: array of TEntry);
begin
  Create;
  DoAddAll(a);
end;

constructor TGHashBiMap.Create(e: IEntryEnumerable);
begin
  Create;
  DoAddAll(e);
end;

constructor TGHashBiMap.Create(aCapacity: SizeInt);
begin
  EnsureCapacity(aCapacity);
end;

constructor TGHashBiMap.Create(aCapacity: SizeInt; const a: array of TEntry);
begin
  Create(aCapacity);
  DoAddAll(a);
end;

constructor TGHashBiMap.Create(aCapacity: SizeInt; e: IEntryEnumerable);
begin
  Create(aCapacity);
  DoAddAll(e);
end;

constructor TGHashBiMap.CreateCopy(aMap: TGHashBiMap);
begin
  FNodeList := System.Copy(aMap.FNodeList);
  FKeyChains := System.Copy(aMap.FKeyChains);
  FValueChains := System.Copy(aMap.FValueChains);
  FCount := aMap.Count;
end;

destructor TGHashBiMap.Destroy;
begin
  DoClear;
  inherited;
end;

function TGHashBiMap.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGHashBiMap.NonEmpty: Boolean;
begin
  Result := Count > 0;
end;

procedure TGHashBiMap.Clear;
begin
  CheckInIteration;
  DoClear;
end;

procedure TGHashBiMap.EnsureCapacity(aValue: SizeInt);
begin
  CheckInIteration;
  DoEnsureCapacity(aValue);
end;

procedure TGHashBiMap.TrimToFit;
begin
  CheckInIteration;
  DoTrimToFit;
end;

function TGHashBiMap.Contains(const aKey: TKey): Boolean;
begin
  Result := FindKey(aKey) <> NULL_INDEX;
end;

function TGHashBiMap.NonContains(const aKey: TKey): Boolean;
begin
  Result := FindKey(aKey) = NULL_INDEX;
end;

function TGHashBiMap.ContainsValue(const aValue: TValue): Boolean;
begin
  Result := FindValue(aValue) <> NULL_INDEX;
end;

function TGHashBiMap.NonContainsValue(const aValue: TValue): Boolean;
begin
  Result := FindValue(aValue) = NULL_INDEX;
end;

function TGHashBiMap.GetValue(const aKey: TKey): TValue;
begin
  if not TryGetValue(aKey, Result) then
    raise ELGMapError.Create(SEKeyNotFound);
end;

function TGHashBiMap.GetKey(const aValue: TValue): TKey;
begin
  if not TryGetKey(aValue, Result) then
    raise ELGMapError.Create(SEValueNotFound);
end;

function TGHashBiMap.TryGetValue(const aKey: TKey; out aValue: TValue): Boolean;
var
  I: SizeInt;
begin
  I := FindKey(aKey);
  Result := I <> NULL_INDEX;
  if Result then
    aValue := FNodeList[I].Data.Value;
end;

function TGHashBiMap.TryGetKey(const aValue: TValue; out aKey: TKey): Boolean;
var
  I: SizeInt;
begin
  I := FindValue(aValue);
  Result := I <> NULL_INDEX;
  if Result then
    aKey := FNodeList[I].Data.Key;
end;

function TGHashBiMap.GetValueDef(const aKey: TKey; const aDefault: TValue): TValue;
begin
  if not TryGetValue(aKey, Result) then
    Result := aDefault;
end;

function TGHashBiMap.GetKeyDef(const aValue: TValue; const aDefault: TKey): TKey;
begin
  if not TryGetKey(aValue, Result) then
    Result := aDefault;
end;

function TGHashBiMap.Add(const aKey: TKey; const aValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(aKey, aValue);
end;

function TGHashBiMap.Add(const e: TEntry): Boolean;
begin
  CheckInIteration;
  Result := DoAdd(e.Key, e.Value);
end;

procedure TGHashBiMap.AddOrSetValue(const aKey: TKey; const aValue: TValue);
begin
  CheckInIteration;
  DoAddOrSetValue(aKey, aValue);
end;

function TGHashBiMap.TryAddOrSetValue(const e: TEntry): Boolean;
begin
  CheckInIteration;
  Result := TryAddOrSetValue(e.Key, e.Value);
end;

procedure TGHashBiMap.AddOrSetKey(const aValue: TValue; const aKey: TKey);
begin
  CheckInIteration;
  DoAddOrSetKey(aValue, aKey);
end;

function TGHashBiMap.TryAddOrSetKey(const e: TInverseEntry): Boolean;
begin
  CheckInIteration;
  Result := TryAddOrSetKey(e.Key, e.Value);
end;

function TGHashBiMap.AddAll(const a: array of TEntry): SizeInt;
begin
  CheckInIteration;
  Result := DoAddAll(a);
end;

function TGHashBiMap.AddAll(e: IEntryEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoAddAll(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGHashBiMap.Remove(const aKey: TKey): Boolean;
begin
  CheckInIteration;
  Result := DoRemoveKey(aKey);
end;

function TGHashBiMap.RemoveAll(const a: array of TKey): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveKeys(a);
end;

function TGHashBiMap.RemoveAll(e: IKeyEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveKeys(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGHashBiMap.RemoveValue(const aValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoRemoveValue(aValue);
end;

function TGHashBiMap.RemoveValues(const a: array of TValue): SizeInt;
begin
  CheckInIteration;
  Result := DoRemoveValues(a);
end;

function TGHashBiMap.RemoveValues(e: IValueEnumerable): SizeInt;
begin
  if not InIteration then
    Result := DoRemoveValues(e)
  else
    begin
      Result := 0;
      e.Discard;
      UpdateLockError;
    end;
end;

function TGHashBiMap.Replace(const aKey: TKey; const aNewValue: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoReplaceValue(aKey, aNewValue);
end;

function TGHashBiMap.ReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean;
begin
  CheckInIteration;
  Result := DoReplaceKey(aValue, aNewKey);
end;

function TGHashBiMap.Extract(const aKey: TKey; out v: TValue): Boolean;
begin
  CheckInIteration;
  Result := DoExtractKey(aKey, v);
end;

function TGHashBiMap.ExtractValue(const aValue: TValue; out k: TKey): Boolean;
begin
  CheckInIteration;
  Result := DoExtractValue(aValue, k);
end;

procedure TGHashBiMap.RetainAll(c: IKeyCollection);
begin
  CheckInIteration;
  DoRetainAll(c);
end;

procedure TGHashBiMap.RetainAll(c: IValueCollection);
begin
  CheckInIteration;
  DoRetainAllVal(c);
end;

function TGHashBiMap.Clone: TSpecBiMap;
begin
  Result := TSpecBiMap.CreateCopy(Self);
end;

function TGHashBiMap.Keys: IKeyEnumerable;
begin
  BeginIteration;
  Result := GetKeys;
end;

function TGHashBiMap.Values: IValueEnumerable;
begin
  BeginIteration;
  Result := GetValues;
end;

function TGHashBiMap.Entries: IEntryEnumerable;
begin
  BeginIteration;
  Result := GetEntries;
end;

function TGHashBiMap.InvEntries: IInvEntryEnumerable;
begin
  BeginIteration;
  Result := TInvEntryEnumerable.Create(Self);
end;

{ TGObjectHashBiMap }

procedure TGObjectHashBiMap.SetOwnership(aOwns: TMapObjOwnership);
begin
  OwnsKeys := moOwnsKeys in aOwns;
  OwnsValues := moOwnsValues in aOwns;
end;

procedure TGObjectHashBiMap.DoClear;
var
  I: SizeInt;
begin
  if OwnsKeys or OwnsValues then
    for I := 0 to Pred(Count) do
      begin
        if OwnsKeys then
          TObject(FNodeList[I].Data.Key).Free;
        if OwnsValues then
          TObject(FNodeList[I].Data.Value).Free;
      end;
  inherited;
end;

function TGObjectHashBiMap.DoRemoveKey(const aKey: TKey): Boolean;
var
  v: TValue;
begin
  Result := DoExtractKey(aKey, v);
  if Result then
    begin
      if OwnsKeys then
        TObject(aKey).Free;
      if OwnsValues then
        TObject(v).Free;
    end;
end;

function TGObjectHashBiMap.DoRemoveValue(const aValue: TValue): Boolean;
var
  k: TKey;
begin
  Result := DoExtractValue(aValue, k);
  if Result then
    begin
      if OwnsKeys then
        TObject(k).Free;
      if OwnsValues then
        TObject(aValue).Free;
    end;
end;

function TGObjectHashBiMap.DoReplaceValue(const aKey: TKey; const aNewValue: TValue): Boolean;
var
  I, J, h: SizeInt;
begin
  I := FindKey(aKey);
  if I = NULL_INDEX then
    exit(False);
  if FindValue(aNewValue) <> NULL_INDEX then
    exit(False);
  if not TValueEqRel.Equal(aNewValue, FNodeList[I].Data.Value) then
    begin
      h := TValueEqRel.HashCode(aNewValue);
      RemoveFromValueChain(I);
      J := h and Pred(Capacity);
      FNodeList[I].ValueHash := h;
      if OwnsValues then
        TObject(FNodeList[I].Data.Value).Free;
      FNodeList[I].Data.Value := aNewValue;
      FNodeList[I].NextValue := FValueChains[J];
      FValueChains[J] := I;
    end;
  Result := True;
end;

function TGObjectHashBiMap.DoReplaceKey(const aValue: TValue; const aNewKey: TKey): Boolean;
var
  I, J, h: SizeInt;
begin
  I := FindValue(aValue);
  if I = NULL_INDEX then
    exit(False);
  if FindKey(aNewKey) <> NULL_INDEX then
    exit(False);
  if not TKeyEqRel.Equal(aNewKey, FNodeList[I].Data.Key) then
    begin
      h := TKeyEqRel.HashCode(aNewKey);
      RemoveFromKeyChain(I);
      J := h and Pred(Capacity);
      FNodeList[I].KeyHash := h;
      if OwnsKeys then
        TObject(FNodeList[I].Data.Key).Free;
      FNodeList[I].Data.Key := aNewKey;
      FNodeList[I].NextKey := FKeyChains[J];
      FKeyChains[J] := I;
    end;
  Result := True;
end;

procedure TGObjectHashBiMap.DoRetainAll(c: IKeyCollection);
var
  I: SizeInt = 0;
begin
  while I < Count do
    if c.NonContains(FNodeList[I].Data.Key) then
      begin
        if OwnsKeys then
          TObject(FNodeList[I].Data.Key).Free;
        if OwnsValues then
          TObject(FNodeList[I].Data.Value).Free;
        DoRemove(I);
      end
    else
      Inc(I);
end;

procedure TGObjectHashBiMap.DoRetainAllVal(c: IValueCollection);
var
  I: SizeInt = 0;
begin
  while I < Count do
    if c.NonContains(FNodeList[I].Data.Value) then
      begin
        if OwnsKeys then
          TObject(FNodeList[I].Data.Key).Free;
        if OwnsValues then
          TObject(FNodeList[I].Data.Value).Free;
        DoRemove(I);
      end
    else
      Inc(I);
end;

constructor TGObjectHashBiMap.Create(aOwns: TMapObjOwnership);
begin
  inherited Create;
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.Create(const a: array of TEntry; aOwns: TMapObjOwnership);
begin
  inherited Create(a);
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.Create(e: IEntryEnumerable; aOwns: TMapObjOwnership);
begin
  inherited Create(e);
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.Create(aCapacity: SizeInt; aOwns: TMapObjOwnership);
begin
  inherited Create(aCapacity);
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.Create(aCapacity: SizeInt; const a: array of TEntry; aOwns: TMapObjOwnership);
begin
  inherited Create(aCapacity, a);
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.Create(aCapacity: SizeInt; e: IEntryEnumerable; aOwns: TMapObjOwnership);
begin
  inherited Create(aCapacity, e);
  SetOwnership(aOwns);
end;

constructor TGObjectHashBiMap.CreateCopy(aMap: TGObjectHashBiMap);
begin
  inherited CreateCopy(aMap);
  OwnsKeys := aMap.OwnsKeys;
  OwnsValues := aMap.OwnsValues;
end;

function TGObjectHashBiMap.Clone: TGObjectHashBiMap;
begin
  Result := TGObjectHashBiMap.CreateCopy(Self);
end;

end.

