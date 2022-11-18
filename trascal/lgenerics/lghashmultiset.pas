{****************************************************************************
*                                                                           *
*   This file is part of the LGenerics package.                             *
*   Generic hash multiset implementations.                                  *
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
unit lgHashMultiSet;

{$mode objfpc}{$H+}
{$INLINE ON}
{$MODESWITCH NESTEDPROCVARS}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses

  SysUtils,
  lgUtils,
  {%H-}lgHelpers,
  lgAbstractContainer,
  lgHashTable,
  lgStrConst;

type

  { TGCustomHashMultiSet: common hash multiset abstract ancestor class }
  generic TGAbstractHashMultiSet<T> = class abstract(specialize TGAbstractMultiSet<T>)
  public
  type
    TAbstractHashMultiSet = specialize TGAbstractHashMultiSet<T>;

  protected
  type
    THashTable          = specialize TGAbstractHashTable<T, TEntry>;
    THashTableClass     = class of THashTable;
    THashMultiSetClass  = class of TAbstractHashMultiSet;
    TSearchResult       = THashTable.TSearchResult;

    TEnumerator = class(TContainerEnumerator)
    protected
      FEnum: THashTable.TEntryEnumerator;
      FCurrKeyCount: SizeInt;
      function  GetCurrent: T; override;
    public
      constructor Create(ms: TAbstractHashMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TDistinctEnumerable = class(TContainerEnumerable)
    protected
      FEnum: THashTable.TEntryEnumerator;
      function  GetCurrent: T; override;
    public
      constructor Create(aSet: TAbstractHashMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

    TEntryEnumerable = class(specialize TGAutoEnumerable<TEntry>)
    protected
      FOwner: TAbstractHashMultiSet;
      FEnum: THashTable.TEntryEnumerator;
      function  GetCurrent: TEntry; override;
    public
      constructor Create(aSet: TAbstractHashMultiSet);
      destructor Destroy; override;
      function  MoveNext: Boolean; override;
      procedure Reset; override;
    end;

  var
    FTable: THashTable;
    procedure EntryRemoved(p: PEntry);
    function  GetFillRatio: Single; inline;
    function  GetLoadFactor: Single; inline;
    procedure SetLoadFactor(aValue: Single); inline;
    function  GetExpandTreshold: SizeInt; inline;
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
    function  GetDistinct: IEnumerable; override;  // distinct keys
    function  GetEntries: IEntryEnumerable; override;
    procedure DoIntersect(aSet: TSpecMultiSet); override;
    function  DoRemoveIf(aTest: TTest): SizeInt; override;
    function  DoRemoveIf(aTest: TOnTest): SizeInt; override;
    function  DoRemoveIf(aTest: TNestTest): SizeInt; override;
    function  DoExtractIf(aTest: TTest): TArray; override;
    function  DoExtractIf(aTest: TOnTest): TArray; override;
    function  DoExtractIf(aTest: TNestTest): TArray; override;
    class function GetTableClass: THashTableClass; virtual; abstract;
    class function GetClass: THashMultiSetClass; virtual; abstract;
  public
    class function DefaultLoadFactor: Single; inline;
    class function MaxLoadFactor: Single; inline;
    class function MinLoadFactor: Single; inline;
    constructor Create;
    constructor Create(constref a: array of T);
    constructor Create(e: IEnumerable);
    constructor Create(aCapacity: SizeInt);
    constructor Create(aCapacity: SizeInt; constref a: array of T);
    constructor Create(aCapacity: SizeInt; e: IEnumerable);
    constructor Create(aLoadFactor: Single);
    constructor Create(aLoadFactor: Single; constref a: array of T);
    constructor Create(aLoadFactor: Single; e: IEnumerable);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; constref a: array of T);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable);
    constructor CreateCopy(aMultiSet: TAbstractHashMultiSet);
    destructor Destroy; override;
    function  Clone: TAbstractHashMultiSet; override;
    property  LoadFactor: Single read GetLoadFactor write SetLoadFactor;
    property  FillRatio: Single read GetFillRatio;
  { The number of entries that can be written without rehashing }
    property  ExpandTreshold: SizeInt read GetExpandTreshold;
  end;

  { TGBaseHashMultiSetLP implements open addressing hash multiset with linear probing;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGBaseHashMultiSetLP<T, TEqRel> = class(specialize TGAbstractHashMultiSet<T>)
  protected
    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  end;

  { TGHashMultiSetLP implements open addressing hash multiset with linear probing;
    it assumes that type T implements TEqRel }
  generic TGHashMultiSetLP<T> = class(specialize TGBaseHashMultiSetLP<T, T>);

  { TGBaseHashMultiSetLPT implements open addressing hash multiset with linear probing and lazy deletion }
  generic TGBaseHashMultiSetLPT<T, TEqRel> = class(specialize TGAbstractHashMultiSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableLPT = specialize TGOpenAddrLPT<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGHashMultiSetLPT implements open addressing hash multiset with linear probing and lazy deletion;
    it assumes that type T implements TEqRel }
  generic TGHashMultiSetLPT<T> = class(specialize TGBaseHashMultiSetLPT<T, T>);

  { TGBaseHashMultiSetQP implements open addressing hashmultiset with quadratic probing(c1 = c2 = 1/2) }
  generic TGBaseHashMultiSetQP<T, TEqRel> = class(specialize TGAbstractHashMultiSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableQP = specialize TGOpenAddrQP<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  { TGHashMultiSetQP implements open addressing hashmultiset with quadratic probing(c1 = c2 = 1/2);
    it assumes that type T implements TEqRel }
  generic TGHashMultiSetQP<T> = class(specialize TGBaseHashMultiSetQP<T, T>);

  { TGBaseChainHashMultiSet implements node based hashset with singly linked list chains }
  generic TGBaseChainHashMultiSet<T, TEqRel> = class(specialize TGAbstractHashMultiSet<T>)
  protected
    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  end;

  { TGChainHashMultiSet implements node based hashset with singly linked list chains;
    it assumes that type T implements TEqRel }
  generic TGChainHashMultiSet<T> = class(specialize TGBaseChainHashMultiSet<T, T>);

  { TGCustomObjectHashMultiSet }

  generic TGCustomObjectHashMultiSet<T: class> = class abstract(specialize TGAbstractHashMultiSet<T>)
  private
    FOwnsObjects: Boolean;
  protected
  type
    TObjectHashMultiSetClass = class of TGCustomObjectHashMultiSet;

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
    constructor Create(const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean = True);
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean = True);
    constructor CreateCopy(aMultiSet: TGCustomObjectHashMultiSet);
    property  OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;
  end;

  generic TGObjectHashMultiSetLP<T: class; TEqRel> = class(specialize TGCustomObjectHashMultiSet<T>)
  protected
    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    function Clone: TGObjectHashMultiSetLP; override;
  end;

  generic TGObjHashMultiSetLP<T: class> = class(specialize TGObjectHashMultiSetLP<T, T>);

  generic TGObjectHashMultiSetLPT<T: class; TEqRel> = class(specialize TGCustomObjectHashMultiSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableLPT = specialize TGOpenAddrLPT<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    function  Clone: TGObjectHashMultiSetLPT; override;
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  generic TGObjHashMultiSetLPT<T: class> = class(specialize TGObjectHashMultiSetLPT<T, T>);

  generic TGObjectHashMultiSetQP<T: class; TEqRel> = class(specialize TGCustomObjectHashMultiSet<T>)
  private
    function GetTombstonesCount: SizeInt; inline;
  protected
  type
    THashTableQP = specialize TGOpenAddrQP<T, TEntry, TEqRel>;

    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    function  Clone: TGObjectHashMultiSetQP; override;
    procedure ClearTombstones; inline;
    property  TombstonesCount: SizeInt read GetTombstonesCount;
  end;

  generic TGObjHashMultiSetQP<T: class> = class(specialize TGObjectHashMultiSetQP<T, T>);

  generic TGObjectChainHashMultiSet<T: class; TEqRel> = class(specialize TGCustomObjectHashMultiSet<T>)
  protected
    class function GetTableClass: THashTableClass; override;
    class function GetClass: THashMultiSetClass; override;
  public
    function Clone: TGObjectChainHashMultiSet; override;
  end;

  generic TGObjChainHashMultiSet<T: class> = class(specialize TGObjectChainHashMultiSet<T, T>);

  { TGLiteHashMultiSet implements open addressing hash multiset with linear probing;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteHashMultiSet<T, TEntry, TTable, TTblEnumerator, TTblRemovableEnumerator> = record
  public
  type
    IEnumerable = specialize IGEnumerable<T>;
    ICollection = specialize IGCollection<T>;
    TTest       = specialize TGTest<T>;
    TOnTest     = specialize TGOnTest<T>;
    TNestTest   = specialize TGNestTest<T>;
    TArray      = array of T;
    TEntryArray = array of TEntry;

  private
  type
    PMultiSet = ^TGLiteHashMultiSet;
    PEntry    = ^TEntry;

  public
  type
    TEnumerator = record
    private
      FEnum: TTblEnumerator;
      FCurrKeyCount: SizeInt;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset;
      property  Current: T read GetCurrent;
    end;

    TDistinctEnumerator = record
    private
      FEnum: TTblEnumerator;
      function  GetCurrent: T; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset;
      property  Current: T read GetCurrent;
    end;

    TEntryEnumerator = record
    private
      FEnum: TTblEnumerator;
      function  GetCurrent: TEntry; inline;
    public
      function  MoveNext: Boolean; inline;
      procedure Reset;
      property  Current: TEntry read GetCurrent;
    end;

    TDistinct = record
    private
      FMultiset: PMultiSet;
    public
      function GetEnumerator: TDistinctEnumerator;
    end;

    TEntries = record
    private
      FMultiset: PMultiSet;
    public
      function GetEnumerator: TEntryEnumerator;
    end;

  private
    FTable: TTable;
    FCount: SizeInt;
    function  GetCapacity: SizeInt; inline;
    function  GetEntryCount: SizeInt; inline;
    function  GetExpandTreshold: SizeInt; inline;
    function  GetFillRatio: Single; inline;
    function  GetLoadFactor: Single; inline;
    procedure SetLoadFactor(aValue: Single); inline;
    function  GetKeyCount(const aKey: T): SizeInt;
    procedure SetKeyCount(const aKey: T; aValue: SizeInt);
    class operator Initialize(var ms: TGLiteHashMultiSet);
  public
    function  DefaultLoadFactor: Single; inline;
    function  MaxLoadFactor: Single; inline;
    function  MinLoadFactor: Single; inline;
    function  GetEnumerator: TEnumerator; inline;
    function  GetDistinctEnumerator: TDistinctEnumerator;
    function  GetEntryEnumerator: TEntryEnumerator;
    function  Distinct: TDistinct; inline;
    function  Entries: TEntries; inline;
    function  ToArray: TArray;
    function  ToEntryArray: TEntryArray;
    function  IsEmpty: Boolean; inline;
    function  NonEmpty: Boolean; inline;
    procedure Clear;
    procedure MakeEmpty;
    procedure TrimToFit; inline;
    procedure EnsureCapacity(aValue: SizeInt); inline;
    function  Contains(const aValue: T): Boolean; inline;
    function  NonContains(const aValue: T): Boolean; inline;
    function  FindFirst(out aValue: T): Boolean; inline;
    function  ContainsAny(const a: array of T): Boolean;
    function  ContainsAny(e: IEnumerable): Boolean;
    function  ContainsAny(constref aSet: TGLiteHashMultiSet): Boolean;
    function  ContainsAll(const a: array of T): Boolean;
    function  ContainsAll(e: IEnumerable): Boolean;
    function  ContainsAll(constref aSet: TGLiteHashMultiSet): Boolean;
    procedure Add(const aValue: T);
  { returns count of added elements }
    function  AddAll(const a: array of T): SizeInt;
    function  AddAll(e: IEnumerable): SizeInt;
    function  AddAll(constref aSet: TGLiteHashMultiSet): SizeInt;
  { returns True if element removed }
    function  Remove(const aValue: T): Boolean; inline;
    function  RemoveAll(const a: array of T): SizeInt;
    function  RemoveAll(e: IEnumerable): SizeInt;
    function  RemoveAll(constref aSet: TGLiteHashMultiSet): SizeInt;
  { returns count of removed elements }
    function  RemoveIf(aTest: TTest): SizeInt;
    function  RemoveIf(aTest: TOnTest): SizeInt;
    function  RemoveIf(aTest: TNestTest): SizeInt;
  { returns True if element extracted }
    function  Extract(const aValue: T): Boolean;
    function  ExtractIf(aTest: TTest): TArray;
    function  ExtractIf(aTest: TOnTest): TArray;
    function  ExtractIf(aTest: TNestTest): TArray;
  { will contain only those elements that are simultaneously contained in self and aCollection }
    procedure RetainAll(aCollection: ICollection);
  { returns True if multiplicity of an any key in self is greater then or equal to
    the multiplicity of that key in aSet }
    function  IsSuperSet(constref aSet: TGLiteHashMultiSet): Boolean; inline;
  { returns True if multiplicity of an any key in aSet is greater then or equal to
    the multiplicity of that key in self }
    function  IsSubSet(constref aSet: TGLiteHashMultiSet): Boolean; inline;
  { returns True if the multiplicity of an any key in self is equal to the multiplicity of that key in aSet }
    function  IsEqual(constref aSet: TGLiteHashMultiSet): Boolean;
    function  Intersecting(constref aSet: TGLiteHashMultiSet): Boolean;
  { will contain only those keys that are simultaneously contained in self and in aSet;
    the multiplicity of a key becomes equal to the MINIMUM of the multiplicities of a key in self and aSet }
    procedure Intersect(constref aSet: TGLiteHashMultiSet);
  { will contain all keys that are contained in self or in aSet;
    the multiplicity of a key will become equal to the MAXIMUM of the multiplicities of
    a key in self and aSet }
    procedure Join(constref aSet: TGLiteHashMultiSet);
  { will contain all keys that are contained in self or in aSet;
    the multiplicity of a key will become equal to the SUM of the multiplicities of a key in self and aSet }
    procedure ArithmeticAdd(constref aSet: TGLiteHashMultiSet);
  { will contain only those keys whose multiplicity is greater then the multiplicity
    of that key in aSet; the multiplicity of a key will become equal to the difference of multiplicities
    of a key in self and aSet }
    procedure ArithmeticSubtract(constref aSet: TGLiteHashMultiSet);
  { will contain only those keys whose multiplicity is not equal to the multiplicity
    of that key in aSet; the multiplicity of a key will become equal to absolute value of difference
    of the multiplicities of a key in self and aSet }
    procedure SymmetricSubtract(constref aSet: TGLiteHashMultiSet);
    property  Count: SizeInt read FCount;
  { returs number of distinct keys }
    property  EntryCount: SizeInt read GetEntryCount; //dimension, Count - cardinality
    property  Capacity: SizeInt read GetCapacity;
    property  LoadFactor: Single read GetLoadFactor write SetLoadFactor;
    property  FillRatio: Single read GetFillRatio;
  { The number of entries that can be written without rehashing }
    property  ExpandTreshold: SizeInt read GetExpandTreshold;
  { will return 0 if not contains an element aValue;
    will raise EArgumentException if one try to set negative multiplicity of a aValue }
    property  Counts[const aValue: T]: SizeInt read GetKeyCount write SetKeyCount; default;
  end;

  { TGLiteHashMultiSetLP implements open addressing hashmultiset with linear probing;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteHashMultiSetLP<T, TEqRel> = record
  private
  type
    TEntry = specialize TGMultiSetEntry<T>;
    TTable = specialize TGLiteHashTableLP<T, TEntry, TEqRel>;
  public
  type
    TMultiSet = specialize TGLiteHashMultiSet
      <T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  end;

  { TGLiteChainHashMultiSet implements node based hashmultiset with load factor 1.0;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGLiteChainHashMultiSet<T, TEqRel> = record
  private
  type
    TEntry = specialize TGMultiSetEntry<T>;
    TTable = specialize TGLiteChainHashTable<T, TEntry, TEqRel>;
  public
  type
    TMultiSet = specialize TGLiteHashMultiSet
      <T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  { returns True if aPerm is a combinatorial permutation of the elements of A }
    class function IsPermutation(const A, aPerm: array of T): Boolean; static;
  end;

  { TGLiteEquatableHashMultiSet: open addressing hashset with linear probing and
    constant load factor 0.5; for types having a defined fast operator "=";
      functor THashFun must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt; }
  generic TGLiteEquatableHashMultiSet<T, THashFun> = record
  private
  type
    TEntry = specialize TGMultiSetEntry<T>;
    TTable = specialize TGLiteEquatableHashTable<T, TEntry, THashFun>;
  public
  type
    TMultiSet = specialize TGLiteHashMultiSet
      <T, TEntry, TTable, TTable.TEnumerator, TTable.TRemovableEnumerator>;
  end;

  { TGThreadFGHashMultiSet: fine-grained concurrent multiset;
      functor TEqRel(equality relation) must provide:
        class function HashCode([const[ref]] aValue: T): SizeInt;
        class function Equal([const[ref]] L, R: T): Boolean; }
  generic TGThreadFGHashMultiSet<T, TEqRel> = class
  private
  type
    PNode = ^TNode;
    TNode = record
      Hash,
      Count: SizeInt;
      Value: T;
      Next: PNode;
    end;

    TSlot = record
    strict private
      FState: SizeUInt;
      class operator Initialize(var aSlot: TSlot);
    public
      Head: PNode;
      procedure Lock; inline;
      procedure Unlock; inline;
    end;

  var
    FSlotList: array of TSlot;
    FNodeCount,
    FCount: SizeInt;
    FLoadFactor: Single;
    FGlobLock: TMultiReadExclusiveWriteSynchronizer;
    function  NewNode(constref aValue: T; aHash: SizeInt): PNode;
    procedure FreeNode(aNode: PNode);
    function  GetCapacity: SizeInt;
    function  GetCount(const aValue: T): SizeInt;
    procedure ClearChainList;
    function  LockSlot(const aValue: T; out aHash: SizeInt): SizeInt;
    function  Find(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
    function  FindOrAdd(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
    function  RemoveNode(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
    procedure CheckNeedExpand;
    procedure Expand;
  public
  const
    MIN_LOAD_FACTOR: Single     = 0.5;
    MAX_LOAD_FACTOR: Single     = 8.0;
    DEFAULT_LOAD_FACTOR: Single = 1.0;

    constructor Create;
    constructor Create(aCapacity: SizeInt; aLoadFactor: Single = 1.0);
    destructor Destroy; override;
    procedure Add(const aValue: T);
    function  Contains(const aValue: T): Boolean;
    function  Remove(const aValue: T): Boolean; virtual;
    property  Count: SizeInt read FCount;
    property  Capacity: SizeInt read GetCapacity;
    property  LoadFactor: Single read FLoadFactor;
    property  EntryCount: SizeInt read FNodeCount;
  { will return 0 if not contains an element aValue }
    property  Counts[const aValue: T]: SizeInt read GetCount; default;
  end;

  { TGThreadHashMultiSetFG: fine-grained concurrent set attempt;
    it assumes that type T implements TEqRel }
  generic TGThreadHashMultiSetFG<T> = class(specialize TGThreadFGHashMultiSet<T, T>);

implementation
{$B-}{$COPERATORS ON}

{ TGAbstractHashMultiSet.TEnumerator }

function TGAbstractHashMultiSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

constructor TGAbstractHashMultiSet.TEnumerator.Create(ms: TAbstractHashMultiSet);
begin
  inherited Create(ms);
  FEnum := ms.FTable.GetEnumerator;
end;

destructor TGAbstractHashMultiSet.TEnumerator.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractHashMultiSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      Result := FEnum.MoveNext;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Count);
    end;
end;

procedure TGAbstractHashMultiSet.TEnumerator.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGAbstractHashMultiSet.TDistinctEnumerable }

function TGAbstractHashMultiSet.TDistinctEnumerable.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

constructor TGAbstractHashMultiSet.TDistinctEnumerable.Create(aSet: TAbstractHashMultiSet);
begin
  inherited Create(aSet);
  FEnum := aSet.FTable.GetEnumerator;
end;

destructor TGAbstractHashMultiSet.TDistinctEnumerable.Destroy;
begin
  FEnum.Free;
  inherited;
end;

function TGAbstractHashMultiSet.TDistinctEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractHashMultiSet.TDistinctEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractHashMultiSet.TEntryEnumerable }

function TGAbstractHashMultiSet.TEntryEnumerable.GetCurrent: TEntry;
begin
  Result := FEnum.Current^;
end;

constructor TGAbstractHashMultiSet.TEntryEnumerable.Create(aSet: TAbstractHashMultiSet);
begin
  inherited Create;
  FOwner := aSet;
  FEnum := aSet.FTable.GetEnumerator;
end;

destructor TGAbstractHashMultiSet.TEntryEnumerable.Destroy;
begin
  FEnum.Free;
  FOwner.EndIteration;
  inherited;
end;

function TGAbstractHashMultiSet.TEntryEnumerable.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGAbstractHashMultiSet.TEntryEnumerable.Reset;
begin
  FEnum.Reset;
end;

{ TGAbstractHashMultiSet }

function TGAbstractHashMultiSet.GetExpandTreshold: SizeInt;
begin
  Result := FTable.ExpandTreshold;
end;

procedure TGAbstractHashMultiSet.EntryRemoved(p: PEntry);
begin
  FCount -= p^.Count;
end;

function TGAbstractHashMultiSet.GetFillRatio: Single;
begin
  Result := FTable.FillRatio;
end;

function TGAbstractHashMultiSet.GetLoadFactor: Single;
begin
  Result := FTable.LoadFactor;
end;

procedure TGAbstractHashMultiSet.SetLoadFactor(aValue: Single);
begin
  FTable.LoadFactor := aValue;
end;

function TGAbstractHashMultiSet.GetCapacity: SizeInt;
begin
  Result := FTable.Capacity;
end;

function TGAbstractHashMultiSet.DoGetEnumerator: TSpecEnumerator;
begin
  Result := TEnumerator.Create(Self);
end;

procedure TGAbstractHashMultiSet.DoClear;
begin
  FTable.Clear;
  FCount := 0;
end;

procedure TGAbstractHashMultiSet.DoTrimToFit;
begin
  FTable.TrimToFit;
end;

procedure TGAbstractHashMultiSet.DoEnsureCapacity(aValue: SizeInt);
begin
  FTable.EnsureCapacity(aValue);
end;

function TGAbstractHashMultiSet.FindEntry(const aKey: T): PEntry;
var
  sr: TSearchResult;
begin
  Result := FTable.Find(aKey, sr);
end;

function TGAbstractHashMultiSet.FindOrAdd(const aKey: T; out p: PEntry): Boolean;
var
  sr: TSearchResult;
begin
  Result := FTable.FindOrAdd(aKey, p, sr);
  if not Result then
    begin
      p^.Key := aKey;
      p^.Count := 1;
    end;
end;

function TGAbstractHashMultiSet.DoSubEntry(const e: TEntry): Boolean;
var
  p: PEntry;
  sr: TSearchResult;
begin
  p := FTable.Find(e.Key, sr);
  if p <> nil then
    begin
      if p^.Count > e.Count then
        begin
          FCount -= e.Count;
          p^.Count -= e.Count;
        end
      else
        begin
          FCount -= p^.Count;
          FTable.RemoveAt(sr);
          exit(True);
        end;
    end;
  Result := False;
end;

function TGAbstractHashMultiSet.DoSymmSubEntry(const e: TEntry): Boolean;
var
  sr: TSearchResult;
  p: PEntry;
begin
  if FTable.FindOrAdd(e.Key, p, sr) then
    begin
      if p^.Count > e.Count then
        begin
          FCount -= e.Count;
          p^.Count -= e.Count;
        end
      else
        if p^.Count < e.Count then
          begin
            FCount -= p^.Count shl 1 - e.Count;
            p^.Count := e.Count - p^.Count;
          end
        else  // counts equals
          begin
            FCount -= p^.Count;
            FTable.RemoveAt(sr);
            exit(True);
          end;
    end
  else
    begin
      p^.Key := e.Key;
      p^.Count := e.Count;
      FCount += e.Count;
    end;
  Result := False;
end;

function TGAbstractHashMultiSet.DoExtract(const aKey: T): Boolean;
var
  p: PEntry;
  sr: TSearchResult;
begin
  p := FTable.Find(aKey, sr);
  Result := p <> nil;
  if Result then
    begin
      Dec(p^.Count);
      Dec(FCount);
      if p^.Count = 0 then
        FTable.RemoveAt(sr);
    end;
end;

function TGAbstractHashMultiSet.GetEntryCount: SizeInt;
begin
  Result := FTable.Count;
end;

function TGAbstractHashMultiSet.DoDoubleEntryCounters: SizeInt;
var
  p: PEntry;
begin
  Result := ElemCount;
  FCount += ElemCount;
  with FTable.GetEnumerator do
    try
      while MoveNext do
        begin
          p := Current;
          p^.Count += p^.Count;
        end;
    finally
      Free;
    end;
end;

function TGAbstractHashMultiSet.GetDistinct: IEnumerable;
begin
  Result := TDistinctEnumerable.Create(Self);
end;

function TGAbstractHashMultiSet.GetEntries: IEntryEnumerable;
begin
  Result := TEntryEnumerable.Create(Self);
end;

procedure TGAbstractHashMultiSet.DoIntersect(aSet: TSpecMultiSet);
var
  I{%H-}: TIntersectHelper;
begin
  I.FSet := Self;
  I.FOtherSet := aSet;
  FTable.RemoveIf(@I.OnIntersect, @EntryRemoved);
  Assert(@I = @I);//to supress hints
end;

function TGAbstractHashMultiSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractHashMultiSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractHashMultiSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGAbstractHashMultiSet.DoExtractIf(aTest: TTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

function TGAbstractHashMultiSet.DoExtractIf(aTest: TOnTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

function TGAbstractHashMultiSet.DoExtractIf(aTest: TNestTest): TArray;
var
  e: TExtractHelper;
begin
  e.Init;
  FTable.RemoveIf(aTest, @e.OnExtract);
  Result := e.Final;
  FCount -= System.Length(Result);
end;

class function TGAbstractHashMultiSet.DefaultLoadFactor: Single;
begin
  Result := GetTableClass.DefaultLoadFactor;
end;

class function TGAbstractHashMultiSet.MaxLoadFactor: Single;
begin
  Result := GetTableClass.MaxLoadFactor;
end;

class function TGAbstractHashMultiSet.MinLoadFactor: Single;
begin
  Result := GetTableClass.MinLoadFactor;
end;

constructor TGAbstractHashMultiSet.Create;
begin
  FTable := GetTableClass.Create;
end;

constructor TGAbstractHashMultiSet.Create(constref a: array of T);
begin
  FTable := GetTableClass.Create;
  DoAddAll(a);
end;

constructor TGAbstractHashMultiSet.Create(e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TAbstractHashMultiSet then
    CreateCopy(TAbstractHashMultiSet(o))
  else
    begin
      if o is TSpecMultiSet then
        Create(TSpecMultiSet(o).EntryCount)
      else
        Create;
      DoAddAll(e);
    end;
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt);
begin
  FTable := GetTableClass.Create(aCapacity);
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt; constref a: array of T);
begin
  FTable := GetTableClass.Create(aCapacity);
  DoAddAll(a);
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt; e: IEnumerable);
begin
  FTable := GetTableClass.Create(aCapacity);
  DoAddAll(e);
end;

constructor TGAbstractHashMultiSet.Create(aLoadFactor: Single);
begin
  FTable := GetTableClass.Create(aLoadFactor);
end;

constructor TGAbstractHashMultiSet.Create(aLoadFactor: Single; constref a: array of T);
begin
  FTable := GetTableClass.Create(aLoadFactor);
  DoAddAll(a);
end;

constructor TGAbstractHashMultiSet.Create(aLoadFactor: Single; e: IEnumerable);
var
  o: TObject;
begin
  o := e._GetRef;
  if o is TSpecMultiSet then
    Create(TSpecMultiSet(o).EntryCount, aLoadFactor)
  else
    Create(aLoadFactor);
  DoAddAll(e);
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single; constref a: array of T);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
  DoAddAll(a);
end;

constructor TGAbstractHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable);
begin
  FTable := GetTableClass.Create(aCapacity, aLoadFactor);
  DoAddAll(e);
end;

constructor TGAbstractHashMultiSet.CreateCopy(aMultiSet: TAbstractHashMultiSet);
var
  e: TEntry;
begin
  if aMultiSet.GetClass = GetClass then
    begin
      FTable := aMultiSet.FTable.Clone;
      FCount := aMultiSet.Count;
    end
  else
    begin
      FTable := GetTableClass.Create(aMultiSet.EntryCount);
      for e in aMultiSet.Entries do
        DoAddEntry(e);
    end;
end;

destructor TGAbstractHashMultiSet.Destroy;
begin
  DoClear;
  FTable.Free;
  inherited;
end;

function TGAbstractHashMultiSet.Clone: TAbstractHashMultiSet;
begin
  Result := GetClass.Create(Self);
end;

{ TGBaseHashMultiSetLP }

class function TGBaseHashMultiSetLP.GetTableClass: THashTableClass;
begin
  Result := specialize TGOpenAddrLP<T, TEntry, TEqRel>;
end;

class function TGBaseHashMultiSetLP.GetClass: THashMultiSetClass;
begin
  Result := TGBaseHashMultiSetLP;
end;

{ TGBaseHashMultiSetLPT }

function TGBaseHashMultiSetLPT.GetTombstonesCount: SizeInt;
begin
  Result := THashTableLPT(FTable).TombstonesCount;
end;

class function TGBaseHashMultiSetLPT.GetTableClass: THashTableClass;
begin
  Result := THashTableLPT;
end;

class function TGBaseHashMultiSetLPT.GetClass: THashMultiSetClass;
begin
  Result := TGBaseHashMultiSetLPT;
end;

procedure TGBaseHashMultiSetLPT.ClearTombstones;
begin
  THashTableLPT(FTable).ClearTombstones;
end;

{ TGBaseHashMultiSetQP }

function TGBaseHashMultiSetQP.GetTombstonesCount: SizeInt;
begin
  Result := THashTableQP(FTable).TombstonesCount;
end;

class function TGBaseHashMultiSetQP.GetTableClass: THashTableClass;
begin
  Result := THashTableQP;
end;

class function TGBaseHashMultiSetQP.GetClass: THashMultiSetClass;
begin
  Result := TGBaseHashMultiSetQP;
end;

procedure TGBaseHashMultiSetQP.ClearTombstones;
begin
  THashTableQP(FTable).ClearTombstones;
end;

{ TGBaseChainHashMultiSet }

class function TGBaseChainHashMultiSet.GetTableClass: THashTableClass;
begin
 Result := specialize TGChainHashTable<T, TEntry, TEqRel>;
end;

class function TGBaseChainHashMultiSet.GetClass: THashMultiSetClass;
begin
  Result := TGBaseChainHashMultiSet;
end;

{ TGCustomObjectHashMultiSet }

function TGCustomObjectHashMultiSet.DoSubEntry(const e: TEntry): Boolean;
begin
  Result := inherited DoSubEntry(e);
  if Result and OwnsObjects then
    e.Key.Free;
end;

function TGCustomObjectHashMultiSet.DoSymmSubEntry(const e: TEntry): Boolean;
begin
  Result := inherited DoSymmSubEntry(e);
  if Result and OwnsObjects then
    e.Key.Free;
end;

function TGCustomObjectHashMultiSet.DoRemove(const aKey: T): Boolean;
var
  p: PEntry;
  ItemPos: TSearchResult;
begin
  p := FTable.Find(aKey, ItemPos);
  Result := p <> nil;
  if Result then
    begin
      Dec(p^.Count);
      Dec(FCount);
      if p^.Count = 0 then
        begin
          FTable.RemoveAt(ItemPos);
          if OwnsObjects then
            aKey.Free;
        end;
    end;
end;

procedure TGCustomObjectHashMultiSet.DoClear;
var
  p: PEntry;
begin
  if OwnsObjects then
    for p in FTable do
      p^.Key.Free;
  inherited;
end;

procedure TGCustomObjectHashMultiSet.EntryRemoved(p: PEntry);
begin
  FCount -= p^.Count;
  if OwnsObjects then
    p^.Key.Free;
end;

procedure TGCustomObjectHashMultiSet.DoIntersect(aSet: TSpecMultiSet);
var
  {%H-}I: TIntersectHelper;
begin
  I.FSet := Self;
  I.FOtherSet := aSet;
  FTable.RemoveIf(@I.OnIntersect, @EntryRemoved);
  Assert(@I = @I);//to supress hints
end;

function TGCustomObjectHashMultiSet.DoRemoveIf(aTest: TTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGCustomObjectHashMultiSet.DoRemoveIf(aTest: TOnTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

function TGCustomObjectHashMultiSet.DoRemoveIf(aTest: TNestTest): SizeInt;
begin
  Result := ElemCount;
  FTable.RemoveIf(aTest, @EntryRemoved);
  Result -= ElemCount;
end;

constructor TGCustomObjectHashMultiSet.Create(aOwnsObjects: Boolean);
begin
  inherited Create;
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(a);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(e);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, a);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, e);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aLoadFactor: Single; const a: array of T; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, a);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aLoadFactor: Single; e: IEnumerable; aOwnsObjects: Boolean);
begin
  inherited Create(aLoadFactor, e);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single; aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single; const a: array of T;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, a);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single; e: IEnumerable;
  aOwnsObjects: Boolean);
begin
  inherited Create(aCapacity, aLoadFactor, e);
  FOwnsObjects := aOwnsObjects;
end;

constructor TGCustomObjectHashMultiSet.CreateCopy(aMultiSet: TGCustomObjectHashMultiSet);
begin
  inherited CreateCopy(aMultiSet);
  FOwnsObjects := aMultiSet.OwnsObjects;
end;

{ TGObjectHashMultiSetLP }

class function TGObjectHashMultiSetLP.GetTableClass: THashTableClass;
begin
  Result := specialize TGOpenAddrLP<T, TEntry, TEqRel>;
end;

class function TGObjectHashMultiSetLP.GetClass: THashMultiSetClass;
begin
  Result := TGObjectHashMultiSetLP;
end;

function TGObjectHashMultiSetLP.Clone: TGObjectHashMultiSetLP;
begin
  Result := TGObjectHashMultiSetLP.CreateCopy(Self);
end;

{ TGObjectHashMultiSetLPT }

function TGObjectHashMultiSetLPT.GetTombstonesCount: SizeInt;
begin
  Result := THashTableLPT(FTable).TombstonesCount;
end;

class function TGObjectHashMultiSetLPT.GetTableClass: THashTableClass;
begin
  Result := THashTableLPT;
end;

class function TGObjectHashMultiSetLPT.GetClass: THashMultiSetClass;
begin
  Result := TGObjectHashMultiSetLPT;
end;

function TGObjectHashMultiSetLPT.Clone: TGObjectHashMultiSetLPT;
begin
  Result := TGObjectHashMultiSetLPT.CreateCopy(Self);
end;

procedure TGObjectHashMultiSetLPT.ClearTombstones;
begin
  THashTableLPT(FTable).ClearTombstones;
end;

{ TGObjectHashMultiSetQP }

function TGObjectHashMultiSetQP.GetTombstonesCount: SizeInt;
begin
  Result := THashTableQP(FTable).TombstonesCount;
end;

class function TGObjectHashMultiSetQP.GetTableClass: THashTableClass;
begin
  Result := THashTableQP;
end;

class function TGObjectHashMultiSetQP.GetClass: THashMultiSetClass;
begin
  Result := TGObjectHashMultiSetQP;
end;

function TGObjectHashMultiSetQP.Clone: TGObjectHashMultiSetQP;
begin
  Result := TGObjectHashMultiSetQP.CreateCopy(Self);
end;

procedure TGObjectHashMultiSetQP.ClearTombstones;
begin
  THashTableQP(FTable).ClearTombstones;
end;

{ TGObjectChainHashMultiSet }

class function TGObjectChainHashMultiSet.GetTableClass: THashTableClass;
begin
  Result := specialize TGChainHashTable<T, TEntry, TEqRel>;
end;

class function TGObjectChainHashMultiSet.GetClass: THashMultiSetClass;
begin
  Result := TGObjectChainHashMultiSet;
end;

function TGObjectChainHashMultiSet.Clone: TGObjectChainHashMultiSet;
begin
  Result := TGObjectChainHashMultiSet.CreateCopy(Self);
end;

{ TGLiteHashMultiSet.TEnumerator }

function TGLiteHashMultiSet.TEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

function TGLiteHashMultiSet.TEnumerator.MoveNext: Boolean;
begin
  Result := FCurrKeyCount > 0;
  FCurrKeyCount -= Ord(Result);
  if not Result then
    begin
      Result := FEnum.MoveNext;
      if Result then
        FCurrKeyCount := Pred(FEnum.Current^.Count);
    end;
end;

procedure TGLiteHashMultiSet.TEnumerator.Reset;
begin
  FEnum.Reset;
  FCurrKeyCount := 0;
end;

{ TGLiteHashMultiSet.TDistinctEnumerator }

function TGLiteHashMultiSet.TDistinctEnumerator.GetCurrent: T;
begin
  Result := FEnum.Current^.Key;
end;

function TGLiteHashMultiSet.TDistinctEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGLiteHashMultiSet.TDistinctEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGLiteHashMultiSet.TEntryEnumerator }

function TGLiteHashMultiSet.TEntryEnumerator.GetCurrent: TEntry;
begin
  Result := FEnum.Current^;
end;

function TGLiteHashMultiSet.TEntryEnumerator.MoveNext: Boolean;
begin
  Result := FEnum.MoveNext;
end;

procedure TGLiteHashMultiSet.TEntryEnumerator.Reset;
begin
  FEnum.Reset;
end;

{ TGLiteHashMultiSet.TDistinct }

function TGLiteHashMultiSet.TDistinct.GetEnumerator: TDistinctEnumerator;
begin
  Result := FMultiset^.GetDistinctEnumerator;
end;

{ TGLiteHashMultiSet.TEntries }

function TGLiteHashMultiSet.TEntries.GetEnumerator: TEntryEnumerator;
begin
  Result := FMultiset^.GetEntryEnumerator;
end;

{ TGLiteHashMultiSet }

function TGLiteHashMultiSet.GetEntryCount: SizeInt;
begin
  Result := FTable.Count;
end;

function TGLiteHashMultiSet.GetExpandTreshold: SizeInt;
begin
  Result := FTable.ExpandTreshold;
end;

function TGLiteHashMultiSet.GetCapacity: SizeInt;
begin
  Result := FTable.Capacity;
end;

function TGLiteHashMultiSet.GetFillRatio: Single;
begin
  Result := FTable.FillRatio;
end;

function TGLiteHashMultiSet.GetLoadFactor: Single;
begin
  Result := FTable.LoadFactor;
end;

procedure TGLiteHashMultiSet.SetLoadFactor(aValue: Single);
begin
  FTable.LoadFactor := aValue;
end;

function TGLiteHashMultiSet.GetKeyCount(const aKey: T): SizeInt;
var
  p: PEntry;
begin
  p := FTable.Find(aKey);
  if p <> nil then
    Result := p^.Count
  else
    Result := 0;
end;

procedure TGLiteHashMultiSet.SetKeyCount(const aKey: T; aValue: SizeInt);
var
  p: PEntry;
  Pos: SizeInt;
begin
  if aValue < 0 then
    raise EArgumentException.Create(SECantAcceptNegCount);
  if aValue > 0 then
    begin
      if FTable.FindOrAdd(aKey, p) then
        begin
          FCount += aValue - p^.Count;
          p^.Count := aValue;
        end
      else
        begin
          FCount += aValue;
          p^.Key := aKey;
          p^.Count := aValue;
        end;
    end
  else
    begin  // aValue = 0;
      p := FTable.Find(aKey, Pos);
      if p <> nil then
        begin
          FCount -= p^.Count;
          FTable.RemoveAt(Pos);
        end;
    end;
end;

class operator TGLiteHashMultiSet.Initialize(var ms: TGLiteHashMultiSet);
begin
  ms.FCount := 0;
end;

function TGLiteHashMultiSet.DefaultLoadFactor: Single;
begin
  Result := FTable.DEFAULT_LOAD_FACTOR;
end;

function TGLiteHashMultiSet.MaxLoadFactor: Single;
begin
  Result := FTable.MAX_LOAD_FACTOR;
end;

function TGLiteHashMultiSet.MinLoadFactor: Single;
begin
  Result := FTable.MIN_LOAD_FACTOR;
end;

function TGLiteHashMultiSet.GetEnumerator: TEnumerator;
begin
  with Result do
    begin
      FEnum := FTable.GetEnumerator;
      FCurrKeyCount := 0;
    end;
end;

function TGLiteHashMultiSet.GetDistinctEnumerator: TDistinctEnumerator;
begin
  Result.FEnum := FTable.GetEnumerator;
end;

function TGLiteHashMultiSet.GetEntryEnumerator: TEntryEnumerator;
begin
  Result.FEnum := FTable.GetEnumerator;
end;

function TGLiteHashMultiSet.Distinct: TDistinct;
begin
  Result.FMultiset := @Self;
end;

function TGLiteHashMultiSet.Entries: TEntries;
begin
  Result.FMultiset := @Self;
end;

function TGLiteHashMultiSet.ToArray: TArray;
var
  I: SizeInt = 0;
  v: T;
begin
  System.SetLength(Result, Count);
  for v in Self do
    begin
      Result[I] := v;
      Inc(I);
    end;
end;

function TGLiteHashMultiSet.ToEntryArray: TEntryArray;
var
  I: SizeInt = 0;
  e: TTblEnumerator;
begin
  System.SetLength(Result, EntryCount);
  e := FTable.GetEnumerator;
  while e.MoveNext do
    begin
      Result[I] := e.Current^;
      Inc(I);
    end;
end;

function TGLiteHashMultiSet.IsEmpty: Boolean;
begin
  Result := Count = 0;
end;

function TGLiteHashMultiSet.NonEmpty: Boolean;
begin
  Result := Count <> 0;
end;

procedure TGLiteHashMultiSet.Clear;
begin
  FTable.Clear;
  FCount := 0;
end;

procedure TGLiteHashMultiSet.MakeEmpty;
begin
  FTable.MakeEmpty;
  FCount := 0;
end;

procedure TGLiteHashMultiSet.TrimToFit;
begin
  FTable.TrimToFit;
end;

procedure TGLiteHashMultiSet.EnsureCapacity(aValue: SizeInt);
begin
  FTable.EnsureCapacity(aValue);
end;

function TGLiteHashMultiSet.Contains(const aValue: T): Boolean;
begin
  Result := FTable.Find(aValue) <> nil;
end;

function TGLiteHashMultiSet.NonContains(const aValue: T): Boolean;
begin
  Result := FTable.Find(aValue) = nil;
end;

function TGLiteHashMultiSet.FindFirst(out aValue: T): Boolean;
begin
  Result := FTable.FindFirstKey(aValue);
end;

function TGLiteHashMultiSet.ContainsAny(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if NonEmpty then
    for I := 0 to System.High(a) do
      if Contains(a[I]) then
        exit(True);
  Result := False;
end;

function TGLiteHashMultiSet.ContainsAny(e: IEnumerable): Boolean;
begin
  if NonEmpty then
    with e.GetEnumerator do
      try
        while MoveNext do
          if Contains(Current) then
            exit(True);
      finally
        Free;
      end
  else
    e.Discard;
  Result := False;
end;

function TGLiteHashMultiSet.ContainsAny(constref aSet: TGLiteHashMultiSet): Boolean;
begin
  if @aSet <> @Self then
    begin
      if NonEmpty then
        with aSet.Distinct.GetEnumerator do
          while MoveNext do
            if Contains(Current) then
              exit(True);
      Result := False;
    end
  else
    Result := True;
end;

function TGLiteHashMultiSet.ContainsAll(const a: array of T): Boolean;
var
  I: SizeInt;
begin
  if IsEmpty then exit(System.Length(a) = 0);
  for I := 0 to System.High(a) do
    if NonContains(a[I]) then
      exit(False);
  Result := True;
end;

function TGLiteHashMultiSet.ContainsAll(e: IEnumerable): Boolean;
begin
  if IsEmpty then exit(e.None);
  with e.GetEnumerator do
    try
      while MoveNext do
        if not Contains(Current) then
          exit(False);
    finally
      Free;
    end;
  Result := True;
end;

function TGLiteHashMultiSet.ContainsAll(constref aSet: TGLiteHashMultiSet): Boolean;
var
  e: TTblEnumerator;
  p: PEntry;
begin
  if @aSet = @Self then
    exit(True);
  if (Count >= aSet.Count) and (EntryCount >= aSet.EntryCount) then
    begin
      e := aSet.FTable.GetEnumerator;
      while e.MoveNext do
        begin
          p := e.Current;
          if GetKeyCount(p^.Key) < p^.Count then
            exit(False);
        end;
      Result := True;
    end
  else
    Result := False;
end;

procedure TGLiteHashMultiSet.Add(const aValue: T);
var
  p: PEntry;
begin
  Inc(FCount);
  if FTable.FindOrAdd(aValue, p) then
    Inc(p^.Count)
  else
    begin
      p^.Key := aValue;
      p^.Count := 1;
    end;
end;

function TGLiteHashMultiSet.AddAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  for I := 0 to System.High(a) do
    Add(a[I]);
  Result := Count - Result;
end;

function TGLiteHashMultiSet.AddAll(e: IEnumerable): SizeInt;
begin
  Result := Count;
  with e.GetEnumerator do
    try
      while MoveNext do
        Add(Current);
    finally
      Free;
    end;
  Result := Count - Result;
end;

function TGLiteHashMultiSet.AddAll(constref aSet: TGLiteHashMultiSet): SizeInt;
begin
  Result := Count;
  Join(aSet);
  Result := Count - Result;
end;

function TGLiteHashMultiSet.Remove(const aValue: T): Boolean;
begin
  Result := Extract(aValue);
end;

function TGLiteHashMultiSet.RemoveAll(const a: array of T): SizeInt;
var
  I: SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      for I := 0 to System.High(a) do
        if Remove(a[I]) and IsEmpty then
          break;
      Result -= Count;
    end;
end;

function TGLiteHashMultiSet.RemoveAll(e: IEnumerable): SizeInt;
begin
  Result := Count;
  if Result > 0 then
    begin
      with e.GetEnumerator do
        try
          while MoveNext do
            if Remove(Current) and IsEmpty then
              break;
        finally
          Free;
        end;
      Result -= Count;
    end
  else
    e.Discard;
end;

function TGLiteHashMultiSet.RemoveAll(constref aSet: TGLiteHashMultiSet): SizeInt;
begin
  Result := Count;
  SymmetricSubtract(aSet);
  Result -= Count;
end;

function TGLiteHashMultiSet.RemoveIf(aTest: TTest): SizeInt;
var
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  Result := Count;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          FCount -= p^.Count;
          e.RemoveCurrent;
        end
    end;
  Result -= Count;
end;

function TGLiteHashMultiSet.RemoveIf(aTest: TOnTest): SizeInt;
var
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  Result := Count;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          FCount -= p^.Count;
          e.RemoveCurrent;
        end
    end;
  Result -= Count;
end;

function TGLiteHashMultiSet.RemoveIf(aTest: TNestTest): SizeInt;
var
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  Result := Count;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          FCount -= p^.Count;
          e.RemoveCurrent;
        end
    end;
  Result -= Count;
end;

function TGLiteHashMultiSet.Extract(const aValue: T): Boolean;
var
  p: PEntry;
  Pos: SizeInt;
begin
  p := FTable.Find(aValue, Pos);
  Result := p <> nil;
  if Result then
    begin
      Dec(p^.Count);
      Dec(FCount);
      if p^.Count = 0 then
        FTable.RemoveAt(Pos);
    end;
end;

function TGLiteHashMultiSet.ExtractIf(aTest: TTest): TArray;
var
  I, Last: SizeInt;
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  I := 0;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          Last := Pred(I + p^.Count);
          FCount -= p^.Count;
          if Last >= System.Length(Result) then
            System.SetLength(Result, RoundUpTwoPower(Succ(Last)));
          for I := I to Last do
            Result[I] := p^.Key;
          e.RemoveCurrent;
          I := Succ(Last);
        end;
    end;
  System.SetLength(Result, I);
end;

function TGLiteHashMultiSet.ExtractIf(aTest: TOnTest): TArray;
var
  I, Last: SizeInt;
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  I := 0;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          Last := Pred(I + p^.Count);
          FCount -= p^.Count;
          if Last >= System.Length(Result) then
            System.SetLength(Result, RoundUpTwoPower(Succ(Last)));
          for I := I to Last do
            Result[I] := p^.Key;
          e.RemoveCurrent;
          I := Succ(Last);
        end;
    end;
  System.SetLength(Result, I);
end;

function TGLiteHashMultiSet.ExtractIf(aTest: TNestTest): TArray;
var
  I, Last: SizeInt;
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  System.SetLength(Result, ARRAY_INITIAL_SIZE);
  I := 0;
  e := FTable.GetRemovableEnumerator;
  while e.MoveNext do
    begin
      p := e.Current;
      if aTest(p^.Key) then
        begin
          Last := Pred(I + p^.Count);
          FCount -= p^.Count;
          if Last >= System.Length(Result) then
            System.SetLength(Result, RoundUpTwoPower(Succ(Last)));
          for I := I to Last do
            Result[I] := p^.Key;
          e.RemoveCurrent;
          I := Succ(Last);
        end;
    end;
  System.SetLength(Result, I);
end;

procedure TGLiteHashMultiSet.RetainAll(aCollection: ICollection);
begin
  RemoveIf(@aCollection.NonContains);
end;

function TGLiteHashMultiSet.IsSuperSet(constref aSet: TGLiteHashMultiSet): Boolean;
begin
  Result := ContainsAll(aSet);
end;

function TGLiteHashMultiSet.IsSubSet(constref aSet: TGLiteHashMultiSet): Boolean;
begin
  Result := aSet.ContainsAll(Self);
end;

function TGLiteHashMultiSet.IsEqual(constref aSet: TGLiteHashMultiSet): Boolean;
var
  e: TTblEnumerator;
  p: PEntry;
begin
  if @aSet = @Self then
    exit(True);
  if (aSet.Count = Count) and (aSet.EntryCount = EntryCount) then
    begin
      e := FTable.GetEnumerator;
      while e.MoveNext do
        begin
          p := e.Current;
          if aSet[p^.Key] <> p^.Count then
            exit(False);
        end;
      Result := True;
    end
  else
    Result := False;
end;

function TGLiteHashMultiSet.Intersecting(constref aSet: TGLiteHashMultiSet): Boolean;
var
  e: TTblEnumerator;
begin
  if @aSet = @Self then
    exit(True);
  e := FTable.GetEnumerator;
  while e.MoveNext do
    if aSet.Contains(e.Current^.Key) then
      exit(True);
  Result := False;
end;

procedure TGLiteHashMultiSet.Intersect(constref aSet: TGLiteHashMultiSet);
var
  cnt: SizeInt;
  e: TTblRemovableEnumerator;
  p: PEntry;
begin
  if @aSet <> @Self then
    begin
      e := FTable.GetRemovableEnumerator;
      while e.MoveNext do
        begin
          p := e.Current;
          cnt := aSet[p^.Key];
          if cnt <> 0 then
            begin
              if cnt < p^.Count then
                begin
                  FCount -= p^.Count - cnt;
                  p^.Count := cnt;
                end;
            end
          else
            begin
              FCount -= p^.Count;
              e.RemoveCurrent;
            end;
        end;
    end;
end;

procedure TGLiteHashMultiSet.Join(constref aSet: TGLiteHashMultiSet);
var
  e: TTblEnumerator;
  p, ps: PEntry;
begin
  if @aSet = @Self then
    begin
      e := FTable.GetEnumerator;
      while e.MoveNext do
        begin
          p := e.Current;
          p^.Count += p^.Count;
        end;
      FCount += FCount;
      exit;
    end;
  e := aSet.FTable.GetEnumerator;
  while e.MoveNext do
    begin
      ps := e.Current;
      if not FTable.FindOrAdd(ps^.Key, p) then
        begin
          p^.Key := ps^.Key;
          p^.Count := ps^.Count;
          FCount += ps^.Count;
        end
      else
        if ps^.Count > p^.Count then
          begin
            FCount += ps^.Count - p^.Count;
            p^.Count := ps^.Count;
          end;
    end;
end;

procedure TGLiteHashMultiSet.ArithmeticAdd(constref aSet: TGLiteHashMultiSet);
var
  e: TTblEnumerator;
  p, ps: PEntry;
begin
  if @aSet <> @Self then
    begin
      e := aSet.FTable.GetEnumerator;
      while e.MoveNext do
        begin
          ps := e.Current;
          FCount += ps^.Count;
          if FTable.FindOrAdd(ps^.Key, p) then
            p^.Count += ps^.Count
          else
            begin
              p^.Key := ps^.Key;
              p^.Count := ps^.Count;
            end;
        end
    end
  else
    begin
      FCount += FCount;
      e := FTable.GetEnumerator;
      while e.MoveNext do
        begin
          p := e.Current;
          p^.Count += p^.Count;
        end;
    end;
end;

procedure TGLiteHashMultiSet.ArithmeticSubtract(constref aSet: TGLiteHashMultiSet);
var
  e: TTblEnumerator;
  p, ps: PEntry;
  Pos: SizeInt;
begin
  if @aSet <> @Self then
    begin
      e := aSet.FTable.GetEnumerator;
      while e.MoveNext do
        begin
          ps := e.Current;
          p := FTable.Find(ps^.Key, Pos);
          if p <> nil then
            begin
              if ps^.Count < p^.Count then
                begin
                  FCount -= ps^.Count;
                  p^.Count -= ps^.Count;
                end
              else
                begin
                  FCount -= p^.Count;
                  FTable.RemoveAt(Pos);
                end;
            end;
        end;
    end
  else
    Clear;
end;

procedure TGLiteHashMultiSet.SymmetricSubtract(constref aSet: TGLiteHashMultiSet);
var
  e: TTblEnumerator;
  p, ps: PEntry;
  Pos: SizeInt;
begin
  if @aSet <> @Self then
    begin
      e := aSet.FTable.GetEnumerator;
      while e.MoveNext do
        begin
          ps := e.Current;
          if FTable.FindOrAdd(ps^.Key, p, Pos) then
            begin
              if p^.Count > ps^.Count then
                begin
                  FCount -= ps^.Count;
                  p^.Count -= ps^.Count;
                end
              else
                if p^.Count < ps^.Count then
                  begin
                    FCount -= p^.Count shl 1 - ps^.Count;
                    p^.Count := ps^.Count - p^.Count;
                  end
                else  // counts equals
                  begin
                    FCount -= p^.Count;
                    FTable.RemoveAt(Pos);
                  end;
            end
          else
            begin
              p^.Key := ps^.Key;
              p^.Count := ps^.Count;
              FCount += ps^.Count;
            end;
        end;
    end
  else
    Clear;
end;

{ TGLiteChainHashMultiSet }

class function TGLiteChainHashMultiSet.IsPermutation(const A, aPerm: array of T): Boolean;
var
  ms: TMultiSet;
begin
  if System.Length(A) = 0 then
    exit(System.Length(aPerm) = 0);
  if System.Length(A) <> System.Length(aPerm) then
    exit(False);
  ms.AddAll(A);
  ms.RemoveAll(aPerm);
  Result := ms.IsEmpty;
end;

{ TGThreadFGHashMultiSet.TSlot }

class operator TGThreadFGHashMultiSet.TSlot.Initialize(var aSlot: TSlot);
begin
  aSlot.FState := 0;
  aSlot.Head := nil;
end;

procedure TGThreadFGHashMultiSet.TSlot.Lock;
begin
{$IFDEF CPU64}
  while Boolean(InterlockedExchange64(FState, SizeUInt(1))) do
{$ELSE CPU64}
  while Boolean(InterlockedExchange(FState, SizeUInt(1))) do
{$ENDIF CPU64}
    ThreadSwitch;
end;

procedure TGThreadFGHashMultiSet.TSlot.Unlock;
begin
{$IFDEF CPU64}
  InterlockedExchange64(FState, SizeUInt(0));
{$ELSE CPU64}
  InterlockedExchange(FState, SizeUInt(0));
{$ENDIF CPU64}
end;

{ TGThreadFGHashMultiSet }

function TGThreadFGHashMultiSet.NewNode(constref aValue: T; aHash: SizeInt): PNode;
begin
  New(Result);
  Result^.Hash := aHash;
  Result^.Count := 0;
  Result^.Value := aValue;
{$IFDEF CPU64}
  InterlockedIncrement64(FNodeCount);
{$ELSE CPU64}
  InterlockedIncrement(FNodeCount);
{$ENDIF CPU64}
end;

procedure TGThreadFGHashMultiSet.FreeNode(aNode: PNode);
begin
  if aNode <> nil then
    begin
      aNode^.Value := Default(T);
      Dispose(aNode);
    {$IFDEF CPU64}
      InterlockedDecrement64(FNodeCount);
    {$ELSE CPU64}
      InterlockedDecrement(FNodeCount);
    {$ENDIF CPU64}
    end;
end;

function TGThreadFGHashMultiSet.GetCapacity: SizeInt;
begin
  FGlobLock.BeginRead;
  try
    Result := System.Length(FSlotList);
  finally
    FGlobLock.EndRead;
  end;
end;

function TGThreadFGHashMultiSet.GetCount(const aValue: T): SizeInt;
var
  SlotIdx, Hash: SizeInt;
  Node: PNode;
begin
  Result := 0;
  SlotIdx := LockSlot(aValue, Hash);
  try
    Node := Find(aValue, SlotIdx, Hash);
    if Node <> nil then
      Result += Node^.Count;
  finally
    FSlotList[SlotIdx].Unlock;
  end;
end;

procedure TGThreadFGHashMultiSet.ClearChainList;
var
  Node, Next: PNode;
  I: SizeInt;
begin
  for I := 0 to System.High(FSlotList) do
    begin
      Node := FSlotList[I].Head;
      while Node <> nil do
        begin
          Next := Node^.Next;
          Node^.Value := Default(T);
          Dispose(Node);
          Node := Next;
        end;
    end;
  FSlotList := nil;
end;

function TGThreadFGHashMultiSet.LockSlot(const aValue: T; out aHash: SizeInt): SizeInt;
begin
  aHash := TEqRel.HashCode(aValue);
  FGlobLock.BeginRead;
  try
    Result := aHash and System.High(FSlotList);
    FSlotList[Result].Lock;
  finally
    FGlobLock.EndRead;
  end;
end;

function TGThreadFGHashMultiSet.Find(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
var
  Node: PNode;
begin
  Node := FSlotList[aSlotIdx].Head;
  while Node <> nil do
    begin
      if (Node^.Hash = aHash) and TEqRel.Equal(Node^.Value, aValue) then
        exit(Node);
      Node := Node^.Next;
    end;
  Result := nil;
end;

function TGThreadFGHashMultiSet.FindOrAdd(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
begin
  Result := Find(aValue, aSlotIdx, aHash);
  if Result = nil then
    begin
      Result := NewNode(aValue, aHash);
      Result^.Next := FSlotList[aSlotIdx].Head;
      FSlotList[aSlotIdx].Head := Result;
    end;
end;

function TGThreadFGHashMultiSet.RemoveNode(const aValue: T; aSlotIdx: SizeInt; aHash: SizeInt): PNode;
var
  Node: PNode;
  Prev: PNode = nil;
begin
  Node := FSlotList[aSlotIdx].Head;
  while Node <> nil do
    begin
      if (Node^.Hash = aHash) and TEqRel.Equal(Node^.Value, aValue) then
        begin
          if Node^.Count = 1 then
            if Prev <> nil then
              Prev^.Next := Node^.Next
            else
              FSlotList[aSlotIdx].Head := Node^.Next;
          exit(Node);
        end;
      Prev := Node;
      Node := Node^.Next;
    end;
  Result := nil;
end;

procedure TGThreadFGHashMultiSet.CheckNeedExpand;
begin
  if EntryCount > Succ(Trunc(System.Length(FSlotList) * FLoadFactor)) then
    begin
      FGlobLock.BeginWrite;
      try
        if EntryCount > Succ(Trunc(System.Length(FSlotList) * FLoadFactor)) then
          Expand;
      finally
        FGlobLock.EndWrite;
      end;
    end;
end;

procedure TGThreadFGHashMultiSet.Expand;
var
  I, Len, Mask: SizeInt;
  Node, Next: PNode;
  Head: PNode = nil;
begin
  Len := System.Length(FSlotList);
  for I := 0 to Pred(Len) do
    FSlotList[I].Lock;
  try
    for I := 0 to Pred(Len) do
      begin
        Node := FSlotList[I].Head;
        while Node <> nil do
          begin
            Next := Node^.Next;
            Node^.Next := Head;
            Head := Node;
            Node := Next;
          end;
        FSlotList[I].Head := nil;
      end;
     Mask := Pred(Len * 2);
     System.SetLength(FSlotList, Succ(Mask));
     Node := Head;
     while Node <> nil do
       begin
         I := Node^.Hash and Mask;
         Next := Node^.Next;
         Node^.Next := FSlotList[I].Head;
         FSlotList[I].Head := Node;
         Node := Next;
       end;
  finally
    for I := Pred(Len) downto 0 do
      FSlotList[I].Unlock;
  end;
end;

constructor TGThreadFGHashMultiSet.Create;
begin
  FLoadFactor := DEFAULT_LOAD_FACTOR;
  System.SetLength(FSlotList, DEFAULT_CONTAINER_CAPACITY);
  FGlobLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

constructor TGThreadFGHashMultiSet.Create(aCapacity: SizeInt; aLoadFactor: Single);
var
  RealCap: SizeInt;
begin
  if aLoadFactor < MIN_LOAD_FACTOR then
    aLoadFactor := MIN_LOAD_FACTOR
  else
    if aLoadFactor > MAX_LOAD_FACTOR then
      aLoadFactor := MAX_LOAD_FACTOR;
  FLoadFactor := aLoadFactor;
  if aCapacity < DEFAULT_CONTAINER_CAPACITY then
    aCapacity := DEFAULT_CONTAINER_CAPACITY;
  RealCap := RoundUpTwoPower(aCapacity);
  System.SetLength(FSlotList, RealCap);
  FGlobLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

destructor TGThreadFGHashMultiSet.Destroy;
begin
  FGlobLock.BeginWrite;
  try
    ClearChainList;
    inherited;
  finally
    FGlobLock.EndWrite;
    FGlobLock.Free;
  end;
end;

procedure TGThreadFGHashMultiSet.Add(const aValue: T);
var
  SlotIdx, Hash: SizeInt;
  Node: PNode;
  NodeAdded: Boolean;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Node := FindOrAdd(aValue, SlotIdx, Hash);
    NodeAdded := Node^.Count = 0;
    Inc(Node^.Count);
  {$IFDEF CPU64}
    InterlockedIncrement64(FCount);
  {$ELSE CPU64}
    InterlockedIncrement(FCount);
  {$ENDIF CPU64}
  finally
    FSlotList[SlotIdx].Unlock;
  end;
  if NodeAdded then
    CheckNeedExpand;
end;

function TGThreadFGHashMultiSet.Contains(const aValue: T): Boolean;
var
  SlotIdx, Hash: SizeInt;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Result := Find(aValue, SlotIdx, Hash) <> nil;
  finally
    FSlotList[SlotIdx].Unlock;
  end;
end;

function TGThreadFGHashMultiSet.Remove(const aValue: T): Boolean;
var
  SlotIdx, Hash: SizeInt;
  Node: PNode;
begin
  SlotIdx := LockSlot(aValue, Hash);
  try
    Node := RemoveNode(aValue, SlotIdx, Hash);
    Result := Node <> nil;
    if Result then
      begin
        Dec(Node^.Count);
      {$IFDEF CPU64}
        InterlockedDecrement64(FCount);
      {$ELSE CPU64}
        InterlockedDecrement(FCount);
      {$ENDIF CPU64}
        if Node^.Count = 0 then
          FreeNode(Node);
      end;
  finally
    FSlotList[SlotIdx].Unlock;
  end;
end;

end.

